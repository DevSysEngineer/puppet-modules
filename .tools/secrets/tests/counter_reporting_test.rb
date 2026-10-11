# frozen_string_literal: true

require_relative 'test_helper'

# Counter exceptions preserve signature detection and all metadata-only output channels.
class CounterReportingTest < SecretsTest
  def test_signatures_in_counter_blocks_are_masked_in_both_modes
    source, values = signature_source
    [[], ['--puppet']].each_with_index do |mode, index|
      @copies = File.join(@directory, "copies-#{index}")
      path = write('counts.pp', source)
      scan(*mode, '--redact', @copies, path)
      assert_complete_copy
      assert_masked(*values)
      assert_equal source, File.read(path)
    end
  end

  def signature_source
    token = "ghp_#{'a' * 36}"
    key = "-----BEGIN RSA PRIVATE KEY-----\nsynthetic-key-body\n-----END RSA PRIVATE KEY-----"
    source = fixture('counts.pp').sub('$api_key_name => 1',
                                      "$api_key_name => 1, 'other' => '#{token}', 'material' => '#{key}'")
    [source, [token, 'synthetic-key-body']]
  end

  def test_console_json_junit_and_debug_mode_never_disclose_values
    path = write('counts.pp', "#{fixture('counts.pp')}$password = 'synthetic-after-counter'\n")
    [[], ['--puppet']].each_with_index do |mode, index|
      assert_reports(path, mode, index)
    end
  end

  def assert_reports(path, mode, index)
    report = File.join(@directory, "report-#{index}.xml")
    scan(*mode, '--junit', report, path)
    assert_complete_copy
    refute_includes File.read(report), 'synthetic-after-counter'
    assert_no_disclosure('synthetic-after-counter')
    assert_unreviewed
    command = File.expand_path('../bin/project-tools-secrets', __dir__)
    output, errors, status = Open3.capture3(Gem.ruby, '-d', command, *mode, path)
    assert_equal 1, status.exitstatus
    refute_includes output + errors, 'synthetic-after-counter'
  end
end
