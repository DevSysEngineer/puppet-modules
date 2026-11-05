# frozen_string_literal: true

require_relative '../test_helper'

# Validate configuration before replacing reports.
class CatalogParallelOptionsTest < Minitest::Test
  include CatalogTestSupport

  def test_invalid_limit_is_rejected_before_report_mutation
    report = stale_report
    [0, -1, '1.5', 'invalid'].each do |jobs|
      assert_raises(ArgumentError) { ProjectTools::Catalog.new(modulepath: @root, jobs: jobs).run(report: report) }
      assert_equal '<previous/>', File.read(report)
    end
  end
end
