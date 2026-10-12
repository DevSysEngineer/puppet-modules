# frozen_string_literal: true

require_relative 'scanner'

module ProjectTools
  module Secrets
    # Paths use scan values; diagnostics also mask escaped values and re-inspect output.
    class Redaction
      def initialize(values: [], data: nil)
        @values = values
        @data = data
      end

      def path(path)
        result = path.to_s.encode('UTF-8', invalid: :replace, undef: :replace)
        @values.reject(&:empty?).uniq.sort_by { |value| -value.length }.each do |value|
          result = result.gsub(value, '[REDACTED]')
        end
        result.gsub(Patterns::TOKENS, '[REDACTED]').gsub(/[[:cntrl:]]/, '?')
      end

      def diagnostics(text)
        text = mask_known(text)
        documents = Scanner.documents({ 'diagnostics.txt' => text }, analysis: false)
        Scanner.complete!(documents)
        documents.first.sanitized(markers: @data['markers'].keys.map { |id| "[REDACTED-#{id}]" })
      end

      def mask_known(text)
        text = mask_paths(text)
        known_values.each { |value| text = text.gsub(value, '[REDACTED]') }
        text
      end

      def known_values
        values = @data['markers'].values.flat_map { |entry| [entry['raw'], entry['value']] }.compact.reject(&:empty?)
        values.flat_map { |value| [value, JSON.generate(value)[1...-1], value.dump[1...-1]] }
              .uniq.sort_by { |value| -value.length }
      end

      def mask_paths(text)
        @data['files'].each do |safe, file|
          text = text.gsub(File.join(@data['root'], file['source']), safe).gsub(file['source'], safe)
        end
        text
      end
    end
  end
end
