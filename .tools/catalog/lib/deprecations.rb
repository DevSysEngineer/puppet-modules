# frozen_string_literal: true

module ProjectTools
  class Catalog
    # Worker-only adapter for the internal registries and language diagnostics in OpenVox 8.29.0.
    class Deprecations
      LIMIT = 100
      PROBE_MESSAGE = 'Catalog deprecation registration probe.'
      class DetectionError < StandardError; end

      def initialize
        @language = []
        @probe = Object.new
      end

      def start
        verify_runtime
        Puppet[:disable_warnings] = Puppet[:disable_warnings] - ['deprecations']
        Puppet[:strict] = :warning
        ENV['STDLIB_LOG_DEPRECATIONS'] = 'true'
        probe_registration
        @registry = native_registry
        verify_registration
        observe_language_diagnostics
      end

      def probe_registration
        level = Puppet::Util::Log.level
        # Only the synthetic probe is quiet; scenario logging keeps its original destination and level.
        Puppet::Util::Log.level = :err
        Puppet.deprecation_warning(PROBE_MESSAGE, @probe)
      ensure
        Puppet::Util::Log.level = level
      end

      def verify_runtime
        return if Gem.loaded_specs['openvox']&.version&.to_s == '8.29.0'

        raise DetectionError, 'Deprecation detection requires the verified OpenVox 8.29.0 adapter.'
      end

      def native_registry
        # Read OpenVox's existing internal registry; never create or reset it.
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
        return if @registry.size < LIMIT

        raise DetectionError, 'Native deprecation registration limit reached; detection coverage is incomplete.'
      end

      def verify_settings
        return unless Puppet[:disable_warnings].include?('deprecations') || Puppet[:strict] != :warning ||
                      ENV.fetch('STDLIB_LOG_DEPRECATIONS', nil) != 'true'

        raise DetectionError, 'Deprecation detection was disabled during compilation.'
      end

      def observe_language_diagnostics
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
