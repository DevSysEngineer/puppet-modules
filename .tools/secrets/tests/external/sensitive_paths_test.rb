# frozen_string_literal: true

require_relative 'helper'

# Exercise directory policies through the installed prepare and write commands.
class ExternalSensitivePathsTest < ExternalSecretsTestCase
  DATA_FILES = %w[data/direct.yaml data/team/deep/nested.yaml data/.hidden.yaml data/.team/note.yaml].freeze
  ALIASED_SOURCE = 'data/team/aliased.yaml'
  ALIAS_PATH = 'review/note.yaml'
  PUBLIC_FILE = 'data-public/example.yaml'
  SAMPLE = 'fictional paper windmill'
  NOTE = "\n# additional note\n"

  def setup
    super
    (DATA_FILES + [ALIASED_SOURCE]).each { |path| write("source/#{path}", "description: #{SAMPLE}\n") }
    write("source/#{PUBLIC_FILE}", "description: public example\n")
  end

  def test_trailing_double_star_protects_the_directory
    assert_directory_protection('data/**')
  end

  def test_explicit_recursive_file_pattern_protects_the_directory
    assert_directory_protection('data/**/*')
  end

  def assert_directory_protection(pattern)
    result = prepare_directory(pattern)
    assert_protected_copies(result.fetch('files'))
    session = result.fetch('session')
    assert_refused_write(session)
    assert_public_write(session)
  end

  def prepare_directory(pattern)
    write('policy.json', JSON.generate(files: DATA_FILES + [ALIASED_SOURCE, PUBLIC_FILE], sensitive_paths: [pattern],
                                       aliases: { ALIASED_SOURCE => ALIAS_PATH }))
    command('bundle', 'exec', 'project-tools-secrets', 'prepare', '--root', 'source',
            '--tree', 'analysis', '--policy', 'policy.json', '--state', 'state')
    assert_equal 1, @status.exitstatus, @errors
    result = JSON.parse(@output)
    assert result.fetch('complete')
    assert result.fetch('prepared')
    result
  end

  def assert_protected_copies(files)
    protected_paths = DATA_FILES + [ALIAS_PATH]
    writable = files.to_h { |record| record.fetch_values('file', 'writable') }
    assert_equal protected_paths.to_h { |path| [path, false] }.merge(PUBLIC_FILE => true), writable
    refute_path_exists File.join(@project, 'analysis', ALIASED_SOURCE)
    protected_paths.each do |path|
      copy = read("analysis/#{path}")
      refute_includes copy, SAMPLE
      assert_match(/REDACTED-[0-9a-f]{32}/, copy)
    end
    assert_equal read("source/#{PUBLIC_FILE}"), read("analysis/#{PUBLIC_FILE}")
  end

  def assert_refused_write(session)
    masked = read("analysis/#{ALIAS_PATH}")
    result = append_note(session, ALIAS_PATH)
    assert_equal 2, @status.exitstatus, @errors
    assert_equal 'refused', result.fetch('status')
    assert_equal ['write_unsupported'], result.fetch('errors')
    assert_equal "description: #{SAMPLE}\n", read("source/#{ALIASED_SOURCE}")
    write("analysis/#{ALIAS_PATH}", masked)
  end

  def assert_public_write(session)
    expected = read("source/#{PUBLIC_FILE}") + NOTE
    result = append_note(session, PUBLIC_FILE)
    assert_equal 0, @status.exitstatus, @errors
    assert_equal 'applied', result.fetch('status')
    assert_equal expected, read("source/#{PUBLIC_FILE}")
  end

  def append_note(session, path)
    write("analysis/#{path}", read("analysis/#{path}") + NOTE)
    write('changes.json', JSON.generate(write: [path]))
    command('bundle', 'exec', 'project-tools-secrets', 'write', '--state', 'state',
            '--session', session, '--changes', 'changes.json')
    JSON.parse(@output)
  end
end
