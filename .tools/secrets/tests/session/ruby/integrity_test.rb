# frozen_string_literal: true

require_relative 'test_helper'

# Existing marker authorization still governs destructive or contextual edits.
class SecretsRubyContainerIntegrityTest < SecretsRubyContainerTestCase
  def test_unregistered_literal_in_a_sensitive_container_is_refused
    copy = prepare_ruby([@value])
    edit('config.rb', copy.sub("]\n", ", 'unregistered']\n"))
    apply('write' => ['config.rb'])
    assert_equal ['unregistered_value'], @result['errors']
    assert_source(@path, @original)
  end

  def test_duplicate_member_marker_is_refused
    copy = prepare_ruby([@value])
    edit('config.rb', copy.sub("]\n", ", '#{marker('config.rb')}']\n"))
    apply('write' => ['config.rb'])
    assert_equal ['duplicate_marker'], @result['errors']
    assert_source(@path, @original)
  end

  def test_marker_cannot_become_part_of_a_larger_string
    copy = prepare_ruby([@value])
    edit('config.rb', copy.sub(marker('config.rb'), "prefix #{marker('config.rb')}"))
    apply('write' => ['config.rb'])
    assert_equal ['unsupported_marker_context'], @result['errors']
    assert_source(@path, @original)
  end

  def test_invalid_edited_ruby_does_not_replace_valid_source
    copy = prepare_ruby([@value])
    edit('config.rb', copy.sub("]\n", "\n"))
    apply('write' => ['config.rb'])
    assert_equal ['inspection_incomplete'], @result['errors']
    assert_source(@path, @original)
  end

  def test_missing_member_requires_explicit_removal
    copy = prepare_ruby([@value])
    id = marker_id('config.rb')
    edit('config.rb', copy.sub("'#{marker('config.rb')}'", ''))
    apply('write' => ['config.rb'])
    assert_equal ['missing_marker'], @result['errors']
    assert_source(@path, @original)
    apply('write' => ['config.rb'], 'remove_ids' => [id])
    assert_applied
    assert_source(@path, source([]))
  end

  def test_member_cannot_silently_move_to_another_assignment
    copy = prepare_ruby([@value])
    edit('config.rb', copy.sub('password', 'other'))
    apply('write' => ['config.rb'])
    assert_equal ['unintended_marker_move'], @result['errors']
    assert_source(@path, @original)
    apply('write' => ['config.rb'], 'move_ids' => { marker_id('config.rb') => 'config.rb' })
    assert_applied
    assert_source(@path, @original.sub('password', 'other'))
  end

  def test_string_member_can_explicitly_move_to_a_standalone_ruby_literal
    copy = prepare_ruby([@value])
    edit('config.rb', copy.sub(/\[(.*)\]/, '\\1'))
    apply('write' => ['config.rb'], 'move_ids' => { marker_id('config.rb') => 'config.rb' })
    assert_applied
    assert_source(@path, source(@value))
  end

  def test_string_member_can_explicitly_move_to_yaml
    path = write('config.rb', source([@value]))
    target = write('config.yaml', "ordinary: before\n")
    prepare(%w[config.rb config.yaml])
    id = marker_id('config.rb')
    edit('config.yaml', "item: '#{marker('config.rb')}'\n")
    edit('config.rb', source([]))
    apply('write' => %w[config.rb config.yaml], 'move_ids' => { id => 'config.yaml' })
    assert_applied
    assert_source(path, source([]))
    assert_source(target, "item: #{@value.to_json}\n")
  end

  def test_non_string_member_cannot_silently_change_type_outside_a_container
    copy = prepare_ruby([42])
    edit('config.rb', copy.sub(/\[(.*)\]/, '\\1'))
    apply('write' => ['config.rb'], 'move_ids' => { marker_id('config.rb') => 'config.rb' })
    assert_equal ['unsupported_marker_context'], @result['errors']
    assert_source(@path, @original)
  end
end
