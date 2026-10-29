# frozen_string_literal: true

require_relative 'test_helper'

# Ensure incomplete inputs never become a successful scan or silently select a later copy.
class DependencyInputTest < Minitest::Test
  include DependencyTestSupport

  def test_broken_first_metadata_is_not_replaced_by_valid_shadow
    write_module('library', version: '2.0.0', base: @second)
    FileUtils.mkdir_p(File.join(@first, 'library'))
    File.write(File.join(@first, 'library/metadata.json'), '{"private": "synthetic-secret",')
    write_root([dependency])
    scan(2)
    assert_includes error_types, 'metadata_error'
    refute_includes @output + @errors + File.read(@report), 'synthetic-secret'
    assert_includes @errors, 'first modules/library/metadata.json'
  end

  def test_broken_shadow_is_not_loaded
    write_module('library', version: '2.0.0')
    shadow = write_module('library', base: @second)
    File.write(File.join(shadow, 'metadata.json'), 'broken')
    write_root([dependency])
    scan(0)
  end

  def test_empty_wrong_type_and_incomplete_module_metadata
    directory = write_module('library')
    ['', '{}', '[]', '42', '{"name":"example-library"}', '{"dependencies": false}'].each do |content|
      File.write(File.join(directory, 'metadata.json'), content)
      scan(2)
      refute_empty junit_errors
      refute_includes @output, 'Declared dependencies satisfy'
    end
  end

  def test_nonsemantic_selected_version_is_not_healthy
    write_module('library', version: 'not-semver')
    write_module('consumer', dependencies: [dependency])
    scan(2)
    assert_includes error_types, 'metadata_error'
    assert_equal 'non_semantic_version', junit_failures.first.attributes['type']
  end

  def test_only_directories_without_metadata_are_an_empty_scan
    FileUtils.mkdir_p(File.join(@first, 'examples'))
    scan(2)
    assert_equal(['empty_scan'], error_types)
    assert_includes @output, 'Module metadata assessed: 0.'
  end

  def test_root_conflicts_are_separate_from_module_conflicts
    write_module('library', version: '4.0.0')
    write_root([dependency, dependency('example-missing')])
    scan(1)
    assert_equal 2, junit_failures.length
    assert(@suite.get_elements('testcase').all? { |node| node.attributes['name'].start_with?('root:') })
  end

  def test_invalid_root_inputs_and_missing_root
    write_module('library')
    ['{', '[]', '{}', '{"dependencies":{}}', '{"dependencies":[42]}',
     '{"dependencies":[{"name":"example-library"}]}',
     '{"dependencies":[{"name":"example-library","version_requirement":""}]}'].each do |content|
      File.write(File.join(@project, 'metadata.json'), content)
      scan(2)
      assert_equal(['metadata_error'], error_types)
    end
    File.unlink(File.join(@project, 'metadata.json'))
    scan(2)
  end

  def test_modulepath_input_contract
    [nil, '', 'relative', "#{@first}:", ":#{@first}", File.join(@project, 'absent')].each do |value|
      @env['PROJECT_TOOLS_MODULEPATH'] = value
      scan(2)
      assert_equal(['configuration_error'], error_types)
    end
  end

  def test_unreadable_module_metadata_cannot_pass
    path = File.join(write_module('library'), 'metadata.json')
    File.chmod(0o000, path)
    scan(2)
    assert_includes error_types, 'metadata_error'
  ensure
    File.chmod(0o600, path) if path && File.exist?(path)
  end

  def test_consumer_root_is_independent_of_imported_root_and_lint_configuration
    write_module('library', version: '2.0.0')
    File.write(File.join(@first, 'metadata.json'), JSON.generate({ dependencies: [dependency('example-missing')] }))
    write_root([dependency('example/library')])
    scan(0)
    refute_path_exists File.join(@project, 'VERSION')
  end
end
