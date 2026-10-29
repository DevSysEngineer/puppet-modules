# frozen_string_literal: true

require 'rubocop'
require 'project_tools/shared/console'
require_relative 'ruby_lint/runtime_coupling'

module ProjectTools
  module RubyLint
    # Add execution metadata without replacing native formatters or their status handling.
    module Versions
      def run(paths)
        Shared::Console.software('project-tools-ruby-lint')
        super
      end
    end
  end
end

RuboCop::Runner.prepend(ProjectTools::RubyLint::Versions)
