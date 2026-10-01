# frozen_string_literal: true

require 'pathname'
require 'project_tools/shared/junit_report'

module ProjectTools
  module ModuleDependencies
    # Render the same deterministic relationships in both output formats.
    class Reporter
      def initialize(result, root)
        @result = result
        @root = root
      end

      def safe(value)
        value.to_s.encode('UTF-8', invalid: :replace, undef: :replace).gsub(/[[:cntrl:]]/, ' ')
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

      def console(output, errors)
        output.puts "Puppet module dependencies: #{@result.status.zero? ? 'PASSED' : 'FAILED'}"
        output.puts 'Declared dependencies satisfy the selected module versions.' if @result.status.zero?
        console_problems(output, errors)
        output.puts coverage
        output.puts format('Result: %<failures>d dependency conflicts, %<errors>d execution errors.', @result.counts)
      end

      def console_problems(output, errors)
        @result.sorted_problems.each do |problem|
          target = problem[:kind] == :error ? errors : output
          # Indentation and flattened fields prevent metadata becoming workflow commands.
          target.puts "\n  #{title(problem)}"
          details(problem).each_line { |line| target.puts "  #{line.chomp}" }
        end
      end
    end
  end
end
