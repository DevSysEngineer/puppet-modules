# frozen_string_literal: true

require_relative 'support'

# Exercise native subprocess contracts at the public Rake boundary.
class ParallelSelectionTest < Minitest::Test
  include ParallelTestSupport

  def test_native_selection_options_aliases_and_unknown_filtered_total
    %w[Alpha Beta Gamma].each { |name| probe(name) }
    %w[TESTOPTS TESTOPT TEST_OPTS TEST_OPT].each do |option|
      run_tests('2', report: 'reports', option => '--name=/Alpha/ --seed=12345 --verbose')
      assert_success
      assert_equal({ %w[Alpha test_contract passed] => 1 }, identities('reports'))
      assert_includes @output, 'Alpha#test_contract'
      assert_includes @output, 'seed=12345'
    end
  end

  def test_exclusion_has_unknown_expected_total
    %w[Alpha Beta Gamma].each { |name| probe(name) }
    run_tests('2', 'TESTOPTS' => '--exclude=/Beta/ --seed=12345')
    assert_success
    assert_includes @output, '2 tests, 2 assertions'
    assert_includes @output, 'Execution: unknown (filtered total unavailable)'
  end

  def test_explicit_file_selection_without_matching_names_publishes_no_reports
    %w[Alpha Beta Gamma].each { |name| probe(name) }
    run_tests('4', report: 'reports', 'TEST' => '.tools/sample/tests/alpha_test.rb,.tools/sample/tests/beta_test.rb',
                   'TESTOPTS' => '--name=/nobody/')
    assert_success
    assert_empty identities('reports')
    refute_includes @output, 'JUnit written:'
  end

  def test_paths_with_spaces_and_shell_characters_are_literal_arguments
    probe('Alpha', path: '.tools/sample/tests/a space_test.rb')
    probe('Beta', path: '.tools/sample/tests/b$(touch unwanted)_test.rb')
    run_tests
    assert_success
    assert_includes @output, '2 tests, 2 assertions'
    refute_path_exists File.join(@project, 'unwanted')
  end

  def test_parent_and_consumer_identities_match_serial_execution
    inherited_probes
    %w[1 4].each do |jobs|
      run_tests(jobs, report: "reports-#{jobs}")
      assert_success
    end
    assert_equal identities('reports-1'), identities('reports-4')
    assert_equal 3, identities('reports-4').size
  end

  def inherited_probes
    parent = '.tools/repository/tests/parser_rake_reporting_test.rb'
    probe('ParserRakeReportingTest', path: parent)
    write('.tools/repository/tests/consumer_parser_rake_reporting_test.rb', <<~RUBY)
      require_relative 'parser_rake_reporting_test'
      class ConsumerParserRakeReportingTest < ParserRakeReportingTest; end
    RUBY
    probe('Unrelated')
  end

  def test_invalid_jobs_do_not_run_tests_or_modify_reports
    probe('Alpha', "File.write('ran', 'yes'); assert true")
    write('reports/TEST-old.xml', '<preserved/>')
    ['', '0', '-1', 'auto', '2.5', ' 2', '+2'].each do |jobs|
      run_tests(jobs, report: 'reports')
      refute @status.success?
      assert_includes @errors, 'positive decimal integer'
      refute_path_exists File.join(@project, 'ran')
      assert_equal '<preserved/>', read('reports/TEST-old.xml')
    end
  end
end
