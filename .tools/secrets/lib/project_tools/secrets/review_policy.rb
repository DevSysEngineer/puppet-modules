# frozen_string_literal: true

require 'date'
require 'json'

module ProjectTools
  module Secrets
    # Validate review provenance and scope before any exception is applied.
    class ReviewPolicy
      FIELDS = %w[path control rationale owner reviewed_on expires_on sha256 findings errors].freeze
      TEXT = %w[path control rationale owner reviewed_on expires_on sha256].freeze
      ERRORS = {
        'non_secret_value' => [],
        'non_secret_artifact' => %w[unsupported_encoding binary_content],
        'synthetic_fixture' => %w[unbounded_sensitive_value unterminated_pem_material nested_pem_material
                                  unterminated_encrypted_secret nested_encrypted_secret invalid_yaml invalid_ruby]
      }.freeze
      attr_reader :entries

      def initialize(path)
        @root = File.realpath(Dir.pwd)
        @entries = {}
        data = JSON.parse(read(path), allow_duplicate_key: false)
        validate_schema(data)
        data['entries'].each { |entry| add(entry) }
      end

      def validate_schema(data)
        raise ArgumentError unless data.is_a?(Hash) && data.keys.sort == %w[entries schema] && data['schema'] == 1
        raise ArgumentError unless data['entries'].is_a?(Array)
      end

      def read(path)
        File.open(path, File::RDONLY | File::NOFOLLOW | File::NONBLOCK) do |file|
          raise ArgumentError unless file.stat.file? && file.stat.size <= 1_048_576

          file.read(1_048_577)
        end
      end

      def add(entry)
        validate_fields(entry)
        validate_date(entry)
        validate_findings(entry)
        absolute = reviewed_path(entry.fetch('path'))
        raise ArgumentError if @entries.key?(absolute)

        @entries[absolute] = entry
      end

      def validate_fields(entry)
        raise ArgumentError unless entry.is_a?(Hash) && entry.keys.sort == FIELDS.sort
        raise ArgumentError unless TEXT.all? { |key| present?(entry[key]) }
        raise ArgumentError unless ERRORS.key?(entry['control']) && entry['sha256'].match?(/\A[0-9a-f]{64}\z/)
      end

      def present?(value)
        value.is_a?(String) && !value.strip.empty?
      end

      def reviewed_path(path)
        raise ArgumentError if path.start_with?('/') || path.match?(/[\\:*?\[\]{}[:cntrl:]]/)
        raise ArgumentError if path.split('/').any? { |part| ['', '.', '..'].include?(part) }

        absolute = File.join(@root, path)
        raise ArgumentError unless File.file?(absolute) && File.realpath(absolute) == absolute

        absolute
      end

      def date(value)
        raise ArgumentError unless value.match?(/\A\d{4}-\d{2}-\d{2}\z/)

        Date.iso8601(value)
      end

      def validate_date(entry)
        reviewed = date(entry['reviewed_on'])
        expires = date(entry['expires_on'])
        raise ArgumentError unless reviewed <= Date.today && Date.today < expires && reviewed < expires
      end

      def validate_findings(entry)
        findings = entry['findings']
        errors = entry['errors']
        raise ArgumentError unless findings.is_a?(Array) && errors.is_a?(Array)
        raise ArgumentError unless findings.all? { |item| finding?(item) }
        raise ArgumentError if findings.empty? && errors.empty?

        validate_errors(entry)
      end

      def validate_errors(entry)
        errors = entry['errors']
        raise ArgumentError unless errors.uniq == errors && (errors - ERRORS.fetch(entry['control'])).empty?
        raise ArgumentError if entry['control'] == 'non_secret_artifact' && errors.empty?
      end

      def finding?(item)
        return false unless item.is_a?(Hash) && item.keys.sort == %w[kind line rule]

        item['line'].is_a?(Integer) && item['line'].positive? && %w[indicator value].include?(item['kind']) &&
          item['rule'].is_a?(String) && item['rule'].match?(/\A[a-z_]+\z/)
      end
    end
  end
end
