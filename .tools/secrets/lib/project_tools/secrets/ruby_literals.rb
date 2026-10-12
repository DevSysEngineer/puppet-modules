# frozen_string_literal: true

require 'ripper'
require 'json'

module ProjectTools
  module Secrets
    # Only simple string tokens are decoded, without evaluating Ruby source.
    class RubyLiterals
      def initialize(document)
        @document = document
        @lines = document.text.lines
      end

      def collect
        Ripper.lex(@document.text).each do |position, kind, token, _state|
          offset = @lines.first(position[0] - 1).sum(&:length) +
                   @lines[position[0] - 1].byteslice(0, position[1]).length
          visit(kind, token, offset)
        end
      end

      def visit(kind, token, offset)
        @opening = [offset, token] if kind == :on_tstring_beg
        @opening = nil if %i[on_embexpr_beg on_embvar].include?(kind)
        return unless kind == :on_tstring_end && @opening

        record(offset + token.length)
        @opening = nil
      rescue JSON::ParserError
        @opening = nil
      end

      def record(last)
        first, quote = @opening
        return unless %w[' "].include?(quote)

        raw = @document.text[first...last]
        value = quote == '"' ? JSON.parse(raw) : raw[1...-1].gsub(/\\([\\'])/, '\\1')
        @document.literals << [first, last, value, 'ruby']
      end
    end
  end
end
