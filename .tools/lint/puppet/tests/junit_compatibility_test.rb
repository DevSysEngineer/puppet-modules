# frozen_string_literal: true

require_relative 'test_helper'

# Preserve the public lint reporter require path.
class JunitCompatibilityTest < Minitest::Test
  def test_lint_compatibility_path_delegates_to_the_same_writer
    require 'project_lint/junit_report'
    assert_same ProjectTools::Shared::JunitReport, ProjectLint::JunitReport
  end
end
