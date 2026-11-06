# frozen_string_literal: true

module ProjectTools
  class Catalog
    # Observe native log levels alongside the unchanged native console destination.
    class Diagnostics
      LEVELS = { emerg: 'Emergency', alert: 'Alert', crit: 'Critical', err: 'Error', warning: 'Warning',
                 notice: 'Notice', info: 'Info', debug: 'Debug' }.freeze
      attr_reader :entries

      def initialize
        @entries = []
      end

      def start
        Puppet::Util::Log.newdesttype(:project_tools_findings) do
          match 'ProjectTools::Catalog::Diagnostics'
          define_method(:initialize) { |receiver| @receiver = receiver }
          define_method(:handle) { |message| @receiver.record(message) }
        end
        Puppet::Util::Log.newdestination(self)
      end

      def record(message)
        text = message.respond_to?(:multiline) ? message.multiline : message.to_s
        source = message.source unless message.source == 'Puppet'
        text = "#{source}: #{text}" if source
        @entries << { level: message.level.to_s, message: "#{LEVELS.fetch(message.level)}: #{text}\n",
                      source: source }
      end
    end
  end
end
