# frozen_string_literal: true

require 'minitest/autorun'
require 'minitest/reporters'
require 'open3'
require 'tmpdir'
require 'fileutils'
require 'json'

# Ruby require initializes this once, regardless of the number or order of tool helpers.
reporters = [Minitest::Reporters::DefaultReporter.new]
if ENV['MINITEST_REPORTERS_REPORTS_DIR']
  reporters << Minitest::Reporters::JUnitReporter.new(ENV.fetch('MINITEST_REPORTERS_REPORTS_DIR'))
end
Minitest::Reporters.use!(reporters)
