# frozen_string_literal: true

require_relative 'rake_jobs'

module ProjectTools
  module Shared
    # Wrap an existing native Rake task without activating the test framework in Rake.
    class TestTask
      def self.wrap(test_task, **options)
        new(test_task, **options).wrap
      end

      def initialize(test_task, groups: [], software: nil)
        @test_task = test_task
        @groups = groups
        @software = software
      end

      def wrap
        task = Rake::Task[@test_task.name]
        @actions = task.actions.dup
        task.clear_actions
        task.enhance { |current, arguments| run(current, arguments) }
      end

      def run(task, arguments)
        count = RakeJobs.count
        return native(task, arguments) if count == 1

        require_relative '../../../test_support/parallel_runner'
        ParallelTask.new(@test_task, count, groups: @groups, software: @software).run { native(task, arguments) }
      end

      def native(task, arguments)
        @actions.each { |action| action.call(task, arguments) }
      end
    end
  end
end
