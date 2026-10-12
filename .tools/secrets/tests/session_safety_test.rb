# frozen_string_literal: true

require_relative 'session_helper'

# Failed preparation and changed context cannot authorize source writes.
class SecretsSessionSafetyTest < SecretsSessionTestCase
  def test_a_source_named_like_an_action_retains_the_standalone_scan_contract
    write('prepare', 'ordinary')
    output = StringIO.new
    code = Dir.chdir(@input) { ProjectTools::Secrets.run(['prepare', '--json'], output: output) }
    assert_equal 0, code
    assert_equal 'no_findings', JSON.parse(output.string)['status']
  end

  def test_same_basename_and_supported_extensions_retain_their_paths
    files = %w[a/init.pp b/init.pp config.erb setup.sh data/common.yaml]
    files.each { |path| write(path, "# ordinary\n") }
    prepare(files)
    assert_equal files.sort, @result['files'].map { |record| record['file'] }.sort
    assert @result['files'].find { |record| record['file'].end_with?('.pp') }['coverage'].include?('puppet_parser')
  end

  def test_prepare_report_failure_withdraws_both_tree_and_mapping
    write('a.txt', 'ordinary')
    File.write(@policy, JSON.generate('files' => ['a.txt']))
    call_session('prepare', '--root', @input, '--tree', @copies, '--policy', @policy, '--junit', @policy)
    refute @result['prepared']
    refute_path_exists @copies
    assert_empty Dir.glob(File.join(@state, '*.json'))
    assert_equal 2, @code
  end

  def test_new_lookup_context_detects_unregistered_values_in_unchanged_files
    write('a.yaml', "unusual: '#{@value}'\n")
    write('options.yaml', "{}\n")
    prepare(['a.yaml'], context: ['options.yaml'])
    edit('options.yaml', "lookup_options:\n  unusual:\n    convert_to: Sensitive\n")
    apply('write' => ['options.yaml'])
    assert_equal ['unregistered_value'], @result['errors']
  end

  def test_unknown_state_version_and_damaged_markers_are_refused
    write('a.yaml', "password: '#{@value}'\n")
    prepare(['a.yaml'])
    edit('a.yaml', analysis('a.yaml').sub('REDACTED-', 'REDACTED-0'))
    apply('write' => ['a.yaml'])
    refute @result['complete']
    store = ProjectTools::Secrets::Store.new(@state)
    store.save(@session, store.load(@session).merge('format' => 999))
    apply('write' => ['a.yaml'])
    assert_equal ['incompatible_state'], @result['errors']
  end

  def test_preparation_uses_only_explicit_files_and_context
    write('a.txt', 'before')
    write('AGENTS.md', 'unselected instructions')
    prepare(['a.txt'])
    assert_equal(['a.txt'], @result['files'].map { |file| file['file'] })
    write('AGENTS.md', 'changed unselected instructions')
    edit('a.txt', 'after')
    apply('write' => ['a.txt'])
    assert_applied
  end

  def test_explicit_instruction_context_keeps_source_conflict_protection
    write('a.txt', 'before')
    write('AGENTS.md', 'selected instructions')
    prepare(['a.txt'], context: ['AGENTS.md'])
    write('AGENTS.md', 'changed selected instructions')
    edit('a.txt', 'after')
    apply('write' => ['a.txt'])
    assert_equal ['source_conflict'], @result['errors']
  end

  def test_generated_fixture_restores_without_a_publication_registry
    write('a.txt', 'ordinary')
    prepare(['a.txt'], destinations: { 'extra.yaml' => '0600' }, fixture_paths: ['extra.yaml'])
    call_session('fixture', '--session', @session, '--to', 'extra.yaml')
    edit('extra.yaml', JSON.generate('password' => @result.fetch('marker')))
    apply('add' => ['extra.yaml'])
    assert_applied
    assert_generated_fixture(File.join(@input, 'extra.yaml'))
  end

  def assert_generated_fixture(path)
    assert_match(/\Asynthetic-[0-9a-f]{32}\z/, Psych.safe_load_file(path)['password'])
    documents = ProjectTools::Secrets::Scanner.documents({ 'extra.yaml' => File.read(path) })
    assert(documents.first.findings.any? { |finding| finding[:kind] == 'value' })
  end

  def test_classified_file_is_opaque_and_cannot_be_rewritten
    write('private.yaml', "unusual: '#{@value}'\n")
    prepare(['private.yaml'], sensitive_paths: ['private.yaml'])
    refute @result['files'].first['writable']
    refute_includes analysis('private.yaml'), @value
    edit('private.yaml', "#{analysis('private.yaml')}\n# changed\n")
    apply('write' => ['private.yaml'])
    assert_equal ['write_unsupported'], @result['errors']
  end
end
