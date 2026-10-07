# frozen_string_literal: true

require_relative '../../shared/test_support/bootstrap'
require_relative '../../shared/test_support/guide_links'
require_relative 'guide_inventory'

# Guard instruction navigation independently from Markdown link parsing.
class GuideInstructionRoutesTest < Minitest::Test
  include ProjectToolsTestSupport::GuideLinks
  include RepositoryGuideInventory

  ROOT = File.expand_path('../../..', __dir__)
  COMPONENTS = %w[lint metadata module-dependencies repository-checks ruby-lint shared validate].freeze
  INSTRUCTION_ROUTES = {
    'AGENTS.md' => ['.tools/AGENTS.md'],
    '.tools/AGENTS.md' => ['../AGENTS.md', 'README.md', *COMPONENTS.map { |name| "#{name}/AGENTS.md" }],
    **COMPONENTS.to_h { |name| [".tools/#{name}/AGENTS.md", ['../../AGENTS.md', '../AGENTS.md', 'README.md']] }
  }.freeze

  def instruction_route_errors(root)
    INSTRUCTION_ROUTES.flat_map do |name, targets|
      source = File.join(root, name)
      next ["Missing instructions: #{name}"] unless File.file?(source)

      text = File.read(source)
      missing = targets.filter_map do |target|
        "#{name}: Missing instruction route: #{target}" unless prose(text).match?(/\]\(#{Regexp.escape(target)}\)/)
      end
      [*missing, *link_errors(text, source: source, root: root)]
    end
  end

  def with_instruction_tree
    Dir.mktmpdir('instruction-routes') do |root|
      INSTRUCTION_ROUTES.each do |name, targets|
        source = File.join(root, name)
        FileUtils.mkdir_p(File.dirname(source))
        File.write(source, "# Instructions\n\n#{targets.map { |target| "[Source](#{target})" }.join("\n")}\n")
        File.write(File.join(File.dirname(source), 'README.md'), "# Guide\n")
      end
      yield root
    end
  end

  def test_instruction_routes_include_every_owner_parent_and_readme
    assert_empty instruction_route_errors(ROOT)
  end

  def test_instruction_routes_reject_missing_files
    with_instruction_tree do |root|
      assert_empty instruction_route_errors(root)
      File.unlink(File.join(root, '.tools/metadata/AGENTS.md'))
      assert_includes instruction_route_errors(root), 'Missing instructions: .tools/metadata/AGENTS.md'
    end
  end

  def test_instruction_routes_reject_missing_links_and_anchors
    with_instruction_tree do |root|
      path = File.join(root, '.tools/metadata/AGENTS.md')
      File.write(path, File.read(path).sub('[Source](../AGENTS.md)', '[Source](../AGENTS.md#absent)'))
      errors = instruction_route_errors(root)
      assert errors.any? { |error| error.include?('Missing instruction route: ../AGENTS.md') }, errors.join("\n")
      assert errors.any? { |error| error.include?('Missing link anchor: ../AGENTS.md#absent') }, errors.join("\n")
    end
  end

  def initialize_repository(root)
    _output, errors, status = Open3.capture3('git', 'init', '--quiet', root)
    assert status.success?, errors
  end

  def test_markdown_inventory_includes_untracked_instructions_and_their_broken_links
    with_instruction_tree do |root|
      initialize_repository(root)
      paths = repository_markdown(root)
      INSTRUCTION_ROUTES.each_key { |name| assert_includes paths, File.join(root, name) }
      path = File.join(root, '.tools/shared/AGENTS.md')
      File.write(path, "[Missing](absent.md)\n", mode: 'a')
      errors = paths.flat_map { |source| link_errors(File.read(source), source: source, root: root) }
      assert errors.any? { |error| error.include?('Missing link target: absent.md') }, errors.join("\n")
    end
  end

  def test_instruction_layers_have_no_literal_duplicate_rules
    rules = INSTRUCTION_ROUTES.keys.flat_map do |name|
      prose(File.read(File.join(ROOT, name))).lines.grep(/^- /).map { |line| [line.strip, name] }
    end
    duplicates = rules.group_by(&:first).select { |_rule, entries| entries.length > 1 }
    assert_empty duplicates, duplicates.inspect
  end
end
