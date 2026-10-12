# frozen_string_literal: true

module ProjectTools
  module Secrets
    # Explicit operations define the complete final tree, including unchanged files.
    class Changes
      attr_reader :final, :origins, :deleted, :moves, :removed

      def initialize(data, change)
        @data = data
        validate_shape(change)
        @renames = change.fetch('rename', {})
        @deleted = change.fetch('delete', [])
        @writes = change.fetch('write', [])
        @adds = change.fetch('add', [])
        @moves = change.fetch('move_ids', {})
        @removed = change.fetch('remove_ids', [])
        select
      end

      def validate_shape(change)
        arrays = %w[write add delete remove_ids]
        hashes = %w[rename move_ids]
        raise Failure, 'invalid_changes' unless change.is_a?(Hash) && (change.keys - arrays - hashes).empty?

        arrays.each { |key| validate_list(change.fetch(key, [])) }
        validate_hashes(change, hashes)
      end

      def validate_hashes(change, hashes)
        hashes.each do |key|
          hash = change.fetch(key, {})
          raise Failure, 'invalid_changes' unless hash.is_a?(Hash)

          validate_list(hash.keys + hash.values, unique: false)
        end
      end

      def validate_list(list, unique: true)
        valid = list.is_a?(Array) && list.all?(String) && (!unique || list.uniq == list)
        raise Failure, 'invalid_changes' unless valid
      end

      def select
        sources = @renames.keys + deleted + @writes
        validate_list(sources)
        raise Failure, 'unknown_source' unless (sources - @data['files'].keys).empty?

        targets = validate_targets
        build_final(targets)
        @renames.each { |old, target| rename_metadata(old, target) }
      end

      def validate_targets
        targets = @adds + @renames.values
        validate_list(targets)
        raise Failure, 'unauthorized_destination' unless (targets - @data['destinations'].keys).empty?

        targets
      end

      def build_final(targets)
        @final = unchanged
        (@writes + targets).each { |path| final[path] = SourceReader.local_read(Paths.inside(@data['tree'], path)) }
        set_origins
        @data['final_analysis'] = final
        @deleted += @renames.keys
      end

      def set_origins
        @origins = final.keys.to_h { |path| [path, @renames.key(path) || path] }
      end

      def unchanged
        selected = @data['files'].reject { |path, _| (deleted + @renames.keys).include?(path) }
        selected.transform_values { |file| file['analysis'] }
      end

      def rename_metadata(old, target)
        source = @data['files'].fetch(old)
        @data['destinations'][target].merge!(source.slice('mode', 'uid', 'gid'))
        @data['destinations'][target]['metadata_source'] = source['source']
      end

      def original(path)
        @data['files'][origins[path]]
      end

      def source(path)
        (@data['files'][path] || @data['destinations'].fetch(path)).fetch('source')
      end
    end
  end
end
