# frozen_string_literal: true

module ProjectTools
  class Catalog
    # Compare native declarations with realized resources, independently of the scenario's spelling.
    class Coverage
      def initialize(directory)
        parser = Puppet::Pops::Parser::EvaluatingParser.new
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

      def report(catalog)
        resources = compiled_resources(catalog)
        compiled = @definitions & resources
        missing = @definitions - compiled
        lines = ["Definition coverage: #{compiled.size}/#{@definitions.size}",
                 "Compiled definitions: #{compiled.join(', ')}"]
        lines << "Missing definitions (review required): #{missing.join(', ')}" unless missing.empty?
        lines.join("\n")
      end

      def compiled_resources(catalog)
        catalog.resources.reject(&:virtual?).map do |resource|
          resource.type == 'Class' ? "class #{resource.title.downcase}" : "define #{resource.type.downcase}"
        end
      end
    end
  end
end
