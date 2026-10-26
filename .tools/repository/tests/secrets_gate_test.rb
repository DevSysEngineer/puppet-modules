# frozen_string_literal: true

require_relative '../../shared/test_support/bootstrap'
require_relative '../../shared/test_support/packages'

# Both public test entrypoints must stop before tests can expose rejected source.
class SecretsGateTest < Minitest::Test
  include ProjectToolsPackageSupport

  def setup
    @project = Dir.mktmpdir('secrets-gate-')
    write('Rakefile', File.read(File.join(ROOT, 'Rakefile')))
    write('.tools/shared/tests/probe_test.rb', "puts 'synthetic-tests-ran'\n")
  end

  def run_task(task, debug: false)
    env = { 'TEST' => nil, 'TESTOPTS' => nil }
    env['RUBYOPT'] = "#{ENV.fetch('RUBYOPT', '')} -d" if debug
    @output, @errors, @status = Open3.capture3(env, Gem.ruby, Gem.bin_path('rake', 'rake'), task, chdir: @project)
  end

  def test_debug_mode_keeps_native_parser_diagnostics_private
    write('sample.pp', "$password = 'synthetic-debug-unclosed")
    run_task('secrets:puppet', debug: true)
    assert_equal 2, @status.exitstatus
    refute_includes @output + @errors, 'synthetic-debug-unclosed'
  end

  def test_default_and_full_tests_reject_secrets_before_running_tests
    write('modules/sample/manifests/init.pp', "$password = Sensitive('synthetic-rejected')\n")
    %w[default test secrets:puppet].each do |task|
      run_task(task)
      assert_equal 1, @status.exitstatus, @output + @errors
      assert_includes @output, 'line=1'
      assert_includes @output, 'puppet_hardcoded_value'
      refute_includes @output + @errors, 'synthetic-rejected'
      refute_includes @output, 'synthetic-tests-ran'
    end
  end

  def test_safe_lookup_runs_tests_and_vendored_fixtures_are_excluded
    write('sample.pp', "$password = lookup('sample::password', Sensitive[String])\n")
    write('stdlib/manifests/example.pp', "$password = 'synthetic-vendor'\n")
    write('.tools/shared/tests/fixture.pp', "$password = 'synthetic-fixture'\n")
    run_task('test')
    assert @status.success?, @output + @errors
    assert_includes @output, 'synthetic-tests-ran'
    refute_includes @output + @errors, 'synthetic-vendor'
  end

  def test_parse_failure_and_empty_selection_block_tests
    %w[empty broken].each do |input|
      write('sample.pp', "$password = 'synthetic-unclosed") if input == 'broken'
      run_task('test')
      refute @status.success?
      refute_includes @output, 'synthetic-tests-ran'
      refute_includes @output + @errors, 'synthetic-unclosed'
    end
  end
end
