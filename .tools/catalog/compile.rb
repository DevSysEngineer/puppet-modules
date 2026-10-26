# frozen_string_literal: true

require 'optparse'
require_relative 'lib/catalog'

report = nil
options = OptionParser.new do |parser|
  parser.banner = 'Usage: bundle exec ruby .tools/catalog/compile.rb [--junit REPORT.xml]'
  parser.on('--junit PATH', 'Write the catalog results as JUnit XML') { |path| report = path }
  parser.on('-h', '--help', 'Show usage') do
    puts parser
    exit 0
  end
end
begin
  options.parse!
  raise OptionParser::InvalidArgument, ARGV.join(' ') unless ARGV.empty?
rescue OptionParser::ParseError => e
  warn e.message
  warn options
  exit 1
end

exit ProjectTools::Catalog.new.run(report: report)
