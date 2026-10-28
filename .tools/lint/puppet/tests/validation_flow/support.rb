# frozen_string_literal: true

require_relative '../test_helper'

# Run the same validation contract in every supported implementation scope.
module ValidationFlowSupport
  include LintTestSupport

  SCOPES = ['class example', 'define example', "node 'example.test'", nil].freeze

  def findings(body, declaration = 'class example')
    code = declaration ? "#{declaration} {\n#{body}\n}\n" : "#{body}\n"
    super(code, :project_positive_flow)
  end

  def assert_in_scopes(body, kinds, message: nil)
    SCOPES.each do |declaration|
      problems = findings(body, declaration)
      assert_equal kinds, problems.map { |problem| problem[:kind] }, "#{declaration || 'top level'}: #{body}"
      assert_includes problems.first[:message], message if message
    end
  end
end
