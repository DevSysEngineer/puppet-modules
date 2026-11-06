# frozen_string_literal: true

require 'json'
require_relative 'parallel_result'
require_relative 'parallel_reports'

module ProjectTools
  # Combine validated results while keeping process errors distinct from native failures.
  class ParallelResults
    attr_reader :entries, :errors

    def initialize
      @entries = []
      @errors = []
      @identities = {}
      @reports = ParallelReports.new(errors)
    end

    def accept(config, status)
      data = ParallelResult.new(JSON.parse(File.read(config.fetch('result'))), config).validate
      entries << data
      check_identities(data)
      check_status(data, status)
      @reports.validate(data, config)
    rescue StandardError => e
      errors << "#{config['worker_id']}: #{e.class}: #{e.message}"
      []
    end

    def check_status(data, status)
      unless expected_status?(data, status)
        errors << "#{data['worker_id']}: unexpected process status #{status || 'unavailable'}."
      end
      errors << "#{data['worker_id']}: execution incomplete." if data['execution'] == 'incomplete'
      errors << "#{data['worker_id']}: #{data['report_error']}" if data['report_error']
    end

    def expected_status?(data, status)
      expected_exit = data['counts'].values_at('failures', 'errors').any?(&:positive?) ? 1 : 0
      status && !status.signaled? && status.exitstatus == expected_exit
    end

    def check_identities(data)
      data['cases'].each do |test|
        identity = test.values_at('class_name', 'test_name')
        errors << "Duplicate testcase: #{identity.join('#')}." if @identities.key?(identity)
        @identities[identity] = data['worker_id']
      end
    end

    def publish(paths, destination)
      @reports.publish(paths, destination)
    end

    def counts
      ParallelResult::COUNTS.to_h { |key| [key, entries.sum { |data| data['counts'][key] }] }
    end

    def finish(console, workers, destination)
      record_findings(console)
      workers.each { |worker| worker.record_output(console) }
      console.finish(status: status, execution: execution, facts: facts, report: report_path(destination))
    end

    def record_findings(console)
      entries.each { |data| record_cases(console, data) }
      errors.each { |error| console.finding(error, kind: :error, title: 'Test worker execution') }
    end

    def record_cases(console, data)
      cases = data['cases'].to_h { |test| [test.values_at('class_name', 'test_name'), test['outcome']] }
      data['findings'].each do |finding|
        key = finding.values_at('class_name', 'test_name')
        identity = key.compact.join('#')
        kind = { 'failure' => :failure, 'error' => :error, 'skipped' => :skipped }.fetch(cases[key], :info)
        console.finding(finding['message'], kind: kind, title: identity.empty? ? 'Worker diagnostic' : identity,
                                            subject: identity.empty? ? nil : identity, unit: 'test')
      end
    end

    def report_path(destination)
      "#{destination}/TEST-*.xml" if destination && errors.empty? && counts['tests'].positive?
    end

    def facts
      totals = counts.map { |key, value| "#{value} #{key}" }.join(', ')
      workers = entries.map do |data|
        duration = format('%.2f', data['duration_seconds'])
        "#{data['worker_id']}: seed=#{data['seed']} | duration=#{duration} s"
      end
      [totals, *workers]
    end

    def status
      return 'ERROR' unless errors.empty? && counts['errors'].zero?

      counts['failures'].positive? ? 'FAILED' : 'PASSED'
    end

    def execution
      return 'incomplete' unless errors.empty?
      return 'unknown (filtered total unavailable)' if entries.any? { |data| data['execution'] == 'unknown' }

      'complete'
    end
  end
end
