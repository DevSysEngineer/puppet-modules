# frozen_string_literal: true

module ProjectTools
  class Catalog
    # Inspect the native execution graph without traversing or applying its resources.
    module DependencyCycles
      class CheckError < StandardError; end

      def self.check(catalog)
        # The native reporter logs actual paths; its sorted components are not paths.
        cycles = catalog.to_ral.relationship_graph.report_cycles_in_graph
        return 0 if cycles.nil?

        raise TypeError, 'Unexpected native cycle report result' unless valid_cycles?(cycles)

        cycles.size
      rescue StandardError => e
        raise CheckError, "Dependency cycle check could not run: #{e.class}: #{e.message}"
      end

      def self.valid_cycles?(cycles)
        cycles.is_a?(Array) && !cycles.empty? && cycles.all? { |cycle| cycle.is_a?(Array) && !cycle.empty? }
      end
    end
  end
end
