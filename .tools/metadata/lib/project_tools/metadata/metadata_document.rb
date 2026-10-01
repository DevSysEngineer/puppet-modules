# frozen_string_literal: true

require 'json'

module ProjectTools
  module Metadata
    # Locate top-level JSON values without serializing unrelated fields or whitespace.
    # JSON.parse validates the document before this lexical index is used.
    class MetadataDocument
      TOKEN = /"(?:[^"\\]|\\.)*"|[^\s{}\[\],:]+|[{}\[\],:]/m.freeze

      def initialize(source)
        @source = source
        @tokens = source.to_enum(:scan, TOKEN).map do
          match = Regexp.last_match
          [match[0], match.begin(0), match.end(0)]
        end
        @fields = fields
      end

      def fields
        result = Hash.new { |hash, key| hash[key] = [] }
        index = 1
        while @tokens[index].first != '}'
          key = field_name(index)
          first = index + 2
          last = value_end(first)
          result[key] << (@tokens[first][1]...@tokens[last][2])
          index = following_field(last)
        end
        result
      end

      def field_name(index)
        JSON.parse(@tokens[index].first)
      end

      def following_field(last)
        @tokens[last + 1].first == ',' ? last + 2 : last + 1
      end

      def value_end(index)
        return index unless ['{', '['].include?(@tokens[index].first)

        depth = 0
        @tokens.each_with_index.drop(index).each do |(text, _start, _finish), cursor|
          depth += 1 if ['{', '['].include?(text)
          depth -= 1 if ['}', ']'].include?(text)
          return cursor if depth.zero?
        end
      end

      def with_field(field, value)
        result = @source.dup
        ranges = @fields.fetch(field, [])
        raise ArgumentError, "#{field}: duplicate top-level keys prevent safe autofix" if ranges.length > 1

        range, text = ranges.empty? ? insertion(field, value) : [ranges.first, JSON.generate(value)]
        result[range] = text
        result
      end

      def insertion(field, value)
        last = @fields.values.flatten.max_by(&:end)
        offset = last ? last.end : @tokens.first[2]
        text = "#{',' if last}#{separator}#{JSON.generate(field)}: #{JSON.generate(value)}"
        [(offset...offset), text]
      end

      def separator
        newline = @source.include?("\r\n") ? "\r\n" : "\n"
        @source.include?("\n") ? "#{newline}#{indent}" : ' '
      end

      def indent
        @source[/\n([\t ]*)"/, 1] || '  '
      end
    end
  end
end
