# frozen_string_literal: true

module ProjectTools
  module Secrets
    # Restore supported literals by value, and opaque fragments only in their bound context.
    module MarkerSyntax
      MARKER = /\[REDACTED-([0-9a-f]{32})\]/.freeze

      def descriptor(first, last, replacement)
        member = ruby_containers&.member(first, last)
        return ruby_containers.descriptor(member) if member && member.values_at(:first, :last) == [first, last]

        literal_descriptor(first, last, replacement)
      end

      def literal_descriptor(first, last, replacement)
        literal = literals.find { |start, stop, _value, _type| start == first && stop == last }
        raw = text[first...last]
        { 'raw' => raw, 'replacement' => literal ? replacement : fragment_marker(raw),
          'type' => literal ? literal[3] : 'fragment', 'value' => literal && literal[2],
          'extension' => File.extname(path), 'reencode' => !literal || literal[4] != false }
      end

      def fragment_marker(raw)
        quote = raw[0]
        return "#{quote}[REDACTED]#{quote}" if %w[' "].include?(quote) && raw[-1] == quote
        return "'[REDACTED]'" if File.extname(path) == '.pp' || (ruby_source? && Ripper.sexp(raw))

        '[REDACTED]'
      end

      def marker_sites
        text.to_enum(:scan, MARKER).map do
          match = Regexp.last_match
          literal = literals.find { |_first, _last, value, _type| value == match[0] }
          { 'id' => match[1], 'marker' => match[0], 'first' => match.begin(0), 'last' => match.end(0),
            'literal' => literal }
        end
      end

      def restore(site, entry)
        return restore_member(site, entry) if entry['type'] == 'ruby_member'

        literal = site['literal']
        return restore_literal(site, entry, literal) if literal && %w[yaml puppet ruby].include?(entry['type'])

        restore_fragment(site, entry)
      end

      def restore_member(site, entry)
        member = ruby_containers&.member(site['first'], site['last'])
        literal = site['literal']
        return restore_member_literal(site, entry, literal) unless member

        valid = literal && literal[2] == site['marker'] &&
                ruby_containers.literal_member?(member, literal, entry)
        raise Failure, 'unsupported_marker_context' unless valid

        [member[:first], member[:last], entry['raw']]
      end

      def restore_member_literal(site, entry, literal)
        valid = entry['value'].is_a?(String) && literal && %w[yaml puppet ruby].include?(literal[3])
        raise Failure, 'unsupported_marker_context' unless valid

        restore_literal(site, entry.merge('type' => 'ruby'), literal)
      end

      def restore_literal(site, entry, literal)
        first, last, _value, type = literal
        current = text[first...last]
        raw = original_literal?(site, entry, literal) ? entry['raw'] : reencode(entry, type)
        raw += "\n" if current.end_with?("\n") && !raw.end_with?("\n")
        [first, last, raw]
      end

      def reencode(entry, type)
        raise Failure, 'unsupported_marker_context' if entry['reencode'] == false

        encode_value(entry['value'], type)
      end

      def original_literal?(site, entry, literal)
        first, last, _value, type = literal
        type == entry['type'] && indentation(first) == entry['indent'] &&
          text[first...last] == entry['replacement'].sub('[REDACTED]', site['marker'])
      end

      def encode_value(value, type)
        return JSON.generate(value) if type == 'yaml'

        "'#{value.gsub(/[\\']/) { |char| "\\#{char}" }}'"
      end

      def indentation(index)
        text[0...index].split("\n", -1).last.to_s[/\A[ \t]*/]
      end

      def marker_role(index)
        text[0...index].split("\n", -1).last.to_s.strip
      end

      def line_context(first, last)
        start = (text.rindex("\n", [first - 1, 0].max) || -1) + 1
        finish = text.index("\n", last) || text.length
        [text[start...first].lstrip.gsub(MARKER, '[OCCURRENCE]'), text[last...finish].gsub(MARKER, '[OCCURRENCE]')]
      end

      def restore_fragment(site, entry)
        expected = entry['replacement'].sub('[REDACTED]', site['marker'])
        first = site['first'] - expected.index(site['marker'])
        last = first + expected.length
        raise Failure, 'unsupported_marker_context' unless fragment_context?(entry, first, last) &&
                                                           text[first...last] == expected

        [first, last, entry['raw']]
      end

      def fragment_context?(entry, first, last)
        extension = File.extname(path)
        return false if extension == '.pp' || extension != entry['extension']
        return false if %w[.yaml .yml .json].include?(extension) && !yaml_container?(first, last)
        return false if entry['raw'].include?("\n") && indentation(first) != entry['indent']

        line_context(first, last) == entry['context']
      end

      def yaml_container?(first, last)
        literals.any? { |start, stop, _value, type| type == 'yaml' && first > start && last < stop }
      end
    end
  end
end
