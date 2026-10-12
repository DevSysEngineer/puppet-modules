# frozen_string_literal: true

require_relative 'test_helper'

# License values use field semantics, not vendor prefixes or token lengths.
class SecretsLicenseTest < SecretsTest
  VALUE = 'synthetic-license-example'
  NAMES = %w[license_key licenseKey license-key license.key LICENSE_KEY].freeze

  def test_license_spellings_in_supported_formats
    %w[license_key licenseKey license-key license.key].each do |name|
      { 'pp' => "$%s = '%s'", 'yaml' => "%s: '%s'",
        'json' => '{"%s":"%s"}', 'properties' => '%s=%s', 'env' => '%s=%s' }.each do |extension, format|
        assert_license_format(name, extension, format)
      end
    end
  end

  def assert_license_format(name, extension, format)
    value = 'synthetic-license-complete-value'
    source = format(format, name, value)
    path = write("sample.#{extension}", source)
    scan(path)
    assert_complete_scan
    assert_masked(value)
    assert_equal source, File.read(path)
  end

  def test_puppet_attributes_defaults_and_lookup_fallbacks
    source = <<~PUPPET
      class example(String $license_key = '#{VALUE}') {
        notify { 'example': licenseKey => '#{VALUE}' }
        $license_key = lookup('example::license_key', String, 'first', '#{VALUE}')
        $wrapped = Sensitive('#{VALUE}')
      }
    PUPPET
    assert_puppet_redaction(source, ['license-example'])
  end

  def test_safe_puppet_references
    path = write('safe.pp', <<~PUPPET)
      $license_key = lookup('example::license_key', Sensitive[String])
      $licenseKey = $license_key.unwrap
      $other = Sensitive($license_key)
    PUPPET
    scan('--puppet', path)
    assert_puppet_clean
  end

  def test_multiline_and_escaped_license_values
    path = write('sample.yaml',
                 "license_key: |\n  synthetic-first\n  synthetic-last\nlicenseKey: \"synthetic-escaped\\nvalue\"\n")
    scan(path)
    assert_complete_scan
    assert_masked('synthetic-first', 'synthetic-last', 'synthetic-escaped')
  end

  def test_unbounded_license_is_incomplete
    path = write('sample.properties', "license.key='#{VALUE}\n")
    scan(path)
    assert_equal 2, @status.exitstatus
    refute @report['complete']
    assert_no_disclosure(VALUE)
  end

  def test_license_values_are_removed_from_paths_reports_and_debug_output
    path = write("#{VALUE}.env", "LICENSE_KEY=#{VALUE}\n")
    report = File.join(@directory, 'report.xml')
    scan('--junit', report, path)
    assert_complete_scan
    assert_masked(VALUE)
    refute_includes File.read(report), VALUE
    command = File.expand_path('../bin/project-tools-secrets', __dir__)
    out, err, status = Open3.capture3(Gem.ruby, '-d', command, path)
    assert_equal 1, status.exitstatus
    refute_includes out + err, VALUE
  end
end
