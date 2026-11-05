# frozen_string_literal: true

module ProjectTools
  module Shared
    # Keep complete diagnostics until final presentation, grouping only identical text per stream.
    class ConsoleFindings
      def initialize
        @streams = {}
      end

      def add(message, subject:, output:)
        groups = (@streams[output] ||= {})
        subjects = (groups[message.to_s] ||= [])
        subjects << subject if subject
      end

      def write
        @streams.each do |output, groups|
          output.puts 'Findings:'
          groups.sort_by { |message, subjects| [subjects.min.to_s, message] }.each do |message, subjects|
            Console.diagnostic(message, output: output)
            affected(subjects, output)
          end
        end
      end

      def affected(subjects, output)
        return if subjects.empty?

        lines = ['Affected:', *subjects.uniq.sort.map { |subject| "  - #{subject}" }]
        Console.diagnostic(lines.join("\n"), output: output)
      end
    end
  end
end
