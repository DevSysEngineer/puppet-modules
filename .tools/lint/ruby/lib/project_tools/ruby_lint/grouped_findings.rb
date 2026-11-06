# frozen_string_literal: true

require 'stringio'

module ProjectTools
  module RubyLint
    # Keep native progress live while rendering complete native diagnostics as CI findings.
    module GroupedFindings
      def initialize(output, options = {})
        @group_findings = ENV['GITHUB_ACTIONS'] == 'true' || ENV['GITLAB_CI'] == 'true'
        @findings_output = output
        super(@group_findings ? $stderr : output, options)
      end

      def finished(inspected_files)
        return super unless @group_findings

        output.puts
        report_summary(inspected_files.size, @total_offense_count, @total_correction_count,
                       @total_correctable_count)
        findings = Shared::ConsoleFindings.new(output: @findings_output)
        @offenses_for_files.each do |file, offenses|
          offenses.each { |offense| record_finding(findings, file, offense) }
        end
        findings.write
      end

      def file_started(file, data)
        return super unless @group_findings

        @failure_options = data.fetch(:cli_options)
        @failure_threshold = RuboCop::Cop::Severity.minimum_to_fail(@failure_options,
                                                                    data.fetch(:config_store).for_pwd)
        super
      end

      def record_finding(findings, file, offense)
        message = native_diagnostic(file, offense)
        findings.add(message, kind: finding_kind(offense), title: offense.cop_name,
                              source: "#{smart_path(file)}:#{offense.line}:#{offense.real_column}",
                              subject: smart_path(file), unit: 'file')
      end

      def native_diagnostic(file, offense)
        previous = @output
        previous_rainbow = @rainbow
        @output = StringIO.new
        @rainbow = Rainbow.new
        @rainbow.enabled = false
        report_file(file, [offense])
        @output.string
      ensure
        @output = previous
        @rainbow = previous_rainbow
      end

      def finding_kind(offense)
        return :info if offense.disabled?
        return :failure if @failure_options[:fail_level] == :autocorrect && offense.correctable?
        return :info if offense.corrected?

        offense.severity >= @failure_threshold ? :failure : :warning
      end
    end
  end
end
