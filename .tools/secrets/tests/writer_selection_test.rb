# frozen_string_literal: true

require_relative 'session_helper'

# Unchanged selections retain syntax, marker and concurrent-edit checks.
class SecretsWriterSelectionTest < SecretsSessionTestCase
  def prepare_selection(source)
    @template = write('templates/script.sh', source)
    @ordinary = write('ordinary.txt', "before\n")
    prepare(['templates/script.sh', 'ordinary.txt'])
    edit('ordinary.txt', "after\n")
  end

  def unchanged_metadata(path)
    stat = File.stat(path)
    [stat.ino, stat.mtime, stat.ctime, *file_metadata(path)]
  end

  def test_unchanged_template_does_not_block_another_file
    source = "#!/bin/sh\n<% if true -%>\nprintf '%s\\n' before\n<% end -%>\n"
    prepare_selection(source)
    before = unchanged_metadata(@template)
    apply('write' => ['ordinary.txt'])
    assert_applied
    assert_source(@ordinary, "after\n")
    assert_source(@template, source)
    assert_equal before, unchanged_metadata(@template)
  end

  def test_unchanged_invalid_template_still_blocks_the_entire_write
    source = "<%= (1 +) %>\n"
    prepare_selection(source)
    apply('write' => ['ordinary.txt'])
    assert_includes @result['errors'], 'invalid_template'
    assert_source(@template, source)
    assert_source(@ordinary, "before\n")
  end

  def test_unchanged_template_source_conflict_still_blocks_write
    prepare_selection("<%= 'before' %>\n")
    File.write(@template, "<%= 'concurrent edit' %>\n")
    apply('write' => ['ordinary.txt'])
    assert_includes @result['errors'], 'source_conflict'
    assert_source(@template, "<%= 'concurrent edit' %>\n")
    assert_source(@ordinary, "before\n")
  end

  def test_markers_in_unchanged_templates_still_count_globally
    source = "<%= Sensitive('#{@value}') %>\n"
    prepare_selection(source)
    edit('ordinary.txt', "#{marker('templates/script.sh')}\n")
    apply('write' => ['ordinary.txt'])
    assert_includes @result['errors'], 'duplicate_marker'
    assert_source(@template, source)
    assert_source(@ordinary, "before\n")
  end
end
