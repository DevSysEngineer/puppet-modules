# frozen_string_literal: true

module ProjectTools
  module Secrets
    # Source offsets only: all detection still runs against the complete document.
    class MarkdownContext
      Region = Data.define(:first, :last, :code)
      FENCE = /\A {0,3}(`{3,}|~{3,})([^\r\n]*)(?:\r?\n)?\z/.freeze
      INDENT = /\A(?: {4}| {0,3}\t)/.freeze
      CONTAINER = /\][ \t]*(?:\(|\[)|^[ \t]*(?:>|\#{1,6}[ \t]|[-+*][ \t]|\d+[.)][ \t]|\[[^\]\r\n]+\]:)/.freeze

      def initialize(text)
        @text = text
        @regions = [Region.new(0, 0, false)]
        @lines = @text.lines
        @offsets = @lines.reduce([0]) { |offsets, line| offsets << (offsets.last + line.length) }
        blocks
      end

      def at(offset)
        @regions.bsearch { |region| region.last > offset } || Region.new(offset, @text.length, false)
      end

      def append(first, last, code: false)
        @regions << Region.new(first, last, code) if last > first
      end

      def blocks
        following = 0
        @lines.each_index do |index|
          next if index < following

          fence = opening_fence(@lines[index])
          next unless fence || INDENT.match?(@lines[index])

          break if inline(@offsets[following], @offsets[index])

          following = fence ? fenced(index, fence) : indented(index)
        end
        inline(@regions.last.last, @text.length)
      end

      def opening_fence(line)
        match = FENCE.match(line)
        match[1] if match && (match[1].start_with?('~') || !match[2].include?('`'))
      end

      def fenced(index, fence)
        append(@offsets[index], @offsets[index + 1])
        first = @offsets[index + 1]
        index = fence_end(index, fence)
        return index.tap { append(first, @text.length) } if index == @lines.length

        fenced_body(first, index)
        index + 1
      end

      def fence_end(index, fence)
        closing = /\A {0,3}#{Regexp.escape(fence[0])}{#{fence.length},}[ \t]*(?:\r?\n)?\z/
        index += 1
        index += 1 while index < @lines.length && !closing.match?(@lines[index])
        index
      end

      def fenced_body(first, index)
        last = @offsets[index]
        # Retain the final line ending so a whole-fragment marker cannot join the closing fence.
        ending = @text[first...last][/\r?\n\z/].to_s.length
        append(first, last - ending, code: true)
        append(last - ending, @offsets[index + 1])
      end

      def indented(index)
        first = @offsets[index]
        index += 1
        index += 1 while index < @lines.length && (INDENT.match?(@lines[index]) || @lines[index].strip.empty?)
        # Container indentation needs a full block parser; it is a boundary, never a fallback.
        append(first, @offsets[index])
        index
      end

      def inline(first, last)
        # HTML and autolinks can outlive paragraphs; their backticks are not code boundaries.
        return append(first, @text.length) if @text[first...last].match?(%r{<[a-z!/?]}i)

        cursor = first
        @text[first...last].to_enum(:scan, /\r?\n[ \t]*\r?\n/).each do
          start, stop = Regexp.last_match.offset(0).map { |offset| first + offset }
          code_spans(cursor, start)
          append(start, stop)
          cursor = stop
        end
        code_spans(cursor, last)
        false
      end

      def code_spans(first, last)
        text = @text[first...last]
        return append(first, last) if CONTAINER.match?(text)

        runs = text.to_enum(:scan, /`+/).map { Regexp.last_match.offset(0).map { |offset| first + offset } }
        consume_spans(first, last, runs, matching_runs(runs))
      end

      def matching_runs(runs)
        following = {}
        runs.each_index.reverse_each.with_object({}) do |index, closers|
          start, stop = runs[index]
          closers[index] = following[stop - start]
          following[stop - start] = index
        end
      end

      def consume_spans(first, last, runs, closers)
        runs.each_with_index do |(start, stop), index|
          next if start < first || escaped?(start)

          closing = closers[index]
          next unless closing

          append(first, stop)
          append(stop, runs[closing][0], code: true)
          append(*runs[closing])
          first = runs[closing][1]
        end
        append(first, last)
      end

      def escaped?(index)
        index.positive? && (index - 1 - (@text.rindex(/[^\\]/, index - 1) || -1)).odd?
      end
    end
  end
end
