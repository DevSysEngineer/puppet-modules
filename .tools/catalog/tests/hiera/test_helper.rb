# frozen_string_literal: true

require_relative '../test_helper'
require 'yaml'

# Keep synthetic Hiera input beside the runner tests that inspect its behavior.
module CatalogHieraSupport
  include CatalogTestSupport

  def fixture(name, data = {}, config: nil, base: @root)
    directory = File.join(base, name, 'tests', 'hiera')
    FileUtils.mkdir_p(File.join(directory, 'data'))
    config ||= { 'version' => 5, 'defaults' => { 'datadir' => 'data', 'data_hash' => 'yaml_data' },
                 'hierarchy' => [{ 'name' => 'Test data', 'path' => 'common.yaml' }] }
    File.write(File.join(directory, 'hiera.yaml'), YAML.dump(config))
    File.write(File.join(directory, 'data', 'common.yaml'), YAML.dump(data))
    directory
  end

  def hiera_input(name)
    File.read(File.join(__dir__, 'fixtures', name))
  end

  def compile_modules
    run_catalogs(nil, report: File.join(@root, 'reports', 'catalog.xml'))
  end

  def assert_counts(tests, failures, errors)
    assert_equal([tests, failures, errors].map(&:to_s),
                 %w[tests failures errors].map { |key| report_suite.attributes[key] })
  end
end
