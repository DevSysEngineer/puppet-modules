# frozen_string_literal: true

require_relative 'test_helper'

# Hiera conversion selectors apply across the explicitly selected YAML files.
class SecretsHieraTest < SecretsTest
  def test_yaml_blocks_json_values_and_nested_secrets_preserve_structure
    path = write('data.yaml', fixture('blocks.txt'))
    original = File.binread(path)
    scan('--redact', @copies, path)
    assert_complete_copy
    assert_equal original, File.binread(path)
    assert_yaml_structure
  end

  def assert_yaml_structure
    clean = Psych.safe_load(copy)
    assert_equal '[REDACTED]', clean['example::password']
    assert_equal '[REDACTED]', clean['api_key']
    assert_equal({ 'first' => '[REDACTED]', 'second' => ['[REDACTED]'] }, clean['secrets'])
    assert_equal 'unchanged', clean['ordinary']
  end

  def test_hiera_conversion_hides_unusually_named_values_across_files
    write('common.yaml', fixture('lookup-options.txt'))
    write('node.yaml', "example::credential: synthetic-credential\nexample::opaque: synthetic-opaque\n")
    scan('--redact', @copies, @input)
    assert_equal 1, @status.exitstatus, @out + @err
    assert_includes copy, 'convert_to: Sensitive'
    refute_includes copy(1), 'synthetic-credential'
    refute_includes copy(1), 'synthetic-opaque'
    assert_no_disclosure('synthetic-credential', 'synthetic-opaque')
  end

  def test_regex_conversion_and_aliases_require_local_review
    ['lookup_options:\n  "^example::.*":\n    convert_to: Sensitive\n',
     'password: &credential synthetic-aliased\nother: *credential\n'].each do |text|
      path = write('data.yaml', text.gsub('\\n', "\n"))
      scan('--redact', @copies, path)
      assert_equal 2, @status.exitstatus, @out + @err
      refute_path_exists @copies
      assert_no_disclosure('synthetic-aliased')
    end
  end

  def test_malformed_yaml_errors_never_include_parser_fragments
    path = write('data.yaml', "password: [synthetic-invalid\n")
    scan('--redact', @copies, path)
    assert_equal 2, @status.exitstatus
    assert_includes @report['files'][0]['errors'], 'invalid_yaml'
    assert_no_disclosure('synthetic-invalid')
    refute_path_exists @copies
  end

  def test_json_sensitive_values_remain_valid_json
    path = write('data.json', '{"password":"synthetic-json","normal":42}')
    scan('--redact', @copies, path)
    assert_equal 1, @status.exitstatus, @out + @err
    assert_equal({ 'password' => '[REDACTED]', 'normal' => 42 }, JSON.parse(copy))
  end

  def test_lookup_options_aliases_block_indirect_conversion_and_data
    write('common.yaml', "lookup_options:\n  default: &conversion {convert_to: Sensitive}\n  " \
                         "example::opaque: *conversion\n")
    write('node.yaml', "example::opaque: synthetic-aliased-conversion\n")
    scan('--redact', @copies, @input)
    assert_equal 2, @status.exitstatus
    refute_path_exists @copies
    assert_no_disclosure('synthetic-aliased-conversion')
  end
end
