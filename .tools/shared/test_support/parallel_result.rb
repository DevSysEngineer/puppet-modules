# frozen_string_literal: true

module ProjectTools
  # Check the internal JSON schema independently of process and report publication state.
  class ParallelResult
    COUNTS = %w[tests assertions failures errors skips].freeze
    OUTCOMES = %w[passed failure error skipped].freeze
    PROBLEMS = { 'failures' => 'failure', 'errors' => 'error', 'skips' => 'skipped' }.freeze
    IDENTITY = %w[class_name test_name].freeze

    def self.check(condition, message)
      raise ArgumentError, message unless condition
    end

    def initialize(data, config)
      @data = data
      @config = config
    end

    def validate
      validate_identity
      validate_counts
      validate_findings
      validate_metadata
      validate_execution
      @data
    end

    def check(condition, message)
      self.class.check(condition, message)
    end

    def validate_identity
      check(@data.is_a?(Hash) && @data['schema_version'] == 1, 'Invalid worker schema.')
      %w[worker_id selected_files].each do |key|
        check(@data[key] == @config[key], "Worker #{key} differs from plan.")
      end
    end

    def validate_counts
      counts = @data['counts']
      check(counts.is_a?(Hash) && COUNTS.all? { |key| natural?(counts[key]) }, 'Invalid native counts.')
      check(@data['cases'].is_a?(Array) && @data['cases'].all? { |test| case?(test) }, 'Invalid testcase records.')
      compare_counts
    end

    def compare_counts
      counts = @data['counts']
      check(counts['tests'] == @data['cases'].size, 'Testcase count differs from records.')
      outcomes = @data['cases'].map { |test| test['outcome'] }.tally
      PROBLEMS.each { |key, outcome| check(counts[key] == outcomes.fetch(outcome, 0), "Inconsistent #{key} count.") }
    end

    def case?(test)
      test.is_a?(Hash) && IDENTITY.all? { |key| test[key].is_a?(String) } && OUTCOMES.include?(test['outcome'])
    end

    def validate_findings
      findings = @data['findings']
      check(findings.is_a?(Array) && findings.all? { |finding| finding?(finding) }, 'Invalid findings.')
      identities = findings.map { |finding| finding.values_at(*IDENTITY) }
      @data['cases'].reject { |test| test['outcome'] == 'passed' }.each do |test|
        check(identities.include?(test.values_at(*IDENTITY)), 'Missing native diagnosis.')
      end
    end

    def finding?(finding)
      finding.is_a?(Hash) && finding['message'].is_a?(String) &&
        IDENTITY.all? { |key| finding[key].nil? || finding[key].is_a?(String) }
    end

    def validate_metadata
      check(@data['seed'].is_a?(Integer), 'Invalid seed.')
      duration = @data['duration_seconds']
      check(duration.is_a?(Numeric) && duration.finite? && duration >= 0, 'Invalid duration.')
      validate_report_metadata
    end

    def validate_report_metadata
      check(@data['report_error'].nil? || @data['report_error'].is_a?(String), 'Invalid report error.')
      check(@data['junit_files'].is_a?(Array) && @data['junit_files'].all? { |name| report_name?(name) },
            'Invalid report file list.')
    end

    def validate_execution
      expected = @data['expected_tests']
      check(expected.nil? || natural?(expected), 'Invalid expected test count.')
      execution = @data['execution']
      check(%w[complete incomplete unknown].include?(execution), 'Invalid execution state.')
      check(expected == @data['counts']['tests'], 'Inconsistent expected count.') if execution == 'complete'
      check(expected.nil?, 'Unknown result has an expected count.') if execution == 'unknown'
    end

    def report_name?(name)
      name.is_a?(String) && name.match?(%r{\ATEST-[^/\\]+\.xml\z})
    end

    def natural?(value)
      value.is_a?(Integer) && value >= 0
    end
  end
end
