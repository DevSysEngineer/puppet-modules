# frozen_string_literal: true

# Shared assertions for the workflow and the executable consumer examples.
module CiPhaseSupport
  def assert_phase_graph(jobs, rows, source:)
    assert_equal rows.map(&:first), jobs.keys
    rows.each do |id, name, predecessors|
      job = jobs.fetch(id)
      assert_equal name, job.fetch('name'), id
      assert_match(/^    name: (["'])#{Regexp.escape(name)}\1$/, source)
      assert_equal predecessors, job.fetch('needs', []), id
      assert_success_required(job, id)
    end
    assert_gate_ancestry(jobs, rows)
  end

  def assert_gate_ancestry(jobs, rows)
    rows.drop(1).each { |id,| assert_includes ancestors(jobs, id), rows.first.first }
  end

  def assert_success_required(job, id)
    %w[if continue-on-error strategy].each { |key| refute job.key?(key), "#{id}: #{key}" }
    job.fetch('steps').each { |step| refute step.key?('continue-on-error'), id }
  end

  def ancestors(jobs, id)
    jobs.fetch(id).fetch('needs', []).flat_map { |parent| [parent, *ancestors(jobs, parent)] }.uniq
  end

  def assert_missing_edges_rejected(jobs, rows, source:)
    rows.each do |id, _name, predecessors|
      predecessors.each do |parent|
        changed = Marshal.load(Marshal.dump(jobs))
        changed.fetch(id).fetch('needs').delete(parent)
        assert_raises(Minitest::Assertion, "#{id} must require #{parent}") do
          assert_phase_graph(changed, rows, source: source)
        end
      end
    end
  end

  def assert_job_bypasses_rejected(jobs, rows, source:)
    jobs.each_key do |id|
      [{ 'if' => '${{ always() }}' }, { 'if' => '${{ !cancelled() }}' },
       { 'continue-on-error' => true }].each do |bypass|
        changed = Marshal.load(Marshal.dump(jobs))
        changed.fetch(id).merge!(bypass)
        assert_raises(Minitest::Assertion) { assert_phase_graph(changed, rows, source: source) }
      end
    end
  end
end
