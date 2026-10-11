# frozen_string_literal: true

require_relative '../../shared/test_support/bootstrap'
require 'project_tools/secrets'

# All scanner inputs are synthetic and confined to a temporary directory.
class SecretsTest < Minitest::Test
  def setup
    @directory = Dir.mktmpdir('secrets-test-')
    @input = File.join(@directory, 'input')
    @copies = File.join(@directory, 'copies')
    FileUtils.mkdir_p(@input)
  end

  def teardown
    FileUtils.remove_entry(@directory)
  end

  def write(name, text)
    path = File.join(@input, name)
    FileUtils.mkdir_p(File.dirname(path))
    File.binwrite(path, text)
    path
  end

  def scan(*args)
    command = File.expand_path('../bin/project-tools-secrets', __dir__)
    @out, @err, @status = Open3.capture3(Gem.ruby, command, '--json', *args)
    @report = JSON.parse(@out)
  end

  def fixture(name)
    File.read(File.join(__dir__, 'fixtures', name))
  end

  def assert_masked(*values, index: 0)
    values.each { |value| refute_includes copy(index), value }
    assert_no_disclosure(*values)
  end

  def assert_complete_copy
    assert_equal 1, @status.exitstatus, @out + @err
    assert @report['complete']
  end

  def copy(index = 0)
    File.read(File.join(@copies, @report.fetch('files')[index].fetch('copy')))
  end

  def assert_no_disclosure(*values)
    values.each do |value|
      refute_includes @out, value
      refute_includes @err, value
    end
  end

  def assert_puppet_redaction(source, suffixes)
    path = write('sample.pp', source)
    scan('--puppet', '--redact', @copies, path)
    assert_complete_copy
    assert_masked(*suffixes.map { |suffix| "synthetic-#{suffix}" })
    assert_equal source, File.read(path)
  end

  def assert_puppet_clean
    assert_equal 0, @status.exitstatus, @out + @err
    assert_empty @report['files'].first['findings']
  end

  def assert_unreviewed
    record = @report['files'].first
    assert_empty record.fetch('reviewed_findings', [])
    assert_empty record.fetch('reviewed_errors', [])
  end
end
