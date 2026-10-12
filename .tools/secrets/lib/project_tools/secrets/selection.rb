# frozen_string_literal: true

require_relative 'scanner'
require_relative 'output'

module ProjectTools
  module Secrets
    # Bind one explicit source selection and Hiera context to local policy bytes.
    class Selection
      attr_reader :data, :files

      def initialize(data, state_directory)
        @data = data
        @state_directory = state_directory
        @aliases = {}
      end

      def prepare
        locations!
        load_policy
      end

      def load_policy
        data['policy_bytes'] = SourceReader.local_read(data['policy_path'])
        data['policy'] = JSON.parse(data['policy_bytes'])
        @files = selected_files
        raise Failure, 'empty_selection' if files.empty?
      rescue KeyError, TypeError, JSON::ParserError
        raise Failure, 'invalid_policy'
      end

      def selected_files
        policy = data['policy']
        (policy.fetch('files') + policy.fetch('context', [])).uniq
      end

      def locations!
        roots = [data['root'], data['tree'], @state_directory]
        overlap = roots.combination(2).any? { |a, b| Paths.within?(a, b) || Paths.within?(b, a) }
        raise Failure, 'unsafe_output_location' if overlap
        raise Failure, 'unsafe_policy_location' if Paths.within?(data['policy_path'], data['tree'])
      end

      def safe_path(relative, documents)
        supplied = data['policy'].fetch('aliases', {}).fetch(relative, relative)
        cleaner = Output.new(documents, [])
        parts = Paths.relative(supplied).split('/').map { |part| @aliases[part] ||= alias_component(part, cleaner) }
        Paths.relative(parts.join('/'))
      end

      def alias_component(part, cleaner)
        return part if cleaner.safe_path(part) == part

        extension = File.extname(part)
        extension = '' unless %w[.pp .yaml .yml .json .erb .epp .sh .rb .txt .md].include?(extension)
        "alias-#{SecureRandom.hex(16)}#{extension}"
      end

      def destinations(documents)
        data['policy'].fetch('destinations', {}).each do |relative, mode|
          validate_destination(relative, mode)

          safe = safe_path(relative, documents)
          reserve!(safe)
          data['destinations'][safe] = { 'source' => relative, 'mode' => mode.to_i(8) }
        end
      end

      def validate_destination(relative, mode)
        raise Failure, 'destination_exists' if File.exist?(Paths.inside(data['root'], relative))
        raise Failure, 'invalid_mode' unless %w[0600 0644 0700 0755].include?(mode)
      end

      def reserve!(safe)
        used = data['files'].keys + data['destinations'].keys
        raise Failure, 'alias_conflict' if used.any? { |path| path.downcase == safe.downcase }
      end
    end
  end
end
