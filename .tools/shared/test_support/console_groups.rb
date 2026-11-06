# frozen_string_literal: true

# Assert the same visible CI boundary through each tool's own entry point.
module ProjectToolsConsoleGroups
  def with_ci_platform(platform, value: 'true')
    keys = %w[GITHUB_ACTIONS GITLAB_CI]
    previous = keys.to_h { |key| [key, ENV.fetch(key, nil)] }
    keys.each { |key| ENV[key] = key == platform ? value : nil }
    yield
  ensure
    previous.each { |key, original| ENV[key] = original }
  end

  def assert_ci_group(text, platform, name:, outcome:)
    opening = platform == 'GITHUB_ACTIONS' ? "::group::Run #{name}" : "\r\e[0KRun #{name}"
    closing = platform == 'GITHUB_ACTIONS' ? '::endgroup::' : 'section_end:'
    assert_equal 1, text.scan(opening).size
    assert_operator text.scan(closing).size, :>=, 1
    assert_ci_order(text, opening, '[START]', closing, "[#{outcome}] #{name}")
    assert_equal [outcome], text.scan(/^\[(PASSED|FAILED|ERROR|SKIPPED)\]/).flatten
    assert_gitlab_section(text) if platform == 'GITLAB_CI'
  end

  def assert_ci_order(text, *markers)
    markers.each_cons(2) { |left, right| assert_operator text.index(left), :<, text.index(right) }
  end

  def assert_gitlab_section(text)
    starts = text.scan(/^\e\[0Ksection_start:\d+:([\w.-]+)\[collapsed=true\]/).flatten
    assert_operator starts.size, :>=, 1
    assert_equal starts.uniq, starts
    assert_equal starts, text.scan(/^\e\[0Ksection_end:\d+:([\w.-]+)/).flatten
  end

  def refute_ci_markers(text)
    refute_match(/::(?:end)?group::|section_(?:start|end):/, text)
  end
end
