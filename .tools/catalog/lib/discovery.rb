# frozen_string_literal: true

require 'puppet'

module ProjectTools
  class Catalog
    # Match Puppet's module names and path precedence before selecting module-owned scenarios.
    class Discovery
      attr_reader :scenarios, :errors, :skipped

      def initialize(paths)
        @scenarios = []
        @errors = []
        @skipped = []
        modules(paths).sort.each { |name, path| inspect_tests(name, path) }
      end

      def modules(paths)
        paths.each_with_object({}) do |path, selected|
          Dir.children(path).sort.each do |name|
            next unless Puppet::Module.is_module_directory?(name, path)

            selected[name] ||= File.join(path, name)
          end
        rescue SystemCallError => e
          error(path, "Cannot discover modules: #{e.message}")
        end
      end

      def inspect_tests(name, path)
        directory = File.join(path, 'tests')
        unless Dir.children(path).include?('tests')
          @skipped << name
          return
        end

        select_scenarios(name, directory)
      rescue ArgumentError, SystemCallError => e
        error(name, "Cannot discover catalog scenarios: #{e.message}")
      end

      def select_scenarios(name, directory)
        manifests = inputs(File.join(directory, 'manifests'), '.pp')
        facts = inputs(File.join(directory, 'facts'), '.json')
        if manifests.empty? || facts.empty?
          error(name, 'Expected at least one tests/manifests/**/*.pp and tests/facts/**/*.json.')
          return
        end

        combine(name, facts, manifests, File.dirname(directory))
      end

      def combine(name, facts, manifests, module_directory)
        facts.product(manifests).each do |fact, manifest|
          @scenarios << { name: "#{name}/#{manifest[:name]} [#{fact[:name]}]",
                          facts: fact[:path], manifest: manifest[:path],
                          module_directory: module_directory }
        end
      end

      def inputs(directory, extension)
        # Explicit traversal reports unreadable directories instead of silently shrinking a glob.
        return [] unless File.exist?(directory) || File.symlink?(directory)
        raise ArgumentError, "Scenario inputs must not be symlinks: #{directory}" if File.symlink?(directory)

        files(directory).select { |path| path.end_with?(extension) }.map do |path|
          { path: path, name: path.delete_prefix("#{directory}/").delete_suffix(extension) }
        end
      end

      def files(directory)
        Dir.children(directory).sort.flat_map do |name|
          next [] if name == 'fixtures'

          path = File.join(directory, name)
          raise ArgumentError, "Scenario inputs must not be symlinks: #{path}" if File.symlink?(path)

          File.directory?(path) ? files(path) : [path]
        end
      end

      def error(name, message)
        @errors << { name: "#{name}/discovery", kind: :error, message: message }
      end
    end
  end
end
