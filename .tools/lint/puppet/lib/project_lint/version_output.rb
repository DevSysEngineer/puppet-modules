# frozen_string_literal: true

require 'project_tools/shared/console'

module ProjectLint
  # The native CLI loads this entrypoint through --load; library analysis stays quiet.
  module VersionOutput
    def self.announce
      return unless File.basename($PROGRAM_NAME) == 'puppet-lint'
      return if @announced || (ARGV & %w[-h --help --version --list-checks]).any?

      @announced = true
      ProjectTools::Shared::Console.software('lint-project', runtime: true)
    end
  end
end
