# frozen_string_literal: true

require 'project_tools/metadata/project_version'

module ProjectTools
  module Metadata
    # Validate the requested project metadata structure without imposing module naming on consumers.
    class RootMetadata
      STRINGS = %w[name version author summary license source project_page issues_url].freeze
      ARRAYS = %w[dependencies operatingsystem_support requirements tags].freeze

      def initialize(data, version:, name: nil)
        @data = data
        @version = version
        @name = name
        @problems = []
      end

      def problems
        STRINGS.each { |key| string(@data, key) unless key == 'version' }
        ARRAYS.each { |key| array(@data, key) }
        identity('name', @name)
        version
        %w[dependencies requirements].each { |key| named_versions(key) }
        platforms
        string_entries(@data['tags'], 'tags')
        @problems
      end

      def module_problems
        string(@data, 'name') unless @name
        %w[author summary license source].each { |key| string(@data, key) }
        string(@data, 'version') unless @version
        array(@data, 'dependencies')
        named_versions('dependencies')
        @problems
      end

      def string(data, key, path = key)
        return if data[key].is_a?(String) && !data[key].strip.empty?

        @problems << "#{path}: expected a non-empty string"
      end

      def array(data, key, path = key)
        @problems << "#{path}: expected an array" unless data[key].is_a?(Array)
      end

      def identity(key, expected)
        value = @data[key]
        return unless expected && value.is_a?(String) && !value.strip.empty? && value != expected

        @problems << "#{key}: expected #{expected}"
      end

      def version
        return string(@data, 'version') unless @version

        mismatch = ProjectVersion.mismatch(@data['version'], @version)
        @problems << mismatch if mismatch
      end

      def objects(key)
        return unless @data[key].is_a?(Array)

        @data[key].each_with_index do |entry, index|
          path = "#{key}[#{index}]"
          if entry.is_a?(Hash)
            yield entry, path
          else
            @problems << "#{path}: expected a JSON object"
          end
        end
      end

      def named_versions(key)
        objects(key) do |entry, path|
          %w[name version_requirement].each { |field| string(entry, field, "#{path}.#{field}") }
        end
      end

      def platforms
        objects('operatingsystem_support') do |entry, path|
          string(entry, 'operatingsystem', "#{path}.operatingsystem")
          array(entry, 'operatingsystemrelease', "#{path}.operatingsystemrelease")
          string_entries(entry['operatingsystemrelease'], "#{path}.operatingsystemrelease")
        end
      end

      def string_entries(entries, path)
        return unless entries.is_a?(Array)

        entries.each_with_index do |entry, index|
          string({ 'value' => entry }, 'value', "#{path}[#{index}]")
        end
      end
    end
  end
end
