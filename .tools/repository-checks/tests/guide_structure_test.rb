# frozen_string_literal: true

require_relative '../../shared/test_support/bootstrap'
require_relative '../../shared/test_support/guide_links'

# Tool guides have navigation without becoming additional lint rule owners.
class SharedGuideStructureTest < Minitest::Test
  include ProjectToolsTestSupport::GuideLinks

  ROOT = File.expand_path('../../..', __dir__)
  COMPONENTS = %w[catalog lint metadata module-dependencies repository-checks ruby-lint secrets shared syntax].freeze
  DEVELOPMENT_ROUTES = {
    'README.md' => ['CONTRIBUTING.md'],
    'CONTRIBUTING.md' => ['TESTS.md', '.tools/lint/docs/CODE_RULES.md#algemene-ontwerpregels',
                          '.tools/lint/docs/DOCUMENTATION_RULES.md', '.tools/lint/docs/OPERATIONAL_RULES.md',
                          '.tools/README.md#gedeeld-toolingonderhoud'],
    '.tools/README.md' => COMPONENTS.map do |name|
      "#{name}/README.md"
    end
  }.freeze

  POLICY_OWNERS = {
    'CONTRIBUTING.md' => %w[voorbereiding-en-wijzigingsscope compatibiliteit-en-versies
                            veilig-werken-en-gegevensdeling],
    'TESTS.md' => %w[testscope-en-plaatsing shellvalidatie monitoringvalidatie],
    '.tools/lint/docs/DOCUMENTATION_RULES.md' => %w[informatieplaatsing markdown readme-richtlijnen redactionele-review]
  }.freeze

  def development_route_errors(root)
    DEVELOPMENT_ROUTES.flat_map do |name, targets|
      source = File.join(root, name)
      next ["Missing development guide: #{name}"] unless File.file?(source)

      text = File.read(source)
      missing = targets.reject { |target| prose(text).match?(/\]\(#{Regexp.escape(target)}(?:#[^)]*)?\)/) }
      missing.map! { |target| "#{name}: Missing development route: #{target}" }
      [*missing, *link_errors(text, source: source, root: root)]
    end
  end

  def test_human_development_routes_reach_shared_policy_and_every_component
    assert_empty development_route_errors(ROOT)
  end

  def test_human_route_rejects_a_missing_development_entry
    Dir.mktmpdir('development-routes') do |root|
      File.write(File.join(root, 'README.md'), "# Guide\n\n[Development](CONTRIBUTING.md)\n")
      errors = development_route_errors(root)
      assert errors.any? { |error| error.include?('Missing link target: CONTRIBUTING.md') }, errors.join("\n")
    end
  end

  def policy_headings
    sources = ['AGENTS.md', '.tools/AGENTS.md', *POLICY_OWNERS.keys,
               *COMPONENTS.map { |name| ".tools/#{name}/AGENTS.md" },
               '.tools/lint/docs/CODE_RULES.md', '.tools/lint/docs/OPERATIONAL_RULES.md', '.tools/lint/README.md']
    sources.to_h { |name| [name, heading_anchors(File.read(File.join(ROOT, name)))] }
  end

  def test_shared_policy_has_one_owner_outside_agent_routes
    documents = policy_headings
    POLICY_OWNERS.each do |owner, required|
      required.each do |anchor|
        assert_equal [owner], documents.filter_map { |name, entries| name if entries.include?(anchor) }, anchor
      end
    end
  end

  def test_package_guides_link_every_heading_and_keep_the_lint_registry_at_its_owner
    root = File.expand_path('../../..', __dir__)
    %w[CONTRIBUTING.md TESTS.md .tools/README.md .tools/shared/README.md .tools/module-dependencies/README.md
       .tools/catalog/README.md .tools/syntax/README.md .tools/metadata/README.md .tools/ruby-lint/README.md
       .tools/repository-checks/README.md .tools/secrets/README.md].each do |name|
      text = File.read(File.join(root, name))
      contents = text[/^## Inhoudsopgave\n(.*?)(?=^## )/m, 1]
      assert_equal expected_contents(text), contents.lines.grep(/^ *- /).map(&:chomp), name
      assert_equal anchors(text).uniq, anchors(text), name
      refute_includes text, '<!-- BEGIN PROJECT CHECK REGISTRY -->'
    end
  end
end
