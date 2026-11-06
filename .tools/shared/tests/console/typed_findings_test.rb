# frozen_string_literal: true

require_relative '../../test_support/bootstrap'
require_relative '../../test_support/console_groups'
require 'project_tools/shared/console'
require 'stringio'

# The shared presentation preserves diagnosis boundaries independently of the producer.
class SharedTypedFindingsTest < Minitest::Test
  include ProjectToolsConsoleGroups

  def test_every_category_has_a_separate_balanced_group_in_priority_order
    %w[GITHUB_ACTIONS GITLAB_CI].each do |platform|
      text = render(platform)
      assert_ci_group(text, platform, name: 'Synthetic check', outcome: 'ERROR')
      assert_equal %w[ERROR FAILED SKIPPED WARNING REVIEW INFO], text.scan(/\[(\w+)\] Cause/).flatten
      assert_equal 6, text.scan('Diagnostic:').size
      assert_equal 7, text.scan(platform == 'GITHUB_ACTIONS' ? '::endgroup::' : 'section_end:').size
      assert_operator text.index('[ERROR] Synthetic check'), :<, text.index('[ERROR] Cause')
    end
  end

  def render(platform)
    output = StringIO.new
    with_ci_platform(platform) do
      console = ProjectTools::Shared::Console.new('Synthetic check', output: output)
      populate(console)
      console.finish(status: 'ERROR', execution: 'incomplete')
    end
    output.string
  end

  def populate(console)
    %i[info review warning skipped failure error].each do |kind|
      message = "full #{kind} diagnosis\nlast line"
      console.finding(message, kind: kind, title: 'Cause', source: 'sample.pp:12',
                               subject: 'sample', unit: 'scenario')
    end
  end

  def test_equal_text_with_different_categories_or_locations_remains_separate
    output = StringIO.new
    findings = ProjectTools::Shared::ConsoleFindings.new(output: output)
    findings.add('same diagnosis', kind: :warning, source: 'one.pp:1')
    findings.add('same diagnosis', kind: :failure, source: 'one.pp:1')
    findings.add('same diagnosis', kind: :failure, source: 'two.pp:1')
    with_ci_platform(nil) { findings.write }
    text = output.string
    assert_equal 3, text.scan('same diagnosis').size
    assert_equal %w[FAILED FAILED WARNING], text.scan(/\[(\w+)\]/).flatten
    refute_ci_markers(text)
  end

  def test_unknown_categories_are_rejected_before_output
    output = StringIO.new
    findings = ProjectTools::Shared::ConsoleFindings.new(output: output)
    assert_raises(KeyError) { findings.add('diagnosis', kind: :unknown) }
    findings.write
    assert_empty output.string
  end

  def test_error_stream_is_written_before_lower_priority_findings_on_the_main_stream
    lines = []
    main = tracking_output(lines)
    errors = tracking_output(lines)
    findings = ProjectTools::Shared::ConsoleFindings.new(output: main)
    findings.add('content rejected', kind: :failure)
    findings.add('report unavailable', kind: :error, output: errors)
    findings.write
    assert_ci_order(lines.join("\n"), '[ERROR]', '[FAILED]')
    refute_includes main.string, 'report unavailable'
    refute_includes errors.string, 'content rejected'
  end

  def tracking_output(lines)
    StringIO.new.tap do |output|
      output.define_singleton_method(:puts) do |*values|
        lines.concat(values)
        super(*values)
      end
    end
  end
end
