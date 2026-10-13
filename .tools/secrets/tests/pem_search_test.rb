# frozen_string_literal: true

require_relative 'session_helper'

# Search markers are bounded code; embedded material still needs complete masking.
class SecretsPemSearchTest < SecretsSessionTestCase
  def pem_marker(kind = 'BEGIN', label = 'CERTIFICATE')
    ['-----', kind, ' ', label, '-----'].join
  end

  def search_patterns
    <<~SH
      #!/bin/sh
      grep -Eq '^(#{pem_marker('BEGIN', 'ENCRYPTED PRIVATE KEY')}|Proc-Type: 4,ENCRYPTED)' "$KEY"
      awk '
          /^#{pem_marker}$/ { inside = 1 }
          /^#{pem_marker('END')}$/ { inside = 0 }
      ' "$FILE"
    SH
  end

  def inspect_source(source, name = 'script.sh')
    path = write(name, source)
    scan(path)
    assert @report['complete'], @out
    prepare([name])
    assert_source(path, source)
    analysis(name)
  end

  def test_separate_search_patterns_do_not_form_pem_blocks
    assert_equal search_patterns, inspect_source(search_patterns)
  end

  def test_awk_file_search_patterns_are_preserved
    source = "/^#{pem_marker}$/ { inside = 1 }\n/^#{pem_marker('END')}$/ { inside = 0 }\n"
    assert_equal source, inspect_source(source, 'program.awk')
  end

  def test_shell_command_reference_and_awk_range_patterns_stay_separate
    source = <<~SH
      #!/bin/sh
      if "$SEARCH_TOOL" -Eq '^(#{pem_marker('BEGIN', 'ENCRYPTED PRIVATE KEY')}|Proc-Type: 4,ENCRYPTED)' "$KEY"; then :; fi
      awk '
          /^#{pem_marker}$/,/^#{pem_marker('END')}$/ { print }
      ' "$FILE"
    SH
    assert_equal source, inspect_source(source)
  end

  def test_search_patterns_do_not_hide_an_actual_value
    source = "#{search_patterns}\nAPI_TOKEN=#{@value}\n"
    copy = inspect_source(source)
    assert_includes copy, search_patterns
    refute_includes copy, @value
  end

  def test_embedded_multiline_material_is_fully_masked
    source = "#{search_patterns}\ncontent='#{pem_marker}\n#{@value}\n#{pem_marker('END')}'\necho ordinary\n"
    copy = inspect_source(source)
    assert_includes copy, search_patterns
    refute_includes copy, @value
    assert_includes copy, 'echo ordinary'
    assert_equal 1, copy.scan(ProjectTools::Secrets::Document::MARKER).length
  end

  def test_material_in_split_ruby_literals_is_masked
    source = "content = '#{pem_marker}' +\n  '#{@value}' +\n  '#{pem_marker('END')}'\nputs 'ordinary'\n"
    copy = inspect_source(source, 'sample.rb')
    refute_includes copy, @value
    refute_includes copy, pem_marker
    refute_includes copy, pem_marker('END')
    assert_includes copy, "puts 'ordinary'"
  end

  def test_regex_containing_actual_material_is_not_exempt
    source = "#!/bin/sh\ngrep '#{pem_marker}\\n#{@value}\\n#{pem_marker('END')}' input\n"
    copy = inspect_source(source)
    refute_includes copy, @value
  end

  def assert_withheld(source)
    write('script.sh', source)
    scan(@input)
    assert_equal 2, @status.exitstatus
    assert_no_disclosure(@value)
    File.write(@policy, JSON.generate('files' => ['script.sh']))
    call_session('prepare', '--root', @input, '--tree', @copies, '--policy', @policy)
    refute @result['complete']
    refute_path_exists @copies
  end

  def test_unterminated_material_still_blocks
    assert_withheld("#{search_patterns}\ncontent='#{pem_marker}\n#{@value}\n'")
    assert_includes @report['files'].first['errors'], 'unterminated_pem_material'
  end

  def test_search_end_cannot_close_unterminated_material
    assert_withheld("#!/bin/sh\ncontent='#{pem_marker}\n#{@value}'\ngrep '^#{pem_marker('END')}$' input\n")
  end

  def test_nested_material_still_blocks
    assert_withheld("#{search_patterns}\n#{pem_marker}\n#{@value}\n#{pem_marker}\n#{pem_marker('END')}\n")
    assert_includes @report['files'].first['errors'], 'nested_pem_material'
  end

  def test_plain_quoted_marker_is_still_suspected_material
    assert_withheld("#!/bin/sh\nvalue='#{pem_marker}'\n")
  end

  def test_search_text_in_shell_data_does_not_hide_suspected_material
    assert_withheld("#!/bin/sh\ncat <<DATA\ngrep '^#{pem_marker}$' input\n#{@value}\nDATA\n")
  end

  def test_complete_original_certificate_template
    relative = 'nginx/templates/check_nginx_cert'
    source = File.binread(File.expand_path("../../../#{relative}", __dir__))
    assert_equal source, inspect_source(source, relative)
  end
end
