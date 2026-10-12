# frozen_string_literal: true

require 'ripper'
require 'json'
require_relative 'marker_syntax'
require_relative 'ruby_literals'

module ProjectTools
  module Secrets
    # Source bytes remain local; only fixed finding metadata leaves this object.
    class Document
      include MarkerSyntax

      attr_reader :path, :text, :findings, :errors, :values, :members, :literals
      attr_accessor :coverage

      def initialize(path, text = '')
        @path = path
        @text = text
        initialize_findings
        @members = []
        @literals = []
        @coverage = 'text'
        @line_ends = []
        text.each_char.with_index { |char, index| @line_ends << index if char == "\n" }
        error('invalid_ruby') if ruby_source? && Ripper.sexp(text).nil?
        RubyLiterals.new(self).collect if ruby_source? && complete?
      end

      def initialize_findings
        @findings = []
        @errors = []
        @spans = []
        @values = []
        @finding_keys = {}
      end

      def finding(rule, offset, kind = 'indicator')
        line = (@line_ends.bsearch_index { |index| index >= offset } || @line_ends.length) + 1
        item = { line: line, rule: rule, kind: kind }
        return if @finding_keys[item]

        @finding_keys[item] = true
        @findings << item
      end

      def error(code)
        @errors << code unless @errors.include?(code)
        nil
      end

      def redact(first, last, rule, replacement = '[REDACTED]', value: nil)
        finding(rule, first, 'value')
        @spans << [first, last, replacement]
        @values << (value || text[first...last])
      end

      def complete?
        errors.empty?
      end

      def ruby_source?
        %w[.rb .rake .gemspec].include?(File.extname(path)) || %w[Gemfile Rakefile].include?(File.basename(path))
      end

      def inspection_coverage
        return %w[archive text_patterns] unless members.empty?
        return %w[text_patterns yaml_parser] if %w[.yaml .yml .json].include?(File.extname(path))
        return %w[text_patterns puppet_parser] if File.extname(path) == '.pp'

        ['text_patterns']
      end

      def sanitized(markers: [])
        raise ArgumentError unless complete?
        return sanitized_members unless members.empty?

        result = text.dup
        merged_spans.reverse_each do |first, last, replacement|
          next if markers.include?(unquote(text[first...last]))

          result[first...last] = replacement
        end
        result
      end

      def unquote(raw)
        raw.delete_prefix("'").delete_suffix("'").delete_prefix('"').delete_suffix('"')
      end

      def sanitized_members
        members.each_with_index.map { |member, index| "[member-#{index + 1}]\n#{member.sanitized}\n" }.join
      end

      def aggregate
        members.each_with_index do |member, index|
          member.aggregate
          member.errors.each { |code| error(code) }
          @values.concat(member.values)
          member.findings.each do |finding|
            @findings << finding.merge(member: [index + 1, *finding[:member]].compact)
          end
        end
      end

      def merged_spans
        merged = []
        @spans.sort_by { |first, last, _| [first, -last] }.each do |first, last, replacement|
          if merged.last && first < merged.last[1]
            merged.last[1] = [last, merged.last[1]].max
          else
            merged << [first, last, replacement]
          end
        end
        merged
      end
    end
  end
end
