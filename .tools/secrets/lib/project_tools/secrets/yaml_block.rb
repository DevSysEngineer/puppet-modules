# frozen_string_literal: true

module ProjectTools
  module Secrets
    # A literal block can retain code only when each decoded character maps exactly to source.
    class YamlBlock
      def initialize(document, node, first, last)
        @document = document
        @node = node
        @first = first
        @raw = document.text[first...last]
      end

      def redact
        return unless @node.style == Psych::Nodes::Scalar::LITERAL

        embedded = Document.new('yaml-scalar.txt', @node.value)
        TextScan.new(embedded).scan
        Patterns.signatures(embedded)
        return unless embedded.complete? && !embedded.merged_spans.empty?

        locations = positions
        apply_spans(embedded, locations) if locations
      end

      def apply_spans(embedded, locations)
        embedded.merged_spans.each do |first, last, replacement|
          @document.redact(locations.fetch(first), locations.fetch(last - 1) + 1,
                           'sensitive_yaml_value', replacement, value: @node.value[first...last])
        end
      end

      def positions
        lines = @raw.lines.drop(1)
        indentation = block_indentation(lines)
        return unless indentation

        decoded, locations = decode(lines, indentation)
        locations if decoded.start_with?(@node.value) && decoded[@node.value.length..].match?(/\A\n*\z/)
      end

      def block_indentation(lines)
        lines.reject { |line| line.strip.empty? }.map { |line| line[/\A */].length }.min
      end

      def decode(lines, indentation)
        position = @first + @raw.index("\n") + 1
        locations = []
        decoded = lines.map do |line|
          trim = [indentation, line[/\A */].length].min
          locations.concat(((position + trim)...(position + line.length)).to_a)
          position += line.length
          line[trim..]
        end.join
        [decoded, locations]
      end
    end
  end
end
