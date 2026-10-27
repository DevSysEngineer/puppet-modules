# frozen_string_literal: true

require 'fileutils'
require 'pathname'
require 'yaml'
require 'puppet'

module ProjectTools
  class Catalog
    # Validate compilation input without replacing native lookup, merge or conversion behavior.
    class HieraFixture
      include Puppet::Pops::Lookup::Interpolation

      LOCATIONS = %w[path paths glob globs].freeze

      def initialize(directory)
        @directory = directory
        @files = files(directory)
        @config = load_config
        validate_entries
        validate_paths
      rescue Psych::Exception, Puppet::Error => e
        raise ArgumentError, "Invalid tests/hiera/hiera.yaml: #{e.message}"
      end

      def load_config
        path = File.join(@directory, 'hiera.yaml')
        raise ArgumentError, 'Expected tests/hiera/hiera.yaml.' unless @files.include?(path)

        config = YAML.safe_load_file(path)
        unless config.is_a?(Hash) && config['version'] == 5 && config['hierarchy'].is_a?(Array)
          raise ArgumentError, 'Expected an explicit Hiera 5 hierarchy in tests/hiera/hiera.yaml.'
        end

        Puppet::Pops::Lookup::HieraConfigV5.new(Pathname(@directory), Pathname(path), config, nil)
        config['defaults'] ||= Puppet::Pops::Lookup::HieraConfigV5::DEFAULT_CONFIG_HASH.fetch('defaults')
        config
      end

      def files(directory)
        ordinary_input(directory)
        Dir.children(directory).sort.flat_map { |name| fixture_entry(File.join(directory, name)) }
      end

      def fixture_entry(path)
        ordinary_input(path)
        return files(path) if File.directory?(path)

        raise ArgumentError, "Expected a regular Hiera fixture file: #{path}" unless File.file?(path)

        [path]
      end

      def ordinary_input(path)
        raise ArgumentError, "Hiera fixture inputs must not be symlinks: #{path}" if File.symlink?(path)
      end

      def validate_entries
        raise ArgumentError, 'Hiera fixtures support the catalog hierarchy only.' if @config.key?('plan_hierarchy')

        names = @config.fetch('hierarchy').map { |entry| entry.fetch('name') }
        raise ArgumentError, 'Hiera hierarchy names must be unique.' unless names.uniq == names

        validate_backend(@config.fetch('defaults'))
        @config.fetch('hierarchy').each { |entry| validate_entry(entry) }
      end

      def validate_backend(entry)
        return if (entry.keys & %w[lookup_key data_dig uri uris mapped_paths]).empty? &&
                  (!entry.key?('data_hash') || entry['data_hash'] == 'yaml_data')

        raise ArgumentError, 'Hiera fixtures support local yaml_data with path, paths, glob or globs only.'
      end

      def validate_entry(entry)
        validate_backend(entry)
        return if (entry.keys & LOCATIONS).any?

        raise ArgumentError, 'Expected a local path, paths, glob or globs in each Hiera hierarchy entry.'
      end

      def validate_paths(invocation = nil)
        @config.fetch('hierarchy').each do |entry|
          datadir = fixture_path(entry.fetch('datadir', @config.fetch('defaults').fetch('datadir', 'data')), invocation)
          contained_path(datadir)
          entry.slice(*LOCATIONS).each do |key, paths|
            Array(paths).each { |path| validate_location(datadir, key, path, invocation) }
          end
        end
      end

      def validate_location(datadir, key, path, invocation)
        relative = File.join(datadir, fixture_path(path, invocation))
        if key.start_with?('glob') && relative.split('/').include?('..')
          raise ArgumentError, 'Hiera fixture globs must not contain parent traversal.'
        end

        contained_path(relative)
      end

      def fixture_path(value, invocation)
        expressions = value.scan(/%\{([^}]+)\}/).flatten
        unless expressions.all? { |expression| expression.match?(/\Afacts(?:\.[\w-]+)+\z/) }
          raise ArgumentError, 'Hiera fixture paths may interpolate facts only.'
        end

        path = invocation ? interpolate(value, invocation, false) : value.gsub(/%\{[^}]+\}/, 'fixture')
        if Pathname(path).absolute? || path.match?(/\A[a-z][a-z0-9+.-]*:/i)
          raise ArgumentError, 'Hiera fixture paths must be local and relative.'
        end

        path
      end

      def contained_path(path)
        root = File.expand_path(@directory)
        resolved = File.expand_path(path, root)
        return if resolved == root || resolved.start_with?("#{root}/")

        raise ArgumentError, 'Hiera fixture path escapes tests/hiera/.'
      end

      def copy_to(destination, scope)
        validate_paths(Puppet::Pops::Lookup::Invocation.new(scope))
        @files.each do |source|
          target = File.join(destination, source.delete_prefix("#{@directory}/"))
          FileUtils.mkdir_p(File.dirname(target), mode: 0o700)
          FileUtils.copy_file(source, target)
          File.chmod(0o600, target)
        end
      rescue Puppet::Error => e
        raise ArgumentError, "Invalid Hiera fixture paths: #{e.message}"
      end
    end
  end
end
