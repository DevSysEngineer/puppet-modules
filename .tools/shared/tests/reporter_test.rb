# frozen_string_literal: true

require_relative '../test_support/bootstrap'
require_relative '../test_support/packages'

# Verify the native framework's skip, error and interruption semantics through the real bootstrap.
class SharedTestReporterTest < Minitest::Test
  include ProjectToolsPackageSupport

  def setup
    @project = Dir.mktmpdir('test-console-')
  end

  def probe(body, *arguments)
    bootstrap = File.join(ROOT, '.tools/shared/test_support/bootstrap')
    write('probe.rb', <<~RUBY)
      require #{bootstrap.dump}
      class SyntheticReporterProbe < Minitest::Test
        def test_synthetic_result
          #{body}
        end
      end
    RUBY
    environment = { 'MINITEST_REPORTERS_REPORTS_DIR' => nil }
    Open3.capture3(environment, RbConfig.ruby, File.join(@project, 'probe.rb'), *arguments)
  end

  def test_skip_is_visible_without_changing_the_successful_process_status
    output, errors, status = probe("skip 'synthetic policy skip'")
    assert status.success?, output + errors
    assert_includes output, '[PASSED] Tool tests'
    assert_includes output, '1 skips'
    assert_includes output, 'synthetic policy skip'
    refute_includes output, 'JUnit written:'
  end

  def test_native_test_exception_retains_its_details_and_error_count
    output, errors, status = probe("raise 'synthetic runtime cause'")
    assert_equal 1, status.exitstatus, errors
    assert_includes output, '[ERROR] Tool tests'
    assert_includes output, '1 errors'
    assert_includes output, 'synthetic runtime cause'
  end

  def test_interruption_does_not_present_unfinished_tests_as_successful
    [[], ['--exclude=/unselected/']].each { |arguments| assert_interrupted(*arguments) }
  end

  def assert_interrupted(*arguments)
    output, errors, status = probe('raise Interrupt', *arguments)
    refute status.success?, errors
    assert_includes output, '[ERROR] Tool tests'
    assert_includes output, 'Execution: incomplete'
    refute_includes output, '[PASSED]'
  end
end
