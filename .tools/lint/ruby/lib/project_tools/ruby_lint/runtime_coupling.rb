# frozen_string_literal: true

module RuboCop
  module Cop
    module Project
      # Keep runtime selection out of individual tools; version bounds require an explicit rationale.
      class RuntimeCoupling < Base
        MSG = 'Use the shared Puppet runtime; justify necessary compatibility bounds at their declaration.'
        RUNTIMES = %w[puppet openvox].freeze
        COMPARISONS = %i[== != === eql? equal?].freeze

        def on_send(node)
          return if runtime_owner? || test_source?
          return unless direct_runtime?(node) || exact_version?(node) || runtime_dependency?(node)
          return if justified_bound?(node)

          add_offense(node)
        end
        alias on_csend on_send

        def runtime_owner?
          cop_config.fetch('RuntimeFiles', []).any? do |pattern|
            File.fnmatch?(pattern, processed_source.file_path, File::FNM_PATHNAME | File::FNM_DOTMATCH)
          end
        end

        def test_source?
          (processed_source.file_path.split(File::SEPARATOR) & %w[tests test spec fixtures]).any?
        end

        def direct_runtime?(node)
          value = node.first_argument
          return false unless value&.str_type?

          name = value.value
          case node.method_name
          when :require, :load then runtime_library?(name)
          when :bin_path, :activate_bin_path, :activate_and_load_bin_path then RUNTIMES.include?(name)
          when :[] then RUNTIMES.include?(name) && loaded_specs?(node.receiver)
          end
        end

        def runtime_library?(name)
          RUNTIMES.include?(name) || name.start_with?('puppet/')
        end

        def loaded_specs?(node)
          node&.send_type? && node.method?(:loaded_specs)
        end

        def runtime_dependency?(node)
          return false unless %i[gem add_dependency add_runtime_dependency].include?(node.method_name)
          return false unless node.first_argument&.str_type? && RUNTIMES.include?(node.first_argument.value)

          # The project chooses its runtime in Gemfile; tool packages must not choose for consumers.
          File.basename(processed_source.file_path) != 'Gemfile' || node.arguments.drop(1).any?(&:str_type?)
        end

        def exact_version?(node)
          return false unless COMPARISONS.include?(node.method_name)

          operands = [node.receiver, *node.arguments].compact
          operands.any? { |operand| version_literal?(operand) } && operands.any? { |operand| runtime_version?(operand) }
        end

        def version_literal?(node)
          return true if node.int_type?
          return node.value.match?(/\A\d+(?:\.\d+)*(?:[-.][a-zA-Z0-9]+)*\z/) if node.str_type?

          node.send_type? && node.method?(:new) && node.first_argument && version_literal?(node.first_argument)
        end

        def runtime_version?(node)
          return true if node.const_type? && %w[PUPPET_VERSION OPENVOX_VERSION].include?(node.const_name)

          runtime_expression?(node)
        end

        def local_assignment(node)
          # Restrict simple dataflow to the current lexical method or block and prior assignments.
          scope = node.each_ancestor(:def, :defs, :block).first || processed_source.ast
          scope.each_node(:lvasgn).select do |item|
            item.children.first == node.children.first && item.source_range.begin_pos < node.source_range.begin_pos
          end.last
        end

        def runtime_expression?(node, seen = [])
          return false unless node

          [node, *node.each_descendant].any? do |part|
            runtime_identifier?(part) || runtime_reference?(part, seen)
          end
        end

        def runtime_identifier?(node)
          (node.const_type? && %w[Puppet PuppetRuntime].include?(node.children.last.to_s)) ||
            (node.str_type? && RUNTIMES.include?(node.value))
        end

        def runtime_reference?(node, seen)
          return false unless node.lvar_type? && !seen.include?(node.children.first)

          assignment = local_assignment(node)
          assignment && runtime_expression?(assignment.children.last, seen + [node.children.first])
        end

        def justified_bound?(node)
          return false if direct_runtime?(node)
          return false if node.method_name.to_s.start_with?('add_')

          previous = processed_source.lines[node.first_line - 2] if node.first_line > 1
          previous&.match?(/\A\s*# runtime-compatibility: \S.+/)
        end
      end
    end
  end
end
