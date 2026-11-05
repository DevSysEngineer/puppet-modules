# frozen_string_literal: true

require_relative 'support'
require_relative '../../test_support/parallel_results'

# Independent records exercise protocol validation and native XML publication.
module ParallelResultSupport
  include ParallelTestSupport

  def result(id = 'worker-00', name = 'Alpha')
    directory = File.join(@project, id)
    FileUtils.mkdir_p(directory)
    config = { 'worker_id' => id, 'selected_files' => ["#{name}.rb"],
               'result' => File.join(directory, 'result.json'), 'reports' => nil }
    record = { 'class_name' => name, 'test_name' => 'test_contract', 'outcome' => 'passed' }
    data = native_data.merge('worker_id' => id, 'selected_files' => ["#{name}.rb"], 'cases' => [record])
    [config, data]
  end

  def native_data
    { 'schema_version' => 1, 'execution' => 'complete', 'expected_tests' => 1,
      'counts' => { 'tests' => 1, 'assertions' => 1, 'failures' => 0, 'errors' => 0, 'skips' => 0 },
      'findings' => [], 'seed' => 12_345, 'duration_seconds' => 0.1, 'junit_files' => [], 'report_error' => nil }
  end

  def accept(results, config, data, code: 0)
    File.write(config['result'], JSON.generate(data))
    status = Struct.new(:exitstatus, :signaled?).new(code, false)
    results.accept(config, status)
  end
end
