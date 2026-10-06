# frozen_string_literal: true

require 'json'
require 'pathname'
require 'project_tools/metadata/project_version'
require 'project_tools/metadata/root_metadata'
require 'project_tools/metadata/metadata_file'

module ProjectTools
  module Metadata
    # Project metadata is selected independently of manifests and dependency modulepaths.
    class Scanner
      REPOSITORY_EXCLUSIONS = %w[examples vendor concat debconf reboot stdlib].freeze

      attr_reader :results

      def initialize(root = Dir.pwd, ignore_paths: [])
        @root = File.realpath(root)
        @ignore_paths = ignore_paths
        @version_source = ProjectVersion.new(@root)
        @repository = File.file?(File.join(@root, '.tools/metadata/project-tools-metadata.gemspec'))
      end

      def paths
        base = modules_path
        return [] unless base

        Dir.children(base).sort.filter_map do |name|
          next unless module_directory?(base, name)

          path = Pathname.new(File.join(base, name, 'metadata.json')).relative_path_from(Pathname.new(@root)).to_s
          path unless excluded?(path)
        end
      end

      def modules_path
        path = ENV.fetch('PROJECT_METADATA_MODULES_PATH', nil)
        if path.nil? || path.empty? || Pathname.new(path).absolute?
          add('configuration',
              'modules_path: set PROJECT_METADATA_MODULES_PATH to a non-empty path relative to the project root')
          return
        end

        configured_directory(File.expand_path(path, @root))
      end

      def configured_directory(base)
        unless File.directory?(base)
          return add('configuration', 'modules_path: PROJECT_METADATA_MODULES_PATH must refer to an existing directory')
        end
        return base unless @version_source.foreign_directory?(base)

        add('configuration', 'modules_path: selects another project; run from its root with its own VERSION')
      end

      def module_directory?(base, name)
        return false if name.start_with?('.') || (@repository && REPOSITORY_EXCLUSIONS.include?(name))

        directory = File.join(base, name)
        File.directory?(directory) && !File.symlink?(directory) && !@version_source.foreign_directory?(directory)
      end

      def excluded?(path)
        @ignore_paths.any? do |pattern|
          File.fnmatch(pattern, path) || File.fnmatch(pattern, "./#{path}")
        end
      end

      def findings(fix: false, &on_problem)
        @on_problem = on_problem
        @results = { 'metadata.json' => [] }
        @fix = fix
        selected = paths
        selected.each { |path| @results[path] = [] }
        version = project_version
        check_root(version)
        prefix = name_prefix unless selected.empty?
        selected.each { |path| check(path, version, prefix) }
        @results
      end

      def check_root(version)
        data = read_metadata('metadata.json', version, @repository ? 'puppet-modules' : nil)
        return unless data

        name = 'puppet-modules' if @repository
        RootMetadata.new(data, version: version, name: name).problems.each do |message|
          add('metadata.json', message)
        end
      end

      def project_version
        @version_source.read
      rescue ArgumentError => e
        add('VERSION', e.message)
      end

      def name_prefix
        return 'puppetmodules' if @repository

        prefix = ENV.fetch('PROJECT_METADATA_PREFIX', nil)
        return prefix if prefix&.match?(/\A[a-zA-Z0-9]+\z/)

        add('configuration', 'name: set PROJECT_METADATA_PREFIX to the consumer project owner (letters/digits)')
        nil
      end

      def check(path, version, prefix)
        expected_name = "#{prefix}-#{File.basename(File.dirname(path))}" if prefix
        data = read_metadata(path, version, expected_name)
        return unless data

        add(path, "name: expected #{expected_name}") if prefix && data['name'] != expected_name
        mismatch = ProjectVersion.mismatch(data['version'], version)
        add(path, mismatch) if mismatch
        RootMetadata.new(data, version: version, name: expected_name).module_problems.each do |message|
          add(path, message)
        end
      end

      def read_metadata(path, version, name)
        file = MetadataFile.new(@root, path, version: version, name: name, fix: @fix)
        data = file.read
        file.problems.each { |message, kind| add(path, message, kind: kind) }
        data
      end

      def add(path, message, kind: :error)
        (@results[path] ||= []) << { check: :project_metadata, kind: kind, line: 1, column: 1,
                                     message: message, path: path, filename: File.basename(path),
                                     fullpath: File.join(@root, path) }
        @on_problem&.call(@results[path].last)
        nil
      end
    end
  end
end
