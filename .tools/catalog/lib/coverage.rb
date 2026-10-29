# frozen_string_literal: true

module ProjectTools
  class Catalog
    # Compare native declarations with realized resources, independently of the scenario's spelling.
    class Coverage
      def initialize(directory)
        parser = Shared::PuppetRuntime.parser
        @definitions = Dir.glob(File.join(directory, 'manifests/**/*.pp')).flat_map do |path|
          parser.parse_file(path).definitions.filter_map { |definition| definition_name(definition) }
        end.uniq.sort
      end

      def definition_name(definition)
        case definition
        when Puppet::Pops::Model::HostClassDefinition
          "class #{definition.name}"
        when Puppet::Pops::Model::ResourceTypeDefinition
          "define #{definition.name}"
        end
      end

      def result(catalog)
        resources = compiled_resources(catalog)
        compiled = @definitions & resources
        missing = @definitions - compiled
        { total: @definitions.size, compiled: compiled, missing: missing }
      end

      def compiled_resources(catalog)
        catalog.resources.reject(&:virtual?).map do |resource|
          resource.type == 'Class' ? "class #{resource.title.downcase}" : "define #{resource.type.downcase}"
        end
      end
    end
  end
end
