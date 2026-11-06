# frozen_string_literal: true

module ProjectTools
  class Catalog
    # Keep independent verdicts separate, including skips on otherwise failed scenarios.
    module ConsoleReporting
      def present(result)
        if result[:kind] && result[:kind] != :skipped
          present_problem(result)
        else
          present_native(result)
        end
        present_cycle_skip(result) if result[:dependency_cycle_skip]
        present_coverage(result)
      end

      def present_problem(result)
        message = [result[:message], *deprecation_details(result)]
        message << "Deprecation detection error: #{result[:deprecation_error]}" if result[:deprecation_error]
        present_diagnostic(result[:name], problem_label(result), message.reject(&:empty?).join("\n"),
                           kind: result[:kind])
      end

      def present_native(result)
        remaining = result[:message].dup
        result.fetch(:native_diagnostics, []).each do |entry|
          remaining.sub!(entry[:message], '')
          present_diagnostic(result[:name], "Native Puppet #{entry[:level]}", entry[:message],
                             kind: entry[:level] == 'warning' ? :warning : :info, source: entry[:source])
        end
        present_diagnostic(result[:name], 'Native diagnostic', remaining, kind: :info) unless remaining.strip.empty?
      end

      def present_cycle_skip(result)
        message = ['Native resource validation prevented graph construction.',
                   'Cycle freedom was not checked.', result[:dependency_cycle_skip]].join("\n")
        present_diagnostic(result[:name], 'Dependency cycle check skipped', message, kind: :skipped)
      end

      def present_coverage(result)
        coverage = result[:coverage]
        return unless coverage && !coverage[:missing].empty?

        message = ['Missing definitions:', *coverage[:missing].sort.map { |name| "  - #{name}" }].join("\n")
        present_diagnostic(result[:name], "Coverage review: #{coverage[:compiled].size}/#{coverage[:total]}",
                           message, kind: :review)
      end

      def present_diagnostic(name, title, message, **metadata)
        @console.finding(message, title: title, subject: name, unit: 'scenario', **metadata)
      end

      def present_unselected
        message = 'Module has no catalog tests and contributes no selected scenarios.'
        Array(@skipped).each do |name|
          @console.finding(message, kind: :skipped, title: 'Module without catalog tests',
                                    subject: name, unit: 'module')
        end
      end
    end
  end
end
