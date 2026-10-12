# frozen_string_literal: true

require 'open3'

module ProjectTools
  module Secrets
    # Stage protected backups and preserve native metadata on the destination filesystem.
    module FileReplacement
      def stage(entry)
        path = source(entry)
        FileUtils.mkdir_p(File.dirname(path), mode: 0o700)
        entry['staging'] = File.join(File.dirname(path), ".secrets-#{SecureRandom.hex(16)}")
        save
        Paths.private_directory(entry['staging'])
        backup(entry, path) if entry['before']
        stage_after(entry) if entry['after']
      end

      def backup(entry, path)
        raise Failure, 'source_conflict' unless current(path) == entry['before']

        verify_identity(entry, path)

        preserve_copy(path, File.join(entry['staging'], 'before'))
      end

      def stage_after(entry)
        target = File.join(entry.fetch('staging'), 'after')
        metadata_source = entry['metadata_source'] && Paths.inside(@data['root'], entry['metadata_source'])
        if entry['before'] || metadata_source
          preserve_copy(metadata_source || File.join(entry['staging'], 'before'), target)
          File.binwrite(target, entry['after'])
        else
          stage_new(entry, target)
        end
        record_staged(entry, target)
      end

      def record_staged(entry, target)
        File.open(target, 'r', &:fsync)
        entry['after_identity'] = SourceVersions.identity(target)
        save
      end

      def verify_identity(entry, path)
        return unless entry['before_identity']
        return if SourceVersions.identity(path) == entry['before_identity']

        raise Failure, 'source_conflict'
      end

      def owned_after?(entry, path)
        entry['after'].nil? || (entry['after_identity'] && SourceVersions.identity(path) == entry['after_identity'])
      end

      def stage_new(entry, target)
        Paths.write_new(target, entry['after'])
        File.chown(entry['uid'], entry['gid'], target)
        File.chmod(entry['mode'], target)
      end

      def preserve_copy(source, target)
        flags = RUBY_PLATFORM.include?('darwin') ? ['-p'] : ['--preserve=all']
        _stdout, _stderr, status = Open3.capture3('cp', *flags, source, target)
        raise Failure, 'metadata_copy_failed' unless status.success?
      end

      def current(path)
        File.exist?(path) ? SourceReader.local_read(path) : nil
      end

      def install(path, staged, absent:)
        if staged.nil?
          File.unlink(path)
        elsif absent
          File.link(staged, path)
        else
          File.rename(staged, path)
        end
        File.open(File.dirname(path), &:fsync)
      end

      def rollback_content(entry, path)
        return install(path, nil, absent: false) unless entry['before']

        backup = entry['staging'] && File.join(entry['staging'], 'before')
        raise Failure, 'recovery_backup_missing' unless backup && File.file?(backup)

        staged = File.join(entry['staging'], 'restore')
        preserve_copy(backup, staged)
        install(path, staged, absent: entry['after'].nil?)
      end

      def ordinary_mode!(target)
        raise Failure, 'privileged_mode_unsupported' unless target['mode'].nobits?(0o6000)
      end
    end
  end
end
