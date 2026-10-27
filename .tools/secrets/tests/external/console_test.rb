# frozen_string_literal: true

require_relative 'helper'

# The installed executable retains concise, safe diagnoses without a repository checkout.
class ExternalSecretsConsoleTest < ExternalSecretsTestCase
  def test_installed_console_explains_findings_and_omits_clean_files
    write('data/ordinary.txt', 'ordinary')
    write('data/problem.txt', "password = 'synthetic-console-consumer'\n")
    command('bundle', 'exec', 'project-tools-secrets', 'data')
    assert_equal 1, @status.exitstatus, @output + @errors
    assert_includes @output, 'Files: 2 selected | 2 complete | 0 incomplete'
    assert_includes @output, 'possible secret value: An assignment targets a sensitive field.'
    refute_includes @output, 'ordinary.txt'
    refute_includes @output + @errors, 'synthetic-console-consumer'
    assert_empty @errors
  end

  def test_installed_console_explains_missing_optional_parser
    write('sample.pp', "notify { 'ordinary': }\n")
    command('bundle', 'exec', 'project-tools-secrets', '--puppet', 'sample.pp')
    assert_equal 2, @status.exitstatus, @output + @errors
    assert_includes @output, '[ERROR] Sensitive data scan'
    assert_includes @output, 'Files: 1 selected | 0 complete | 1 incomplete'
    assert_includes @output, 'The Puppet parser is unavailable; install OpenVox in the active bundle.'
    assert_includes @output, '(puppet_parser_unavailable)'
    assert_empty @errors
  end

  def test_installed_console_identifies_archive_members_without_disclosing_content
    buffer = StringIO.new(''.b)
    Zlib::GzipWriter.wrap(buffer) { |writer| writer.write("password = 'synthetic-archive-console'\n") }
    write('settings.gz', buffer.string)
    command('bundle', 'exec', 'project-tools-secrets', 'settings.gz')
    assert_equal 1, @status.exitstatus, @output + @errors
    assert_includes @output, 'settings.gz [archive member 1] | line=1 | possible secret value:'
    assert_includes @output, 'Coverage: 1 archive'
    refute_includes @output + @errors, 'synthetic-archive-console'
  end
end
