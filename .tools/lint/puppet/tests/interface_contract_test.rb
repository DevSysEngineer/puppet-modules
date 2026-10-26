# frozen_string_literal: true

require_relative 'test_helper'

# Verify interface contracts with native lint diagnostics.
class InterfaceContractTest < Minitest::Test
  include LintTestSupport

  def test_nested_parameter_types_and_multiline_defaults
    code = fixture('interface_contract/types_and_multiline_defaults_code')
    assert_empty findings(code, 'parameter_types')
    assert_empty findings(code, 'project_parameter_order')
    assert_empty findings(code, 'project_parameter_alignment')
    refute_empty findings('class example ($label = "demo") {}', 'parameter_types')
  end

  def test_optional_without_default_does_not_change_call_contract
    assert_empty findings('class example (String $z, Optional[String] $a) {}', 'project_parameter_order')
    refute_empty findings('class example (Optional[String] $a, String $z) {}', 'project_parameter_order')
    parsed = ProjectLint::Ast.new('class example (String $z, Optional[String] $a) {}')
    assert_nil parsed.declarations.first.parameters.last.value
  end

  def test_interface_calls_require_optional_parameters_without_defaults
    definition = 'define example (Optional[String] $value) {}'
    problems = findings("#{definition} example { 'synthetic': }", :project_interface_calls)
    assert_equal([:warning], problems.map { |problem| problem[:kind] })
    assert_equal 'Public interface call omits required parameters: value', problems.first[:message]
    assert_empty findings("#{definition} example { 'synthetic': value => undef }", 'project_interface_calls')
    assert_empty findings("define example (String $value = 'default') {} example { 'synthetic': }",
                          'project_interface_calls')
  end

  def test_interface_calls_allow_missing_class_arguments_in_the_current_source
    ['String', 'Sensitive[String]', 'Optional[String]'].each do |type|
      code = "class example::service (#{type} $value) {}\nclass { 'example::service': }\n"
      assert_empty findings(code, :project_interface_calls), type
    end
  end

  def test_interface_calls_allow_missing_class_arguments_from_the_modulepath
    previous = ENV.fetch('PROJECT_TOOLS_MODULEPATH', nil)
    Dir.mktmpdir('interface-classes-') do |directory|
      ENV['PROJECT_TOOLS_MODULEPATH'] = directory
      path = File.join(directory, 'example/manifests/service.pp')
      FileUtils.mkdir_p(File.dirname(path))
      assert_class_arguments_from_modulepath(path)
    end
  ensure
    ENV['PROJECT_TOOLS_MODULEPATH'] = previous
  end

  def assert_class_arguments_from_modulepath(path)
    ['String', 'Sensitive[String]', 'Optional[String]'].each do |type|
      File.write(path, "class example::service (#{type} $value) {}")
      assert_empty findings("class { 'example::service': }", :project_interface_calls), type
    end
  end

  def test_interface_calls_report_missing_define_arguments_without_fixing
    code = "define example::item (String $value) {}\nexample::item { 'synthetic': }\n"
    [false, true].each do |fix|
      problems, unchanged = lint_checks(code, [:project_interface_calls], fix: fix)
      assert_equal code, unchanged
      assert_equal([:warning], problems.map { |problem| problem[:kind] })
      assert_equal 'Public interface call omits required parameters: value', problems.first[:message]
      assert_equal [2, 17], problems.first.values_at(:line, :column)
    end
  end

  def test_interface_calls_accept_explicit_define_values_without_evaluating_them
    definition = 'define example::item (String $value) {}'
    ["'synthetic'", "lookup('synthetic::value')"].each do |value|
      code = "#{definition}\nexample::item { 'synthetic': value => #{value} }\n"
      assert_empty findings(code, :project_interface_calls)
    end
  end

  def test_interface_calls_skip_dynamic_splats_and_unresolved_declarations
    code = "define example::item (String $value) {}\nexample::item { 'synthetic': * => $settings }\n"
    assert_empty findings(code, :project_interface_calls)
    assert_empty findings("synthetic::unresolved { 'synthetic': }", :project_interface_calls)
  end

  def test_default_dependencies_and_explanatory_comment
    code = fixture('interface_contract/dependencies_and_explanatory_comment_code')
    assert_empty findings(code, 'project_parameter_order')
    refute_empty findings(code.sub(/ # Must[^\n]+/, ''), 'project_parameter_order')
    refute_empty findings('class example (String $listen_user = $user, String $user = "example") {}',
                          'project_parameter_order')
  end

  def test_alignment_including_mandatory_parameters
    valid = "class example (\n  String           $required,\n  Optional[String] $optional = undef,\n) {}\n"
    assert_empty findings(valid, 'project_parameter_alignment')
    refute_empty findings(valid.sub('String           $required', 'String $required'), 'project_parameter_alignment')
  end

  def test_documentation_matches_each_declaration
    valid = fixture('interface_contract/documentation_matches_each_declaration_valid')
    assert_empty findings(valid, 'project_documentation')
    refute_empty findings(valid.sub('@param label', '@param other'), 'project_documentation')
    refute_empty findings("#{valid}\nclass undocumented {}", 'project_documentation')
  end
end
