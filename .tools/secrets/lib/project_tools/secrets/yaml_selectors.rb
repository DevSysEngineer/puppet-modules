# frozen_string_literal: true

module ProjectTools
  module Secrets
    # Collect explicit Hiera conversion keys without loading YAML objects or aliases.
    module YamlSelectors
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

      def children(node)
        node.children || []
      end
    end
  end
end
