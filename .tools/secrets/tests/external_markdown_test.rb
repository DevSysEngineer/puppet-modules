# frozen_string_literal: true

require_relative 'external_helper'

# Installed consumers use the identical Markdown detector and session workflow.
class ExternalSecretsMarkdownTest < ExternalSecretsTestCase
  def test_installed_markdown_preparation_write_and_diff
    @synthetic = 'synthetic-installed-markdown'
    source = "Before.\n\n```ruby\npassword = join(['#{@synthetic}'\n```\n"
    write('source/example.md', source)
    prepare_markdown
    assert_private_copy
    edit_markdown
    run_success('bundle', 'exec', 'project-tools-secrets', 'write', *session_arguments, '--changes', 'changes.json')
    assert_equal source.sub('Before.', 'After.'), read('source/example.md')
    assert_installed_diff
  end

  def edit_markdown
    path = File.join(@project, 'analysis', 'example.md')
    File.write(path, File.read(path).sub('Before.', 'After.'))
    write('changes.json', JSON.generate('write' => ['example.md']))
  end

  def prepare_markdown
    write('policy.json', JSON.generate('files' => ['example.md']))
    command('bundle', 'exec', 'project-tools-secrets', 'prepare', '--root', 'source',
            '--tree', 'analysis', '--policy', 'policy.json', '--state', 'state', '--junit', 'prepare.xml')
    assert_equal 1, @status.exitstatus, @output + @errors
    result = JSON.parse(@output)
    assert result['complete']
    assert result['prepared']
    @session = result.fetch('session')
  end

  def assert_private_copy
    refute_includes read('analysis/example.md'), @synthetic
    refute_includes read('prepare.xml') + @output + @errors, @synthetic
    assert_equal 0o600, File.stat(File.join(@project, 'analysis', 'example.md')).mode & 0o777
    refute_path_exists File.join(@project, '.git')
  end

  def session_arguments
    ['--state', 'state', '--session', @session]
  end

  def assert_installed_diff
    run_success('bundle', 'exec', 'project-tools-secrets', 'diff', *session_arguments)
    assert_includes JSON.parse(@output)['diff'], 'After.'
    refute_includes @output + @errors, @synthetic
    run_success('bundle', 'exec', 'project-tools-secrets', 'close', *session_arguments)
    assert_equal 'closed', JSON.parse(@output)['status']
  end

  def test_installed_cli_withholds_incomplete_markdown_and_report_excerpts
    write('source/example.md', "~~~\npassword = join(['synthetic-blocked'\n")
    write('policy.json', JSON.generate('files' => ['example.md']))
    command('bundle', 'exec', 'project-tools-secrets', 'prepare', '--root', 'source',
            '--tree', 'analysis', '--policy', 'policy.json', '--state', 'state', '--junit', 'prepare.xml')
    assert_equal 2, @status.exitstatus
    refute JSON.parse(@output)['complete']
    refute_path_exists File.join(@project, 'analysis')
    refute_includes read('prepare.xml') + @output + @errors, 'synthetic-blocked'
  end
end
