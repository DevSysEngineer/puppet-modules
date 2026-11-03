# frozen_string_literal: true

require_relative '../test_helper'
require_relative 'installed_gem_support'

# Exercise attribute spacing through a separately built and installed consumer gem.
class ExternalResourceAttributeSpacingTest < Minitest::Test
  include InstalledGemSupport

  def test_installed_check_and_fix_preserve_the_consumer_manifest_contract
    before = "notify { 'example':\n\n  message => 'Example',\n\n  withpath => false,\n}\n"
    after = "notify { 'example':\n  message  => 'Example',\n  withpath => false,\n}\n"
    write('manifests/site.pp', before)
    assert_spacing_warning(before)
    lint('--fix', 'manifests')
    assert @status.success?, @output + @errors
    assert_equal after, read('manifests/site.pp')
    assert_stable_spacing(after)
  end

  def assert_spacing_warning(before)
    lint('manifests')
    assert_equal 1, @status.exitstatus
    assert_equal 2, @output.scan('project_layout: warning: Remove blank lines before resource attributes').length
    assert_equal before, read('manifests/site.pp')
  end

  def assert_stable_spacing(after)
    [[], ['--fix']].each do |options|
      lint(*options, 'manifests')
      assert @status.success?, @output + @errors
      assert_empty @output
      assert_equal after, read('manifests/site.pp')
    end
  end
end
