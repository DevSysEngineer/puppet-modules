# frozen_string_literal: true

module ProjectTools
  module ModuleDependencies
    # Validate comparable metadata and preserve each native unmet relationship before presentation.
    class ModuleDependencies
      def initialize(result)
        @result = result
      end

      def check(mod)
        return missing_metadata(mod) unless File.exist?(mod.metadata_file)

        inspect_module(mod)
        check_dependencies(mod) if @result.assessed.include?(mod.metadata_file)
      end

      def missing_metadata(mod)
        if !File.directory?(mod.path) || !mod.metadata.empty? || File.symlink?(mod.metadata_file)
          metadata_error(mod, 'Selected module or metadata disappeared or cannot be read.')
        else
          @result.unassessed << mod.path
        end
      end

      def metadata_error(mod, message)
        @result.error(:metadata_error, message, scope: 'module', requester_name: mod.name,
                                                requester_metadata: mod.metadata_file)
      end

      def inspect_module(mod)
        unless usable_metadata?(mod)
          metadata_error(mod, 'Selected metadata lacks usable identity, version or dependency fields.')
          return
        end

        SemanticPuppet::Version.parse(mod.version)
        @result.assessed << mod.metadata_file
      rescue ArgumentError
        metadata_error(mod, 'Selected module version is not a semantic version.')
      end

      def usable_metadata?(mod)
        mod.metadata.is_a?(Hash) && forge_name?(mod.forge_name) && mod.version.is_a?(String) &&
          mod.dependencies.is_a?(Array) && mod.dependencies.all? { |dep| usable_dependency?(dep) }
      end

      def forge_name?(name)
        name.is_a?(String) && Puppet::Module.is_module_namespaced_name?(name.tr('/', '-'))
      end

      def usable_dependency?(dependency)
        dependency.is_a?(Hash) && forge_name?(dependency['name']) && dependency['version_requirement'].is_a?(String)
      end

      def check_dependencies(mod)
        mod.unmet_dependencies.each { |finding| record_finding(mod, finding) }
      rescue StandardError => e
        @result.error(:runtime_error, "OpenVox could not compare module dependencies (#{e.class}).",
                      scope: 'module', requester_name: mod.name, requester_metadata: mod.metadata_file)
      end

      def original_requirement(mod, finding)
        dependency = mod.dependencies.find do |dep|
          dep['name'] == finding[:name] &&
            dep['version_requirement'].gsub(/^(?=\d)/, 'v') == finding[:version_constraint]
        end
        dependency.fetch('version_requirement')
      end

      def record_finding(mod, finding)
        selected = mod.environment.module_by_forge_name(finding.fetch(:name))
        @result.conflict(finding.fetch(:reason), scope: 'module', requester_name: mod.forge_name,
                                                 requester_version: mod.version, requester_metadata: mod.metadata_file,
                                                 dependency_name: finding.fetch(:name),
                                                 version_requirement: original_requirement(mod, finding),
                                                 selected_version: selected&.version,
                                                 selected_metadata: selected&.metadata_file)
      end
    end
  end
end
