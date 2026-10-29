# frozen_string_literal: true

module ProjectTools
  module Shared
    # Select only an activated gem; installed alternatives and PATH never choose the runtime.
    class PuppetRuntime
      class Error < StandardError; end

      NAMES = %w[puppet openvox].freeze
      attr_reader :spec

      def self.detect(specs: Gem.loaded_specs, features: $LOADED_FEATURES)
        selected = NAMES.filter_map { |name| specs[name] }
        raise Error, 'Select Puppet or OpenVox in the active bundle; no runtime is activated.' if selected.empty?
        raise Error, 'Conflicting runtimes: activate exactly one of Puppet and OpenVox.' unless selected.one?

        new(selected.first).tap { |runtime| runtime.verify_features(features) }
      end

      def initialize(spec)
        @spec = spec
      end

      def name
        spec.name == 'openvox' ? 'OpenVox' : 'Puppet'
      end

      def version
        spec.version.to_s
      end

      def to_s
        "#{name} #{version}"
      end

      def verify_features(features)
        roots = spec.full_require_paths.map { |path| File.realpath(path) }
        loaded = features.select { |path| core_feature?(path, roots) }
        return if loaded.all? { |path| roots.any? { |root| File.realpath(path).start_with?("#{root}/") } }

        raise Error, 'Loaded Puppet code does not belong to the activated runtime gem.'
      rescue SystemCallError
        raise Error, 'Cannot verify the origin of the selected Puppet runtime.'
      end

      def core_feature?(path, roots)
        relative = path[%r{/(puppet(?:\.rb|/.*))\z}, 1]
        relative && roots.any? { |root| File.file?(File.join(root, relative)) }
      end

      def executable(resolver: Gem.method(:bin_path))
        path = resolver.call(spec.name, 'puppet', version)
        verify_executable(path)
        self.class.record_usage(self)
        path
      rescue Gem::Exception, SystemCallError
        raise Error, 'The selected runtime does not provide its Puppet executable.'
      end

      def verify_executable(path)
        return if spec.executables.include?('puppet') && File.file?(path) &&
                  File.realpath(path).start_with?("#{File.realpath(spec.full_gem_path)}/")

        raise Error, 'The selected runtime does not provide its Puppet executable.'
      end

      def self.load!(feature = 'puppet')
        runtime = detect
        record_usage(runtime)
        runtime.load_feature(feature)
        runtime
      rescue Error => e
        record_usage("unavailable (#{e.message})")
        raise
      end

      def load_feature(feature)
        require 'puppet'
        require feature
        verify_features($LOADED_FEATURES)
        unless defined?(Puppet) && Puppet.respond_to?(:version) && Gem::Version.new(Puppet.version) == spec.version
          raise Error, 'Loaded Puppet version differs from the activated runtime gem.'
        end
      rescue LoadError, ArgumentError, TypeError
        raise Error, 'The selected Puppet runtime could not load its required interface.'
      end

      def self.parser
        load!('puppet/pops')
        parser = Puppet::Pops::Parser::EvaluatingParser.new
        verify_parser(parser)
        parser
      rescue Error
        raise
      rescue StandardError
        raise Error, 'Puppet parser does not provide the required syntax-tree interface.'
      end

      def self.verify_parser(parser)
        # Exercise parsing, traversal and source positions, rather than accepting method names alone.
        tree = parser.parse_string("class runtime_probe { $value = 'ok' }", 'runtime_probe.pp')
        nodes = []
        tree._pcore_all_contents([]) { |node| nodes << node }
        definition = nodes.find { |node| node.is_a?(Puppet::Pops::Model::HostClassDefinition) }
        literal = nodes.find { |node| node.is_a?(Puppet::Pops::Model::LiteralString) }
        return if valid_definition?(definition) && literal&.value == 'ok'

        raise Error, 'Puppet parser failed the syntax-tree capability probe.'
      end

      def self.valid_definition?(definition)
        definition && definition.name == 'runtime_probe' && definition.line == 1
      end

      def self.record_usage(runtime)
        Thread.current[:project_tools_runtime_usage]&.replace([runtime])
      end

      def self.with_usage
        previous = Thread.current[:project_tools_runtime_usage]
        usage = []
        Thread.current[:project_tools_runtime_usage] = usage
        yield usage
      ensure
        Thread.current[:project_tools_runtime_usage] = previous
      end
    end
  end
end
