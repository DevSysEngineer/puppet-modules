# frozen_string_literal: true

require_relative '../../../shared/test_support/bootstrap'
require 'rubocop'
require_relative '../lib/project_tools/ruby_lint/runtime_coupling'

# Exercise the shipped AST rule with synthetic code, independently of any Puppet installation.
class RuntimeCouplingTest < Minitest::Test
  def offenses(source, file = 'example.rb')
    config = RuboCop::Config.new('Project/RuntimeCoupling' => { 'Enabled' => true })
    cop = RuboCop::Cop::Project::RuntimeCoupling.new(config)
    team = RuboCop::Cop::Team.new([cop], config, raise_error: true)
    team.investigate(RuboCop::ProcessedSource.new(source, 3.2, "/tmp/#{file}")).offenses
  end

  def test_direct_runtime_loading_selection_and_dependencies_are_rejected
    ["require 'puppet'", "require 'puppet/pops'", "Gem.bin_path('openvox', 'puppet')",
     "Gem.loaded_specs['puppet']", "spec.add_dependency 'openvox', '~> 8.29'",
     "spec.add_dependency 'puppet'"].each do |source|
      refute_empty offenses(source), source
    end
  end

  def test_exact_runtime_guards_and_indirect_assignments_are_rejected
    ["Puppet.version == '8.29.0'", "'9.0.0' != Puppet.version",
     "version = Puppet.version; version == '8.29.0'",
     "runtime = ProjectTools::Shared::PuppetRuntime.detect; version = runtime.version; version == '9.0.0'",
     "ProjectTools::Shared::PuppetRuntime.detect.version.eql?('9.0.0')"].each do |source|
      refute_empty offenses(source), source
    end
  end

  def test_project_choice_unrelated_versions_and_explained_bounds_are_allowed
    assert_empty offenses("gem 'puppet', require: false", 'Gemfile')
    assert_empty offenses("schema_version == '1.0.0'")
    assert_empty offenses("require 'project_tools/shared/puppet_runtime'")
    assert_empty offenses("require 'puppet'", 'fixtures/runtime.rb')
    assert_empty offenses("# runtime-compatibility: API removed before this release.\ngem 'puppet', '>= 8'", 'Gemfile')
    assert_empty offenses("# runtime-compatibility: Tracked upstream defect.\nPuppet.version == '8.0.0'")
    refute_empty offenses("gem 'puppet', '~> 8'", 'Gemfile')
    refute_empty offenses("# runtime-compatibility: reason\nGem.bin_path('openvox', 'puppet')")
  end
end
