# frozen_string_literal: true

require_relative '../test_support/bootstrap'
require 'rake'
require 'project_tools/shared/rake_jobs'

# Reuse Rake's accepted option forms without replaying its option callbacks.
class SharedRakeJobsTest < Minitest::Test
  def count(*arguments)
    ProjectTools::Shared::RakeJobs.count(arguments.freeze)
  end

  def test_absent_option_keeps_serial_execution
    assert_equal 1, count('test')
    assert_equal 1, count('-f', 'Rakefile with spaces', 'test', 'TESTOPTS=--name=/jobs/')
    assert_equal 1, count('test', '--', '--jobs', '4')
  end

  def test_long_short_and_equals_forms_select_the_same_limit
    [%w[test --jobs 4], %w[--jobs=4 test], %w[-j4 test], %w[test -j 4], %w[-sj4 test]].each do |arguments|
      assert_equal 4, count(*arguments), arguments.inspect
    end
    assert_equal 2, count('--jobs=4', 'test', '--jobs', '2')
  end

  def test_other_native_callbacks_and_argument_arrays_are_unchanged
    arguments = ['--execute-continue', "raise 'must not execute twice'", 'test', '--jobs', '2'].freeze
    before = Rake.application.options.thread_pool_size
    assert_equal 2, ProjectTools::Shared::RakeJobs.count(arguments)
    assert_equal before, Rake.application.options.thread_pool_size
    assert_equal '2', arguments.last
  end

  def test_explicit_limit_must_be_a_positive_integer
    ['', '0', '-1', 'auto', '2.5', ' 2', '+2'].each do |value|
      assert_raises(ArgumentError) { count('test', "--jobs=#{value}") }
    end
    assert_raises(ArgumentError) { count('test', '--jobs') }
  end
end
