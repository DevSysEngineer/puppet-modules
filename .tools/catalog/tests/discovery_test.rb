# frozen_string_literal: true

require_relative 'test_helper'

# Selection belongs to modules and must match the compiler's modulepath precedence.
class CatalogDiscoveryTest < Minitest::Test
  include CatalogTestSupport

  def test_discovers_module_local_products_and_new_modules_without_a_registry
    prepare_matrix
    first = ProjectTools::Catalog::Discovery.new([@root])
    assert_matrix(first)
    module_inputs('beta')
    second = ProjectTools::Catalog::Discovery.new([@root])
    assert_equal 5, second.scenarios.size
    assert_equal 'beta/default [debian]', second.scenarios.last[:name]
  end

  def assert_matrix(first)
    assert_equal(['alpha/default [debian]', 'alpha/nested/extra [debian]',
                  'alpha/default [ubuntu]', 'alpha/nested/extra [ubuntu]'], first.scenarios.map { |item| item[:name] })
    assert_equal ['untested'], first.skipped
    assert_empty first.errors
  end

  def prepare_matrix
    alpha = module_inputs('alpha')
    FileUtils.mkdir_p(File.join(alpha, 'tests', 'manifests', 'nested'))
    File.write(File.join(alpha, 'tests', 'manifests', 'nested', 'extra.pp'), 'include alpha')
    FileUtils.cp(@facts, File.join(alpha, 'tests', 'facts', 'ubuntu.json'))
    FileUtils.mkdir_p(File.join(@root, 'untested', 'manifests'))
    module_inputs('.hidden')
  end

  def test_first_module_wins_even_without_tests_and_repeated_paths_do_not_duplicate_tests
    paths = overlapping_modules
    discovery = ProjectTools::Catalog::Discovery.new(paths)
    assert_equal 2, discovery.scenarios.size
    assert discovery.scenarios.last[:manifest].start_with?(paths.first)
  end

  def test_first_module_without_tests_shadows_later_tests
    paths = overlapping_modules
    FileUtils.remove_entry(File.join(paths.first, 'sample', 'tests'))
    discovery = ProjectTools::Catalog::Discovery.new(paths)
    assert_equal(['other/default [debian]'], discovery.scenarios.map { |item| item[:name] })
    assert_equal ['sample'], discovery.skipped
  end

  def overlapping_modules
    first = File.join(@root, 'first')
    second = File.join(@root, 'second')
    module_inputs('sample', base: first)
    module_inputs('sample', base: second)
    module_inputs('other', base: second)
    [first, second, first]
  end

  def test_module_symlinks_are_discovered_and_used_by_the_compiler
    actual = module_inputs('sample', code: 'include sample')
    File.write(File.join(actual, 'manifests', 'init.pp'), 'class sample {}')
    directory = File.join(@root, 'linked modules')
    FileUtils.mkdir_p(directory)
    File.symlink(actual, File.join(directory, 'sample'))
    runner = ProjectTools::Catalog.new(modulepath: directory, console: @console)
    assert_equal 0, runner.run
    assert_includes @console.string, '1 selected | 1 checked'
  end
end
