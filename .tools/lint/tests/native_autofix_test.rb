# frozen_string_literal: true

require_relative 'test_helper'

# Execute the bundled native/plugin corrections through their ordinary public CLI.
class NativeAutofixTest < Minitest::Test
  include LintCliSupport

  SAMPLES = {
    arrow_on_right_operand_line: ["File['a'] ->\nFile['b']\n", "File['a']\n-> File['b']\n"],
    names_containing_uppercase: ["class Example {}\n", "class example {}\n"],
    slash_comments: ["// Explain this.\n", "# Explain this.\n"],
    star_comments: ["/* Explain this. */\n", "# Explain this.\n"],
    unquoted_node_name: ["node example {}\n", "node 'example' {}\n"],
    ensure_first_param: ["file { 'x': mode => '0600', ensure => present, }\n",
                         "file { 'x': ensure => present, mode => '0600', }\n"],
    ensure_not_symlink_target: ["file { 'x':\n  ensure => '/tmp/example',\n}\n",
                                "file { 'x':\n  ensure => symlink,\n  target => '/tmp/example',\n}\n"],
    file_mode: ["file { 'x': mode => '600' }\n", "file { 'x': mode => '0600' }\n"],
    unquoted_file_mode: ["file { 'x': mode => 0600 }\n", "file { 'x': mode => '0600' }\n"],
    unquoted_resource_title: ["notify { example: }\n", "notify { 'example': }\n"],
    double_quoted_strings: ["$value = \"example\"\n", "$value = 'example'\n"],
    only_variable_string: ["$value = \"${example}\"\n", "$value = $example\n"],
    variables_not_enclosed: ["$value = \"prefix $example\"\n", "$value = \"prefix ${example}\"\n"],
    hard_tabs: ["class example {\n\tnotice('value')\n}\n", "class example {\n  notice('value')\n}\n"],
    space_before_arrow: ["notify { 'example': message=> 'value' }\n", "notify { 'example': message => 'value' }\n"],
    trailing_whitespace: ["$value = 1  \n", "$value = 1\n"],
    legacy_facts: ["$value = $::osfamily\n", "$value = $facts['os']['family']\n"],
    top_scope_facts: ["$value = $::kernel\n", "$value = $facts['kernel']\n"],
    arrow_alignment: ["notify { 'example':\n  message => 'value',\n  loglevel => 'notice',\n}\n",
                      "notify { 'example':\n  message  => 'value',\n  loglevel => 'notice',\n}\n"],
    trailing_comma: ["$value = [\n  1\n]\n", "$value = [\n  1,\n]\n"]
  }.freeze

  SAMPLES.each do |check, (before, after)|
    define_method("test_#{check}_writes_and_is_idempotent") do
      assert_native_fix(before, after, check)
    end
  end

  def test_unmappable_facts_do_not_lose_their_hash_key_or_report_false_success
    code = "$value = $facts['memoryfree_mb']\n"
    write_source(code)
    2.times do
      assert_cli_failure('--fix', '--only-checks=legacy_facts', @file)
      assert_includes @output, ': warning:'
      refute_includes @output, ': fixed:'
      assert_equal code, source
    end
  end

  def test_yaml_findings_stay_visible_with_fix_without_a_token_fix_crash
    code = "path: \"os/%{facts.osfamily}.yaml\"\n"
    write_source(code, path: 'example.yaml')
    assert_cli_failure('--fix', '--only-checks=legacy_facts', @file)
    assert_includes @output, 'legacy_facts: warning:'
    refute_includes @output, 'Whoops!'
    assert_equal code, source
  end

  def native_checks
    PuppetLint.configuration.check_object.reject { |name, _| name.to_s.start_with?('project_') }
  end

  def test_every_active_native_fixer_has_an_execution_case_or_an_explicit_refusal
    native = native_checks
    active = native.select do |name, klass|
      PuppetLint.configuration.public_send("#{name}_enabled?") && klass.new.respond_to?(:fix)
    end
    assert_equal (SAMPLES.keys + %i[right_to_left_relationship puppet_url_without_modules]).sort, active.keys.sort
  end
end
