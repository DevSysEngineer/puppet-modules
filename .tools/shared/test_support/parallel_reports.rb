# frozen_string_literal: true

require 'rexml/document'
require 'tempfile'
require_relative 'parallel_result'

module ProjectTools
  # Publish native XML only after checking it against the independent worker result.
  class ParallelReports
    def initialize(errors)
      @errors = errors
      @published = {}
    end

    def check(condition, message)
      ParallelResult.check(condition, message)
    end

    def validate(data, config)
      paths = report_paths(data, config)
      cases = paths.flat_map { |path| read_cases(path) }
      return paths unless config['reports']

      assertions = cases.sum { |test| test.delete('assertions') }
      check(cases.tally == data['cases'].tally && assertions == data['counts']['assertions'],
            'JUnit testcases differ from worker result.')
      paths
    end

    def report_paths(data, config)
      names = data['junit_files']
      unless config['reports']
        check(names.empty?, 'Unexpected JUnit without a report request.')
        return []
      end
      actual = Dir.children(config['reports']).grep(/\ATEST-.*\.xml\z/).sort
      check(names.sort == actual && names.uniq == names, 'Missing or unlisted JUnit report.')
      names.map { |name| File.join(config['reports'], name) }
    end

    def read_cases(path)
      content = File.read(path)
      check(!content.include?('<!DOCTYPE'), 'Unexpected XML document type.')
      document = REXML::Document.new(content)
      check(document.root&.name == 'testsuites', 'Invalid JUnit root.')
      document.root.get_elements('testsuite').flat_map do |suite|
        cases = suite.get_elements('testcase').map { |test| case_record(test) }
        validate_suite(suite, cases)
        cases
      end
    end

    def case_record(test)
      outcome = %w[failure error skipped].find { |name| test.elements[name] } || 'passed'
      { 'class_name' => test.attributes['classname'], 'test_name' => test.attributes['name'],
        'outcome' => outcome, 'assertions' => Integer(test.attributes['assertions'], 10) }
    end

    def validate_suite(suite, cases)
      check(Integer(suite.attributes['tests'], 10) == cases.size, 'JUnit test count differs.')
      check(Integer(suite.attributes['assertions'], 10) == cases.sum { |test| test['assertions'] },
            'JUnit assertion count differs.')
      validate_outcomes(suite, cases)
    end

    def validate_outcomes(suite, cases)
      outcomes = cases.map { |test| test['outcome'] }.tally
      { 'failures' => 'failure', 'errors' => 'error', 'skipped' => 'skipped' }.each do |key, outcome|
        check(Integer(suite.attributes[key], 10) == outcomes.fetch(outcome, 0), "JUnit #{key} count differs.")
      end
    end

    def publish(paths, destination)
      paths.each do |path|
        name = File.basename(path)
        check(!@published.key?(name), "JUnit filename collision: #{name}.")
        replace(path, File.join(destination, name))
        @published[name] = true
      rescue StandardError => e
        @errors << "Cannot publish #{name}: #{e.class}: #{e.message}"
      end
    end

    def replace(source, destination)
      # Staging in the destination also works across filesystems.
      Tempfile.create(['.test-report-', '.xml'], File.dirname(destination)) do |file|
        file.binmode
        IO.copy_stream(source, file)
        file.close
        File.rename(file.path, destination)
      end
    end
  end
end
