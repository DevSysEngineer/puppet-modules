# frozen_string_literal: true

require_relative 'puppet_runtime'

module ProjectTools
  module Shared
    # One presentation implementation for native CLIs, consoles and machine-readable producers.
    module Software
      def software(tool, runtime: false, version: nil, output: $stderr)
        version ||= Gem.loaded_specs.fetch(tool).version.to_s
        output.puts "Tool: #{safe(tool)} #{safe(version)}"
        output.puts runtime_line(runtime)
        output.puts "Ruby: #{RUBY_VERSION}"
        output.flush
      end

      def runtime_line(runtime)
        description = runtime == true ? PuppetRuntime.detect : runtime
        description ? "Runtime: #{safe(description)}" : 'Puppet runtime: not required'
      rescue PuppetRuntime::Error => e
        "Runtime: unavailable (#{safe(e.message)})"
      end

      # A scanner may discover its need for a parser only after selecting file types.
      def with_software(tool, output: $stderr)
        PuppetRuntime.with_usage do |usage|
          yield
        ensure
          software(tool, runtime: usage.first, output: output)
        end
      end
    end
  end
end
