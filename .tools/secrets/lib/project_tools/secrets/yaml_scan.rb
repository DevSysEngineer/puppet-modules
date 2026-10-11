# frozen_string_literal: true

require 'psych'
require_relative 'patterns'

module ProjectTools
  module Secrets
    # Psych supplies source ranges only; tags, objects and aliases are never loaded.
    class YamlScan
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

      def lookup_options(node)
        @document.error('unsupported_yaml_alias') if node.is_a?(Psych::Nodes::Alias)
        node.children.each_slice(2) { |key, value| lookup_entry(key, value) } if node.is_a?(Psych::Nodes::Mapping)
        children(node).each { |child| lookup_options(child) }
      end

      def lookup_entry(key, value)
        return @document.error('unsupported_yaml_key') unless scalar?(key)

        conversions(value) if key.value == 'lookup_options'
      end

      def conversions(node)
        return unless node.is_a?(Psych::Nodes::Mapping)

        node.children.each_slice(2) do |key, options|
          next unless scalar?(key) && options.is_a?(Psych::Nodes::Mapping)
          next unless options.children.each_slice(2).any? { |name, type| sensitive_conversion?(name, type) }

          conversion(key)
        end
      end

      def conversion(key)
        @document.finding('hiera_sensitive_conversion', offset(key))
        if key.value.start_with?('^')
          @document.error('unsupported_hiera_selector')
        else
          @selectors << key.value
        end
      end

      def sensitive_conversion?(name, type)
        return false unless scalar?(name) && name.value == 'convert_to'

        candidate = type.is_a?(Psych::Nodes::Sequence) ? type.children.first : type
        scalar?(candidate) && candidate.value.match?(/\ASensitive(?:\[|\z)/)
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

          visit(value, sensitive: sensitive_key?(key) || sensitive)
        end
      end

      def sensitive_key?(key)
        secret = Patterns::NAME.match?(key.value) || @active_selectors.include?(key.value)
        @document.finding('sensitive_name', offset(key)) if secret
        secret
      end

      def scalar_value(node, sensitive)
        sensitive = sensitive_scalar?(node) || sensitive
        return unless sensitive
        return if empty?(node)

        first = offset(node)
        last = offset(node, ending: true)
        replacement = '"[REDACTED]"'
        replacement += "\n" if @document.text[first...last].end_with?("\n")
        @document.redact(first, last, 'sensitive_yaml_value', replacement, value: node.value)
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
