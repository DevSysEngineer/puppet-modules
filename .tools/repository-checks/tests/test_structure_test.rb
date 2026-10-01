# frozen_string_literal: true

require_relative '../../shared/test_support/bootstrap'
require_relative '../../shared/test_support/packages'

# Guard tool ownership and recursive discovery through the repository's native Rake tasks.
class TestStructureTest < Minitest::Test
  include ProjectToolsPackageSupport

  def setup
    @project = Dir.mktmpdir('test-discovery-')
    @directory = @project
  end

  def write_file(path, contents)
    write(path, contents)
  end

  def test_tool_test_files_stay_under_the_owning_tool
    paths = Dir.glob('.tools/**/*_test.rb', base: ProjectToolsPackageSupport::ROOT)
    refute_empty paths
    misplaced = paths.grep_v(%r{\A\.tools/[^/]+/tests/})
    assert_empty misplaced, "Move tool tests to .tools/<tool-name>/tests/: #{misplaced.join(', ')}"
  end

  def test_tool_test_directories_use_one_location_per_tool
    paths = Dir.glob('.tools/**/{test,tests}', base: ProjectToolsPackageSupport::ROOT)
    misplaced = paths.grep_v(%r{\A\.tools/[^/]+/tests\z})
    assert_empty misplaced, "Keep test directories under their owning tool: #{misplaced.join(', ')}"
  end

  def test_rake_tasks_discover_nested_tests_and_keep_tool_selection_separate
    write_file('Rakefile', File.read(File.join(ProjectToolsPackageSupport::ROOT, 'Rakefile')))
    selections = tool_selections
    all = [*selections.values.flatten, '.tools/inventory/tests/inventory_test.rb'].sort
    all.each { |path| write_file(path, "puts #{path.dump}\n") }
    selections.merge('test' => all, 'default' => all).each do |task, expected|
      assert_task_selection(task, expected)
    end
  end

  def tool_selections
    { 'test:lint' => %w[.tools/lint/tests/check_test.rb .tools/lint/tests/nested/check_test.rb],
      'test:metadata' => ['.tools/metadata/tests/metadata_test.rb'],
      'test:ruby_lint' => ['.tools/ruby-lint/tests/cli_test.rb'],
      'test:repository_checks' => ['.tools/repository-checks/tests/workflow_test.rb'],
      'test:shared' => ['.tools/shared/tests/library_test.rb'],
      'test:module_dependencies' => ['.tools/module-dependencies/tests/cli_test.rb'],
      'test:validate' => ['.tools/validate/tests/cli_test.rb'] }
  end

  def assert_task_selection(task, expected)
    # A targeted outer test run must not override this independent task selection.
    environment = { 'TEST' => nil, 'TESTOPTS' => nil }
    output, errors, status = Open3.capture3(environment, Gem.ruby, Gem.bin_path('rake', 'rake'), task,
                                            chdir: @directory)
    assert status.success?, output + errors
    assert_equal expected, output.lines.map(&:strip).grep(%r{\A\.tools/}).sort, task
  end
end
