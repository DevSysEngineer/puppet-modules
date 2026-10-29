# frozen_string_literal: true

require_relative 'deprecation_probes'

module ProjectTools
  class Catalog
    # Probe the native registration and language diagnostic contracts inside each isolated worker.
    class Deprecations
      include DeprecationProbes

      class DetectionError < StandardError; end

      def initialize
        @language = []
        @probe = Object.new
      end

      def start
        Shared::PuppetRuntime.load!
        Puppet[:disable_warnings] = Puppet[:disable_warnings] - ['deprecations']
        Puppet[:strict] = :warning
        ENV['STDLIB_LOG_DEPRECATIONS'] = 'true'
        probe_registration
        @registry = native_registry
        probe_capacity
        verify_registration
        observe_language_diagnostics
        probe_language
      end

      def native_registry
        # Read the runtime's own registry, including warnings raised before scenario compilation.
        $deprecation_warnings # rubocop:disable Style/GlobalVars
      end

      def verify_registration
        unless @registry.is_a?(Hash) && @registry.equal?(native_registry) && @registry[@probe] == PROBE_MESSAGE
          raise DetectionError, 'Native deprecation registration is unavailable or was reset.'
        end

        verify_contents
        verify_settings
      end

      def verify_contents
        unless @registry.values.all? { |message| message.is_a?(String) && !message.empty? }
          raise DetectionError, 'Native deprecation registration has an unsupported format.'
        end
        return if @limit && @registry.size < @limit

        raise DetectionError, 'Native deprecation registration limit reached; detection coverage is incomplete.'
      end

      def verify_settings
        return unless Puppet[:disable_warnings].include?('deprecations') || Puppet[:strict] != :warning ||
                      ENV.fetch('STDLIB_LOG_DEPRECATIONS', nil) != 'true'

        raise DetectionError, 'Deprecation detection was disabled during compilation.'
      end

      def observe_language_diagnostics
        unless Puppet::Pops::IssueReporter.respond_to?(:assert_and_report)
          raise DetectionError, 'Native language deprecation reporting is unavailable.'
        end

        install_language_observer
      end

      def install_language_observer
        observer = self
        # Language deprecations bypass the registry. Observe their native severity before logging limits apply.
        observer_module = Module.new do
          define_method(:assert_and_report) do |acceptor, options|
            observer.record_language(acceptor) if acceptor
            super(acceptor, options)
          end
        end
        Puppet::Pops::IssueReporter.singleton_class.prepend(observer_module)
      end

      def record_language(acceptor)
        acceptor.warnings.each do |diagnostic|
          next unless diagnostic.severity == :deprecation

          entry = language_entry(diagnostic)
          @language << entry unless @language.include?(entry)
        end
      end

      def language_entry(diagnostic)
        formatter = Puppet::Pops::Validation::DiagnosticFormatterPuppetStyle.new
        entry = { message: formatter.format_message(diagnostic) }
        return entry unless diagnostic.file.is_a?(String) && !diagnostic.file.empty?

        entry[:source] = diagnostic.file
        entry[:line] = diagnostic.source_pos.line if diagnostic.source_pos
        entry
      end

      def result
        verify_registration
        { deprecations: registered_messages + @language }
      rescue DetectionError => e
        { deprecations: registered_messages + @language, deprecation_error: e.message }
      end

      def registered_messages
        return [] unless @registry.is_a?(Hash)

        @registry.filter_map do |key, message|
          { message: message } if !key.equal?(@probe) && message.is_a?(String) && !message.empty?
        end.uniq
      end
    end
  end
end
