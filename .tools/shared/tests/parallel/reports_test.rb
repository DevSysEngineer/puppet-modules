# frozen_string_literal: true

require_relative 'result_support'

# Preserve valid reports and reject missing XML, inconsistent identities and filename collisions.
class ParallelReportsTest < Minitest::Test
  include ParallelResultSupport

  def with_report(id = 'worker-00', name = 'Alpha')
    config, data = result(id, name)
    config['reports'] = File.dirname(config['result'])
    data['junit_files'] = ['TEST-report.xml']
    File.write(File.join(config['reports'], 'TEST-report.xml'), report_xml(name))
    [config, data]
  end

  def report_xml(name)
    <<~XML
      <testsuites><testsuite name="#{name}" tests="1" assertions="1" failures="0" errors="0" skipped="0">
      <testcase classname="#{name}" name="test_contract" assertions="1"/></testsuite></testsuites>
    XML
  end

  def test_missing_corrupt_and_inconsistent_junit_are_errors
    [nil, '<broken', '<testsuites/>'].each do |xml|
      results = ProjectTools::ParallelResults.new
      config, data = with_report
      path = File.join(config['reports'], 'TEST-report.xml')
      xml ? File.write(path, xml) : File.delete(path)
      assert_empty accept(results, config, data)
      assert_equal 'ERROR', results.status
      assert_equal 'incomplete', results.execution
    end
  end

  def test_publication_rejects_collisions_and_preserves_already_published_reports
    results = ProjectTools::ParallelResults.new
    destination = File.join(@project, 'published')
    FileUtils.mkdir_p(destination)
    results.publish(accept(results, *with_report), destination)
    results.publish(accept(results, *with_report('worker-01', 'Beta')), destination)
    assert_equal report_xml('Alpha'), read('published/TEST-report.xml')
    assert_match(/collision/, results.errors.join)
  end

  def test_publication_failure_is_not_success_and_leaves_other_files
    results = ProjectTools::ParallelResults.new
    destination = File.join(@project, 'published')
    FileUtils.mkdir_p(File.join(destination, 'TEST-report.xml'))
    File.write(File.join(destination, 'other.xml'), '<preserved/>')
    results.publish(accept(results, *with_report), destination)
    assert_equal 'ERROR', results.status
    assert_equal 'incomplete', results.execution
    assert_preserved_publication(destination)
  end

  def assert_preserved_publication(destination)
    assert_equal '<preserved/>', File.read(File.join(destination, 'other.xml'))
    assert_equal %w[TEST-report.xml other.xml], Dir.children(destination).sort
  end
end
