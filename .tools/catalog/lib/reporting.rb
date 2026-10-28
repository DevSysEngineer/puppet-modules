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
          present_diagnostic(result[:name], problem_label(result), diagnostic_details(result))
          present_coverage(result) if result[:resources]
        else
          present_coverage(result)
          present_diagnostic(result[:name], 'Native diagnostic', result[:message]) unless result[:message].empty?
        end
      end

      def problem_label(result)
        return 'Execution error' if result[:kind] == :error

        result[:cause] == :deprecation ? 'Deprecated Puppet usage' : 'Compilation failure'
      end

      def diagnostic_details(result)
        lines = [result[:message], *deprecation_details(result)]
        lines << "Deprecation detection error: #{result[:deprecation_error]}" if result[:deprecation_error]
        lines.reject(&:empty?).join("\n")
      end

      def deprecation_details(result)
        entries = result.fetch(:deprecations, [])
        return [] if entries.empty?

        # Native logging usually already contains the message and location; print it only once.
        missing = entries.reject { |entry| result[:message].include?(entry[:message]) }
        ["Native deprecations: #{entries.size}", *missing.map { |entry| deprecation_detail(entry) }]
      end

      def deprecation_detail(entry)
        location = [entry[:source], entry[:line]].compact.join(':')
        [entry[:message], (location unless location.empty?)].compact.join(' | ')
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
            type = 'Deprecation' if result[:kind] == :failure && result[:cause] == :deprecation
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
        diagnostic = diagnostic_details(result)
        lines << diagnostic unless diagnostic.empty?
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
