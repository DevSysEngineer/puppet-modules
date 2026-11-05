# frozen_string_literal: true

require 'minitest/autorun'
require 'minitest/reporters'
require 'open3'
require 'tmpdir'
require 'fileutils'
require 'json'
require_relative '../../../test_support/console_reporter'

# Ruby require initializes this once, regardless of the number or order of tool helpers.
ProjectTools::Shared::Console.singleton_class.prepend(ProjectTools::TestConsoleReporter::SoftwareOutput)
reporter = if defined?(ProjectTools::ParallelWorker::CONFIG)
             require_relative '../../../test_support/parallel_worker_reporter'
             ProjectTools::TestWorkerReporter.new(ProjectTools::ParallelWorker::CONFIG)
           else
             ProjectTools::TestConsoleReporter.new
           end
Minitest::Reporters.use!(reporter)
