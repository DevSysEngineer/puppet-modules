# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'installed_gem_support'
require_relative '../../shared/test_support/guide_links'

# Keep the guide and its rule targets available to independently installed consumers.
class ExternalGuideTest < Minitest::Test
  include InstalledGemSupport
  include ProjectToolsTestSupport::GuideLinks

  def test_installed_package_contains_all_four_complete_documents
    %w[README.md docs/CODE_RULES.md docs/DOCUMENTATION_RULES.md docs/OPERATIONAL_RULES.md].each do |name|
      assert_equal File.read(File.join(LintTestSupport::ROOT, '.tools/lint', name)),
                   File.read(File.join(@installed, name)), "Packaged #{name} must retain its complete contents"
    end
  end

  def test_links_to_packaged_targets_resolve_inside_the_installed_package
    @package_files = Gem::Package.new(File.join(@project, 'lint-project.gem')).spec.files
    errors = Dir[File.join(@installed, '**/*.md')].flat_map do |path|
      link_errors(File.read(path), source: path, root: @installed)
    end
    assert_empty errors, errors.join("\n")
  end

  def link_error(link, source:, root:)
    target = link_target(link.split('#', 2).first, source: source, root: root).delete_prefix("#{@installed}/")
    # Repository-only references are verified against the checkout by the repository documentation tests.
    return unless @package_files.any? { |name| name == target || name.start_with?("#{target}/") }

    super
  end
end
