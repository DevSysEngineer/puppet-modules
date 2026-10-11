# frozen_string_literal: true

require 'psych'
require_relative 'patterns'
require_relative 'text_scan'
require_relative 'yaml_selectors'

module ProjectTools
  module Secrets
    # Psych supplies source ranges only; tags, objects and aliases are never loaded.
    class YamlScan
      include YamlSelectors

      attr_reader :selectors

      def initialize(document)
        @document = document
        @selectors = []
        @lines = [0]
        document.text.each_char.with_index { |char, index| @lines << (index + 1) if char == "\n" }
        @tree = Psych.parse_stream(document.text)
        lookup_options(@tree)
      rescue Psych::Exception, ArgumentError
        document.error('invalid_yaml')
      end

      def offset(node, ending: false)
        line = ending ? node.end_line : node.start_line
        column = ending ? node.end_column : node.start_column
        @lines.fetch(line, @document.text.length) + column
      end

      def children(node)
        node.children || []
      end

      def scan(selectors)
        @active_selectors = selectors
        visit(@tree) if @tree
      end

      def visit(node, sensitive: false)
        case node
        when Psych::Nodes::Alias then @document.error('unsupported_yaml_alias')
        when Psych::Nodes::Mapping then mapping(node, sensitive)
        when Psych::Nodes::Scalar then scalar_value(node, sensitive)
        else children(node).each { |child| visit(child, sensitive: sensitive) }
        end
      end

      def mapping(node, sensitive)
        node.children.each_slice(2) do |key, value|
          unless scalar?(key)
            @document.error('unsupported_yaml_key')
            next
          end
          next if key.value == 'lookup_options'

          visit(value, sensitive: field_sensitive?(key, value) || sensitive)
        end
      end

      def field_sensitive?(key, value)
        named = sensitive_key?(key)
        return true if @active_selectors.include?(key.value)
        return false if scalar?(value) && Context.metadata?(key.value, value.value)

        named && !ci_job?(key, value)
      end

      def ci_job?(key, value)
        return false unless key.start_column.zero? && key.value.include?(' ') && value.is_a?(Psych::Nodes::Mapping)

        fields = mapping_fields(value)
        scalar?(fields['stage']) && (scalar?(fields['script']) || fields['script'].is_a?(Psych::Nodes::Sequence))
      end

      def mapping_fields(node)
        node.children.each_slice(2).to_h { |name, child| [scalar?(name) ? name.value : nil, child] }
      end

      def sensitive_key?(key)
        secret = Patterns::NAME.match?(key.value) || @active_selectors.include?(key.value)
        @document.finding('sensitive_name', offset(key)) if secret
        secret
      end

      def scalar_value(node, sensitive)
        embedded = embedded_value(node)
        sensitive = sensitive_scalar?(node) || sensitive || embedded
        return unless sensitive
        return if empty?(node)

        first = offset(node)
        last = offset(node, ending: true)
        replacement = '"[REDACTED]"'
        replacement += "\n" if @document.text[first...last].end_with?("\n")
        @document.redact(first, last, 'sensitive_yaml_value', replacement, value: node.value)
      end

      def embedded_value(node)
        document = Document.new('yaml-scalar.txt', node.value)
        TextScan.new(document).scan
        @document.values.concat(document.values)
        !document.complete? || document.findings.any? { |finding| finding[:kind] == 'value' }
      end

      def empty?(node)
        return true if node.value.empty? || node.value == '[REDACTED]'

        node.plain && !node.tag && node.value.match?(/\A(?:null|~)\z/i)
      end

      def sensitive_scalar?(node)
        @document.finding('puppet_sensitive', offset(node)) if node.value.match?(/\bSensitive\b/)
        node.value.match?(/\bSensitive\s*\(/) || node.tag.to_s.match?(/sensitive/i)
      end

      def scalar?(node)
        node.is_a?(Psych::Nodes::Scalar)
      end
    end
  end
end
