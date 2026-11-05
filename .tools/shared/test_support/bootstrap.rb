# frozen_string_literal: true

require 'project_tools/shared/test_bootstrap'

ProjectTools::TestConsoleReporter.software = {
  tool: 'project-tools-tests', runtime: true,
  version: File.read(File.expand_path('../../../VERSION', __dir__)).strip
}.freeze
