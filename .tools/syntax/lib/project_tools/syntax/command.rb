# frozen_string_literal: true

require 'optparse'

module ProjectTools
  # Parse the reporter interface before any native validation or report writes.
  module SyntaxCommand
    def run(arguments, console: $stdout, errors: $stderr)
      options = parser do |help|
        console.puts help
        return 0
      end
      report, *paths = options.parse(arguments)
      return usage(console, errors) unless report&.end_with?('.xml')

      new(paths, console).run(report, errors)
    rescue OptionParser::ParseError
      usage(console, errors)
    end

    def parser(&help)
      OptionParser.new do |cli|
        cli.banner = 'Usage: syntax-junit REPORT.xml MANIFEST.pp [MANIFEST.pp ...]'
        cli.on('-h', '--help', 'Show usage') { help.call(cli) }
      end
    end

    def usage(console, errors)
      errors.puts 'Usage: syntax-junit REPORT.xml MANIFEST.pp [MANIFEST.pp ...]'
      Shared::Console.new('Puppet syntax', output: console)
                     .finish(status: 'ERROR', execution: 'not executed', details: ['Invalid arguments; see usage.'])
      1
    end
  end
end
