# frozen_string_literal: true

require 'project_lint/ast'
require 'project_lint/strings_documentation'
require 'project_lint/token_helpers'

# Project-owned Puppet lint rules.
module ProjectLint
  # Native checks and their local analyses.
  module Checks
    # Check required Strings sections and parameter documentation in declaration order.
    module Documentation
      include AstCheck
      include StringsDocumentation
      include TokenHelpers

      def check
        @orders = []
        ast.declarations.each do |declaration|
          rows = @fixing ? live_documentation_rows(declaration) : documentation_blocks([declaration]).first.last
          text = rows.reject { |row| control?(row[:text]) }.map { |row| row[:text] }
          check_sections(declaration, text)
          check_parameters(declaration, text, rows)
          check_descriptions(declaration, text)
        end
      end

      def check_sections(declaration, text)
        unless text.grep(/^@summary\s+\S/).one?
          issue(declaration,
                'Document the declaration with one non-empty @summary')
        end
        unless text.grep(/^@api (?:public|private)$/).one?
          issue(declaration,
                'Document the declaration with @api public or @api private')
        end
        issue(declaration, 'Provide a Puppet Strings @example') if text.grep(/^@example\s+\S/).empty?
      end

      def check_parameters(declaration, text, rows)
        documented = text.filter_map { |line| line[/^@param\s+(?:\[[^\]]+\]\s+)?(\w+)/, 1] }
        parameters = parameter_order(declaration)
        return if documented == parameters

        @orders << { rows: rows, documented: documented, parameters: parameters }
        notify(:warning, message: 'Document every parameter exactly once, in declaration order',
                         line: declaration.line, column: declaration.pos, edit: @orders.length - 1)
      end

      def parameter_order(declaration)
        positions = tokens.each_with_index.to_h { |token, index| [[token.line, token.column], index] }
        declaration.parameters.sort_by { |parameter| positions.fetch([parameter.line, parameter.pos]) }.map(&:name)
      end

      def fix_problems
        return super if @problems.any? { |problem| problem[:check] == :syntax }

        # Parameter order and comment layout may have changed; use the live token order.
        @fixing = true
        @problems = []
        run
        super
      end

      def fix(problem)
        raise PuppetLint::NoFix unless problem.key?(:edit)

        order = @orders.fetch(problem[:edit])
        groups = ordered_parameter_groups(order)
        sort_parameter_comments(groups, order[:parameters])
      end

      def sort_parameter_comments(groups, names)
        spans = groups.values.map { |rows| [rows.first[:token], rows.last[:token]] }
        validate_documentation_spans(spans)
        replacement = reordered_tokens(spans, names.map { |name| groups.keys.index(name) })
        replace_tokens(spans.first.first, spans.last.last, replacement)
      end

      def validate_documentation_spans(spans)
        raise PuppetLint::NoFix if ignored_span?(spans.first.first, spans.last.last)
      end

      def ordered_parameter_groups(order)
        names = order[:parameters]
        raise PuppetLint::NoFix unless order[:documented].sort == names.sort

        groups = parameter_rows(order[:rows])
        raise PuppetLint::NoFix unless groups.keys.sort == names.sort

        groups
      end

      def parameter_rows(rows)
        groups = rows.slice_before { |row| parameter_tag?(row) }.to_a
        groups.shift unless parameter_tag?(groups.first&.first)
        groups.each_with_index.to_h do |group, index|
          name = parameter_name(group.first)
          [name, parameter_description(group, index == groups.length - 1)]
        end
      end

      def parameter_tag?(row)
        row && row[:text].start_with?('@param ')
      end

      def parameter_name(row)
        row[:text][/\A@param\s+(?:\[[^\]]+\]\s+)?(\w+)/, 1]
      end

      def parameter_description(group, last)
        description = group.drop(1).take_while { |row| description_row?(row) }
        raise PuppetLint::NoFix unless last || description.length == group.length - 1

        description.pop while description.last && description.last[:text].empty?
        [group.first] + description
      end

      def description_row?(row)
        row[:text].empty? || row[:text].match?(/\A\s+\S/)
      end

      def check_descriptions(declaration, text)
        text.each_with_index do |line, index|
          next unless line.start_with?('@param ')
          next if line.match?(/^@param\s+(?:\[[^\]]+\]\s+)?\w+\s+\S/) || text[index + 1]&.match?(/^\s+\S/)

          issue(declaration, 'Give each @param a description of its contract and default meaning')
        end
      end
    end
    PuppetLint.new_check(:project_documentation) { include Documentation }
  end
end
