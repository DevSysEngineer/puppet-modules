# frozen_string_literal: true

require_relative 'test_helper'
require 'project_tools/module_dependencies/openvox_adapter'

# The adapter uses the supplied paths without applying manifests, facts or personal settings.
class DependencyIsolationTest < Minitest::Test
  include DependencyTestSupport

  CONFIGURED_SCAN = <<~RUBY
    require 'puppet'
    Puppet.initialize_settings(['--config', ARGV.shift], true, false)
    raise 'Synthetic configuration was not loaded' unless Puppet[:basemodulepath] == ARGV.shift
    require 'project_tools/module_dependencies/cli'
    exit ProjectTools::ModuleDependencies::Cli.run(ARGV)
  RUBY

  def test_puppetlib_and_personal_configuration_do_not_replace_explicit_paths
    write_module('library', version: '2.0.0')
    write_module('library', version: '9.0.0', base: @second)
    write_root([dependency])
    @env['PROJECT_TOOLS_MODULEPATH'] = @first
    @env['PUPPETLIB'] = @second
    scan_with_personal_configuration
  end

  def scan_with_personal_configuration
    config = File.join(@project, 'puppet.conf')
    File.write(config, "[main]\nbasemodulepath = #{@second}\n")
    output, errors, status = Open3.capture3(@env, RbConfig.ruby, '-e', CONFIGURED_SCAN,
                                            config, @second, '--junit', @report, chdir: @project)
    assert_equal 0, status.exitstatus, output + errors
    assert_equal '0', read_suite.attributes['failures']
  end

  def test_existing_runtime_configuration_cannot_replace_explicit_paths
    write_module('library', version: '2.0.0')
    write_module('library', version: '9.0.0', base: @second)
    result = ProjectTools::ModuleDependencies::Result.new
    with_modulepath_setting do
      ProjectTools::ModuleDependencies::OpenvoxAdapter.new([@first], result).scan do |environment|
        assert_equal '2.0.0', environment.module_by_forge_name('example/library').version
      end
      assert_equal 0, result.status
    end
  end

  def with_modulepath_setting
    previous = Puppet[:modulepath]
    Puppet[:modulepath] = @second
    yield
  ensure
    Puppet[:modulepath] = previous if previous
  end

  def test_disappearing_selected_module_is_an_execution_error
    directory = write_module('library')
    environment = Puppet::Node::Environment.create(:dependency_disappearance, [@first])
    mod = environment.modules.first
    FileUtils.remove_entry(directory)
    result = ProjectTools::ModuleDependencies::Result.new
    ProjectTools::ModuleDependencies::ModuleDependencies.new(result).check(mod)
    assert_equal 2, result.status
    assert_equal :metadata_error, result.problems.first[:reason]
  end

  def test_adapter_restores_environment_settings_and_log_destinations
    write_module('library')
    with_existing_settings do
      result = ProjectTools::ModuleDependencies::Result.new
      destinations = Puppet::Util::Log.destinations.dup
      ProjectTools::ModuleDependencies::OpenvoxAdapter.new([@first], result).scan { |_environment| nil }
      assert_equal 0, result.status
      assert_equal @second, ENV.fetch('PUPPETLIB')
      assert_equal :warning, Puppet[:strict]
      assert_equal destinations, Puppet::Util::Log.destinations
    end
  end

  def with_existing_settings
    previous = ENV.fetch('PUPPETLIB', nil)
    strict = Puppet[:strict]
    ENV['PUPPETLIB'] = @second
    Puppet[:strict] = :warning
    yield
  ensure
    previous ? ENV['PUPPETLIB'] = previous : ENV.delete('PUPPETLIB')
    Puppet[:strict] = strict
  end

  def test_unexpected_native_comparison_error_preserves_earlier_findings
    write_module('consumer', dependencies: [dependency('example-missing')])
    result = ProjectTools::ModuleDependencies::Result.new
    ProjectTools::ModuleDependencies::OpenvoxAdapter.new([@first], result).scan { raise 'synthetic failure' }
    assert_equal 2, result.status
    assert_equal(%i[failure error], result.problems.map { |problem| problem[:kind] })
  end
end
