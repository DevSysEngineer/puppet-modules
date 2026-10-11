# frozen_string_literal: true

require_relative 'test_helper'

# Error paths must never turn missing coverage into successful disclosure.
class SecretsIoTest < SecretsTest
  def test_clean_scan_and_hidden_file_selection
    write('normal.txt', "ordinary = unchanged\n")
    write('.hidden', "password=synthetic-hidden\n")
    scan(@input)
    assert_equal 1, @status.exitstatus
    assert_equal 2, @report['files'].length
    assert_no_disclosure('synthetic-hidden')
    scan(File.join(@input, 'normal.txt'))
    assert_equal 0, @status.exitstatus
    assert_equal 'no_findings', @report['status']
    refute_path_exists @copies
  end

  def test_failures_block_all_redacted_output_including_clean_files
    write('clean.txt', 'ordinary')
    write('binary.bin', "synthetic-binary\x00")
    write('invalid.txt', "synthetic-encoding\xff".b)
    scan('--redact', @copies, @input, File.join(@input, 'missing'))
    assert_equal 2, @status.exitstatus
    refute @report['complete']
    assert_equal(3, @report['files'].count { |file| !file['complete'] })
    refute_path_exists @copies
  end

  def test_symlinks_and_special_files_are_not_followed
    original = write('original.txt', 'password=synthetic-link')
    link = File.join(@input, 'link.txt')
    File.symlink(original, link)
    pipe = File.join(@input, 'pipe')
    File.mkfifo(pipe)
    scan('--redact', @copies, link, pipe)
    assert_equal 2, @status.exitstatus
    refute_path_exists @copies
    assert(@report['files'].all? { |file| file['errors'] == ['unsupported_file_type'] })
    assert_no_disclosure('synthetic-link')
  end

  def test_empty_directories_and_oversized_files_are_incomplete
    scan(@input)
    assert_equal 2, @status.exitstatus
    path = write('large.txt', '')
    File.truncate(path, ProjectTools::Secrets::Scanner::MAX_BYTES + 1)
    scan(path)
    assert_equal 2, @status.exitstatus
    assert_includes @report['files'][0]['errors'], 'file_too_large'
  end

  def test_destinations_never_overwrite_input_or_existing_content
    path = write('settings.txt', 'password=synthetic-preserved')
    [path, @input, File.join(@input, 'copies')].each do |target|
      scan('--redact', target, @input)
      assert_equal 2, @status.exitstatus
      assert_equal 'password=synthetic-preserved', File.read(path)
    end
    assert_equal ['settings.txt'], Dir.children(@input)
    scan('--junit', path, path)
    assert_equal 2, @status.exitstatus
    assert_equal 'password=synthetic-preserved', File.read(path)
  end

  def test_output_has_private_permissions_and_does_not_reuse_secret_filenames
    path = write('synthetic-filename.txt', 'password=synthetic-filename')
    scan('--redact', @copies, path)
    assert_equal 1, @status.exitstatus
    assert_no_disclosure('synthetic-filename')
    assert_equal ['file-000001.txt'], Dir.children(@copies)
    assert_equal 0o700, File.stat(@copies).mode & 0o777
    assert_equal 0o600, File.stat(File.join(@copies, 'file-000001.txt')).mode & 0o777
  end

  def test_argument_errors_do_not_echo_values
    scan('--unknown=synthetic-invalid-option')
    assert_equal 2, @status.exitstatus
    assert_no_disclosure('synthetic-invalid-option')
    scan
    assert_equal 2, @status.exitstatus
  end

  def test_console_and_ruby_debug_never_disclose_parser_input
    path = write('invalid.yaml', "password: [synthetic-invalid-yaml\n")
    executable = File.expand_path('../bin/project-tools-secrets', __dir__)
    @out, @err, @status = Open3.capture3({ 'DEBUG' => 'true' }, Gem.ruby, '-d', executable, path)
    assert_equal 2, @status.exitstatus
    assert_includes @out, 'Execution: incomplete'
    assert_no_disclosure('synthetic-invalid-yaml')
    refute_includes @err, 'Psych::SyntaxError'
  end
end
