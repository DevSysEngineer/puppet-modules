# frozen_string_literal: true

require_relative 'support'

# Exercise native subprocess contracts at the public Rake boundary.
class ParallelRunnerTest < Minitest::Test
  include ParallelTestSupport

  def test_workers_overlap_with_a_bounded_pool_and_reuse_each_batch_interpreter
    overlap_probes
    probe('Gamma', "File.write('Gamma-pid', Process.pid.to_s); assert true")
    run_tests('2')
    assert_success
    assert_equal read('Alpha-pid'), read('Gamma-pid')
    refute_equal read('Alpha-pid'), read('Beta-pid')
  end

  def overlap_probes
    %w[Alpha Beta].each do |name|
      other = name == 'Alpha' ? 'Beta' : 'Alpha'
      probe(name, <<~RUBY, extra: "require 'timeout'")
        File.write('#{name}-pid', Process.pid.to_s)
        Timeout.timeout(10) { sleep 0.02 until File.exist?('#{other}-pid') }
        refute_equal File.read('#{other}-pid'), Process.pid.to_s
      RUBY
    end
  end

  def test_process_start_failure_stops_and_reaps_workers_already_started
    %w[Alpha Beta].each { |name| probe(name, 'sleep; assert true') }
    inject_spawn_failure
    run_tests
    refute @status.success?
    assert_includes @output, 'synthetic spawn failure'
    assert_includes @output, 'Execution: incomplete'
    assert_raises(Errno::ESRCH) { Process.kill(0, Integer(read('started-pid'))) }
  end

  def inject_spawn_failure
    File.write(File.join(@project, 'Rakefile'), <<~RUBY, mode: 'a')
      require_relative '.tools/shared/test_support/parallel_runner'
      ProjectTools::ParallelRunner.prepend(Module.new do
        def start_worker(directory, files, index)
          raise Errno::ENOENT, 'synthetic spawn failure' if index == 1
          super
          File.write('started-pid', @workers.last.pid.to_s)
        end
      end)
    RUBY
  end

  def test_help_version_and_alternative_reporter_use_native_route_once
    %w[Alpha Beta].each { |name| probe(name) }
    %w[-h --help -V --version].each do |option|
      run_tests('4', 'TESTOPTS' => option)
      assert_success
      refute_includes @output, 'worker-'
      refute_includes @output + @errors, 'result.json'
    end
  end

  def test_empty_alternative_reporter_environment_uses_native_route
    %w[Alpha Beta].each { |name| probe(name) }
    run_tests('4', 'VIM' => '')
    assert_success
    assert_includes @errors, 'VIM is present'
    refute_includes @output, 'worker-'
  end

  def test_nested_processes_do_not_inherit_worker_control_and_serial_fallback_preserves_parent_options
    nested_probe
    probe('Beta')
    run_tests
    assert_success
    verify_parent_environment
    run_tests('4', task: 'both', 'TEST' => '.tools/sample/tests/alpha_test.rb')
    assert_success
    refute_includes @output, 'worker-'
  end

  def nested_probe
    probe('Alpha', <<~RUBY)
      refute ARGV.any? { |argument| argument.start_with?('--jobs') }
      assert_nil ENV['PROJECT_TOOLS_TEST_WORKER_CONFIG']
      assert_nil ENV['TESTOPTS'] if defined?(ProjectTools::ParallelWorker)
      output, errors, status = Open3.capture3({'MINITEST_REPORTERS_REPORTS_DIR' => nil}, RbConfig.ruby,
        '-e', "require './.tools/shared/test_support/bootstrap'; class Nested < Minitest::Test; def test_nested; assert true; end; end")
      assert status.success?, output + errors
      assert_includes output, '[PASSED] Tool tests'
    RUBY
  end

  def verify_parent_environment
    File.open(File.join(@project, 'Rakefile'), 'a') do |file|
      file.puts "task(:verify) { raise 'parent changed' unless ProjectTools::Shared::RakeJobs.count == 4 }"
      file.puts "task both: ['test:tools', :verify]"
    end
  end
end
