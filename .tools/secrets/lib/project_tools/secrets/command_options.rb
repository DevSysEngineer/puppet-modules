# frozen_string_literal: true

module ProjectTools
  module Secrets
    # Shared CLI option declarations for local and CI invocations.
    module CommandOptions
      def parser
        OptionParser.new do |options|
          options.banner = 'Usage: project-tools-secrets [--redact NEW_DIR] [--json] [--junit NEW_FILE] PATH ...'
          options.on('--redact NEW_DIR', 'Write separate sanitized copies') { |dir| @options[:redact] = dir }
          options.on('--json', 'Print metadata only as JSON') { @options[:json] = true }
          inspection_options(options)
          options.on('--junit NEW_FILE', 'Also write metadata as JUnit XML') { |path| @options[:junit] = path }
          options.on('-h', '--help', 'Show usage') { @options[:help] = true }
        end
      end

      def inspection_options(options)
        options.on('--puppet', 'Check hardcoded values in Puppet manifests (requires OpenVox)') do
          @options[:puppet] = true
        end
      end
    end
  end
end
