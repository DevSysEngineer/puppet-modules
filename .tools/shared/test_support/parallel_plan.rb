# frozen_string_literal: true

require 'pathname'

module ProjectTools
  # Keep native load order while assigning indivisible groups to processes.
  class ParallelPlan
    attr_reader :files, :groups, :batches, :requested_jobs

    def initialize(files, jobs:, root: Dir.pwd, groups: [])
      @requested_jobs = jobs
      raise ArgumentError, 'Worker count must be positive.' unless jobs.is_a?(Integer) && jobs.positive?

      @root = File.expand_path(root)
      @atomic_groups = atomic_groups(groups)
      @files = files.uniq { |file| File.expand_path(file, @root) }
      @groups = @files.group_by { |file| group(file) }
      distribute
      raise 'Parallel selection differs from native selection.' unless @batches.flatten.tally == @files.tally
    end

    def distribute
      assignments = @groups.keys.sort.each_with_index.to_h { |key, index| [key, index % effective_jobs] }
      @batches = Array.new(effective_jobs) do |index|
        @files.select { |file| assignments.fetch(group(file)) == index }
      end
    end

    def effective_jobs
      [requested_jobs, groups.size].min
    end

    private

    def atomic_groups(groups)
      normalized = groups.map { |group| group.map { |file| relative(file) } }
      members = normalized.flatten
      if normalized.any?(&:empty?) || members.uniq != members
        raise ArgumentError, 'Atomic groups must be disjoint and nonempty.'
      end

      normalized
    end

    def group(file)
      path = relative(file)
      @atomic_groups.find { |members| members.include?(path) }&.first || path
    end

    def relative(file)
      Pathname.new(File.expand_path(file, @root)).relative_path_from(Pathname.new(@root)).to_s
    end
  end
end
