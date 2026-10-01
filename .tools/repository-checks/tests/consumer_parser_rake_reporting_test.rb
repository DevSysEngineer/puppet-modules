# frozen_string_literal: true

require_relative 'parser_rake_reporting_test'

# Run the documented consumer task through the same behavior checks as the repository task.
class ConsumerParserRakeReportingTest < ParserRakeReportingTest
  def rakefile
    guide = File.read(File.join(ROOT, '.tools/validate/README.md'))
    guide[/^```ruby\n(.*?)^```/m, 1]
  end

  def excluded_directories
    %w[.tools vendor global-modules]
  end
end
