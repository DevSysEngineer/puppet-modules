# frozen_string_literal: true

require_relative '../session_helper'

# Shell branch labels are code; assignments and options in their bodies are data.
class SecretsShellCaseTest < SecretsSessionTestCase
  def script(body)
    "#!/bin/sh\ncase \"$1\" in\n#{body}\n  *) exit 1 ;;\nesac\n"
  end

  def patterns
    "  caching_sha2_password:*) exit 0 ;;\n  (mysql_native_password:*|access_token:*) exit 0 ;;"
  end

  def test_scan_and_prepare_preserve_case_patterns_as_indicators
    source = script(patterns)
    path = write('script.sh', source)
    scan(path)
    assert_complete_scan
    assert_equal ['indicator'], @report['files'].first['findings'].map { |finding| finding['kind'] }.uniq
    prepare(['script.sh'])
    assert_equal source, analysis('script.sh')
  end

  def test_new_case_patterns_are_writable_and_preserve_protected_values
    source = script("  ordinary) password='#{@value}'; exit 0 ;;")
    path = write('script.sh', source)
    File.chmod(0o750, path)
    before = file_metadata(path)
    prepare(['script.sh'])
    edit('script.sh', analysis('script.sh').sub('  *)', "#{patterns}\n  *)"))
    apply('write' => ['script.sh'])
    assert_applied
    assert_source(path, source.sub('  *)', "#{patterns}\n  *)"))
    assert_equal before, file_metadata(path)
  end

  def test_assignments_and_command_options_inside_case_remain_masked
    source = script("  password:*) password='#{@value}'; client --api-key '#{@value}' ;;\n  " \
                    "secret:*) client --password='#{@value}' ;;")
    path = write('script.sh', source)
    assert_scan_reports_masked(path)
    prepare(['script.sh'])
    refute_includes analysis('script.sh'), @value
    edit('script.sh', "#{analysis('script.sh')}# ordinary edit\n")
    apply('write' => ['script.sh'])
    assert_applied
    assert_source(path, "#{source}# ordinary edit\n")
  end

  def assert_scan_reports_masked(path)
    report_path = File.join(@directory, 'scan.xml')
    scan('--junit', report_path, path)
    assert_complete_scan
    assert_masked(@value)
    refute_includes File.read(report_path), @value
  end

  def test_plain_new_secret_in_case_is_rejected_without_changing_any_source
    source = script('  ordinary) exit 0 ;;')
    path = write('script.sh', source)
    ordinary = write('ordinary.txt', "before\n")
    prepare(['script.sh', 'ordinary.txt'])
    edit('script.sh', script("  password:*) password='#{@value}'; exit 0 ;;"))
    edit('ordinary.txt', "after\n")
    apply('write' => ['script.sh', 'ordinary.txt'])
    assert_includes @result['errors'], 'unregistered_value'
    assert_source(path, source)
    assert_source(ordinary, "before\n")
  end

  def test_multiline_value_in_case_remains_fully_masked
    source = script("  ordinary) password='#{@value}\n#{@value}'; exit 0 ;;")
    path = write('script.sh', source)
    scan(path)
    assert_complete_scan
    assert_masked(@value)
    prepare(['script.sh'])
    refute_includes analysis('script.sh'), @value
  end

  def test_uncertain_value_boundary_withholds_the_entire_selection
    body = ['  ordinary) password', '=', "'#{@value}"].join
    write('script.sh', script(body))
    write('ordinary.txt', "before\n")
    File.write(@policy, JSON.generate('files' => ['script.sh', 'ordinary.txt']))
    call_session('prepare', '--root', @input, '--tree', @copies, '--policy', @policy)
    refute @result['complete']
    refute_path_exists @copies
  end

  def test_colon_value_outside_shell_is_not_a_case_pattern
    path = write('settings.txt', "password:#{@value})\n")
    scan(path)
    assert_complete_scan
    assert_masked(@value)
  end

  def test_colon_value_in_shell_data_is_not_a_case_pattern
    path = write('script.sh', "#!/bin/sh\ncat <<'DATA'\npassword:#{@value})\nDATA\n")
    scan(path)
    assert_complete_scan
    assert_masked(@value)
  end

  def test_console_and_debug_reports_do_not_disclose_branch_values
    path = write("file-#{@value}.sh", script("  ordinary) password='#{@value}'; exit 0 ;;"))
    command = File.expand_path('../../bin/project-tools-secrets', __dir__)
    @out, @err, @status = Open3.capture3(Gem.ruby, '-d', command, path)
    assert_equal 1, @status.exitstatus
    assert_no_disclosure(@value)
  end
end
