# frozen_string_literal: true

module ProjectTools
  class Catalog
    # Exercise native behavior only in the worker, retaining the preexisting registry and its identity.
    module DeprecationProbes
      PROBE_BUDGET = 100
      PROBE_MESSAGE = 'Catalog deprecation registration probe.'

      def quietly
        level = Puppet::Util::Log.level
        Puppet::Util::Log.level = :err
        yield
      ensure
        Puppet::Util::Log.level = level
      end

      def probe_registration
        quietly { Puppet.deprecation_warning(PROBE_MESSAGE, @probe) }
      rescue NameError, ArgumentError, TypeError
        raise Deprecations::DetectionError, 'Native deprecation registration has an incompatible interface.'
      end

      def probe_capacity
        unless @registry.is_a?(Hash) && @registry[@probe] == PROBE_MESSAGE
          raise Deprecations::DetectionError, 'Native deprecation registration failed its capability probe.'
        end

        saved = @registry.dup
        @limit = quietly { observed_capacity }
      rescue NameError, ArgumentError, TypeError
        raise Deprecations::DetectionError, 'Native deprecation registration has an incompatible interface.'
      ensure
        @registry.replace(saved) if saved
      end

      def observed_capacity
        PROBE_BUDGET.times { return @registry.size unless register_one? }
        # A larger or unlimited native registry still gets a conservative observation ceiling.
        PROBE_BUDGET
      end

      def register_one?
        key = Object.new
        before = @registry.size
        Puppet.puppet_deprecation_warning(PROBE_MESSAGE, key: key)
        return false unless @registry.size == before + 1 && @registry[key] == PROBE_MESSAGE

        Puppet.deprecation_warning('Duplicate probe must not replace its first message.', key)
        unless @registry[key] == PROBE_MESSAGE && @registry.size == before + 1
          raise Deprecations::DetectionError, 'Native deprecation deduplication failed its capability probe.'
        end

        true
      end

      def probe_language
        acceptor = language_probe
        Puppet::Pops::IssueReporter.assert_and_report(acceptor, emit_warnings: false, max_deprecations: 0)
        return if @language.delete({ message: PROBE_MESSAGE, source: 'runtime_probe.pp' })

        raise Deprecations::DetectionError, 'Native language deprecation observation failed its capability probe.'
      rescue NameError, ArgumentError, TypeError
        raise Deprecations::DetectionError, 'Native language deprecation diagnostics have an incompatible interface.'
      end

      def language_probe
        issue = Puppet::Pops::Issues::Issue.new(:PROJECT_TOOLS_PROBE) { PROBE_MESSAGE }
        diagnostic = Puppet::Pops::Validation::Diagnostic.new(:deprecation, issue, 'runtime_probe.pp', nil)
        Puppet::Pops::Validation::Acceptor.new.tap { |acceptor| acceptor.accept(diagnostic) }
      end
    end
  end
end
