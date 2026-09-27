# frozen_string_literal: true

require 'json'
require 'pathname'
require 'project_lint/project_version'
require 'project_lint/root_metadata'

module ProjectLint
  # Project metadata is selected independently of manifests and dependency modulepaths.
  class Metadata
    REPOSITORY_EXCLUSIONS = %w[examples vendor concat debconf reboot stdlib timezone].freeze

    def initialize(root = Dir.pwd)
      @root = File.realpath(root)
      @repository = File.file?(File.join(@root, '.tools/lint/lint-project.gemspec'))
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
      path = ENV.fetch('PROJECT_LINT_MODULES_PATH', nil)
      if path.nil? || path.empty? || Pathname.new(path).absolute?
        add('.puppet-lint.rc',
            'modules_path: set PROJECT_LINT_MODULES_PATH to a non-empty path relative to the project root')
        return
      end

      base = File.expand_path(path, @root)
      return base if File.directory?(base)

      add('.puppet-lint.rc', 'modules_path: PROJECT_LINT_MODULES_PATH must refer to an existing directory')
    end

    def module_directory?(base, name)
      return false if name.start_with?('.') || (@repository && REPOSITORY_EXCLUSIONS.include?(name))

      directory = File.join(base, name)
      File.directory?(directory) && !File.symlink?(directory)
    end

    def excluded?(path)
      PuppetLint.configuration.ignore_paths.any? do |pattern|
        File.fnmatch(pattern, path) || File.fnmatch(pattern, "./#{path}")
      end
    end

    def findings
      @findings = { 'metadata.json' => [] }
      selected = paths
      selected.each { |path| @findings[path] = [] }
      version = project_version
      check_root(version)
      prefix = name_prefix unless selected.empty?
      selected.each { |path| check(path, version, prefix) }
      @findings
    end

    def check_root(version)
      data = read_metadata('metadata.json')
      return unless data

      name = 'puppet-modules' if @repository
      RootMetadata.new(data, version: version, name: name).problems.each do |message|
        add('metadata.json', message)
      end
    end

    def project_version
      ProjectVersion.new(@root).read
    rescue ArgumentError => e
      add('VERSION', e.message)
    end

    def name_prefix
      return 'puppetmodules' if @repository

      prefix = ENV.fetch('PROJECT_LINT_METADATA_PREFIX', nil)
      return prefix if prefix&.match?(/\A[a-zA-Z0-9]+\z/)

      add('.puppet-lint.rc', 'name: set PROJECT_LINT_METADATA_PREFIX to the consumer project owner (letters/digits)')
      nil
    end

    def check(path, version, prefix)
      data = read_metadata(path)
      return unless data

      expected_name = "#{prefix}-#{File.basename(File.dirname(path))}" if prefix
      add(path, "name: expected #{expected_name}") if prefix && data['name'] != expected_name
      mismatch = ProjectVersion.mismatch(data['version'], version)
      add(path, mismatch) if mismatch
    end

    def read_metadata(path)
      data = JSON.parse(File.read(File.join(@root, path)))
      return data if data.is_a?(Hash)

      add(path, 'metadata: expected a JSON object')
    rescue JSON::ParserError, EncodingError
      add(path, 'metadata: invalid JSON; expected a JSON object')
    rescue Errno::ENOENT
      location = path == 'metadata.json' ? 'the project root' : 'every module directory'
      add(path, "metadata: missing metadata.json; expected a file in #{location}")
    rescue SystemCallError
      add(path, 'metadata: cannot read metadata.json; expected a readable file')
    end

    def add(path, message)
      (@findings[path] ||= []) << { check: :project_metadata, kind: :error, line: 1, column: 1,
                                    message: message, path: path, filename: File.basename(path),
                                    fullpath: File.join(@root, path) }
      nil
    end
  end
end
