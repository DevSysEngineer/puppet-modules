# frozen_string_literal: true

require 'optparse'
require_relative 'worker_count'

module ProjectTools
  module Shared
    # Read explicit CLI concurrency without changing Rake's options or executing its callbacks again.
    module RakeJobs
      def self.count(arguments = ARGV)
        requested = '1'
        parser = OptionParser.new do |options|
          Rake.application.standard_rake_options.each do |definition|
            options.on(*definition[0...-1]) { |value| requested = value if definition.first == '--jobs' }
          end
        end
        parser.parse(arguments)
        WorkerCount.parse(requested)
      end
    end
  end
end
