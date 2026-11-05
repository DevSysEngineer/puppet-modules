# frozen_string_literal: true

require 'shellwords'
require 'rbconfig'
require_relative 'parallel_plan'

module ProjectTools
  # Isolate Rake's nodoc APIs so framework upgrades have one native compatibility boundary.
  class ParallelTask
    REPORTER_ENV = %w[MINITEST_REPORTER TM_PID RM_INFO TEAMCITY_VERSION VIM].freeze

    def initialize(task, jobs, groups: [], software: nil)
      @task = task
      @jobs = jobs
      @groups = groups
      @software = software
      verbose = task.verbose || Rake::FileUtilsExt.verbose_flag == true
      @options = Shellwords.split(task.option_list(verbose: verbose))
    end

    def run
      return yield if native_only?

      plan = ParallelPlan.new(@task.file_list.to_a, jobs: @jobs, groups: @groups)
      return yield if plan.effective_jobs <= 1

      runner = ParallelRunner.new(plan, command: command, options: @options, name: @task.name)
      runner.software = @software
      raise 'Parallel tool tests failed.' unless runner.run.zero?
    end

    def native_only?
      reporter = REPORTER_ENV.find { |key| ENV.key?(key) }
      warn "Parallel tests use the native serial route because #{reporter} is present." if reporter
      reporter || (@options & %w[-h --help -V --version]).any? || Gem.win_platform?
    end

    def command
      loader = File.join(Gem.loaded_specs.fetch('rake').full_gem_path, 'lib/rake/rake_test_loader.rb')
      [RbConfig.ruby, *Shellwords.split(@task.ruby_opts_string), '-r', File.join(__dir__, 'parallel_worker.rb'), loader]
    end
  end
end
