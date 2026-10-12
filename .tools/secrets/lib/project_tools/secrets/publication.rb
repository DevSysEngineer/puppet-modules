# frozen_string_literal: true

require 'fileutils'
require 'tmpdir'
require_relative 'source_reader'

module ProjectTools
  module Secrets
    # Publish sanitized files in new private destinations, withdrawing partial output.
    class Publication
      def initialize(sources)
        @sources = sources.map { |path| File.exist?(path) ? File.realpath(path) : File.expand_path(path) }
      end

      def destination(path)
        raise ArgumentError if path.empty?

        parent = File.realpath(File.dirname(File.expand_path(path)))
        target = File.join(parent, File.basename(path))
        raise ArgumentError if File.exist?(target) || File.symlink?(target)
        raise ArgumentError if @sources.any? { |source| target == source || target.start_with?("#{source}/") }

        target
      end

      def analysis_tree(directory, files)
        target = destination(directory)
        staging = Dir.mktmpdir('.secrets-analysis-', File.dirname(target))
        write_tree(staging, files)
        raise Failure, 'destination_exists' if File.exist?(target) || File.symlink?(target)

        File.rename(staging, target)
      ensure
        FileUtils.remove_entry(staging) if staging && File.exist?(staging)
      end

      def write_tree(staging, files)
        files.each do |name, text|
          path = Paths.inside(staging, name)
          FileUtils.mkdir_p(File.dirname(path), mode: 0o700)
          Paths.write_new(path, text)
        end
      end
    end
  end
end
