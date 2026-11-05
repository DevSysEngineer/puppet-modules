# frozen_string_literal: true

require 'json'

module ProjectTools
  # Only an explicit Ruby preload consumes this configuration, before any test loads.
  module ParallelWorker
    CONFIG = JSON.parse(File.read(ENV.delete('PROJECT_TOOLS_TEST_WORKER_CONFIG'))).freeze
  end
end

require 'project_tools/shared/test_bootstrap'
