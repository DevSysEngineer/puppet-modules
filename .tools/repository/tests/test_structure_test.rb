# frozen_string_literal: true

require_relative '../../shared/test_support/bootstrap'
require_relative '../../shared/test_support/packages'
require_relative 'structure_support'

# Guard tool ownership and recursive discovery through the repository's native Rake tasks.
class TestStructureTest < Minitest::Test
  include ProjectToolsPackageSupport
  include RepositoryStructureSupport

  def setup
    @project = Dir.mktmpdir('test-discovery-')
    @directory = @project
  end

  def write_file(path, contents)
    write(path, contents)
    return unless path.end_with?('_test.rb')

    write(path.sub('/tests/', '/tests/fixtures/'), contents)
    write(path.sub('/tests/', '/tests/nested/fixtures/'), contents)
  end

  def test_tool_test_files_stay_under_the_owning_tool
    paths = Dir.glob('.tools/**/*_test.rb', base: ProjectToolsPackageSupport::ROOT)
    refute_empty paths
    misplaced = paths.grep_v(%r{\A\.tools/(?:lint/(?:puppet|ruby)|(?!lint/)[^/]+)/tests/})
    assert_empty misplaced, "Move tool tests under their owning tool: #{misplaced.join(', ')}"
  end

  def test_tool_test_directories_use_one_location_per_tool
    paths = Dir.glob('.tools/**/{test,tests}', base: ProjectToolsPackageSupport::ROOT)
    misplaced = paths.grep_v(%r{\A\.tools/(?:lint/(?:puppet|ruby)|(?!lint/)[^/]+)/tests\z})
    assert_empty misplaced, "Keep test directories under their owning tool: #{misplaced.join(', ')}"
  end

  def test_components_have_documentation_instructions_tests_and_rake_integration
    assert_empty component_errors(ROOT)
  end

  def test_gems_supply_their_registered_executables
    assert_empty registered_executable_errors(ROOT)
    gemspecs(ROOT).each do |path, spec|
      files = Dir.glob(File.join(File.dirname(path), 'bin', '*'), base: ROOT)
      assert_equal spec.executables.sort, files.map { |file| File.basename(file) }.sort,
                   "Register every bin executable in #{path}"
    end
  end

  def test_catalog_has_its_own_executable_without_a_legacy_entry_point
    assert_empty executable_errors(ROOT, '.tools/catalog/bin/project-tools-catalog')
    refute_path_exists File.join(ROOT, '.tools/catalog/compile.rb')
  end

  def test_cli_entry_points_load_from_another_working_directory
    paths = Dir.glob('.tools/**/bin/*', base: ROOT).reject { |path| path.include?('/fixtures/') }
    refute_empty paths
    paths.each { |path| assert_cli_loads(path) }
    assert_empty Dir.children(@project), 'CLI usage must not create files'
  end

  def test_structure_checks_reject_missing_registered_executables
    write('.tools/sample/sample.gemspec', <<~RUBY)
      Gem::Specification.new do |spec|
        spec.name = 'sample'
        spec.version = '1.0.0'
        spec.bindir = 'bin'
        spec.executables = ['project-tools-sample']
      end
    RUBY
    assert_includes registered_executable_errors(@project),
                    'Missing CLI executable: .tools/sample/bin/project-tools-sample'
  end

  def test_structure_checks_reject_a_missing_catalog_executable
    assert_includes executable_errors(@project, '.tools/catalog/bin/project-tools-catalog'),
                    'Missing CLI executable: .tools/catalog/bin/project-tools-catalog'
  end

  def test_component_contract_accepts_no_cli_and_rejects_missing_files_and_tests
    write('Rakefile', "'.tools/library/tests/**/*_test.rb'")
    write('.tools/library/README.md', '# Library')
    write('.tools/library/AGENTS.md', '# Instructions')
    write('.tools/library/tests/library_test.rb', '# Synthetic test')
    assert_empty component_errors(@project)
    assert_empty registered_executable_errors(@project)
    File.unlink(File.join(@project, '.tools/library/README.md'))
    File.unlink(File.join(@project, '.tools/library/tests/library_test.rb'))
    assert_equal ['Missing component file: .tools/library/README.md',
                  'Missing tool tests: .tools/library/tests/**/*_test.rb'], component_errors(@project)
  end

  def test_a_new_cli_requires_a_rake_test_selection
    write('Rakefile', '')
    write('.tools/new/bin/project-tools-new', "#!/usr/bin/env ruby\n")
    assert_includes component_errors(@project), 'Missing Rake test selection: .tools/new/tests/**/*_test.rb'
  end

  def test_rake_tasks_discover_nested_tests_and_keep_tool_selection_separate
    write_file('Rakefile', File.read(File.join(ProjectToolsPackageSupport::ROOT, 'Rakefile')))
    write_file('sample.pp', "notify { 'synthetic': }\n")
    selections = tool_selections
    all = [*selections.values.flatten, '.tools/inventory/tests/inventory_test.rb'].sort
    all.each { |path| write_file(path, "puts #{path.dump}\n") }
    selections.merge('test:tools' => all, 'test' => all, 'default' => all).each do |task, expected|
      assert_task_selection(task, expected)
    end
  end

  def tool_selections
    { 'test:lint' => %w[.tools/lint/puppet/tests/check_test.rb .tools/lint/puppet/tests/nested/check_test.rb],
      'test:metadata' => ['.tools/metadata/tests/check_test.rb'],
      'test:ruby_lint' => ['.tools/lint/ruby/tests/cli_test.rb'],
      'test:repository' => ['.tools/repository/tests/workflow_test.rb'],
      'test:secrets' => ['.tools/secrets/tests/detection_test.rb'],
      'test:shared' => ['.tools/shared/tests/library_test.rb'],
      'test:dependencies' => ['.tools/dependencies/tests/cli_test.rb'],
      'test:catalog' => ['.tools/catalog/tests/catalog_test.rb'],
      'test:syntax' => ['.tools/syntax/tests/cli_test.rb'] }
      .transform_values { |paths| [paths.first, paths.first.sub('/tests/', '/tests/nested/')].sort }
  end
end
