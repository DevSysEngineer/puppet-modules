# frozen_string_literal: true

require_relative '../test_helper'

# Every supported signature is exercised through native detection, correction and parsing.
class DuplicateFunctionRegistryTest < Minitest::Test
  include LintTestSupport

  RULE = :project_duplicate_function_calls
  CASES = {
    'String' => ['42', "42, '%04d'", 'true', 'undef', '4.2', '[1, 2]', "{'a' => 1}"],
    'Integer' => ["'42'", "'0xff', 16", "'-42', 10, true"],
    'Float' => ["'42.5'", "'-42.5', true"],
    'Boolean' => ["'yes'"],
    'Array' => ["{'a' => 42}", "{'a' => 42}, false", '[1, 2]', '[1, 2], true', '42, true'],
    'Hash' => ["{'a' => 42}", "['a', 42]", "[['a', [42]]]"],
    'downcase' => ["'ABC'"], 'upcase' => ["'abc'"], 'capitalize' => ["'abc'"],
    'strip' => ["' abc '"], 'lstrip' => ["' abc'"], 'rstrip' => ["'abc '"],
    'chomp' => ["'abc'"], 'chop' => ["'abc'"],
    'sprintf' => ["'%s=%d', 'a', 42"],
    'join' => ["['a', 'b']", "['a', 'b'], ':'"],
    'split' => ["'a:b', ':'", "'a:b', /:/"],
    'regsubst' => ["'abc', 'b', 'x'", "'abc', 'b', 'x', 'GI'", "'abc', /b/, 'x'", "'abc', /b/, 'x', 'G'"],
    'keys' => ["{'a' => 42}"], 'values' => ["{'a' => 42}"],
    'dig' => ["{'a' => [42]}, 'a', 0"],
    'length' => ["'abc'", '[1, 2]', "{'a' => 1}"],
    'size' => ["'abc'", '[1, 2]', "{'a' => 1}"],
    'empty' => ["''", '[]', '{}'],
    'flatten' => ['[1, [2]]'], 'sort' => ['[2, 1]', "['b', 'a']"], 'unique' => ['[1, 1]'],
    'abs' => ['-42', '-4.2'], 'floor' => ['4.2'], 'ceiling' => ['4.2'], 'round' => ['4.2'],
    'stdlib::to_json' => ["{'a' => [42]}"],
    'stdlib::to_json_pretty' => ["{'a' => [42]}", "{'a' => undef}, true"],
    'stdlib::to_yaml' => ["{'a' => [42]}"],
    'stdlib::merge' => ["{'a' => 1}, {'b' => 2}"],
    'stdlib::shell_escape' => ["'a b'"], 'stdlib::sha256' => ["'abc'", '42'],
    'stdlib::seeded_rand' => ["42, 'example'"],
    'shell_join' => ["['a', 'b c']"], 'shell_split' => ["'a b'"],
    'base64' => ["'encode', 'abc'", "'decode', 'YWJj'", "'encode', 'abc', 'strict'",
                 "'decode', 'YWJj', 'default'", "'encode', 'abc', 'urlsafe'", "'encode', 'abc', 'default'",
                 "'decode', 'YWJj', 'strict'", "'decode', 'YWJj', 'urlsafe'"],
    'basename' => ["'/example/a.txt'", "'/example/a.txt', '.txt'"], 'dirname' => ["'/example/a'"]
  }.freeze

  CASES.each do |name, forms|
    define_method("test_#{name.tr(':', '_')}_supported_forms_and_unsafe_nested_argument") do
      forms.each do |arguments|
        call = "#{name}(#{arguments})"
        variable = "$#{name.split('::').last.sub(/\Ato_/, '').downcase}_result"
        before = resource(call)
        after = "#{variable} = #{call}\n#{resource(variable)}"
        assert_fix(before, after, count: 1)
      end
      assert_clean_passes(resource("#{name}(lookup('example::unknown'))"))
    end
  end

  def resource(call)
    "notify { 'example':\n  message => [#{call}, #{call}],\n}\n"
  end

  def test_unreviewed_overloads_remain_excluded
    ["Integer({'from' => '42'})", "Float({'from' => '4.2'})", "String(42, {Integer => '%d'})",
     "Hash([[['a'], 42]], 'tree')", "Hash([[['a'], 42]])", "downcase(['A'])", 'capitalize(42)',
     "chomp(['a'])", "sort('cba')", "unique('abc')", 'flatten(1, [2])',
     "regsubst('abc', 'a', 'x', 'G', 'U')", "regsubst('abc', /a/, 'x', 'I')",
     "sprintf('%<x>s', {'x' => 'a'})", 'empty(42)', 'length(Binary(\'abc\'))',
     "stdlib::to_json_pretty({}, true, {'indent' => ' '})", "stdlib::to_yaml({}, {'indentation' => 4})",
     'stdlib::seeded_rand(0, \'example\')', 'stdlib::merge([1]) |$memo, $value| { {} }',
     'shell_join([42])', "base64('other', 'abc')", "dirname('')", "stdlib::basename('/example')"].each do |call|
      assert_clean_passes(resource(call))
    end
  end
end
