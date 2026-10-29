# frozen_string_literal: true

require_relative '../../session_helper'

# Preparation must withhold invalid generated source before publishing a tree or mapping.
class SecretsRubyPreparationTest < SecretsSessionTestCase
  def round_trip(body)
    path = write('config.rb', body)
    prepare(['config.rb'])
    copy = analysis('config.rb')
    assert Ripper.sexp(copy), 'Prepared Ruby must parse'
    refute_includes copy, @value
    edit('config.rb', copy.sub(':before', ':after'))
    apply('write' => ['config.rb'])
    assert_applied
    assert_source(path, body.sub(':before', ':after').b)
    copy
  end

  def test_multiline_containers_keep_unicode_offsets_and_scalar_types
    name = 'password'
    body = "label = 'café'; #{name} = [\n  #{@value.inspect},\n  { account: [nil, +12, -1.25, :label] },\n]\n"
    copy = round_trip("#{body}ordinary = :before\n")
    assert_includes copy, "label = 'café'"
    refute_includes copy, 'account'
  end

  def test_dynamic_container_stays_opaque_and_restores_without_execution
    name = 'password'
    body = "#{name} = [#{@value.inspect}, missing_method]\nordinary = :before\n"
    copy = round_trip(body)
    refute_includes copy, 'missing_method'
    assert_equal 1, copy.scan(ProjectTools::Secrets::Document::MARKER).length
  end

  def test_comment_inside_a_sensitive_container_is_not_released
    name = 'password'
    body = "#{name} = [\n  #{@value.inspect}, # private annotation\n]\nordinary = :before\n"
    copy = round_trip(body)
    refute_includes copy, 'private annotation'
  end

  def test_reserved_marker_pattern_in_a_regexp_stays_parseable
    prefix = 'REDACTED'
    pattern = "/\\[#{prefix}-[0-9a-f]{32}\\]/"
    copy = round_trip("pattern = #{pattern}\nordinary = :before\n")
    assert_equal 1, copy.scan(ProjectTools::Secrets::Document::MARKER).length
  end

  def with_invalid_mask
    type = ProjectTools::Secrets::Analysis
    original = type.instance_method(:mask)
    type.define_method(:mask) do |masked, *args|
      original.bind_call(self, masked, *args)
      masked << "\n)\n"
    end
    yield
  ensure
    type.define_method(:mask, original)
  end

  def prepare_invalid_copy
    name = 'password'
    @original = "#{name} = #{@value.inspect}\n"
    @path = write('config.rb', @original)
    File.write(@policy, JSON.generate('files' => ['config.rb']))
    @report_path = File.join(@directory, 'report.xml')
    with_invalid_mask do
      call_session('prepare', '--root', @input, '--tree', @copies, '--policy', @policy, '--junit', @report_path)
    end
  end

  def test_invalid_masked_ruby_is_refused_before_publication
    prepare_invalid_copy
    assert_equal 2, @code
    assert_equal ['inspection_incomplete'], @result['errors']
    refute @result['complete']
    refute @result['prepared']
    refute_path_exists @copies
    assert_empty Dir.glob(File.join(@state, '**', '*.json'))
    refute_includes File.read(@report_path), @value
    assert_source(@path, @original)
  end

  def test_invalid_masking_keeps_values_out_of_both_process_streams
    streams = capture_io { prepare_invalid_copy }
    streams.each { |stream| refute_includes stream, @value }
    assert_equal ['inspection_incomplete'], @result['errors']
  end
end
