# frozen_string_literal: true

require 'json'
require_relative 'ruby_container_parser'

module ProjectTools
  module Secrets
    # Keep container syntax visible while binding protected members to their owner.
    class RubyContainers
      def initialize(document)
        @document = document
        @text = document.text
        @containers = RubyContainerParser.new(document).containers
      end

      def leaves(node)
        node[:children] ? node[:children].flat_map { |child| leaves(child) } : [node]
      end

      def parts(first, last)
        finish = first + @text[first...last].rstrip.length
        node = @containers.find { |item| item[:first] == first && item[:last] == finish }
        return unless node

        leaves(node) if structural_gaps?(node)
      end

      def structural_gaps?(node)
        first = node[:first]
        remainder = @text[first...node[:last]].dup
        leaves(node).reverse_each { |member| remainder[(member[:first] - first)...(member[:last] - first)] = '' }
        remainder.match?(/\A[\s,\[\]{}]*\z/)
      end

      def member(first, last = first + 1)
        @members ||= @containers.flat_map { |node| leaves(node) }.uniq
        @members.find { |leaf| first >= leaf[:first] && last <= leaf[:last] }
      end

      def literal_member?(member, literal, entry)
        member[:first] == literal[0] && (member[:kind] == :key) == entry['key'] &&
          member.fetch(:value_last, member[:last]) == literal[1]
      end

      def replacement(member)
        member[:kind] == :key ? "'[REDACTED]' =>" : "'[REDACTED]'"
      end

      def descriptor(member)
        literal = @document.literals.find { |first, last, _| member.values_at(:first, :last) == [first, last] }
        { 'raw' => @text[member[:first]...member[:last]], 'type' => 'ruby_member',
          'replacement' => replacement(member), 'key' => member[:kind] == :key,
          'value' => literal && literal[2] }
      end

      def value(member)
        first = member[:first]
        last = member.fetch(:value_last, member[:last])
        literal = @document.literals.find { |start, stop, _| start == first && stop == last }
        literal ? literal[2] : @text[first...last].delete_prefix(':').delete_suffix(':')
      end

      def role(index)
        root = @containers.select { |node| index >= node[:first] && index < node[:last] }.max_by do |node|
          node[:last] - node[:first]
        end
        return unless root

        JSON.generate([@document.marker_role(root[:first]), *route(root, index)])
      end

      def route(node, index)
        return [] unless node[:children]

        child = node[:children].find { |item| index >= item[:first] && index < item[:last] }
        return [] unless child
        return ['array', *route(child, index)] if node[:kind] == :array

        hash_route(node, child, index)
      end

      def hash_route(node, child, index)
        return ['key'] if child[:kind] == :key

        key = node[:children][node[:children].index(child) - 1]
        ['value', value(key), *route(child, index)]
      end
    end
  end
end
