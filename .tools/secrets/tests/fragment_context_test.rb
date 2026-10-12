# frozen_string_literal: true

require_relative 'session_helper'

# Every occurrence comes from prepare, including opaque multiline expressions.
class SecretsFragmentContextTest < SecretsSessionTestCase
  def fragment_change(source)
    path = write('settings.erb', source)
    File.chmod(0o640, path)
    @before_metadata = file_metadata(path)
    ordinary = write('ordinary.txt', "before\n")
    prepare(['settings.erb', 'ordinary.txt'])
    refute_includes analysis('settings.erb'), @value
    edit('settings.erb', yield(analysis('settings.erb')))
    edit('ordinary.txt', "after\n")
    apply('write' => ['settings.erb', 'ordinary.txt'])
    [path, ordinary]
  end

  def expression
    "<%= Sensitive('#{@value}') %>\n"
  end

  def assert_refused_sources(source, &block)
    path, ordinary = fragment_change(source, &block)
    assert_equal 'refused', @result['status']
    assert_includes @result['errors'], 'unsupported_marker_context'
    assert_source(path, source)
    assert_source(ordinary, "before\n")
  end

  def test_inline_condition_after_fragment_is_refused
    assert_refused_sources(expression) { |copy| copy.sub(' %>', ' if enabled %>') }
  end

  def test_inline_comment_after_fragment_is_refused
    assert_refused_sources(expression) { |copy| "#{copy.chomp} # ordinary comment\n" }
  end

  def test_enclosing_block_and_separate_comment_preserve_single_line_fragment
    source = expression
    path, ordinary = fragment_change(source) do |copy|
      "<% if enabled -%>\n<%# ordinary comment %>\n  #{copy}<% end -%>\n"
    end
    assert_applied
    expected = "<% if enabled -%>\n<%# ordinary comment %>\n  #{source}<% end -%>\n"
    assert_source(path, expected)
    assert_source(ordinary, "after\n")
    assert_equal @before_metadata, file_metadata(path)
  end

  def test_indented_multiline_fragment_in_enclosing_block_is_refused
    source = "<%= Sensitive(\n  '#{@value}'\n) %>\n"
    assert_refused_sources(source) { |copy| "<% if enabled %>\n  #{copy}<% end %>\n" }
  end

  def test_multiline_fragment_with_unchanged_indentation_can_be_enclosed
    source = "<%= Sensitive(\n  '#{@value}'\n) %>\n"
    path, = fragment_change(source) { |copy| "<% if enabled %>\n#{copy}<% end %>\n" }
    assert_applied
    assert_source(path, "<% if enabled %>\n#{source}<% end %>\n")
  end
end
