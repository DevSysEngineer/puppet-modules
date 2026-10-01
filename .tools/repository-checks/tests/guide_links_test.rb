# frozen_string_literal: true

require_relative '../../shared/test_support/bootstrap'
require_relative '../../shared/test_support/guide_links'

# Guard local documentation navigation and reproduce malformed fragments.
class GuideLinksTest < Minitest::Test
  include ProjectToolsTestSupport::GuideLinks

  ROOT = File.expand_path('../../..', __dir__)

  def repository_markdown
    output, errors, status = Open3.capture3('git', 'ls-files', '-z', '--cached', '--others', '--exclude-standard',
                                            '--', '*.md', chdir: ROOT)
    assert status.success?, errors
    output.split("\0").map { |path| File.join(ROOT, path) }.select { |path| File.file?(path) }
  end

  def with_guide(text)
    Dir.mktmpdir('guide-links') do |root|
      source = File.join(root, '.tools/lint/README.md')
      FileUtils.mkdir_p(File.dirname(source))
      File.write(source, text)
      yield root, source
    end
  end

  def test_local_links_reject_a_trailing_comma
    with_guide("# Guide\n\n## Technische werking van de checks\n") do |root, source|
      ['#', 'README.md#'].each do |prefix|
        link = "#{prefix}technische-werking-van-de-checks"
        assert_empty link_errors("[Valid](#{link})", source: source, root: root)
        errors = link_errors("[Invalid](#{link},)", source: source, root: root)
        assert_equal ["#{source}:1: Missing link anchor: #{link},"], errors
      end
    end
  end

  def test_reports_all_missing_targets_and_fragments_with_original_line_numbers
    with_guide("# Guide\n") do |root, source|
      text = "```markdown\n[Example](#ignored)\n```\n[One](#missing) [Two](absent.md#title)\n"
      assert_equal ["#{source}:4: Missing link anchor: #missing",
                    "#{source}:4: Missing link target: absent.md#title"],
                   link_errors(text, source: source, root: root)
    end
  end

  def test_checks_relative_files_encoded_fragments_and_explicit_anchors
    with_guide("# Guide\n") do |root, source|
      File.write(File.join(root, 'README.md'), "# Één keuze\n\n<a id='legacy'></a>\n")
      %w[../../README.md#%C3%A9%C3%A9n-keuze ../../README.md#legacy].each do |link|
        assert_empty link_errors("[Target](#{link} \"Title\")", source: source, root: root)
      end
      refute_empty link_errors('[Missing](../../README.md#absent)', source: source, root: root)
    end
  end

  def test_ignores_external_destinations_and_code_examples
    text = <<~MARKDOWN
      [External](https://example.org/guide#unknown) [External repository](https://github.com/example/other/blob/main/README.md#unknown)
      `[Inline example](#missing)`
      ~~~~markdown
      [Fenced example](#missing)
      ~~~
      ## Hidden heading
      ~~~~
      ## Visible heading
    MARKDOWN
    with_guide(text) { |root, source| assert_empty link_errors(text, source: source, root: root) }
    assert_equal ['visible-heading'], anchors(text)
  end

  def test_heading_anchors_include_duplicate_suffixes_and_literal_suffix_collisions
    text = "# Code `my_value`, één!\n\n## Repeat\n\n## Repeat\n\n## Repeat-1\n\n## Repeat\n"
    assert_equal %w[code-my_value-één repeat repeat-1 repeat-1-1 repeat-2], heading_anchors(text)
  end

  def test_guide_and_incoming_repository_links_resolve
    paths = repository_markdown
    refute_empty paths
    errors = paths.flat_map do |source|
      link_errors(File.read(source), source: source, root: ROOT)
    end
    assert_empty errors, errors.join("\n")
  end

  def test_repository_markdown_has_no_hardcoded_repository_urls
    repository_url = %r{(?:https?://|//)(?:github\.com|raw\.githubusercontent\.com)/DevSysEngineer/puppet-modules\b}i
    paths = repository_markdown
    refute_empty paths
    paths.each do |source|
      refute File.read(source).match?(repository_url), "#{source}: Use relative repository links (AGENTS.md#markdown)"
    end
  end
end
