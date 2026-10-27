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
        return '[REDACTED]' if SshPublicKey::RECORD.match?(result)

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
        values = local_values.compact.reject(&:empty?)
        values += values.flat_map { |value| SshPublicKey.encoded_values(value) }
        values.flat_map { |value| representations(value) }
              .uniq.sort_by { |value| -value.length }
      end

      def local_values
        @data['markers'].values.flat_map { |entry| [entry['raw'], entry['value']] } +
          @data['files'].values.flat_map { |file| file.fetch('ssh_public_values', []) }
      end

      def representations(value)
        [value, JSON.generate(value)[1...-1], value.dump[1...-1]]
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
