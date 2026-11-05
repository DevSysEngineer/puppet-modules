# frozen_string_literal: true

require_relative '../../test_support/bootstrap'
require_relative '../../test_support/parallel_plan'

# Check selection invariants independently of test discovery and execution.
class ParallelPlanTest < Minitest::Test
  def test_round_robin_preserves_native_load_order_and_covers_selection_once
    files = %w[z.rb c.rb a.rb d.rb b.rb]
    plan = ProjectTools::ParallelPlan.new(files, jobs: 2)
    assert_equal [%w[c.rb a.rb z.rb].sort_by { |file| files.index(file) }, %w[d.rb b.rb]], plan.batches
    assert_equal files.tally, plan.batches.flatten.tally
  end

  def test_parser_consumer_group_does_not_insert_unselected_members
    parent = 'parent.rb'
    consumer = 'consumer.rb'
    groups = [[parent, consumer]]
    plan = ProjectTools::ParallelPlan.new([consumer, 'z.rb', parent, 'a.rb'], jobs: 4, groups: groups)
    assert_equal 3, plan.effective_jobs
    assert_includes plan.batches, [consumer, parent]
    assert_equal [consumer], ProjectTools::ParallelPlan.new([consumer], jobs: 4, groups: groups).batches.first
  end

  def test_path_aliases_and_empty_selection_follow_native_require_identity
    plan = ProjectTools::ParallelPlan.new(['a.rb', './a.rb', File.join(Dir.pwd, 'a.rb'), 'b.rb'], jobs: 9)
    assert_equal [%w[a.rb], %w[b.rb]], plan.batches
    assert_empty ProjectTools::ParallelPlan.new([], jobs: 3).batches
  end

  def test_group_assignment_is_stable_when_native_order_changes
    first = ProjectTools::ParallelPlan.new(%w[c.rb a.rb b.rb d.rb], jobs: 2)
    second = ProjectTools::ParallelPlan.new(%w[d.rb b.rb a.rb c.rb], jobs: 2)
    assert_equal first.batches.map(&:sort), second.batches.map(&:sort)
    assert_equal [%w[a.rb c.rb], %w[d.rb b.rb]], second.batches
  end
end
