# frozen_string_literal: true

# Compare parsed expression structure independently of source locations.
module ArrayLayoutSupport
  include LintTestSupport

  RULE = :project_layout

  def assert_array_fix(before, after)
    assert_equal structure(before), structure(assert_fix(before, after))
  end

  def structure(code)
    semantic_value(ProjectLint::Ast.new(code).program)
  end

  def semantic_value(value)
    return value.map { |item| semantic_value(item) } if value.is_a?(Array)
    return value.transform_values { |item| semantic_value(item) } if value.is_a?(Hash)
    return value unless value.respond_to?(:_pcore_init_hash)

    properties = value._pcore_init_hash.reject { |key, _| %w[locator offset length].include?(key) }
    [value.class.name, semantic_value(properties)]
  end
end
