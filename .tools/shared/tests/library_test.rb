# frozen_string_literal: true

require_relative '../test_support/bootstrap'
require 'project_tools/shared/modulepath'
require 'project_tools/shared/junit_report'
require 'rexml/document'
require 'stringio'

# Guard the policy-free runtime boundary and the extracted interfaces.
class SharedLibraryTest < Minitest::Test
  def test_paths_preserve_order_duplicates_and_spaces
    Dir.mktmpdir('shared paths ') do |root|
      second = File.join(root, 'second')
      FileUtils.mkdir_p(second)
      paths = [second, root, second]
      assert_equal paths.map { |path| File.realpath(path) },
                   ProjectTools::Shared::Modulepath.parse(paths.join(File::PATH_SEPARATOR))
    end
  end

  def test_invalid_paths_are_rejected
    [nil, '', '.', '/missing-synthetic-directory', "#{Dir.pwd}:", ":#{Dir.pwd}"].each do |value|
      assert_raises(ArgumentError) { ProjectTools::Shared::Modulepath.parse(value) }
    end
  end

  def test_xml_envelope_escapes_fields_and_preserves_producer_counts
    output = StringIO.new
    ProjectTools::Shared::JunitReport.write(output, name: 'example & suite', tests: 1, failures: 1, errors: 0) do |xml|
      xml.testcase(name: 'requires < 3') { xml.failure('value > 4 & "quoted"') }
    end
    suite = REXML::Document.new(output.string).root.elements['testsuite']
    assert_xml_fields(suite)
  end

  def assert_xml_fields(suite)
    assert_equal 'example & suite', suite.attributes['name']
    assert_equal '1', suite.attributes['failures']
    assert_equal 'value > 4 & "quoted"', suite.elements['testcase/failure'].text
  end

  def test_require_has_no_tool_or_test_initialization
    script = <<~RUBY
      require 'project_tools/shared/modulepath'
      require 'project_tools/shared/junit_report'
      abort 'tool loaded' if defined?(Puppet) || defined?(PuppetLint) || defined?(Minitest)
    RUBY
    output, errors, status = Open3.capture3(RbConfig.ruby, '-e', script)
    assert status.success?, output + errors
    assert_empty output + errors
  end
end
