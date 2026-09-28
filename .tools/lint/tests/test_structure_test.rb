# frozen_string_literal: true

require_relative 'test_helper'

# Guard tool ownership and recursive discovery through the repository's native Rake tasks.
class TestStructureTest < Minitest::Test
  include LintCliSupport

  def test_tool_test_files_stay_under_the_owning_tool
    paths = Dir.glob('.tools/**/*_test.rb', base: LintTestSupport::ROOT)
    refute_empty paths
    misplaced = paths.grep_v(%r{\A\.tools/[^/]+/tests/})
    assert_empty misplaced, "Move tool tests to .tools/<tool-name>/tests/: #{misplaced.join(', ')}"
  end

  def test_tool_test_directories_use_one_location_per_tool
    paths = Dir.glob('.tools/**/{test,tests}', base: LintTestSupport::ROOT)
    misplaced = paths.grep_v(%r{\A\.tools/[^/]+/tests\z})
    assert_empty misplaced, "Keep test directories under their owning tool: #{misplaced.join(', ')}"
  end

  def test_rake_tasks_discover_nested_tests_and_keep_tool_selection_separate
    write_file('Rakefile', File.read(File.join(LintTestSupport::ROOT, 'Rakefile')))
    lint = %w[.tools/lint/tests/check_test.rb .tools/lint/tests/metadata/version_test.rb]
    all = [*lint, '.tools/inventory/tests/inventory_test.rb'].sort
    all.each { |path| write_file(path, "puts #{path.dump}\n") }
    { 'test' => all, 'test:lint' => lint, 'default' => all }.each do |task, expected|
      assert_task_selection(task, expected)
    end
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
