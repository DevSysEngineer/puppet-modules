# frozen_string_literal: true

require 'pathname'

module ProjectTools
  module Shared
    # Validate explicit search paths without choosing modules or filtering source files.
    module Modulepath
      def self.parse(value)
        paths = value.to_s.split(File::PATH_SEPARATOR, -1)
        raise ArgumentError, 'PROJECT_TOOLS_MODULEPATH must not be empty' if paths.empty?

        paths.map do |path|
          unless Pathname.new(path).absolute? && File.directory?(path)
            raise ArgumentError, 'PROJECT_TOOLS_MODULEPATH must contain existing absolute module directories'
          end

          File.realpath(path)
        end.freeze
      end
    end
  end
end
