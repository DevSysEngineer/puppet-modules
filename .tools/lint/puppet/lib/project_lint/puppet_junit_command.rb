# frozen_string_literal: true

require 'optparse'

module ProjectLint
  # Handle options before reading the native JSON stream or opening a report.
  module PuppetJunitCommand
    def run(arguments, input: $stdin, console: $stdout, errors: $stderr)
      settings = {}
      options = parser(settings) do |help|
        console.puts help
        return 0
      end
      paths = options.parse(arguments)
      return usage(errors) unless paths.length == 1

      report_with_versions(paths.first, input, console, errors, settings)
    rescue OptionParser::ParseError
      usage(errors)
    end

    def report_with_versions(path, input, console, errors, settings)
      ProjectTools::Shared::Console.software('lint-project', output: errors)
      report(path, input, console, errors, finding_status: settings[:result_status] ? self::FINDINGS_STATUS : 0)
    end

    def parser(settings, &help)
      OptionParser.new do |cli|
        cli.banner = 'Usage: puppet-lint --json ... | puppet-lint-junit [--result-status] REPORT.xml'
        cli.on('--result-status', 'Return a separate status for active findings') { settings[:result_status] = true }
        cli.on('-h', '--help', 'Show usage') { help.call(cli) }
      end
    end

    def usage(errors)
      errors.puts 'Usage: puppet-lint --json ... | puppet-lint-junit [--result-status] REPORT.xml'
      1
    end
  end
end
