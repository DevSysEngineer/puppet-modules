# frozen_string_literal: true

require_relative 'test_helper'
require_relative '../../shared/test_support/console_groups'

# The human scan uses CI groups while structured output remains machine-readable.
class SecretsCiGroupsTest < SecretsTest
  include ProjectToolsConsoleGroups

  def test_cli_groups_only_human_output
    path = write('ordinary.txt', 'ordinary')
    %w[GITHUB_ACTIONS GITLAB_CI].each do |platform|
      with_ci_platform(platform) do
        output, errors, status = run_cli(path)
        assert_equal 0, status.exitstatus, errors
        assert_ci_group(output, platform, name: 'Sensitive data scan', outcome: 'PASSED')
        assert_json_output(path)
      end
    end
  end

  def assert_json_output(path)
    output, errors, status = run_cli('--json', path)
    assert_equal 0, status.exitstatus, errors
    assert JSON.parse(output).fetch('complete')
    refute_ci_markers(output)
  end

  def test_inspection_errors_have_a_separate_group_after_the_run
    %w[GITHUB_ACTIONS GITLAB_CI].each do |platform|
      with_ci_platform(platform) do
        output, errors, status = run_cli(File.join(@directory, 'missing.txt'))
        assert_equal 2, status.exitstatus, errors
        assert_ci_group(output, platform, name: 'Sensitive data scan', outcome: 'ERROR')
        assert_includes output, '[ERROR] unreadable_path | 1 file'
      end
    end
  end

  def run_cli(*arguments)
    Open3.capture3(Gem.bin_path('project-tools-secrets', 'project-tools-secrets'), *arguments)
  end
end
