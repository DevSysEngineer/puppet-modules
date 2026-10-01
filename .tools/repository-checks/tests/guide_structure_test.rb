# frozen_string_literal: true

require_relative '../../shared/test_support/bootstrap'
require_relative '../../shared/test_support/guide_links'

# Tool guides have navigation without becoming additional lint rule owners.
class SharedGuideStructureTest < Minitest::Test
  include ProjectToolsTestSupport::GuideLinks

  def test_package_guides_link_every_heading_and_keep_the_lint_registry_at_its_owner
    root = File.expand_path('../../..', __dir__)
    %w[.tools/README.md .tools/shared/README.md .tools/module-dependencies/README.md
       .tools/validate/README.md .tools/metadata/README.md .tools/ruby-lint/README.md
       .tools/repository-checks/README.md].each do |name|
      text = File.read(File.join(root, name))
      contents = text[/^## Inhoudsopgave\n(.*?)(?=^## )/m, 1]
      assert_equal expected_contents(text), contents.lines.grep(/^ *- /).map(&:chomp), name
      assert_equal anchors(text).uniq, anchors(text), name
      refute_includes text, '<!-- BEGIN PROJECT CHECK REGISTRY -->'
    end
  end
end
