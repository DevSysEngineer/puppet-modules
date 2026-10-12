# frozen_string_literal: true

require_relative 'file_replacement'
require_relative 'source_reader'
require_relative 'source_versions'

module ProjectTools
  module Secrets
    # The durable journal records intent before staging or replacing any source.
    class Transaction
      include FileReplacement

      def initialize(store, id, data)
        @store = store
        @id = id
        @data = data
      end

      def apply(candidates, integrity)
        begin_journal(candidates, integrity)
        stage_all
        replace_all
        @data['status'] = 'applied'
        save
        cleanup
        result('applied', true)
      rescue StandardError, SignalException => e
        @data['write_error'] = e.is_a?(Failure) ? e.code : 'write_failed'
        recover
      end

      def begin_journal(candidates, integrity)
        @data['journal'] = candidates.map { |path, bytes| operation(path, bytes) }
        @data['integrity'] = integrity
        @data['status'] = 'writing'
        save
      end

      def stage_all
        @data['journal'].each { |entry| stage(entry) }
      end

      def replace_all
        @data['journal'].each { |entry| replace(entry) }
      end

      def operation(path, bytes)
        old = @data['files'][path]
        target = old || @data['destinations'].fetch(path)
        ordinary_mode!(target)

        { 'file' => path, 'source' => target['source'], 'before' => old && old['original'], 'after' => bytes,
          'mode' => target['mode'], 'uid' => target.fetch('uid', Process.uid),
          'gid' => target.fetch('gid', Process.gid), 'state' => 'planned', 'action' => file_action(old, bytes, target),
          'metadata_source' => target['metadata_source'], 'before_identity' => old && old['identity'] }
      end

      def file_action(old, bytes, target)
        return 'deleted' if bytes.nil?
        return 'renamed' if target['metadata_source']

        old ? 'written' : 'added'
      end

      def source(entry)
        Paths.inside(@data['root'], entry['source'])
      end

      def save
        @store.save(@id, @data)
      end

      def replace(entry)
        path = source(entry)
        raise Failure, 'source_conflict' unless current(path) == entry['before']

        verify_identity(entry, path)

        entry['state'] = 'replacing'
        save
        install(path, entry['after'] && File.join(entry['staging'], 'after'), absent: entry['before'].nil?)
        entry['state'] = 'applied'
        save
      end

      def recover
        @data.fetch('journal', []).reverse_each { |entry| rollback(entry) }
        complete = @data.fetch('journal', []).all? { |entry| %w[planned restored].include?(entry['state']) }
        @data['status'] = complete ? 'rolled_back' : 'recovery_required'
        save
        cleanup if complete
        result(@data['status'], complete)
      rescue StandardError
        result('recovery_required', false)
      end

      def rollback(entry)
        return if entry['state'] == 'planned'

        entry['state'] = rollback_state(entry)
        save
      rescue StandardError
        entry['state'] = 'recovery_failed'
      end

      def rollback_state(entry)
        path = source(entry)
        bytes = current(path)
        if bytes == entry['after'] && owned_after?(entry, path)
          rollback_content(entry, path)
          'restored'
        elsif bytes == entry['before']
          'restored'
        else
          'external_change'
        end
      end

      def cleanup
        @data.fetch('journal', []).each do |entry|
          next unless entry['staging'] && File.directory?(entry['staging'])

          FileUtils.remove_entry(entry['staging'])
        end
      end

      def result(status, complete)
        { 'operation' => 'apply', 'status' => status, 'complete' => complete,
          'files' => @data.fetch('journal', []).map { |entry| entry.slice('file', 'state', 'action') },
          'integrity' => @data.fetch('integrity', []), 'errors' => [@data['write_error']].compact }
      end
    end
  end
end
