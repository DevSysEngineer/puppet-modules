# frozen_string_literal: true

require_relative '../../test_support/bootstrap'
require_relative '../../test_support/console_groups'
require 'project_tools/shared/console'
require 'stringio'

# CI decoration must not hide the outcome or turn dynamic text into commands.
class SharedConsoleGroupsTest < Minitest::Test
  include ProjectToolsConsoleGroups

  def render(platform, name: 'Synthetic check', value: 'true')
    output = StringIO.new
    with_ci_platform(platform, value: value) do
      console = ProjectTools::Shared::Console.new(name, output: output)
      yield console
    end
    output.string
  end

  def grouped_result(platform, outcome)
    render(platform) do |console|
      console.during do
        console.finding('Synthetic finding')
        console.progress
        2.times { console.finish(status: outcome, execution: 'complete') }
      end
    end
  end

  def test_ci_progress_is_collapsible_and_every_outcome_remains_visible
    %w[GITHUB_ACTIONS GITLAB_CI].product(%w[PASSED FAILED ERROR SKIPPED]).each do |platform, outcome|
      text = grouped_result(platform, outcome)
      assert_ci_group(text, platform, name: 'Synthetic check', outcome: outcome)
      closing = platform == 'GITHUB_ACTIONS' ? '::endgroup::' : 'section_end:'
      assert_operator text.index('[PROGRESS]'), :<, text.index(closing)
      assert_operator text.index("[#{outcome}]"), :<, text.index('Synthetic finding')
      assert_equal 1, text.scan('Synthetic finding').size
    end
  end

  def test_interruption_closes_the_group_and_preserves_the_exception
    %w[GITHUB_ACTIONS GITLAB_CI].each do |platform|
      text = render(platform) do |console|
        assert_raises(Interrupt) { console.during { raise Interrupt } }
      end
      assert_ci_group(text, platform, name: 'Synthetic check', outcome: 'ERROR')
      assert_includes text, 'Execution: incomplete'
    end
  end

  def test_repeated_gitlab_runs_have_distinct_sections
    texts = Array.new(2) { grouped_result('GITLAB_CI', 'PASSED') }
    texts.each { |text| assert_gitlab_section(text) }
    assert_equal 4, texts.join.scan(/section_start:\d+:([\w.-]+)/).flatten.uniq.size
  end

  def test_titles_cannot_inject_workflow_commands
    name = "Example %\n::endgroup::\r\e[0Ksection_end:1:injected"
    %w[GITHUB_ACTIONS GITLAB_CI].each do |platform|
      text = render(platform, name: name) { |console| console.finish(status: 'PASSED', execution: 'complete') }
      refute_match(/^::endgroup:: .*injected/, text)
      refute_includes text, "\e[0Ksection_end:1:injected"
      assert_includes text, 'Run Example %25 ' if platform == 'GITHUB_ACTIONS'
    end
  end

  def test_local_output_has_no_platform_markers
    [nil, '', 'false'].each do |value|
      text = render('GITHUB_ACTIONS', value: value) do |console|
        console.finish(status: 'PASSED', execution: 'complete')
      end
      refute_ci_markers(text)
      assert_match(/\A\[START\]/, text)
    end
  end
end
