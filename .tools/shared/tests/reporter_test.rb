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
    assert_operator output.index('[PASSED]'), :<, output.index('synthetic policy skip')
    assert_equal 1, output.scan('synthetic policy skip').size
    refute_includes output, 'JUnit written:'
  end

  def test_native_test_exception_retains_its_details_and_error_count
    output, errors, status = probe("raise 'synthetic runtime cause'")
    assert_equal 1, status.exitstatus, errors
    assert_includes output, '[ERROR] Tool tests'
    assert_includes output, '1 errors'
    assert_includes output, 'synthetic runtime cause'
    assert_operator output.index('[ERROR]'), :<, output.index('synthetic runtime cause')
    assert_equal 1, output.scan('synthetic runtime cause').size
  end

  def test_software_versions_appear_at_start_without_repeating_during_tests
    output, errors, status = probe(software_calls)
    assert status.success?, output + errors
    header, body = output.split('Test body started', 2)
    assert_software_header(header)
    refute_match(/^(?:Tool:|Runtime:|Puppet runtime:|Ruby:)/, body)
    assert_equal "Synthetic diagnostic remains visible\n", errors
  end

  def software_calls
    <<~RUBY
      puts 'Test body started'
      tools = Gem.loaded_specs.keys.grep(/\\A(?:project-tools-|lint-project\\z)/).sort
      2.times do
        tools.each do |tool|
          ProjectTools::Shared::Console.software(tool)
          ProjectTools::Shared::Console.software(tool, output: $stdout)
        end
      end
      warn 'Synthetic diagnostic remains visible'
      assert true
    RUBY
  end

  def assert_software_header(header)
    assert_includes header, 'Tool: project-tools-tests '
    assert_includes header, ProjectTools::Shared::PuppetRuntime.detect.to_s
    assert_includes header, "Ruby: #{RUBY_VERSION}"
    tools = Gem.loaded_specs.values.select { |spec| spec.name.match?(/\A(?:project-tools-|lint-project\z)/) }
    tools.each { |spec| assert_includes header, "#{spec.name} #{spec.version}" }
  end

  def test_captured_software_output_remains_available_to_assertions
    output, errors, status = probe(captured_software_calls)
    assert status.success?, output + errors
    assert_empty errors
  end

  def captured_software_calls
    <<~RUBY
      captured_output, captured_errors = capture_io do
        ProjectTools::Shared::Console.software('synthetic', version: '1.0')
        ProjectTools::Shared::Console.software('synthetic', version: '1.0', output: $stdout)
      end
      [captured_output, captured_errors].each do |text|
        assert_includes text, 'Tool: synthetic 1.0'
        assert_includes text, 'Puppet runtime: not required'
      end
      direct = StringIO.new
      ProjectTools::Shared::Console.software('synthetic', version: '1.0', output: direct)
      assert_includes direct.string, 'Tool: synthetic 1.0'
    RUBY
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
