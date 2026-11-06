# frozen_string_literal: true

require 'tempfile'

module ProjectTools
  module Shared
    # Stage in the destination directory so publication is one same-filesystem rename.
    module AtomicFile
      def self.write(path)
        Tempfile.create(['.project-tools-', File.extname(path)], File.dirname(path)) do |output|
          yield output
          output.close
          File.rename(output.path, path)
        end
      end
    end
  end
end
