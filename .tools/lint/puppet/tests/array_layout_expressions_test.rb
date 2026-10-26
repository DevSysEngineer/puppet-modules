# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'array_layout_support'
# Preserve expression content and plan nesting.
class ArrayLayoutExpressionsTest < Minitest::Test
  include ArrayLayoutSupport

  def test_every_simple_node_category_preserves_its_source_notation
    ["'text'", '"hello ${name}"', '0x10', '1.25', 'true', 'false', 'undef', '$example::value', '-12', '-1.5',
     'bare'].each do |value|
      assert_array_fix("$values = [\n  #{value},\n]\n", "$values = [#{value}]\n")
    end
  end

  def test_complex_single_line_expressions_keep_their_exact_tokens
    ['-(2 + 3)', "call( 'first' , 'second' )", '$active ? { true => 1, default => 2 }', "{ 'name' => 1 }",
     "Package['curl', 'wget']", "$facts['os']"].each do |value|
      assert_array_fix("$values = [#{value}]\n", "$values = [\n  #{value},\n]\n")
    end
  end

  def test_nested_plans_keep_layers_and_are_independent_of_original_layout
    expected = "$groups = [\n  [\n    ['curl', 'wget'],\n  ],\n  ['git', 'rsync'],\n]\n"
    ["$groups = [[['curl', 'wget']], ['git', 'rsync']]\n",
     "$groups = [\n      [[\n      'curl',\n      'wget',\n      ]], ['git', 'rsync']]\n"].each do |code|
      assert_array_fix(code, expected)
    end
    assert_array_fix("$groups = [[1]]\n", "$groups = [\n  [1],\n]\n")
  end

  def test_shared_line_budget_expands_rightmost_and_never_refolds_locally
    first = "'#{'a' * 54}'"
    second = "'#{'b' * 54}'"
    prefix = "$#{'v' * 80} = call("
    expected = "#{prefix}[\n  #{first},\n], [\n  #{second},\n])\n"
    ["#{prefix}[#{first}], [#{second}])\n",
     "#{prefix}[\n  #{first},\n], [#{second}])\n",
     "#{prefix}[#{first}], [\n  #{second},\n])\n"].each do |code|
      assert_array_fix(code, expected)
    end
  end

  def test_shared_line_budget_only_expands_the_rightmost_when_sufficient
    first = "'#{'a' * 54}'"
    second = "'#{'b' * 54}'"
    short_prefix = "$#{'v' * 30} = call("
    assert_array_fix("#{short_prefix}[#{first}], [#{second}])\n",
                     "#{short_prefix}[#{first}], [\n  #{second},\n])\n")
  end

  def test_fixed_newlines_between_arguments_are_preserved
    assert_array_fix("$x = call([\n  1,\n],\n  [\n    2,\n  ])\n", "$x = call([1],\n  [2])\n")
  end

  def test_contexts_and_resource_title_indentation
    value = "'#{'x' * 57}'"
    assert_array_fix("$x = join([#{value}], ',')\n", "$x = join([\n  #{value},\n], ',')\n")
    assert_array_fix("class example (\n  Array $x = [#{value}],\n) {}\n",
                     "class example (\n  Array $x = [\n    #{value},\n  ],\n) {}\n")
    assert_array_fix("$x = { 'names' => [#{value}] }\n", "$x = { 'names' => [\n  #{value},\n] }\n")
    assert_array_fix("file { [#{value}]:\n    ensure => absent,\n}\n",
                     "file { [\n    #{value},\n  ]:\n    ensure => absent,\n}\n")
  end

  def test_quotes_escapes_and_interpolation_are_opaque
    ["'comma,#[]'", %q('quote\'s'), %q("line\ntext"), %q{"${join([1,2], ',')}"}].each do |value|
      assert_array_fix("$x = [\n  #{value},\n]\n", "$x = [#{value}]\n")
    end
    assert_clean_passes(<<~PUPPET)
      $x = "${join([1,2], ',')}"
    PUPPET
  end
end
