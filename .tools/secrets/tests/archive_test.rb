# frozen_string_literal: true

require_relative 'test_helper'

# Compressed payloads are inspected locally with bounded expansion and no extraction.
class SecretsArchiveTest < SecretsTest
  def tar(entries)
    buffer = StringIO.new(''.b)
    Gem::Package::TarWriter.new(buffer) do |writer|
      entries.each { |name, text| writer.add_file_simple(name, 0o600, text.bytesize) { |file| file.write(text) } }
    end
    buffer.string
  end

  def gzip(text)
    buffer = StringIO.new(''.b)
    Zlib::GzipWriter.wrap(buffer) { |writer| writer.write(text) }
    buffer.string
  end

  def test_nested_archive_license_is_masked_without_extra_top_level_records
    source = gzip(tar('settings.yaml' => "license_key: synthetic-archive-license\n"))
    path = write('payload.tar.gz', source)
    scan('--redact', @copies, path)
    assert_complete_copy
    assert_archive_copy
    assert_equal source, File.binread(path)
  end

  def assert_archive_copy
    assert_equal 1, @report['files'].size
    assert_equal 'archive', @report['files'].first['coverage']
    assert_masked('synthetic-archive-license')
    assert_private_copies
  end

  def assert_private_copies
    assert_equal 0o700, File.stat(@copies).mode & 0o777
    assert_equal 0o600, File.stat(File.join(@copies, @report['files'].first['copy'])).mode & 0o777
  end

  def test_hiera_selectors_apply_across_archive_members
    source = tar('options.yaml' => "lookup_options:\n  example::opaque:\n    convert_to: Sensitive\n",
                 'data.yaml' => "example::opaque: synthetic-archive-conversion\n")
    path = write('payload.tar', source)
    scan('--redact', @copies, path)
    assert_complete_copy
    assert_masked('synthetic-archive-conversion')
  end

  def test_unsafe_member_names_and_links_are_rejected
    sources = [tar('../escape.txt' => 'ordinary'), tar('/absolute.txt' => 'ordinary')]
    buffer = StringIO.new(''.b)
    Gem::Package::TarWriter.new(buffer) { |writer| writer.add_symlink('link', '../outside', 0o777) }
    sources << buffer.string
    sources.each do |source|
      path = write('unsafe.tar', source)
      scan('--redact', @copies, path)
      assert_equal 2, @status.exitstatus
      refute_path_exists @copies
    end
  end

  def test_limits_truncation_and_trailing_payload_fail_closed
    nested = 'ordinary'
    4.times { nested = tar('nested.tar' => nested) }
    sources = [nested, tar('a.txt' => 'ordinary')[0...-1024],
               "#{tar('a.txt' => 'ordinary')}synthetic-trailing-value"]
    assert_incomplete_archives(sources)
  end

  def assert_incomplete_archives(sources)
    sources.each do |source|
      path = write('unsafe.tar', source)
      scan('--redact', @copies, path)
      assert_equal 2, @status.exitstatus
      refute_path_exists @copies
      assert_no_disclosure('synthetic-trailing-value')
    end
  end

  def test_expansion_and_member_count_are_bounded
    path = write('large.gz', gzip('x' * (ProjectTools::Secrets::Scanner::MAX_BYTES + 1)))
    scan('--redact', @copies, path)
    assert_equal 2, @status.exitstatus
    refute_path_exists @copies
    entries = (0..ProjectTools::Secrets::Archive::MAX_MEMBERS).to_h { |index| ["member-#{index}", 'x'] }
    path = write('many.tar', tar(entries))
    scan('--redact', @copies, path)
    assert_equal 2, @status.exitstatus
    refute_path_exists @copies
  end
end
