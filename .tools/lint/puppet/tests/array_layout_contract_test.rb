# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'array_layout_support'

# Exercise canonical array plans through the native check and fix lifecycle.
class ArrayLayoutContractTest < Minitest::Test
  include ArrayLayoutSupport

  def test_ports
    assert_array_fix("$ports = [\n  22,\n  80,\n  443,\n  8443,\n]\n", "$ports = [22, 80, 443, 8443]\n")
  end

  def test_paths
    assert_array_fix("$configuration_files = ['/etc/example/application/production/main.conf', " \
                     "'/etc/example/application/production/fallback.conf']\n", fixture('array_contract/paths_after'))
  end

  def test_packages
    packages = %w[apt-listchanges debconf debian-archive-keyring debian-keyring dirmngr libssl-dev needrestart ucf
                  unattended-upgrades]
    assert_array_fix("$packages = [#{packages.map do |name|
      "'#{name}'"
    end.join(', ')}]\n", fixture('array_contract/packages_after'))
  end

  def test_array_width_is_inclusive_and_counts_unicode_characters
    [59, 60, 61].each do |width|
      value = "'#{'é' * (width - 4)}'"
      compact = "$values = [#{value}]\n"
      multiline = "$values = [\n  #{value},\n]\n"
      expected = width <= 60 ? compact : multiline
      assert_array_fix(width <= 60 ? multiline : compact, expected)
    end
  end

  def test_full_line_width_includes_prefix_suffix_and_indent
    [139, 140, 141].each do |width|
      prefix = "  $#{'v' * (width - 12)} = "
      compact = "#{prefix}[1, 2]\n"
      assert_equal width, compact.chomp.length
      multiline = "#{prefix}[\n    1,\n    2,\n  ]\n"
      assert_array_fix(width <= 140 ? multiline : compact, width <= 140 ? compact : multiline)
    end
  end

  def test_full_line_width_includes_the_suffix
    suffix = " # #{'s' * 124}"
    assert_array_fix("$x = [1, 2, 3]#{suffix}\n", "$x = [\n  1,\n  2,\n  3,\n]#{suffix}\n")
  end

  def test_empty_and_noncanonical_compact_arrays
    assert_array_fix("$values = [\n]\n", "$values = []\n")
    assert_array_fix("$values = [ 'first','second', ]\n", "$values = ['first', 'second']\n")
    assert_array_fix("$values = [\n  'first',\n]\n", "$values = ['first']\n")
    assert_clean_passes("$#{'v' * 150} = []\n")
  end
end
