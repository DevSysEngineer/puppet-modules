# frozen_string_literal: true

require 'json'
require 'semantic_puppet'

module ProjectTools
  module ModuleDependencies
    # Compare only the active project's dependency declarations with the native environment.
    class RootDependencies
      def initialize(root, result)
        @path = File.join(root, 'metadata.json')
        @result = result
        @requester = { scope: 'root', requester_name: 'project root', requester_metadata: @path }
      end

      def read
        extract_dependencies(JSON.parse(File.read(@path)))
      rescue JSON::ParserError, EncodingError
        input_error('Invalid JSON in root metadata; inspect the file locally.')
      rescue SystemCallError => e
        input_error("Cannot read root metadata (#{e.class}).")
      end

      def extract_dependencies(metadata)
        identify_root(metadata) if metadata.is_a?(Hash)
        unless metadata.is_a?(Hash) && metadata['dependencies'].is_a?(Array)
          return input_error('Expected a JSON object with a dependencies array.')
        end

        @dependencies = metadata['dependencies'].select do |dependency|
          valid = valid_dependency?(dependency)
          input_error('Every root dependency needs a Forge name and a non-empty version_requirement.') unless valid
          valid
        end
      end

      def identify_root(metadata)
        { 'name' => :requester_name, 'version' => :requester_version }.each do |field, key|
          value = metadata[field]
          @requester[key] = value if value.is_a?(String) && !value.empty?
        end
      end

      def valid_dependency?(dependency)
        dependency.is_a?(Hash) && dependency['name'].is_a?(String) &&
          Puppet::Module.is_module_namespaced_name?(dependency['name'].tr('/', '-')) &&
          dependency['version_requirement'].is_a?(String) && !dependency['version_requirement'].strip.empty?
      end

      def input_error(message)
        @result.error(:metadata_error, message, **@requester)
      end

      def check(environment)
        Array(@dependencies).each { |dependency| compare(environment, dependency) }
      end

      def compare(environment, dependency)
        name = dependency.fetch('name').tr('-', '/')
        selected = environment.module_by_forge_name(name)
        context = { **@requester, dependency_name: name, version_requirement: dependency.fetch('version_requirement'),
                                  selected_version: selected&.version, selected_metadata: selected&.metadata_file }
        reason = comparison_reason(selected, dependency.fetch('version_requirement'))
        @result.conflict(reason, **context) if reason
      end

      def comparison_reason(selected, requirement)
        return :missing unless selected

        range = SemanticPuppet::VersionRange.parse(requirement)
        version = SemanticPuppet::Version.parse(selected.version)
        :version_mismatch unless range.include?(version)
      rescue ArgumentError
        :non_semantic_version
      end
    end
  end
end
