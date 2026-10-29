# frozen_string_literal: true

require_relative 'test_helper'

# Containers remain editable while original values retain their bytes and types.
class SecretsRubyContainersTest < SecretsRubyContainerTestCase
  def test_sensitive_array_remains_an_array_and_accepts_a_registered_element
    copy = prepare_ruby([@value, "#{@value}-second"])
    assert_equal 2, copy.scan(ProjectTools::Secrets::Document::MARKER).length
    addition = "#{@value}-added"
    fresh = register_value('config.rb', addition)
    edit('config.rb', copy.sub("]\n", ", '#{fresh}']\n"))
    apply('write' => ['config.rb'])
    assert_applied
    assert_source(@path, @original.sub("]\n", ", '#{addition}']\n"))
  end

  def test_nested_containers_and_scalar_types_restore_exactly
    values = [@value, { account: ['private-name', { 42 => true, nil => false }] }, -12, 1.25, :symbol]
    copy = prepare_ruby(values)
    refute_includes copy, 'private-name'
    refute_includes copy, 'account'
    edit('config.rb', copy.sub(':before', ':after'))
    apply('write' => ['config.rb'])
    assert_applied
    assert_source(@path, @original.sub(':before', ':after'))
  end

  def test_public_element_can_be_inserted_before_a_protected_array_member
    @value = "ghp_#{'a' * 36}"
    copy = prepare_ruby([@value], name: 'items')
    edit('config.rb', copy.sub('[', "['public', "))
    apply('write' => ['config.rb'])
    assert_applied
    assert_source(@path, source(['public', @value], name: 'items').sub('"public"', "'public'"))
  end

  def test_rakefile_keeps_parseable_task_arrays
    task_name = 'test:secrets'
    body = "TASKS = #{{ task_name => [@value, 'checks/*.rb'] }.inspect}\nordinary = :before\n"
    path = write('Rakefile', body)
    prepare(['Rakefile'])
    copy = analysis('Rakefile')
    assert Ripper.sexp(copy), 'Prepared Rakefile must parse'
    edit('Rakefile', copy.sub(':before', ':after'))
    apply('write' => ['Rakefile'])
    assert_applied
    assert_source(path, body.sub(':before', ':after'))
  end

  def test_ruby_source_is_never_executed
    body = "#{source([@value])}raise 'source must never execute'\n"
    path = write('config.rb', body)
    prepare(['config.rb'])
    edit('config.rb', analysis('config.rb').sub(':before', ':after'))
    apply('write' => ['config.rb'])
    assert_applied
    assert_source(path, body.sub(':before', ':after'))
  end

  def test_empty_array_accepts_a_registered_value
    copy = prepare_ruby([])
    fresh = register_value('config.rb', @value)
    edit('config.rb', copy.sub('[]', "['#{fresh}']"))
    apply('write' => ['config.rb'])
    assert_applied
    assert_source(@path, source([@value]).tr('"', "'"))
  end

  def test_nested_hash_accepts_a_registered_pair
    copy = prepare_ruby([{ account: @value }])
    key = register_value('config.rb', 'extra')
    value = register_value('config.rb', 'registered')
    edit('config.rb', copy.sub('}', ", '#{key}' => '#{value}'}"))
    apply('write' => ['config.rb'])
    assert_applied
    assert_source(@path, @original.sub('}', ", 'extra' => 'registered'}"))
  end

  def test_cloned_member_can_be_inserted_before_the_original
    copy = prepare_ruby([@value])
    call_session('clone', '--session', @session, '--id', marker_id('config.rb'), '--to', 'config.rb')
    edit('config.rb', copy.sub('[', "['#{@result.fetch('marker')}', "))
    apply('write' => ['config.rb'])
    assert_applied
    assert_source(@path, source([@value, @value]))
  end

  def test_reordered_members_can_be_formatted_on_separate_lines
    values = [@value, "#{@value}-second"]
    copy = prepare_ruby(values)
    reordered = copy.scan(/'[^']*'/).reverse.join(",\n  ")
    edit('config.rb', copy.sub(/\[.*\]/, "[\n  #{reordered}\n]"))
    apply('write' => ['config.rb'])
    assert_applied
    expected = source(values.reverse).sub('[', "[\n  ").sub(', ', ",\n  ").sub("]\n", "\n]\n")
    assert_source(@path, expected)
  end
end
