# frozen_string_literal: true

require 'optparse'

module ProjectLint
  # Own command options, report-file handling and final human presentation.
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

    def report(path, input, console, errors, finding_status: 0)
      converter, message = read(input)
      begin
        write_error = write_report(path, converter, message)
      ensure
        present_result(converter, console, errors, [message, write_error].compact)
      end
      console.puts "JUnit written: #{ProjectTools::Shared::Console.safe(path)}" unless write_error
      return 1 if message || write_error

      converter.active.any? ? finding_status : 0
    end

    def write_report(path, converter, message)
      File.open(path, 'w') { |output| converter ? converter.write_findings(output) : write_error(output, message) }
      nil
    rescue SystemCallError, IOError => e
      "Cannot write Puppet-lint JUnit report: #{e.message}"
    end

    def present_result(converter, console, errors, messages)
      if converter
        converter.present(console, errors: messages, errors_output: errors)
      else
        report_error(messages, errors)
      end
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
