# frozen_string_literal: true

require 'project_tools/shared/command_pool'

module ProjectTools
  class Catalog
    # Preserve scenario order while progress follows completed native workers.
    module Compilation
      def compile(scenario)
        output, diagnostics, status = Open3.capture3(*worker_command(scenario))
        worker_result(scenario, output, diagnostics, status)
      rescue SystemCallError => e
        { name: scenario.fetch(:name), kind: :error, message: "Cannot start compiler: #{e.message}" }
      end

      def worker_result(scenario, output, diagnostics, status)
        WorkerResult.new(scenario.fetch(:name), output, diagnostics, status).result
      end

      def worker_arguments(scenario)
        [@modulepath.join(File::PATH_SEPARATOR), *scenario.values_at(:manifest, :facts),
         scenario[:module_directory].to_s, scenario[:hiera].to_s]
      end

      def worker_command(scenario)
        [RbConfig.ruby, File.join(__dir__, 'worker.rb'), *worker_arguments(scenario)]
      end

      def compile_scenarios
        return @scenarios.each { |scenario| record(compile(scenario)) } if @jobs == 1 || Gem.win_platform?

        parallel_compile
      end

      def parallel_compile
        results = Array.new(@scenarios.size)
        commands = @scenarios.map { |scenario| worker_command(scenario) }
        Shared::CommandPool.new(commands, jobs: @jobs).run do |index, result|
          results[index] = parallel_result(@scenarios.fetch(index), result)
          @processed += 1
          @console.advance(unit: 'scenarios', total: @scenarios.size)
        end
      ensure
        retain_results(results)
      end

      def retain_results(results)
        results.compact.each do |result|
          @results << result
          present(result)
        end
      end

      def parallel_result(scenario, result)
        return worker_result(scenario, result.stdout, result.stderr, result.status) unless result.error

        { name: scenario.fetch(:name), kind: :error, message: "Cannot start compiler: #{result.error.message}" }
      end
    end
  end
end
