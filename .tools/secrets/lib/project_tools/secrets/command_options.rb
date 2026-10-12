# frozen_string_literal: true

module ProjectTools
  module Secrets
    # Shared CLI option declarations for local and CI invocations.
    module CommandOptions
      def parser
        OptionParser.new do |options|
          options.banner = 'Usage: project-tools-secrets [--redact NEW_DIR] [--json] [--junit NEW_FILE] PATH ...'
          options.separator 'Development: project-tools-secrets prepare --help; project-tools-secrets-write --help'
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

      def session_parser
        OptionParser.new do |options|
          session_usage(options)
          %w[root policy tree state session changes id to input command].each do |name|
            options.on("--#{name} VALUE") { |value| @options[name] = value }
          end
          options.on('--json', 'Emit JSON (the session default)') { @options['json'] = true }
          options.on('--junit NEW_FILE') { |value| @options['junit'] = value }
          options.on('-h', '--help') { @options['help'] = true }
        end
      end

      def session_usage(options)
        options.banner = 'Usage: project-tools-secrets ACTION [OPTIONS]; project-tools-secrets-write [OPTIONS]'
        options.separator 'Actions: prepare, diff, run, close, cancel, clone, register, fixture, recover.'
        options.separator 'Writer accepts --state, --session, --changes.'
        options.separator 'Prepare: --root --policy --tree --state. Other session actions: --state --session.'
        options.separator 'See README for operation-specific options.'
      end
    end
  end
end
