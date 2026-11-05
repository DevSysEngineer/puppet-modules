# frozen_string_literal: true

module ProjectTools
  class Catalog
    # Inspect the native execution graph without traversing or applying its resources.
    module DependencyCycles
      class CheckError < StandardError; end
      class ResourceUnavailable < StandardError; end

      def self.check(catalog)
        # The native reporter logs actual paths; its sorted components are not paths.
        cycles = execution_graph(catalog).report_cycles_in_graph
        return { dependency_cycles: 0 } if cycles.nil?

        raise TypeError, 'Unexpected native cycle report result' unless valid_cycles?(cycles)

        { dependency_cycles: cycles.size }
      rescue ResourceUnavailable => e
        { dependency_cycle_skip: e.message }
      rescue StandardError => e
        raise CheckError, "Dependency cycle check could not run: #{e.class}: #{e.message}"
      end

      def self.execution_graph(catalog)
        catalog.to_ral.relationship_graph
      rescue Puppet::ResourceError => e
        # Resource validation depends on providers and the isolated catalog's defaults.
        raise ResourceUnavailable, e.message
      end

      def self.valid_cycles?(cycles)
        cycles.is_a?(Array) && !cycles.empty? && cycles.all? { |cycle| cycle.is_a?(Array) && !cycle.empty? }
      end
    end
  end
end
