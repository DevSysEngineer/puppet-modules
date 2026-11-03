# frozen_string_literal: true

require_relative '../test_helper'
require_relative 'installed_gem_support'

# Preserve the native indentation contract in an independently installed gem.
class ExternalResourceIndentationTest < Minitest::Test
  include InstalledGemSupport

  BEFORE = "    notify { 'example':\n    message => 'hello',\n}\n"
  AFTER = "notify { 'example':\n  message => 'hello',\n}\n"

  def test_installed_check_rejects_structural_resource_indentation_without_writing
    write('manifests/site.pp', BEFORE)
    lint('manifests')
    assert_equal 1, @status.exitstatus
    assert_includes @output, '2sp_soft_tabs: error: Resource indentation'
    assert_equal BEFORE, read('manifests/site.pp')
  end

  def test_installed_fix_is_stable
    write('manifests/site.pp', BEFORE)
    lint('--fix', 'manifests')
    assert @status.success?, @output + @errors
    assert_equal AFTER, read('manifests/site.pp')
    lint('--fix', 'manifests')
    assert @status.success?, @output + @errors
    assert_empty @output
    assert_equal AFTER, read('manifests/site.pp')
  end
end
