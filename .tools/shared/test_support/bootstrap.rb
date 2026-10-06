# frozen_string_literal: true

require 'minitest/autorun'
require 'minitest/reporters'
require 'open3'
require 'tmpdir'
require 'fileutils'
require 'json'
require_relative 'console_reporter'

# Ruby require initializes this once, regardless of the number or order of tool helpers.
Minitest::Reporters.use!(ProjectTools::TestConsoleReporter.new)
