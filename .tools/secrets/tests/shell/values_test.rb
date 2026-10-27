# frozen_string_literal: true

require_relative 'helper'

# Exercise word boundaries through the same scan and publication used by consumers.
class SecretsShellValuesTest < SecretsSessionTestCase
  include SecretsShellValuesHelper

  def test_awk_argument_after_variable_assignment_stays_separate
    source = <<~SH
      #!/bin/sh
      $AWK -v pid="$PID" -v passwd_path="$PASSWD_PATH" '
          BEGIN {
              print "ordinary code"
          }
      '
    SH
    assert_equal source, inspect_script(source, name: 'templates/check')
  end

  def test_following_awk_code_is_still_inspected
    source = <<~SH
      #!/bin/sh
      awk -v passwd_path="$PASSWD_PATH" '
          BEGIN { api_token = "#{@value}"; print "ordinary code" }
      '
    SH
    copy = inspect_script(source)
    refute_includes copy, @value
    assert_includes copy, 'passwd_path="$PASSWD_PATH"'
    assert_includes copy, 'print "ordinary code"'
  end

  def test_separate_arguments_and_indented_statements_survive
    source = "#!/bin/sh\npassword=\"#{@value}\" printf ordinary\n    echo following\n"
    copy = inspect_script(source)
    refute_includes copy, @value
    assert_includes copy, " printf ordinary\n    echo following\n"
  end

  def test_quoted_references_are_distinct_from_literal_defaults
    source = <<~SH
      #!/bin/sh
      password="$VALUE"
      token=${VALUE}
      API_TOKEN=${API_TOKEN:-#{@value}}
      PASSWD_PATH=${PASSWD_PATH:-/etc/passwd}
      secret_file=#{@value}
    SH
    copy = inspect_script(source)
    assert_includes copy, 'password="$VALUE"'
    refute_includes copy, @value
  end

  def test_unknown_source_does_not_gain_shell_boundaries
    write('settings.txt', "password=first\n    uncertain continuation\n")
    File.write(@policy, JSON.generate('files' => ['settings.txt']))
    call_session('prepare', '--root', @input, '--tree', @copies, '--policy', @policy)
    refute @result['complete']
    refute_path_exists @copies
  end

  def test_unclosed_shell_value_withholds_all_copies
    write('script.sh', "#!/bin/sh\npassword='#{@value}\n    echo following\n")
    write('ordinary.txt', "ordinary\n")
    scan(@input)
    assert_equal 2, @status.exitstatus
    assert_no_disclosure(@value)
    File.write(@policy, JSON.generate('files' => ['script.sh', 'ordinary.txt']))
    call_session('prepare', '--root', @input, '--tree', @copies, '--policy', @policy)
    refute @result['complete']
    refute_path_exists @copies
  end

  def test_complete_original_memory_template
    relative = 'basic_settings/templates/monitoring/check_memory_pressure'
    source = File.binread(File.expand_path("../../../../#{relative}", __dir__))
    copy = inspect_script(source, name: relative)
    program = source[/\$AWK -v pid=.*?\n    '\s*/m]
    refute_nil program
    assert_includes copy, program
  end
end
