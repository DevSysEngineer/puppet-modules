# frozen_string_literal: true

require_relative '../session_helper'

# Reports and diagnostics preserve the operation result without exposing local restored bytes.
class SecretsSessionReviewTest < SecretsSessionTestCase
  def test_junit_preserves_preparation_findings_without_the_value
    write('a.yaml', "password: '#{@value}'\n")
    File.write(@policy, JSON.generate('files' => ['a.yaml']))
    report = File.join(@directory, 'report.xml')
    call_session('prepare', '--root', @input, '--tree', @copies, '--policy', @policy, '--junit', report)
    assert_equal 1, @code
    assert @result['prepared']
    xml = File.read(report)
    refute_includes xml, @value
    assert_match(/<failure\b/, xml)
  end

  def test_escaped_multiline_diagnostics_are_masked_with_local_value_knowledge
    @value = "synthetic-quote-\"-\\-\nsecond"
    write('a.yaml', "password: #{JSON.generate(@value)}\n")
    command = [Gem.ruby, '-rjson', '-rpsych', '-e', "print JSON.generate(Psych.safe_load_file('a.yaml')['password'])"]
    prepare(['a.yaml'], commands: { 'diagnose' => command })
    call_session('run', '--session', @session, '--command', 'diagnose')
    assert_equal 'executed', @result['status']
    refute_includes @result['stdout'], 'synthetic-quote'
    assert_includes @result['stdout'], '[REDACTED]'
  end

  def test_diff_refuses_context_changed_after_application
    write('a.yaml', 'ordinary: before')
    context = write('options.yaml', '{}')
    prepare(['a.yaml'], context: ['options.yaml'])
    edit('a.yaml', 'ordinary: after')
    apply('write' => ['a.yaml'])
    assert_applied
    File.write(context, 'changed: true')
    call_session('diff', '--session', @session)
    assert_equal ['source_conflict'], @result['errors']
  end

  def test_json_writes_require_json_syntax
    path = write('a.json', '{"ordinary":"before"}')
    prepare(['a.json'])
    edit('a.json', 'ordinary: after')
    apply('write' => ['a.json'])
    assert_equal ['invalid_json'], @result['errors']
    assert_equal '{"ordinary":"before"}', File.read(path)
  end
end
