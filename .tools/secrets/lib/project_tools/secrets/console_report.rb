# frozen_string_literal: true

module ProjectTools
  module Secrets
    # Present only inspected metadata; descriptions never interpolate source values or exceptions.
    class ConsoleReport
      FINDINGS = {
        'sensitive_name' => 'A name indicates potentially sensitive data.',
        'sensitive_assignment' => 'An assignment targets a sensitive field.',
        'sensitive_yaml_value' => 'A YAML or JSON field contains a potentially sensitive value.',
        'puppet_sensitive' => 'A Puppet Sensitive type or wrapper marks sensitive data.',
        'puppet_hardcoded_value' => 'A sensitive Puppet setting or Sensitive wrapper contains a hardcoded value.',
        'hiera_sensitive_conversion' => 'Hiera lookup options mark this field as Sensitive.',
        'token_signature' => 'A value matches a recognized token pattern.',
        'authorization' => 'An authorization header contains authentication material.',
        'credential_url' => 'A URL contains authentication material.',
        'encrypted_secret' => 'Encrypted secret material is present.',
        'pem_material' => 'Private key, certificate or certificate request material is present.'
      }.freeze
      ERRORS = {
        'invalid_arguments_or_destination' => 'Invalid arguments or output destination; check --help.',
        'execution_failed' => 'The scan could not finish; inspection is incomplete.',
        'report_write_failed' => 'The requested JUnit report could not be written; scan findings remain valid.',
        'inspection_failed' => 'Source inspection failed; this source has not been fully checked.',
        'unreadable_path' => 'The path could not be read; check that it exists and is accessible.',
        'unsupported_file_type' => 'This file type cannot be inspected; provide a regular file or directory.',
        'empty_directory' => 'The selected directory contains no files to inspect.',
        'no_puppet_manifests' => 'No Puppet manifests were selected; provide .pp files or a directory containing them.',
        'file_too_large' => 'The source exceeds the inspection size limit.',
        'source_changed' => 'The source changed while being read; repeat the scan on stable input.',
        'unsupported_encoding' => 'The source is not valid UTF-8 text.',
        'binary_content' => 'The source contains unsupported binary content.',
        'invalid_ruby' => 'Ruby syntax could not be parsed; inspection is incomplete.',
        'invalid_yaml' => 'YAML or JSON syntax could not be parsed; inspection is incomplete.',
        'unsupported_yaml_alias' => 'YAML aliases cannot be fully inspected.',
        'unsupported_yaml_key' => 'A YAML key uses an unsupported structure.',
        'unsupported_hiera_selector' => 'A Hiera lookup selector cannot be resolved by this scanner.',
        'unresolved_hiera_scope' => 'Hiera sensitivity could not be resolved across the selected files.',
        'puppet_parser_unavailable' => 'The Puppet parser is unavailable; install OpenVox in the active bundle.',
        'puppet_inspection_failed' => 'Puppet syntax could not be inspected; check the manifest locally.',
        'unbounded_puppet_value' => 'The boundaries of a sensitive Puppet value could not be determined.',
        'unbounded_sensitive_value' => 'The boundaries of a potentially sensitive value could not be determined.',
        'unterminated_pem_material' => 'A key or certificate block has no matching end marker.',
        'nested_pem_material' => 'Nested key or certificate blocks prevent complete inspection.',
        'unterminated_encrypted_secret' => 'An encrypted value has no matching end marker.',
        'nested_encrypted_secret' => 'Nested encrypted-value delimiters prevent complete inspection.',
        'archive_depth_limit' => 'Archive nesting exceeds the inspection limit.',
        'invalid_archive' => 'The archive is invalid, unsupported or exceeds an inspection limit.'
      }.freeze

      def initialize(result)
        @records = result.fetch(:files)
        @errors = result.fetch(:errors)
      end

      def facts
        [file_counts, finding_counts,
         "Errors: #{@errors.length + @records.sum { |record| record[:errors].length }}", coverage].compact
      end

      def file_counts
        return 'Files: selection not evaluated' if @records.empty?

        complete = @records.count { |record| record[:complete] }
        "Files: #{@records.length} selected | #{complete} complete | #{@records.length - complete} incomplete"
      end

      def finding_counts
        findings = @records.flat_map { |record| record[:findings] }
        values = findings.count { |item| item[:kind] == 'value' }
        "Findings: #{findings.length} | #{values} possible secret values | " \
          "#{findings.length - values} sensitivity indicators"
      end

      def coverage
        return if @records.empty?

        kinds = @records.group_by { |record| record[:coverage] }.sort
        "Coverage: #{kinds.map { |kind, records| "#{records.length} #{kind}" }.join(' | ')}"
      end

      def details
        @records.sort_by { |record| record[:file] }.flat_map { |record| record_details(record) } +
          @errors.sort.map { |code| error_message(code) }
      end

      def record_details(record)
        record[:findings].map { |item| finding_message(record[:file], item) } +
          record[:errors].sort.map { |code| "#{record[:file]}: #{error_message(code)}" }
      end

      def finding_message(file, item)
        kind = item[:kind] == 'value' ? 'possible secret value' : 'sensitivity indicator'
        member = " [archive member #{item[:member].join('.')}]" if item[:member]
        "#{file}#{member} | line=#{item[:line]} | #{kind}: #{FINDINGS.fetch(item[:rule])} (#{item[:rule]})"
      end

      def error_message(code)
        "error: #{ERRORS.fetch(code)} (#{code})"
      end
    end
  end
end
