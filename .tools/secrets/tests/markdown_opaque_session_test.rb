# frozen_string_literal: true

require_relative 'session_helper'

# HTML ambiguity must not expose even part of a value through preparation or reports.
class SecretsMarkdownOpaqueSessionTest < SecretsSessionTestCase
  def test_diagnostics_mask_whole_fragments_in_both_output_streams
    write('example.md', "```ruby\npassword = join(['#{@value}'\n```\n")
    program = 'text = File.read("example.md"); $stdout.write(text); $stderr.write(text); exit 7'
    prepare(['example.md'], commands: { 'inspect' => [Gem.ruby, '-e', program] })
    call_session('run', '--session', @session, '--command', 'inspect')
    assert_equal 7, @code
    assert_equal 'executed', @result['status']
    assert_includes @result['stdout'], '[REDACTED]'
    assert_includes @result['stderr'], '[REDACTED]'
  end

  def test_uncertain_indentation_withholds_the_entire_preparation
    write('example.md', "    password = #{@value}\n   synthetic-tail\n")
    File.write(@policy, JSON.generate('files' => ['example.md']))
    call_session('prepare', '--root', @input, '--tree', @copies, '--policy', @policy)
    refute @result['complete']
    refute @result['prepared']
    refute_path_exists @copies
  end

  def test_preparation_covers_values_containing_backticks_in_html
    source = "Text <span title=\"`password = '#{@value}`synthetic-tail'\">example</span>\nBefore.\n"
    path = write('example.md', source)
    prepare(['example.md'])
    refute_includes analysis('example.md'), 'synthetic-tail'
    edit('example.md', analysis('example.md').sub('Before.', 'After.'))
    apply('write' => ['example.md'])
    assert_applied
    assert_equal source.sub('Before.', 'After.'), File.read(path)
    assert_safe_html_review
  end

  def assert_safe_html_review
    call_session('diff', '--session', @session)
    assert_reviewed
    refute_includes @result['diff'], 'synthetic-tail'
  end

  def test_raw_html_failure_withholds_analysis_and_source_excerpts
    write('example.md', "<script>\n\n```\npassword = join(['#{@value}'\n```\n</script>\n")
    File.write(@policy, JSON.generate('files' => ['example.md']))
    report = File.join(@directory, 'report.xml')
    call_session('prepare', '--root', @input, '--tree', @copies, '--policy', @policy, '--junit', report)
    refute @result['complete']
    refute_path_exists @copies
    refute_includes File.read(report), @value
  end

  def test_preparation_and_reports_mask_the_entire_link_title_value
    write('example.md', "[example](https://example.org \"`password = '#{@value}`synthetic-tail'\")\n")
    File.write(@policy, JSON.generate('files' => ['example.md']))
    report = File.join(@directory, 'report.xml')
    call_session('prepare', '--root', @input, '--tree', @copies, '--policy', @policy, '--junit', report)
    assert @result['prepared']
    refute_includes analysis('example.md'), 'synthetic-tail'
    refute_includes File.read(report), 'synthetic-tail'
  end
end
