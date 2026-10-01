# frozen_string_literal: true

module ProjectTools
  module ModuleDependencies
    # One scan result supplies console output, JUnit cases and the process status.
    class Result
      attr_reader :problems, :assessed, :unassessed

      def initialize
        @problems = []
        @assessed = []
        @unassessed = []
      end

      def error(reason, message, **context)
        @problems << { kind: :error, scope: 'scan', reason: reason, message: message, **context }
      end

      def conflict(reason, **context)
        messages = {
          missing: 'No selected module has the required Forge identity and usable metadata.',
          version_mismatch: 'The selected version does not satisfy the declared requirement.',
          non_semantic_version: 'The requirement or selected version cannot be interpreted semantically.'
        }
        @problems << { kind: :failure, reason: reason, message: messages.fetch(reason), **context }
      end

      def sorted_problems
        problems.uniq.sort_by do |problem|
          problem.values_at(:scope, :requester_name, :dependency_name, :reason, :version_requirement).map(&:to_s)
        end
      end

      def counts
        cases = sorted_problems
        { tests: [cases.length, 1].max, failures: cases.count { |p| p[:kind] == :failure },
          errors: cases.count { |p| p[:kind] == :error } }
      end

      def status
        return 2 if problems.any? { |problem| problem[:kind] == :error }

        problems.empty? ? 0 : 1
      end
    end
  end
end
