# frozen_string_literal: true

require_relative 'test_helper'

# Source delimiters must not become part of a credential value.
class SecretsSourceContextTest < SecretsTest
  def test_assignment_inside_a_quoted_command_has_a_bounded_value
    source = "exec { 'example': command => \"client --password=synthetic-command-value\", }\n"
    path = write('command.pp', source)
    scan(path)
    assert_complete_scan
    assert_masked('synthetic-command-value')
    assert_includes sanitized, 'client --password='
    assert_equal source, File.read(path)
  end

  def test_ruby_keyword_argument_is_not_an_indented_value_continuation
    source = "def inspect_value\n  secret = false\n  finish\nend\n"
    path = write('sample.rb', source)
    scan(path)
    assert @report['complete'], @out + @err
  end

  def test_rake_task_name_does_not_consume_the_rest_of_the_document
    source = "```sh\nbundle exec rake secrets:puppet\n```\n\nOrdinary documentation.\n"
    path = write('README.md', source)
    scan(path)
    assert_complete_scan
    assert_equal source, sanitized
  end

  def test_unclosed_assignment_is_incomplete
    path = write('sample.env', "PASSWORD='synthetic-unclosed\n")
    scan(path)
    assert_equal 2, @status.exitstatus
    refute @report['complete']
    assert_no_disclosure('synthetic-unclosed')
  end

  def test_ruby_fixture_containing_malformed_secret_is_incomplete
    source = "sample = \"password='synthetic-unclosed\\n\"\n"
    path = write('fixture.rb', source)
    scan(path)
    assert_equal 2, @status.exitstatus
    assert_no_disclosure('synthetic-unclosed')
    assert_equal source, File.read(path)
  end

  def test_key_material_split_across_ruby_literals_is_fully_masked
    source = 'data = "-----BEGIN PRIVATE KEY-----\\n" + "synthetic-fragment-body\\n" + ' \
             "\"-----END PRIVATE KEY-----\"\n"
    path = write('fixture.rb', source)
    scan(path)
    assert_complete_scan
    assert_masked('synthetic-fragment-body')
  end

  def test_invalid_ruby_is_incomplete
    path = write('fixture.rb', "sample = \"password='synthetic-unclosed\n")
    scan(path)
    assert_equal 2, @status.exitstatus
    assert_no_disclosure('synthetic-unclosed')
  end
end
