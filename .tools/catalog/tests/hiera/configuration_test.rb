# frozen_string_literal: true

require_relative 'test_helper'

# Invalid fixture input must be visible even when the manifest performs no lookup.
class CatalogHieraConfigurationTest < Minitest::Test
  include CatalogHieraSupport

  def test_missing_empty_and_invalid_configurations_are_errors_and_keep_independent_success
    invalid_configurations
    module_inputs('valid')
    assert_equal 1, compile_modules
    assert_counts(8, 0, 7)
    assert_includes @console.string, 'hiera.yaml'
    assert_independent_success
  end

  def assert_independent_success
    last = report_suite.get_elements('testcase').last
    assert_equal 'valid/default [debian]', last.attributes['name']
    assert_nil last.elements['error']
  end

  def invalid_configurations
    cases = { 'missing' => nil, 'empty' => '', 'scalar' => 'synthetic scalar', 'malformed' => 'version: [',
              'legacy' => "version: 3\nhierarchy: []\n", 'implicit' => "version: 5\n",
              'invalid' => "version: 5\nhierarchy: wrong\n" }
    cases.each do |name, config|
      module_inputs(name)
      path = File.join(fixture(name), 'hiera.yaml')
      config ? File.write(path, config) : File.unlink(path)
    end
  end

  def test_absolute_traversing_uri_and_external_backend_configurations_are_errors
    unsupported_entries.each_with_index do |entry, index|
      name = "invalid_#{index}"
      module_inputs(name)
      fixture(name, config: { 'version' => 5, 'hierarchy' => [entry.merge('name' => 'Invalid')] })
    end
    module_inputs('valid')
    assert_equal 1, compile_modules
    assert_counts(11, 0, 10)
    assert_includes @console.string, 'fixture'
  end

  def unsupported_entries
    [{ 'path' => '/outside.yaml' }, { 'path' => '../../outside.yaml' },
     { 'uri' => 'https://example.org/synthetic.yaml' }, { 'path' => 'common.yaml', 'data_hash' => 'json_data' },
     { 'path' => 'common.yaml', 'lookup_key' => 'custom' }, { 'glob' => '**/../../outside.yaml' },
     { 'path' => "%{lookup('outside')}" }, { 'path' => 'common.yaml', 'datadir' => '/outside' },
     { 'path' => 7 }, { 'path' => 'common.yaml', 'unsupported' => 'synthetic-option' }]
  end

  def test_fixture_symlinks_are_errors_but_module_symlinks_remain_supported
    %w[config data directory broken].each { |name| symlink_fixture(name) }
    links = module_link
    assert_equal 1, compile_modules
    assert_counts(5, 0, 4)
    assert_includes @console.string, 'must not be symlinks'
    runner = ProjectTools::Catalog.new(modulepath: links, console: @console)
    assert_equal 0, runner.run, @console.string
  end

  def symlink_fixture(name)
    module_inputs(name)
    directory = fixture(name)
    target = name == 'config' ? File.join(directory, 'hiera.yaml') : File.join(directory, 'data', 'linked.yaml')
    File.unlink(target) if name == 'config'
    if name == 'directory'
      FileUtils.remove_entry(directory)
      target = directory
    end
    File.symlink(name == 'broken' ? 'missing.yaml' : @facts, target)
  end

  def module_link
    actual = module_inputs('valid', code: "lookup('selected', String)")
    fixture('valid', { 'selected' => 'synthetic-value' })
    links = File.join(@root, 'links')
    FileUtils.mkdir_p(links)
    File.symlink(actual, File.join(links, 'valid'))
    links
  end

  def test_interpolated_path_escape_is_a_scenario_error_without_lookup
    directory = module_inputs('invalid')
    fixture('invalid', config: { 'version' => 5,
                                 'hierarchy' => [{ 'name' => 'Facts', 'path' => '%{facts.location}' }] })
    File.write(File.join(directory, 'tests', 'facts', 'debian.json'), JSON.generate('location' => '../../outside.yaml'))
    module_inputs('valid')
    assert_equal 1, compile_modules
    assert_counts(2, 0, 1)
    assert_includes report_suite.elements['testcase/error'].text, 'escapes tests/hiera/'
    assert_includes @console.string, 'invalid/default [debian]'
  end
end
