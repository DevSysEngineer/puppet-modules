# frozen_string_literal: true

module ProjectTools
  class Catalog
    # Validate the worker protocol before applying the scenario quality policy.
    class WorkerResult
      def initialize(name, output, diagnostics, status)
        @name = name
        @output = output
        @kind = { 0 => nil, 1 => :failure }.fetch(status.exitstatus, :error)
        @diagnostics = diagnostics.empty? && @kind ? "Compiler process ended: #{status}" : diagnostics
      end

      def result
        details = @output.empty? && @kind ? {} : JSON.parse(@output, symbolize_names: true)
        return invalid_result('missing or invalid deprecation registration') unless valid_details?(details)

        classify(details)
      rescue JSON::ParserError => e
        invalid_result(e.message)
      end

      def classify(details)
        cause = :deprecation if @kind.nil? && !details[:deprecations].empty?
        kind = cause ? :failure : @kind
        kind = :error if details[:deprecation_error]
        details.merge(name: @name, kind: kind, cause: cause, message: @diagnostics)
      end

      def valid_details?(details)
        return false unless details.is_a?(Hash)
        return true if @kind == :error && details.empty?

        entries = details[:deprecations]
        entries.is_a?(Array) && entries.all? { |entry| valid_entry?(entry) } &&
          optional?(details, :deprecation_error, String)
      end

      def valid_entry?(entry)
        entry.is_a?(Hash) && entry[:message].is_a?(String) && !entry[:message].empty? &&
          optional?(entry, :source, String) && valid_line?(entry)
      end

      def optional?(entry, key, type)
        !entry.key?(key) || entry[key].is_a?(type)
      end

      def valid_line?(entry)
        !entry.key?(:line) || (entry[:line].is_a?(Integer) && entry[:line].positive? && entry[:source].is_a?(String))
      end

      def invalid_result(reason)
        { name: @name, kind: :error, message: "Invalid compiler result: #{reason}.\n#{@diagnostics}" }
      end
    end
  end
end
