# frozen_string_literal: true

require_relative 'console_group'

module ProjectTools
  module Shared
    # Explicit categories and complete diagnoses determine grouping, never text heuristics.
    class ConsoleFindings
      LABELS = { error: 'ERROR', failure: 'FAILED', skipped: 'SKIPPED', warning: 'WARNING',
                 review: 'REVIEW', info: 'INFO' }.freeze

      def initialize(output: $stdout)
        @output = output
        @streams = {}
      end

      def add(message, subject: nil, output: @output, **presentation)
        kind = presentation.fetch(:kind, :info)
        LABELS.fetch(kind)
        fields = [presentation.fetch(:title, 'Diagnostic'), presentation[:source], message,
                  presentation.fetch(:unit, 'item')]
        key = [kind, *fields.map { |value| value.to_s.dup }]
        subjects = ((@streams[output] ||= {})[key] ||= [])
        subjects << subject.to_s.dup if subject
      end

      def write(details: [], kind: :info)
        details.each { |message| add(message, kind: kind, title: 'Execution details') }
        headers = {}
        entries.sort_by { |_output, key, subjects| sort_key(key, subjects) }.each do |output, key, subjects|
          output.puts 'Findings:' unless headers[output]
          headers[output] = true
          render(output, key, subjects)
        end
      end

      def entries
        @streams.flat_map do |output, groups|
          groups.map { |key, subjects| [output, key, subjects.uniq.sort] }
        end
      end

      def sort_key(key, subjects)
        kind, title, source, message, unit = key
        [LABELS.keys.index(kind), title, source, message, unit, subjects.min.to_s]
      end

      def render(output, key, subjects)
        kind, title, source, _message, unit = key
        count = "#{subjects.size} #{unit}#{'s' unless subjects.one?}" unless subjects.empty?
        heading = ["[#{LABELS.fetch(kind)}] #{title}", count, source].compact.reject(&:empty?).join(' | ')
        write_group(output, heading, key, subjects, count)
        output.puts
        output.flush
      end

      def write_group(output, heading, key, subjects, count)
        _kind, _title, source, message = key
        ConsoleGroup.new(heading, output: output).during do |grouped|
          output.puts "  #{Console.safe(heading)}" unless grouped
          Console.diagnostic("Diagnostic:\n#{message}", output: output)
          Console.diagnostic("Location: #{source}", output: output) unless source.empty?
          affected(subjects, count, output)
        end
      end

      def affected(subjects, count, output)
        return if subjects.empty?

        lines = ["Affected (#{count}):", *subjects.map { |subject| "  - #{subject}" }]
        Console.diagnostic(lines.join("\n"), output: output)
      end
    end
  end
end
