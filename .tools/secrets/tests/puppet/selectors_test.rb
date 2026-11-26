# frozen_string_literal: true

require_relative '../test_helper'

# Exercise the text boundary and the Puppet gate on the same synthetic selector.
class PuppetSelectorsTest < SecretsTest
  VARIABLE = '$sample_token'
  MANIFEST = <<~PUPPET
    class demo(Hash $record) {
      #{VARIABLE} = $record['mode'] ? {
        default => $record['entry'],
      }
      if $record['enabled'] {
        # Report the worker's status.
        notice($record)
      }
    }
  PUPPET

  def test_selector_ends_before_the_following_conditional
    %w[if unless].each do |keyword|
      source = MANIFEST.sub('if ', "#{keyword} ")
      scan(write('demo.pp', source))
      assert_complete_scan
      copy = sanitized
      assert_includes copy, "#{VARIABLE} = '[REDACTED]'"
      refute_includes copy, "$record['entry']"
      assert_includes copy, "#{keyword} $record['enabled']"
    end
  end

  def test_selector_with_only_references_passes_the_puppet_gate
    scan('--puppet', write('demo.pp', MANIFEST))
    assert_puppet_clean
  end

  def test_hash_inside_a_multiline_string_keeps_its_closing_quote
    source = MANIFEST.sub('notice($record)', "notice(\"first line\n# second line\")")
    path = write('demo.pp', source)
    scan(path)
    assert_complete_scan
    scan('--puppet', path)
    assert_puppet_clean
  end

  def test_literal_selector_result_is_rejected_by_puppet
    literal = 'synthetic-selector-result'
    path = write('demo.pp', MANIFEST.sub("$record['entry']", "'#{literal}'"))
    scan('--puppet', path)
    assert_complete_scan
    assert_includes @report.fetch('files').first.fetch('findings'),
                    { 'line' => 3, 'rule' => 'puppet_hardcoded_value', 'kind' => 'value' }
    assert_masked(literal)
  end

  def test_incomplete_or_ambiguous_expressions_remain_unbounded
    unclosed = MANIFEST.lines.take(3).join
    extra_operand = MANIFEST.sub("  }\n", "  } + {}\n")
    commented_closer = MANIFEST.sub(/    #.*/m, "    # }\n")
    [unclosed, extra_operand, commented_closer].each do |source|
      scan(write('demo.pp', source))
      assert_equal 2, @status.exitstatus
      refute @report.fetch('complete')
      assert_includes @report.fetch('files').first.fetch('errors'), 'unbounded_sensitive_value'
    end
  end
end
