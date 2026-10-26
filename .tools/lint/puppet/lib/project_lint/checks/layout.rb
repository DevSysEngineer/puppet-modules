# frozen_string_literal: true

require 'project_lint/ast'
require 'project_lint/token_helpers'
require 'project_lint/array_layout'

# Project-owned Puppet lint rules.
module ProjectLint
  # Native checks and their local analyses.
  module Checks
    # Integrate joint array plans with the native diagnostic lifecycle.
    module ArrayLayoutCheck
      def check_array_layout
        @array_layout = ArrayLayout.new(ast, tokens, PuppetLint::Data.ignore_overrides.fetch(:project_layout, {}))
        @array_layout.findings.each do |plan, message|
          opening = tokens[plan[:first]]
          report_edit(message, opening.line, opening.column, array_layout: true)
        end
      end

      # The final native pass runs after checks that may replace array anchors.
      def fix_array_layout(problem)
        raise PuppetLint::NoFix unless @array_final_pass && !problem[:message].include?('[review]')

        @array_layout.replacements.reverse_each do |plan|
          replace_tokens(tokens[plan[:first]], tokens[plan[:last]], plan[:replacement])
        end
        @array_layout.replacements.clear
      end

      def finish_arrays
        @array_final_pass = true
        run
        fix_problems
      end
    end

    # Coordinate array, brace and comma layout checks using original source positions.
    module Layout
      include AstCheck
      include TokenHelpers
      include ArrayLayoutCheck

      def report_edit(message, line, column, edit)
        @edits << edit
        notify(:warning, message: message, line: line, column: column, edit: @edits.length - 1)
      end

      def check
        @edits = []
        check_array_layout
        return if @array_final_pass

        check_opening_brace_spacing
        check_commas
        (class_indexes + defined_type_indexes).each { |declaration| check_parameter_comma(declaration) }
      end

      def check_commas
        tokens.each { |token| check_comma_gap(token) if token.type == :COMMA && token.next_code_token }
      end

      def check_comma_gap(token)
        return if @array_layout.owns_comma?(token)

        following = token.next_code_token
        return if following.line != token.line || %i[RBRACK RBRACE RPAREN].include?(following.type)
        return if token.next_token.type == :WHITESPACE && token.next_token.value == ' '

        report_edit('Use one space after a same-line comma', token.line, token.column, comma: token,
                                                                                       following: following)
      end

      def multiline_parameter_end(declaration, parameters)
        code = parameters.reject { |token| PuppetLint::Data.formatting_tokens.include?(token.type) }
        last = code.last
        last if last && declaration[:name_token].line != last.line && last.type != :COMMA
      end

      def check_parameter_comma(declaration)
        parameters = declaration[:param_tokens]
        return unless parameters&.any?

        last = multiline_parameter_end(declaration, parameters)
        return unless last

        report_edit('End a multiline parameter block with a trailing comma', last.line, last.column,
                    closing: parameters.last.next_token)
      end

      def inline_brace_comment?(token, opening)
        token && token.line == opening.line && %i[WHITESPACE COMMENT SLASH_COMMENT MLCOMMENT].include?(token.type) &&
          !token.value.include?("\n")
      end

      def opening_newline(opening)
        following = opening.next_token
        following = following.next_token while inline_brace_comment?(following, opening)
        following if following&.type == :NEWLINE && following.line == opening.line
      end

      def blank_tokens(cursor)
        blank = []
        while cursor && %i[INDENT WHITESPACE NEWLINE].include?(cursor.type)
          blank << cursor
          cursor = cursor.next_token
        end
        blank.pop while blank.last && blank.last.type != :NEWLINE
        blank
      end

      def check_opening_brace_spacing
        tokens.select { |token| token.type == :LBRACE }.each do |opening|
          following = opening_newline(opening)
          next unless following && PuppetLint::Data.manifest_lines[opening.line]&.strip == ''

          report_edit('Remove blank lines immediately after an opening brace', opening.line + 1, 1,
                      remove: blank_tokens(following.next_token))
        end
      end

      def fix(problem)
        edit = @edits.fetch(problem[:edit])
        if edit[:array_layout]
          fix_array_layout(problem)
        elsif edit[:remove]
          remove_blank_lines(edit[:remove])
        elsif edit[:comma]
          fix_comma_gap(edit)
        else
          fix_parameter_comma(edit[:closing])
        end
      end

      def remove_blank_lines(blank)
        raise PuppetLint::NoFix if ignored_span?(blank.first, blank.last)

        blank.each { |token| remove_token(token) if tokens.include?(token) }
      end

      def fix_comma_gap(edit)
        raise PuppetLint::NoFix if ignored_span?(edit[:comma], edit[:following])

        set_whitespace(edit[:comma], code_after(edit[:comma]), 1)
      end

      def trailing_parameter_token(closing)
        index = tokens.index(closing)
        raise PuppetLint::NoFix unless index

        last = tokens.take(index).reverse.find { |token| !PuppetLint::Data.formatting_tokens.include?(token.type) }
        # A detached heredoc terminator cannot act as the parameter separator.
        raise PuppetLint::NoFix if last.type.to_s.start_with?('HEREDOC')

        last
      end

      def fix_parameter_comma(closing)
        last = trailing_parameter_token(closing)
        return if last.type == :COMMA

        add_token(tokens.index(last) + 1, PuppetLint::Lexer::Token.new(:COMMA, ',', last.line, last.column))
      end
    end
    PuppetLint.new_check(:project_layout) { include Layout }
  end
end
