# frozen_string_literal: true

# Parse consumer examples and check their reporting and phase contracts.
module GuideCiSupport
  ROOT = File.expand_path('../../../..', __dir__)

  PHASES = [
    ['puppet_secrets', 'Puppet secrets', []],
    ['puppet_metadata', 'Puppet metadata', ['puppet_secrets']],
    ['puppet_syntax', 'Puppet syntax', ['puppet_secrets']],
    ['puppet_dependencies', 'Puppet dependencies', %w[puppet_metadata puppet_syntax]],
    ['puppet_lint', 'Puppet lint', %w[puppet_metadata puppet_syntax]],
    ['puppet_catalog', 'Puppet catalogs', %w[puppet_dependencies puppet_lint]]
  ].freeze
  STAGES = %w[secrets basic_validation static_checks tool_tests catalogs].freeze

  def guide
    File.read(File.join(ROOT, '.tools/README.md'))
  end

  def configuration_with(key)
    configurations = guide.scan(/^```yaml\n(.*?)^```/m).flatten.map { |text| YAML.safe_load(text) }
    config = configurations.find { |item| item.is_a?(Hash) && item.key?(key) }
    refute_nil config
    config
  end

  def command_contracts
    { 'puppet_syntax' => /bundle exec (?:syntax-junit|rake syntax:puppet)/,
      'puppet_lint' => /bundle exec puppet-lint-junit/,
      'puppet_catalog' => %r{bundle exec global-modules/\.tools/catalog/bin/project-tools-catalog --junit },
      'puppet_metadata' => /bundle exec project-tools-metadata --junit /,
      'puppet_dependencies' => /bundle exec project-tools-module --junit / }
  end

  def assert_secret_stages
    assert_equal STAGES, configuration_with('.check_setup').fetch('stages')
  end

  def assert_gitlab_phases(config)
    assert_equal STAGES, config.fetch('stages')
    assert_equal PHASES.map(&:first), config.keys - %w[stages variables .check_setup]
    setup = gitlab_setup(config)
    expected = %w[secrets basic_validation basic_validation static_checks static_checks catalogs]
    PHASES.map(&:first).zip(expected).each do |id, stage|
      assert_gitlab_phase(config.fetch(id), stage, setup)
    end
  end

  def gitlab_setup(config)
    setup = config.fetch('.check_setup')
    assert_gitlab_success(setup, setup)
    %w[needs rules only except].each { |key| refute setup.key?(key) }
    setup
  end

  def assert_gitlab_phase(job, stage, setup)
    assert_equal stage, job.fetch('stage')
    assert_equal '.check_setup', job.fetch('extends')
    %w[needs rules only except dependencies].each { |key| refute job.key?(key) }
    assert_gitlab_success(job, setup)
  end

  def assert_gitlab_success(job, setup)
    assert_equal false, job.fetch('allow_failure', setup.fetch('allow_failure'))
    assert_equal 'on_success', job.fetch('when', setup.fetch('when'))
  end

  def assert_github_job(job)
    steps = job.fetch('steps')
    assert(steps.any? { |step| step.fetch('run', '').include?('if git diff --quiet HEAD --; then') })
    refute(steps.any? { |step| step.fetch('run', '').include?('--fix') })
    uploads = steps.select { |step| step.fetch('uses', '').start_with?('actions/upload-artifact@') }
    assert_github_uploads(uploads)
  end

  def assert_github_uploads(uploads)
    assert_equal 1, uploads.size
    upload = uploads.first
    assert_equal '${{ !cancelled() }}', upload.fetch('if')
    assert upload.dig('with', 'include-hidden-files')
    assert_match(%r{\A\$\{\{ env.PROJECT_REPORT_DIR \}\}/(?:[\w-]+|TEST-\*)\.xml\z},
                 upload.dig('with', 'path'))
  end

  def assert_gitlab_job(job)
    refute job.key?('needs')
    assert_equal '.check_setup', job.fetch('extends')
    assert_includes job.fetch('script').last, 'if git diff --quiet HEAD --; then'
    refute(job.fetch('script').any? { |command| command.include?('--fix') })
    assert_equal 'always', job.dig('artifacts', 'when')
    assert_equal [job.dig('artifacts', 'reports', 'junit')], job.dig('artifacts', 'paths')
  end

  def ci_scripts
    gitlab = configuration_with('.check_setup')
    github_scripts + gitlab.dig('.check_setup', 'before_script') +
      command_contracts.keys.flat_map { |job| gitlab.fetch(job).fetch('script') }
  end

  def github_scripts
    steps = configuration_with('jobs').fetch('jobs').values.flat_map { |job| job.fetch('steps') }
    steps.filter_map { |step| step['run'] }
  end
end
