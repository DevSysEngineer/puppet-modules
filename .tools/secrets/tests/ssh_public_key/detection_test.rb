# frozen_string_literal: true

require_relative 'helper'

# Detection and report channels share the disclosure-only record contract.
class SecretsSshPublicKeyDetectionTest < SecretsSshPublicKeyTestCase
  def test_detection_does_not_depend_on_filename_or_field_name
    sources = { 'sample.pp' => "$public_keys = { 'example' => '#{@record}' }\n",
                'sample.yaml' => "ordinary: #{@record.to_json}\n",
                'sample.json' => { ordinary: @record }.to_json,
                'example.pub' => "#{@record}\n", 'authorized_keys' => "#{@record}\n",
                'unknown.txt' => "prefix\n#{@record}\nsuffix\n" }
    sources.each do |name, source|
      scan(write(name, source))
      assert_key_finding
    end
  end

  def test_algorithm_names_and_references_are_not_keys
    path = write('sample.pp', "$algorithm = 'ssh-ed25519'\n$source = 'puppet:///modules/example/id_ed25519.pub'\n")
    scan(path)
    assert_equal 0, @status.exitstatus
    prepare(['sample.pp'])
    assert_equal File.read(path), analysis('sample.pp')
  end

  def test_supported_algorithms_and_certificates_use_content_detection
    algorithms = %w[ssh-rsa ssh-dss ssh-ed25519 ssh-mldsa44-ed25519 ecdsa-sha2-nistp256
                    ecdsa-sha2-nistp384 ecdsa-sha2-nistp521 sk-ssh-ed25519@openssh.com
                    sk-ecdsa-sha2-nistp256@openssh.com]
    algorithms += algorithms.map { |name| "#{name.delete_suffix('@openssh.com')}-cert-v01@openssh.com" }
    algorithms.each do |algorithm|
      source = "#{algorithm}\t#{@encoded}\t#{@comment}\r\n"
      scan(write('arbitrary.data', source))
      assert_complete_scan
      assert_hidden(@out + @err + sanitized)
    end
  end

  def test_console_debug_and_path_reporting_do_not_publish_key_records
    command = File.expand_path('../../bin/project-tools-secrets', __dir__)
    path = write('example.pub', "#{@record}\n")
    stdout, stderr, status = Open3.capture3(Gem.ruby, '-d', command, path)
    assert_equal 1, status.exitstatus
    assert_hidden(stdout + stderr)
    assert_includes stdout, 'ssh_public_key'
  end

  def test_path_reporting_hides_key_records
    path = write("#{@algorithm} #{@encoded} #{@comment}.txt", 'ordinary')
    scan(path)
    assert_equal 0, @status.exitstatus
    assert_hidden(@out + @err)
  end
end
