# frozen_string_literal: true

require_relative 'test_helper'

# The real compiler must perform lookup, parameter binding, conversion and merging.
class CatalogHieraLookupTest < Minitest::Test
  include CatalogHieraSupport

  SYNTHETIC_VALUE = 'synthetic-catalog-test-only'

  def test_explicit_and_automatic_lookup_convert_yaml_strings_to_sensitive
    prepare_sensitive_module
    assert_equal 0, compile_modules, @console.string
    assert_counts(1, 0, 0)
    refute_includes @console.string, SYNTHETIC_VALUE
    refute_includes File.read(File.join(@root, 'reports', 'catalog.xml')), SYNTHETIC_VALUE
  end

  def prepare_sensitive_module
    directory = module_inputs('catalog_fixture', code: hiera_input('sensitive_scenario.pp'))
    File.write(File.join(directory, 'manifests', 'init.pp'), hiera_input('sensitive_class.pp'))
    key = 'catalog_fixture::password'
    fixture('catalog_fixture', { 'lookup_options' => { key => { 'convert_to' => 'Sensitive' } },
                                 key => SYNTHETIC_VALUE })
  end

  def test_priority_merge_module_data_default_hierarchy_and_parameter_defaults_remain_native
    directory = module_inputs('sample', code: hiera_input('priority_scenario.pp'))
    File.write(File.join(directory, 'manifests', 'init.pp'), hiera_input('priority_class.pp'))
    priority_fixture
    module_data(directory)
    assert_equal 0, compile_modules, @console.string
    assert_counts(1, 0, 0)
  end

  def priority_fixture
    config = { 'version' => 5, 'hierarchy' => [{ 'name' => 'Facts', 'path' => '%{facts.os.name}.yaml' },
                                               { 'name' => 'Common', 'path' => 'common.yaml' }] }
    hiera = fixture('sample', { 'sample::priority' => 'fixture-low', 'sample::items' => %w[shared low] },
                    config: config)
    high = { 'lookup_options' => { 'sample::items' => { 'merge' => 'unique' } },
             'sample::priority' => 'fixture-high', 'sample::items' => %w[high shared] }
    File.write(File.join(hiera, 'data', 'Debian.yaml'), YAML.dump(high))
  end

  def module_data(directory)
    FileUtils.mkdir_p(File.join(directory, 'data'))
    config = { 'version' => 5, 'hierarchy' => [{ 'name' => 'Module', 'path' => 'common.yaml' }],
               'default_hierarchy' => [{ 'name' => 'Defaults', 'path' => 'defaults.yaml' }] }
    File.write(File.join(directory, 'hiera.yaml'), YAML.dump(config))
    File.write(File.join(directory, 'data', 'common.yaml'), YAML.dump('sample::module_value' => 'module-data',
                                                                      'sample::priority' => 'module-low'))
    File.write(File.join(directory, 'data', 'defaults.yaml'), YAML.dump('sample::fallback' => 'module-default'))
  end

  def prepare_lookup_failures
    module_inputs('missing', code: "lookup('required', String)")
    fixture('missing')
    module_inputs('wrong_type', code: "lookup('typed', Integer)")
    fixture('wrong_type', { 'typed' => 'synthetic-string' })
    module_inputs('valid', code: "lookup('optional', String, 'first', 'valid-default')")
    fixture('valid', config: { 'version' => 5,
                               'hierarchy' => [{ 'name' => 'Optional', 'path' => '%{facts.os.name}.yaml' }] })
  end

  def test_local_paths_and_globs_keep_relative_datadirs
    module_inputs('sample', code: <<~PUPPET)
      if lookup('first', String) != 'paths' { fail('wrong relative paths') }
      if lookup('second', String) != 'glob' { fail('wrong relative glob') }
    PUPPET
    local_path_fixture
    assert_equal 0, compile_modules, @console.string
    assert_counts(1, 0, 0)
  end

  def local_path_fixture
    config = { 'version' => 5,
               'hierarchy' => [{ 'name' => 'Data', 'datadir' => 'data/nested', 'paths' => %w[missing.yaml first.yaml] },
                               { 'name' => 'Glob', 'glob' => 'extra/*.yaml' }] }
    directory = fixture('sample', config: config)
    %w[nested extra].each { |name| FileUtils.mkdir_p(File.join(directory, 'data', name)) }
    File.write(File.join(directory, 'data', 'nested', 'first.yaml'), YAML.dump('first' => 'paths'))
    File.write(File.join(directory, 'data', 'extra', 'second.yaml'), YAML.dump('second' => 'glob'))
  end

  def test_missing_required_lookup_and_invalid_type_are_failures_but_optional_sources_are_allowed
    prepare_lookup_failures
    assert_equal 1, compile_modules
    assert_counts(3, 2, 0)
    assert_includes @console.string, 'required'
    assert_includes @console.string, 'Integer'
    valid = report_suite.get_elements('testcase').find { |item| item.attributes['name'] == 'valid/default [debian]' }
    assert_nil valid.elements['failure']
  end
end
