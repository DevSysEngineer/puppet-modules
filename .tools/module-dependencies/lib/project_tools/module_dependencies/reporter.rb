# frozen_string_literal: true

require 'pathname'
require 'project_tools/shared/junit_report'
require 'project_tools/shared/console'

module ProjectTools
  module ModuleDependencies
    # Render the same deterministic relationships in both output formats.
    class Reporter
      def initialize(result, root)
        @result = result
        @root = root
      end

      def safe(value)
        ProjectTools::Shared::Console.safe(value)
      end

      def path(value)
        return 'missing' unless value

        safe(Pathname.new(value).relative_path_from(Pathname.new(@root)).to_s)
      end

      def title(problem)
        requester = [problem[:requester_name] || 'dependency scan', problem[:requester_version]].compact.join(' ')
        return safe("#{problem[:scope]}: #{requester}; #{problem[:reason]}") unless problem[:dependency_name]

        safe("#{problem[:scope]}: #{requester} -> #{problem[:dependency_name]}; " \
             "requires #{problem[:version_requirement]}; selected #{problem[:selected_version] || 'missing'}")
      end

      def details(problem)
        lines = [safe("#{problem[:reason]}: #{problem[:message]}"),
                 "Request metadata: #{path(problem[:requester_metadata])}"]
        lines << "Selected metadata: #{path(problem[:selected_metadata])}" if problem[:dependency_name]
        lines.join("\n")
      end

      def coverage
        lines = ["Module metadata assessed: #{@result.assessed.length}.",
                 "Directories not assessed for metadata: #{@result.unassessed.length}."]
        @result.unassessed.sort.each { |directory| lines << "  #{path(directory)}" }
        lines.join("\n")
      end

      def write(output)
        ProjectTools::Shared::JunitReport.write(output, name: 'project-tools-module-dependencies',
                                                        **@result.counts) do |xml|
          if @result.problems.empty?
            xml.testcase(classname: 'project-tools-module-dependencies', name: 'Declared dependencies satisfied')
          end
          @result.sorted_problems.each { |problem| write_case(xml, problem) }
          xml.tag!('system-out', coverage)
        end
      end

      def write_case(xml, problem)
        xml.testcase(classname: 'project-tools-module-dependencies', name: title(problem)) do
          xml.tag!(problem.fetch(:kind), details(problem), type: safe(problem.fetch(:reason)))
        end
      end

      def console(presentation, errors, report: nil, error: nil)
        incomplete = error || @result.status == 2
        outcome = @result.status.zero? ? 'PASSED' : 'FAILED'
        presentation.finish(status: incomplete ? 'ERROR' : outcome, execution: incomplete ? 'incomplete' : 'complete',
                            facts: console_facts, report: report) do
          console_problems(presentation, errors)
          presentation.diagnostic(error, output: errors) if error
          presentation.diagnostic('Final report: not produced') if error
        end
      end

      def console_facts
        coverage.lines.map(&:chomp) +
          [format('Scan: %<failures>d dependency conflicts, %<errors>d execution errors.', @result.counts)]
      end

      def console_problems(presentation, errors)
        @result.sorted_problems.each do |problem|
          options = problem[:kind] == :error ? { output: errors } : {}
          presentation.diagnostic("#{title(problem)}\n#{details(problem)}", **options)
        end
      end
    end
  end
end
