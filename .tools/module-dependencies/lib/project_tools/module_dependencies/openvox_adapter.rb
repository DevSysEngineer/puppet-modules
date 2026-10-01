# frozen_string_literal: true

require 'puppet'
require 'project_tools/module_dependencies/module_dependencies'

module ProjectTools
  module ModuleDependencies
    # Use one native environment; inventory candidates only to detect silently dropped modules.
    class OpenvoxAdapter
      def initialize(paths, result)
        @paths = paths
        @result = result
      end

      def scan
        isolated_runtime do
          environment = Puppet::Node::Environment.create(:dependency_scan, @paths)
          inspect_environment(environment)
          yield environment
        end
      rescue StandardError => e
        @result.error(:runtime_error, "OpenVox could not complete dependency inventory (#{e.class}).")
      end

      def inspect_environment(environment)
        candidates = native_candidates
        modules = environment.modules
        verify_inventory(candidates, modules)
        inspector = ModuleDependencies.new(@result)
        modules.each { |mod| inspector.check(mod) }
      rescue TypeError, NoMethodError, SystemCallError => e
        @result.error(:metadata_error, "Cannot load selected module metadata (#{e.class}).")
      end

      def isolated_runtime(&block)
        previous_lib = ENV.delete('PUPPETLIB')
        previous_strict = Puppet[:strict]
        destinations = Puppet::Util::Log.destinations.dup
        silence_native_logs
        Puppet[:strict] = :error
        # Requiring the runtime supplies defaults without reading personal configuration or facts.
        Puppet.override({ bolt_project: nil }, &block)
      ensure
        ENV['PUPPETLIB'] = previous_lib if previous_lib
        Puppet[:strict] = previous_strict if previous_strict
        Puppet::Util::Log.destinations.replace(destinations) if destinations
      end

      def silence_native_logs
        # Native parser messages can contain raw metadata; expose structured failures instead.
        sink = Puppet::Util::Log.desttypes.fetch(:array).new([])
        Puppet::Util::Log.destinations.replace(dependency_scan: sink)
      end

      def native_candidates
        @paths.each_with_object({}) do |path, candidates|
          Puppet::FileSystem.children(path).each do |entry|
            name = Puppet::FileSystem.basename_string(entry)
            next unless Puppet::Module.is_module_directory?(name, path)

            candidates[name] ||= File.join(path, name)
          end
        end
      end

      def verify_inventory(candidates, modules)
        selected = modules.to_h { |mod| [mod.name, mod.path] }
        candidates.each do |name, path|
          next if selected[name] == path && File.directory?(path)

          @result.error(:metadata_error, 'OpenVox omitted a selected module or its directory disappeared.',
                        scope: 'module', requester_name: name, requester_metadata: File.join(path, 'metadata.json'))
        end
      end
    end
  end
end
