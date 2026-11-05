# frozen_string_literal: true

module ProjectTools
  class Catalog
    # Keep exit policy, JUnit counts and console completeness consistent for partial checks.
    module Summary
      def counts
        { tests: @results.size, failures: @results.count { |result| result[:kind] == :failure },
          errors: @results.count { |result| result[:kind] == :error },
          skipped: @results.count { |result| result[:kind] == :skipped } }
      end

      def outcome(error)
        return 'ERROR' if error || counts[:errors].positive?
        return 'FAILED' if counts[:failures].positive?

        cycle_skips.positive? ? 'SKIPPED' : 'PASSED'
      end

      def cycle_skips
        @results.count { |result| result[:dependency_cycle_skip] }
      end

      def facts(error: nil)
        totals = counts
        selected = @scenarios ? @scenarios.size : 'unknown'
        checked = totals[:tests] - totals[:errors] - totals[:skipped]
        details = ["Scenarios: #{selected} selected | #{@processed} processed | #{checked} checked",
                   "Results: #{totals[:failures]} failures | #{totals[:errors] + (error ? 1 : 0)} errors"]
        details.concat(cycle_skip_summary)
        details << "Modules without tests: #{@skipped.size} skipped" if @skipped
        details
      end

      def cycle_skip_summary
        return [] if cycle_skips.zero?

        ["Dependency cycle checks: #{cycle_skips} skipped; cycle freedom was not checked for these scenarios"]
      end
    end
  end
end
