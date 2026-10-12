# frozen_string_literal: true

require_relative 'session_helper'

# Public task boundaries retain safe startup, publication and source-validation contracts.
class SecretsTaskContractTest < SecretsSessionTestCase
  def test_source_reader_loads_and_reads_without_loading_the_scanner
    path = write('ordinary.txt', 'ordinary')
    script = <<~CODE
      require 'project_tools/secrets/source_reader'
      abort if defined?(ProjectTools::Secrets::Scanner)
      print ProjectTools::Secrets::SourceReader.local_read(ARGV.fetch(0))
    CODE
    assert_reader_output(script, path, 'ordinary')
  end

  def test_source_reader_rejects_incomplete_input_without_the_scanner
    assert_reader_failure(write('binary.txt', "\x00"))
  end

  def assert_reader_failure(path)
    script = <<~CODE
      require 'project_tools/secrets/source_reader'
      begin
        ProjectTools::Secrets::SourceReader.local_read(ARGV.fetch(0))
      rescue ProjectTools::Secrets::Failure => e
        print e.code
      end
    CODE
    assert_reader_output(script, path, 'inspection_incomplete')
  end

  def assert_reader_output(script, path, expected)
    stdout, stderr, status = Open3.capture3(Gem.ruby, '-e', script, path)
    assert status.success?, stderr
    assert_equal expected, stdout
    assert_empty stderr
  end

  def test_executable_withholds_load_errors_even_in_ruby_debug_mode
    root = File.join(@directory, 'load-path')
    FileUtils.mkdir_p(File.join(root, 'project_tools'))
    %w[LoadError SyntaxError RuntimeError SystemStackError Interrupt].each do |failure|
      File.write(File.join(root, 'project_tools/secrets.rb'), "raise #{failure}, 'synthetic-source-content'\n")
      assert_safe_startup('project-tools-secrets', root)
    end
  end

  def assert_safe_startup(name, root)
    executable = File.expand_path("../bin/#{name}", __dir__)
    stdout, stderr, status = Open3.capture3(Gem.ruby, '-d', '-I', root, executable, '--help')
    assert_equal 2, status.exitstatus
    assert_empty stdout
    assert_includes stderr, 'execution_failed; incomplete; no content released.'
    refute_includes stderr, 'synthetic-source-content'
  end

  def test_failed_required_output_withdraws_preparation
    write('ordinary.txt', 'ordinary')
    File.write(@policy, JSON.generate('files' => ['ordinary.txt']))
    output = failing_output
    code = ProjectTools::Secrets.run(['prepare', '--state', @state, '--root', @input, '--tree', @copies,
                                      '--policy', @policy], output: output)
    assert_equal 2, code
    refute_path_exists @copies
    assert_empty Dir.glob(File.join(@state, '*.json'))
  end

  def failing_output
    Object.new.tap do |output|
      def output.puts(*)
        raise IOError
      end
    end
  end

  def test_restored_candidate_is_parsed_once_for_inspection_and_puppet_policy
    write('ordinary.pp', "notify { 'before': }\n")
    prepare(['ordinary.pp'])
    edit('ordinary.pp', "notify { 'after': }\n")
    inspections = 0
    trace = TracePoint.new(:call) do |event|
      inspections += 1 if event.defined_class == ProjectTools::Secrets::PuppetScan && event.method_id == :scan
    end
    trace.enable { apply('write' => ['ordinary.pp']) }
    assert_applied
    # One parse of analysis and one of restored bytes; policy reuses the latter.
    assert_equal 2, inspections
  end

  def test_writer_and_recovery_refuse_a_source_root_locked_by_another_writer
    write('ordinary.txt', 'ordinary')
    prepare(['ordinary.txt'])
    store = ProjectTools::Secrets::Store.new(@state)
    File.open(@input) do |root|
      root.flock(File::LOCK_EX)
      assert_source_busy { apply('write' => ['ordinary.txt']) }
      store.save(@session, store.load(@session).merge('status' => 'writing'))
      assert_source_busy { call_session('recover', '--session', @session) }
    end
  end

  def assert_source_busy
    yield
    assert_equal 2, @code
    assert_equal ['source_busy'], @result['errors']
  end
end
