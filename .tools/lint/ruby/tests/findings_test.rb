# frozen_string_literal: true

require_relative '../../../shared/test_support/bootstrap'
require_relative '../../../shared/test_support/console_groups'
require 'open3'

# Exercise the native formatter, native threshold and unchanged XML together.
class RubyFindingsTest < Minitest::Test
  include ProjectToolsConsoleGroups

  ROOT = File.expand_path('../../../..', __dir__)

  def setup
    @root = Dir.mktmpdir('ruby findings ')
    @source = File.join(@root, 'example.rb')
    @findings = File.join(@root, 'findings.txt')
    @report = File.join(@root, 'report.xml')
    File.write(@source, "# frozen_string_literal: true\n\nputs 1+2\n")
  end

  def teardown
    FileUtils.remove_entry(@root)
  end

  def check(platform, *options)
    environment = { 'GITHUB_ACTIONS' => nil, 'GITLAB_CI' => nil, platform => 'true' }
    Open3.capture3(environment, 'bundle', 'exec', 'rubocop', '--config', File.join(ROOT, '.rubocop.yml'),
                   '--cache', 'false', '--only', 'Layout/SpaceAroundOperators', '--stderr',
                   '--format', 'progress', '--out', @findings, '--format', 'junit', '--out', @report,
                   *options, @source, chdir: ROOT)
  end

  def test_ci_findings_keep_native_source_and_caret_with_the_native_failure_status
    %w[GITHUB_ACTIONS GITLAB_CI].each do |platform|
      output, errors, status = check(platform, '--color')
      assert_equal 1, status.exitstatus, errors
      assert_empty output
      assert_includes errors, 'Inspecting 1 file'
      assert_native_details
    end
  end

  def assert_native_details
    text = File.read(@findings)
    assert_includes text, '[FAILED] Layout/SpaceAroundOperators | 1 file'
    assert_includes text, "puts 1+2\n        ^"
    assert_equal 1, text.scan('Surrounding space missing').size
    assert_includes File.read(@report), "failure type='Layout/SpaceAroundOperators'"
    refute_ci_markers(File.read(@report))
  end

  def test_nonblocking_offense_is_a_warning_and_autocorrection_is_information
    _output, errors, status = check('GITHUB_ACTIONS', '--fail-level', 'error')
    assert_equal 0, status.exitstatus, errors
    assert_includes File.read(@findings), '[WARNING] Layout/SpaceAroundOperators'
    _output, errors, status = check('GITHUB_ACTIONS', '--autocorrect')
    assert_equal 0, status.exitstatus, errors
    assert_includes File.read(@findings), '[INFO] Layout/SpaceAroundOperators'
    assert_includes File.read(@source), 'puts 1 + 2'
  end
end
