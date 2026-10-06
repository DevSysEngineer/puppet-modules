# frozen_string_literal: true

require_relative '../../shared/test_support/packages'

# Temporary workspaces and Bash execution shared by presentation and native-step checks.
module CiLogSupport
  include ProjectToolsPackageSupport

  def setup
    @project = Dir.mktmpdir('ci-logs-')
    @helper = File.join(ROOT, '.github/actions/setup-tooling/log.sh')
  end

  def shell(script, env = {})
    environment = { 'GITHUB_ACTIONS' => nil, 'GITLAB_CI' => nil }.merge(env)
    Open3.capture3(environment, 'bash', '-e', '-o', 'pipefail', '-c', script, 'ci-log-test', @helper, chdir: @project)
  end
end
