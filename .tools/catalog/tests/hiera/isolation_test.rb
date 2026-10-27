# frozen_string_literal: true

require_relative 'test_helper'

# Fixture ownership and worker lifetime must isolate values across modules and scenarios.
class CatalogHieraIsolationTest < Minitest::Test
  include CatalogHieraSupport

  def test_each_module_uses_its_own_data_and_later_scenarios_do_not_retain_lookup_caches
    %w[alpha beta].each do |name|
      module_inputs(name, code: "if lookup('shared', String) != '#{name}' { fail('fixture leaked') }")
      fixture(name, { 'shared' => name })
    end
    module_inputs('later', code: <<~PUPPET)
      if lookup('shared', String, 'first', 'clean') != 'clean' { fail('cached fixture leaked') }
    PUPPET
    FileUtils.cp(@facts, File.join(@root, 'alpha', 'tests', 'facts', 'second.json'))
    assert_equal 0, compile_modules, @console.string
    assert_counts(4, 0, 0)
  end

  def test_modulepath_selects_code_and_fixtures_together_without_merging_dependencies
    paths = overlapping_modules
    assert_equal 0, run_modulepaths(paths), @console.string
    FileUtils.remove_entry(File.join(paths.first, 'sample', 'tests', 'hiera'))
    assert_equal 1, run_modulepaths(paths), 'A shadowed fixture must not fill missing data in the selected module.'
  end

  def run_modulepaths(paths)
    ProjectTools::Catalog.new(modulepath: paths.join(File::PATH_SEPARATOR), console: @console).run
  end

  def overlapping_modules
    first = File.join(@root, 'first')
    second = File.join(@root, 'second')
    directory = module_inputs('sample', base: first, code: <<~PUPPET)
      include sample
      if lookup('selected', String) != 'first' { fail('wrong fixture') }
      if lookup('dependency_only', String, 'first', 'absent') != 'absent' { fail('dependency fixture merged') }
    PUPPET
    File.write(File.join(directory, 'manifests', 'init.pp'), 'class sample {}')
    precedence_fixtures(first, second)
    [first, second]
  end

  def precedence_fixtures(first, second)
    module_inputs('sample', base: second, code: "fail('shadowed scenario')")
    File.write(File.join(second, 'sample', 'manifests', 'init.pp'), "class sample { fail('shadowed code') }")
    fixture('sample', { 'selected' => 'first' }, base: first)
    fixture('sample', { 'selected' => 'second', 'dependency_only' => 'unwanted' }, base: second)
    module_inputs('dependency', base: second)
    fixture('dependency', { 'dependency_only' => 'unwanted' }, base: second)
  end

  def test_foreign_global_and_environment_data_are_ignored_and_temporary_files_are_removed
    target = prepare_isolation_module
    with_foreign_hierarchies do
      assert_equal 0, compile_modules, @console.string
      assert_path_exists File.join(@root, 'foreign-settings-used')
      refute_path_exists File.read(target)
      File.write(File.join(@root, 'sample', 'tests', 'manifests', 'default.pp'), hiera_input('isolation_failure.pp'))
      assert_equal 1, compile_modules
      refute_path_exists File.read(target)
    end
  end

  def prepare_isolation_module
    target = File.join(@root, 'temporary-path.txt')
    facts = JSON.parse(File.read(@facts)).merge('record' => target)
    File.write(@facts, JSON.generate(facts))
    module_inputs('sample', code: hiera_input('isolation_scenario.pp'))
    fixture('sample')
    target
  end

  def with_foreign_hierarchies
    keys = %w[RUBYOPT CATALOG_TEST_FOREIGN CATALOG_TEST_ROOT]
    previous = ENV.to_h.slice(*keys)
    ENV.update('RUBYOPT' => "#{ENV.fetch('RUBYOPT', nil)} -r#{@root}/settings_hook.rb",
               'CATALOG_TEST_FOREIGN' => foreign_hierarchies, 'CATALOG_TEST_ROOT' => @root)
    yield
  ensure
    keys.each { |key| ENV.delete(key) }
    ENV.update(previous)
  end

  def foreign_hierarchies
    foreign = File.join(@root, 'foreign')
    FileUtils.mkdir_p(File.join(foreign, 'data'))
    File.write(File.join(foreign, 'hiera.yaml'), YAML.dump('version' => 5))
    File.write(File.join(foreign, 'data', 'common.yaml'), YAML.dump('foreign' => 'unwanted'))
    copy_foreign_environment(foreign)
    File.write(File.join(@root, 'settings_hook.rb'), hiera_input('settings_hook.rb'))
    foreign
  end

  def copy_foreign_environment(foreign)
    FileUtils.mkdir_p(File.join(foreign, 'catalog_check'))
    %w[hiera.yaml data].each { |part| FileUtils.cp_r(File.join(foreign, part), File.join(foreign, 'catalog_check')) }
  end
end
