# frozen_string_literal: true

require 'project_tools/shared/command_pool'

module ProjectTools
  # Both execution routes keep the native parser's combined diagnostics and status.
  module SyntaxValidation
    def syntax(path)
      unless path.end_with?('.pp') && File.file?(path)
        return { path: path, kind: :error, message: "Expected an existing .pp file: #{path}" }
      end

      # The active bundle supplies the executable and Ruby; no shell interprets manifest paths.
      output, status = Open3.capture2e(*validator_command(path))
      validation_result(path, output, status)
    rescue SystemCallError, Shared::PuppetRuntime::Error => e
      { path: path, kind: :error, message: "Cannot start Puppet validator: #{e.message}" }
    end

    def validation_result(path, output, status)
      kind = status.success? ? nil : :failure
      kind = :error if status.signaled?
      output = "Validator failed: #{status}" if kind && output.empty?
      { path: path, kind: kind, message: output }
    end

    def validator_command(path)
      [RbConfig.ruby, Shared::PuppetRuntime.detect.executable,
       'parser', 'validate', '--color=false', File.expand_path(path)]
    end

    def selected_command(path)
      raise ArgumentError, "Expected an existing .pp file: #{path}" unless path.end_with?('.pp') && File.file?(path)

      validator_command(path)
    end

    def validation_commands(results)
      @paths.each_with_index.filter_map do |path, index|
        [index, selected_command(path)]
      rescue ArgumentError, SystemCallError, Shared::PuppetRuntime::Error => e
        message = e.is_a?(ArgumentError) ? e.message : "Cannot start Puppet validator: #{e.message}"
        results[index] = { path: path, kind: :error, message: message }
        @console.advance(unit: 'files', total: @paths.size)
        nil
      end
    end

    def parallel_validation
      results = Array.new(@paths.size)
      commands = validation_commands(results)
      Shared::CommandPool.new(commands.map(&:last), jobs: @jobs, combined: true).run do |index, result|
        position = commands.fetch(index).first
        results[position] = parallel_result(@paths.fetch(position), result)
        @console.advance(unit: 'files', total: @paths.size)
      end
    ensure
      retain_results(results)
    end

    def retain_results(results)
      @results = results.compact
      @results.each { |result| @console.finding(diagnostic(result)) unless result[:message].empty? }
    end

    def parallel_result(path, result)
      return validation_result(path, result.stdout, result.status) unless result.error

      { path: path, kind: :error, message: "Cannot start Puppet validator: #{result.error.message}" }
    end
  end
end
