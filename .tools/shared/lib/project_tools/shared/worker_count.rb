# frozen_string_literal: true

module ProjectTools
  module Shared
    # Validate explicit concurrency before a caller starts work or mutates reports.
    module WorkerCount
      def self.parse(value)
        text = value.to_s
        unless text.match?(/\A[0-9]+\z/) && text.to_i.positive?
          raise ArgumentError, 'Worker count must be a positive decimal integer.'
        end

        text.to_i
      end
    end
  end
end
