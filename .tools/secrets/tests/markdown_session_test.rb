# frozen_string_literal: true

require_relative 'session_helper'

# The same bounded spans must survive preparation, restoration and controlled review.
class SecretsMarkdownSessionTest < SecretsSessionTestCase
  def test_fragment_markers_round_trip_with_crlf_unicode_and_ordinary_edits
    original = multiline_source
    path = write('example.md', original)
    prepare(['example.md'])
    assert_prepared_fragments
    edit('example.md', analysis('example.md').sub('Vóór.', 'Gewijzigd.'))
    apply('write' => ['example.md'])
    assert_applied
    assert_equal original.sub('Vóór.', 'Gewijzigd.'), File.read(path)
    assert_markdown_review
  end

  def multiline_source
    "Vóór.\r\n\r\nGebruik `Sensitive.new(join(['#{@value}'` hier.\r\n\r\n" \
      "~~~ruby\r\npassword = join([\r\n'#{@value}'\r\n~~~\r\n\r\nNa.\r\n"
  end

  def assert_prepared_fragments
    assert_equal 1, @code
    assert @result['complete']
    assert @result['files'].first['context_omitted']
    assert_private_analysis
    refute_includes analysis('example.md'), @value
    assert_equal 2, analysis('example.md').scan(ProjectTools::Secrets::Document::MARKER).length
  end

  def assert_private_analysis
    assert_equal 0o600, File.stat(File.join(@copies, 'example.md')).mode & 0o777
    assert_equal 0o700, File.stat(@copies).mode & 0o777
  end

  def assert_markdown_review
    call_session('diff', '--session', @session)
    assert_reviewed
    assert_includes @result['diff'], 'Gewijzigd.'
    refute_includes @result['diff'], @value
  end

  def test_precise_values_and_whole_fragments_share_marker_integrity
    original = "Before.\n\n`password = '#{@value}'` and `password = join(['#{@value}'`.\n"
    path = write('example.md', original)
    prepare(['example.md'])
    representation = analysis('example.md')
    assert_marker_rejections(path, original, representation)
    edit('example.md', representation.sub('Before.', 'After.'))
    apply('write' => ['example.md'])
    assert_applied
    assert_equal original.sub('Before.', 'After.'), File.read(path)
  end

  def assert_marker_rejections(path, original, representation)
    edit('example.md', representation.sub(marker('example.md'), ''))
    apply('write' => ['example.md'])
    assert_equal ['missing_marker'], @result['errors']
    assert_equal original, File.read(path)
    edit('example.md', "#{representation}\n#{marker('example.md')}")
    apply('write' => ['example.md'])
    assert_equal ['duplicate_marker'], @result['errors']
  end

  def test_incomplete_preparation_publishes_neither_partial_tree_nor_mapping
    write('good.md', "`password = '#{@value}'`\n")
    write('bad.md', "```\npassword = join(['#{@value}'\n")
    File.write(@policy, JSON.generate('files' => %w[good.md bad.md]))
    report = File.join(@directory, 'report.xml')
    call_session('prepare', '--root', @input, '--tree', @copies, '--policy', @policy, '--junit', report)
    assert_withheld(report)
  end

  def assert_withheld(report)
    assert_equal 2, @code
    refute @result['prepared']
    refute @result['complete']
    refute_path_exists @copies
    assert_empty Dir.glob(File.join(@state, '*.json'))
    refute_includes File.read(report), @value
  end

  def test_unregistered_markdown_value_is_rejected_before_writing
    original = "Before.\n\n`password = '#{@value}'`\n"
    path = write('example.md', original)
    prepare(['example.md'])
    edit('example.md', "#{analysis('example.md')}\n`password = 'synthetic-new-value'`\n")
    apply('write' => ['example.md'])
    assert_equal ['unregistered_value'], @result['errors']
    assert_equal original, File.read(path)
  end

  def test_changed_fence_cannot_restore_an_unbounded_candidate
    original = "```ruby\npassword = join(['#{@value}'\n```\n"
    path = write('example.md', original)
    prepare(['example.md'])
    edit('example.md', analysis('example.md').delete_suffix("```\n"))
    apply('write' => ['example.md'])
    assert_equal 2, @code
    refute @result['complete']
    assert_equal original, File.read(path)
  end
end
