# frozen_string_literal: true

module ProjectLint
  # VERSION in the checked project is the sole authority for its metadata versions.
  class ProjectVersion
    FORMAT = /\A(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\z/.freeze

    def initialize(root)
      @root = root
    end

    def read
      version = File.binread(File.join(@root, 'VERSION')).chomp
      raise ArgumentError, 'version: VERSION is empty; expected MAJOR.MINOR.PATCH' if version.empty?

      return version if FORMAT.match?(version)

      raise ArgumentError, 'version: VERSION must contain only MAJOR.MINOR.PATCH without leading zeros'
    rescue Errno::ENOENT
      raise ArgumentError, 'version: missing VERSION; expected a file in the project root'
    rescue SystemCallError
      raise ArgumentError, 'version: cannot read VERSION; expected a readable file'
    end

    def foreign_directory?(directory)
      current = File.realpath(directory)
      until current == @root || current == File.dirname(current)
        return true if %w[VERSION .git .tools/lint/lint-project.gemspec].any? do |marker|
          File.exist?(File.join(current, marker))
        end

        current = File.dirname(current)
      end
      false
    end

    def self.mismatch(actual, expected)
      return if expected.nil? || actual == expected

      "version: expected #{expected} from VERSION; found #{actual.inspect}"
    end
  end
end
