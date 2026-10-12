# frozen_string_literal: true

require_relative 'session_helper'

# Marker restoration follows syntax and decoded values, independently of old line numbers.
class SecretsSessionSyntaxTest < SecretsSessionTestCase
  def test_puppet_signature_inside_a_literal_retains_parseable_analysis
    write('a.pp', "$ordinary = 'ghp_#{'a' * 36}'\n")
    prepare(['a.pp'])
    refute_includes analysis('a.pp'), 'ghp_'
    documents = ProjectTools::Secrets::Scanner.documents({ 'a.pp' => analysis('a.pp') })
    assert documents.all?(&:complete?)
  end

  def test_literal_script_block_keeps_ordinary_code_and_restores_the_embedded_value
    original = "script: |\n  echo before\n  PASSWORD='#{@value}'\n  echo after\n"
    path = write('a.yaml', original)
    prepare(['a.yaml'])
    assert_includes analysis('a.yaml'), 'echo before'
    refute_includes analysis('a.yaml'), @value
    edit('a.yaml', analysis('a.yaml').sub('echo after', 'echo changed'))
    apply('write' => ['a.yaml'])
    assert_applied
    assert_equal original.sub('echo after', 'echo changed'), File.read(path)
  end

  def test_sensitive_crlf_source_without_final_newline_is_not_rewritten
    original = "password: '#{@value}'\r\nordinary: preserved"
    path = write('a.yaml', original)
    inode = File.stat(path).ino
    prepare(['a.yaml'])
    apply('write' => ['a.yaml'])
    assert_applied
    assert_equal original, File.binread(path)
    assert_equal inode, File.stat(path).ino
  end

  def test_multiple_occurrences_on_one_line_survive_a_rewrite
    original = "{password: '#{@value}', api_key: '#{@value}', ordinary: before}\n"
    path = write('a.yaml', original)
    prepare(['a.yaml'])
    edit('a.yaml', analysis('a.yaml').sub('before', 'after'))
    apply('write' => ['a.yaml'])
    assert_applied
    assert_equal original.sub('before', 'after'), File.read(path)
  end

  def test_unknown_yaml_scalar_type_cannot_silently_become_a_string
    write('a.yaml', "password: 12345\n")
    prepare(['a.yaml'])
    edit('a.yaml', "outer:\n  #{analysis('a.yaml')}")
    apply('write' => ['a.yaml'], 'move_ids' => { marker_id('a.yaml') => 'a.yaml' })
    assert_equal ['unsupported_marker_context'], @result['errors']
  end

  def test_explicit_path_alias_also_masks_literal_references
    write('data/person.yaml', "ordinary: before\n")
    path = write('references.yaml', "input: data/person.yaml\nordinary: before\n")
    prepare(%w[data/person.yaml references.yaml], aliases: { 'data/person.yaml' => 'data/record.yaml' })
    refute_includes analysis('references.yaml'), 'person'
    edit('references.yaml', analysis('references.yaml').sub('before', 'after'))
    apply('write' => ['references.yaml'])
    assert_applied
    assert_includes File.read(path), 'data/person.yaml'
  end
end
