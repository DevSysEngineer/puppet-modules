# frozen_string_literal: true

require_relative '../test_helper'
require_relative 'installed_gem_support'

# Verify class and define argument handling in the distributed check.
class ExternalInterfaceCallsTest < Minitest::Test
  include InstalledGemSupport

  def test_installed_interface_check_skips_classes_and_checks_defines
    write('manifests/site.pp', "class { 'profile': }\nshared { 'synthetic': }\n")
    lint('--only-checks=project_interface_calls', 'manifests')
    assert_equal 1, @status.exitstatus, @output + @errors
    assert_equal ['manifests/site.pp:2:10: project_interface_calls: warning: ' \
                  "Public interface call omits required parameters: value\n"], @output.lines
    assert_equal 1, @errors.scan('Tool: lint-project').size
    assert_includes @errors, 'Runtime: '
    assert_includes @errors, "Ruby: #{RUBY_VERSION}"
  end
end
