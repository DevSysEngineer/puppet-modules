# frozen_string_literal: true

require_relative '../session_helper'
require 'base64'
require 'openssl'

# Generate fresh wire-format public material without retaining any private key bytes.
class SecretsSshPublicKeyTestCase < SecretsSessionTestCase
  def setup
    super
    @algorithm = 'ssh-ed25519'
    public_bytes = OpenSSL::PKey.generate_key('ED25519').public_to_der.byteslice(-32, 32)
    @encoded = Base64.strict_encode64([@algorithm.bytesize].pack('N') + @algorithm + [32].pack('N') + public_bytes)
    @comment = "synthetic-owner-#{SecureRandom.hex(8)}"
    @option = "synthetic-command-#{SecureRandom.hex(8)}"
    @record = "command=\"#{@option}\",restrict #{@algorithm} #{@encoded} #{@comment}"
  end

  def assert_hidden(text)
    [@encoded, @comment, @option].each do |value|
      refute text.include?(value), 'Public SSH record escaped disclosure protection'
    end
  end

  def assert_key_finding
    assert_complete_scan
    assert(@report['files'].first['findings'].any? { |finding| finding['rule'] == 'ssh_public_key' })
    assert_hidden(@out + @err + sanitized)
  end

  def round_trip(path, source)
    prepare([File.basename(path)])
    assert_hidden(analysis(File.basename(path)))
    edit(File.basename(path), analysis(File.basename(path)).sub("'before'", "'after'"))
    apply('write' => [File.basename(path)])
    assert_applied
    assert_source(path, source.sub("'before'", "'after'"))
  end
end
