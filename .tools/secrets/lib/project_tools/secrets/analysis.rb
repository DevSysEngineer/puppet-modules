# frozen_string_literal: true

module ProjectTools
  module Secrets
    # Allocate occurrence identities after the shared detector has merged its spans.
    class Analysis
      def initialize(document, safe, data)
        @document = document
        @safe = safe
        @data = data
      end

      def prepare
        protect_path_references
        protect_marker_text
        protect_literals
        masked = @document.text.dup
        spans.reverse_each { |first, last, replacement| mask(masked, first, last, replacement) }
        remember_context(masked)
        metadata(masked)
      end

      def protect_marker_text
        @document.text.to_enum(:scan, /\[REDACTED-/).each do
          @document.redact(*Regexp.last_match.offset(0), 'reserved_marker_text', '[REDACTED]')
        end
      end

      def protect_literals
        return unless File.extname(@document.path) == '.pp' || @document.ruby_source?

        @document.merged_spans.each { |first, last, _| protect_reference(first, last) }
      end

      def protect_path_references
        @data['policy'].fetch('aliases', {}).each_key do |path|
          @document.text.to_enum(:scan, Regexp.new(Regexp.escape(path))).each do
            protect_reference(*Regexp.last_match.offset(0))
          end
        end
      end

      def protect_reference(first, last)
        literal = @document.literals.find { |start, stop, _value, _type| first >= start && last <= stop }
        first, last = literal.first(2) if literal
        @document.redact(first, last, 'protected_literal', '"[REDACTED]"')
      end

      def metadata(masked)
        source = Paths.inside(@data['root'], @document.path)
        stat = File.stat(source)
        { 'source' => @document.path, 'original' => @document.text, 'analysis' => masked,
          'mode' => stat.mode & 0o7777, 'uid' => stat.uid, 'gid' => stat.gid,
          'coverage' => @document.inspection_coverage, 'context_omitted' => omitted?, 'writable' => !classified?,
          'ssh_public_values' => SshPublicKey.known_values(@document),
          'identity' => SourceVersions.identity(source) }
      end

      def classified?
        @data['policy'].fetch('sensitive_paths', []).any? do |glob|
          File.fnmatch?(glob, @document.path, File::FNM_PATHNAME | File::FNM_DOTMATCH)
        end
      end

      def spans
        return [[0, @document.text.length, '[REDACTED]']] if classified? && !@document.text.empty?

        @document.merged_spans
      end

      def omitted?
        spans.any? { |first, last, _| @document.text[first...last].include?("\n") }
      end

      def mask(masked, first, last, replacement)
        id = SecureRandom.hex(16)
        entry = @document.descriptor(first, last, replacement)
        entry.merge!('file' => @safe, 'indent' => @document.indentation(first), 'role' => @document.marker_role(first))
        classify(entry) if classified?
        @data['markers'][id] = entry
        masked[first...last] = entry['replacement'].sub('[REDACTED]', "[REDACTED-#{id}]")
      end

      def classify(entry)
        entry['replacement'] = File.extname(@safe) == '.json' ? '"[REDACTED]"' : '# [REDACTED]'
        entry['role'] = nil
      end

      def remember_context(text)
        representation = Document.new(@safe, text)
        @data['markers'].each do |id, entry|
          next unless entry['file'] == @safe

          visible = entry['replacement'].sub('[REDACTED]', "[REDACTED-#{id}]")
          first = text.index(visible)
          entry['context'] = representation.line_context(first, first + visible.length)
          entry['role'] = representation.marker_role(first) if entry['role']
        end
      end
    end
  end
end
