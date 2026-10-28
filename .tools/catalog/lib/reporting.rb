# frozen_string_literal: true

require 'tempfile'
require 'project_tools/shared/junit_report'

module ProjectTools
  class Catalog
    # Present catalog results through shared and retain scenario details in JUnit.
    module Reporting
      def invalid_report
        @console.finish(status: 'ERROR', execution: 'not executed', details: ['Expected a JUnit path ending in .xml.'])
        1
      end

      def present(result)
        if result[:kind]
          problem = result[:kind] == :failure ? 'Compilation failure' : 'Execution error'
          present_diagnostic(result[:name], problem, result[:message])
        else
          present_coverage(result)
          present_diagnostic(result[:name], 'Native diagnostic', result[:message]) unless result[:message].empty?
        end
      end

      def present_diagnostic(name, problem, message)
        @has_findings = true
        @console.finding("#{name} | #{problem}")
        @console.diagnostic(message)
      end

      def present_coverage(result)
        coverage = result[:coverage]
        return unless coverage && !coverage[:missing].empty?

        present_diagnostic(result[:name], "Coverage review: #{coverage[:compiled].size}/#{coverage[:total]}",
                           "Missing definitions: #{coverage[:missing].join(', ')}")
      end

      def summary_details(error)
        error || @has_findings ? ['See findings and diagnostics above.'] : []
      end

      def write_report(path)
        FileUtils.mkdir_p(File.dirname(path))
        Tempfile.create(['catalog-report-', '.xml'], File.dirname(path)) do |output|
          Shared::JunitReport.write(output, name: 'catalog', **counts) do |xml|
            @results.each { |result| write_case(xml, result) }
          end
          output.close
          File.rename(output.path, path)
        end
      rescue StandardError => e
        raise IOError, "Cannot write catalog JUnit report: #{e.message}"
      end

      def write_case(xml, result)
        xml.testcase(classname: 'catalog', name: result[:name]) do
          if result[:kind]
            type = result[:kind] == :failure ? 'CatalogFailure' : 'CompilerError'
            xml.tag!(result[:kind], report_details(result), type: type)
          else
            xml.tag!('system-out', report_details(result))
          end
        end
      end

      def report_details(result)
        lines = []
        lines << "Compiled #{result[:resources]} resources." if result[:resources]
        lines.concat(coverage_details(result[:coverage])) if result[:coverage]
        lines << result[:message] unless result[:message].empty?
        lines.join("\n")
      end

      def coverage_details(coverage)
        lines = ["Definition coverage: #{coverage[:compiled].size}/#{coverage[:total]}",
                 "Compiled definitions: #{coverage[:compiled].join(', ')}"]
        missing = coverage[:missing]
        lines << "Missing definitions (review required): #{missing.join(', ')}" unless missing.empty?
        lines
      end
    end
  end
end
