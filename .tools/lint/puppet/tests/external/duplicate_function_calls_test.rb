# frozen_string_literal: true

require_relative '../test_helper'
require_relative 'installed_gem_support'
require_relative '../duplicate_function_calls_support'

# Exercise packaged detection and correction without a development checkout.
class ExternalDuplicateFunctionCallsTest < Minitest::Test
  include LintTestSupport
  include InstalledGemSupport
  include DuplicateFunctionCallsSupport

  def test_installed_profile_detection_fix_and_idempotence
    relative = 'manifests/site.pp'
    before = resource('String(42)', 'String(42)')
    after = "$string_result = String(42)\n#{resource('$string_result', '$string_result')}"
    write(relative, before)
    lint(relative)
    refute @status.success?, @output + @errors
    assert_includes @output, 'project_duplicate_function_calls: warning:'
    assert_equal before, read(relative)
    assert_consumer_fix(relative, after)
  end

  def assert_consumer_fix(relative, after)
    lint('--fix', relative)
    assert @status.success?, @output + @errors
    assert_equal after, read(relative)
    [[], ['--fix']].each do |options|
      lint(*options, relative)
      assert @status.success?, @output + @errors
      assert_empty @output
      assert_equal after, read(relative)
    end
  end
end
