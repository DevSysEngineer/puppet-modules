# frozen_string_literal: true

require_relative 'test_helper'
require 'project_tools/secrets/session_command'

# Exercise complete local round trips, rather than comparing implementation fragments.
class SecretsSessionTestCase < SecretsTest
  def setup
    super
    @directory = File.realpath(@directory)
    @input = File.join(@directory, 'input')
    @copies = File.join(@directory, 'copies')
    @state = File.join(@directory, 'state')
    @policy = File.join(@directory, 'policy.json')
    @value = "synthetic-#{SecureRandom.hex(16)}"
  end

  def prepare(files, **policy)
    File.write(@policy, JSON.generate({ 'files' => files }.merge(policy.transform_keys(&:to_s))))
    call_session('prepare', '--root', @input, '--tree', @copies, '--policy', @policy)
    @session = @result['session']
    assert @result['prepared'], @result.inspect
  end

  def call_session(*arguments)
    output = StringIO.new
    @code = ProjectTools::Secrets::SessionCommand.new(output).run([*arguments, '--state', @state])
    @result = JSON.parse(output.string)
    refute_includes output.string, @value
    @result
  end

  def apply(change)
    path = File.join(@directory, 'change.json')
    File.write(path, JSON.generate(change))
    call_session('apply', '--session', @session, '--changes', path)
  end

  def analysis(path)
    File.read(File.join(@copies, path))
  end

  def edit(path, text)
    absolute = File.join(@copies, path)
    FileUtils.mkdir_p(File.dirname(absolute))
    File.write(absolute, text)
  end

  def assert_applied
    assert_equal 'applied', @result['status'], @result.inspect
  end

  def assert_reviewed
    assert_equal 'reviewed', @result['status'], @result.inspect
  end

  def marker(path)
    analysis(path)[ProjectTools::Secrets::Document::MARKER]
  end

  def marker_id(path)
    marker(path)[ProjectTools::Secrets::Document::MARKER, 1]
  end
end
