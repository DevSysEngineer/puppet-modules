# frozen_string_literal: true

require_relative '../../../shared/test_support/packages'
require 'yaml'

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

  def workflow_steps(job)
    YAML.load_file(File.join(ROOT, '.github/workflows/checks.yml')).fetch('jobs').fetch(job).fetch('steps')
  end

  def guide_configuration(key)
    guide = File.read(File.join(ROOT, '.tools/README.md'))
    configs = guide.scan(/^```yaml\n(.*?)^```/m).flatten.map { |yaml| YAML.safe_load(yaml) }
    configs.find { |config| config.key?(key) }
  end
end
