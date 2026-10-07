# frozen_string_literal: true

require_relative 'test_helper'

# Reject additional lint documents without treating local instructions as a Dutch guide.
class GuideInventoryTest < Minitest::Test
  DOCUMENTS = %w[README.md docs/CODE_RULES.md docs/DOCUMENTATION_RULES.md docs/OPERATIONAL_RULES.md
                 AGENTS.md].freeze
  ROOT = File.join(LintTestSupport::ROOT, '.tools/lint')

  def assert_document_inventory(root)
    documents = Dir.glob('**/*.md', File::FNM_DOTMATCH, base: root)
    assert_equal DOCUMENTS.sort, documents.sort
  end

  def with_guides
    Dir.mktmpdir('lint-guides') do |root|
      DOCUMENTS.each do |name|
        path = File.join(root, name)
        FileUtils.mkdir_p(File.dirname(path))
        File.write(path, "# Synthetic guide\n")
      end
      yield root
    end
  end

  def test_repository_has_exactly_four_guides_and_local_instructions
    assert_document_inventory(ROOT)
  end

  def test_inventory_allows_the_local_instruction_file
    with_guides { |root| assert_document_inventory(root) }
  end

  def test_inventory_rejects_an_unexpected_lint_document
    with_guides do |root|
      File.write(File.join(root, 'docs/EXTRA.md'), "# Unexpected guide\n")
      assert_raises(Minitest::Assertion) { assert_document_inventory(root) }
    end
  end

  def test_inventory_requires_the_local_instruction_file
    with_guides do |root|
      File.unlink(File.join(root, 'AGENTS.md'))
      assert_raises(Minitest::Assertion) { assert_document_inventory(root) }
    end
  end
end
