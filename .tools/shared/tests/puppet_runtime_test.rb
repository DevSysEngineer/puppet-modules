# frozen_string_literal: true

require_relative '../test_support/bootstrap'
require 'project_tools/shared/puppet_runtime'
require 'project_tools/shared/console'
require 'stringio'

# Synthetic gem specifications exercise selection, not compatibility of external runtime releases.
class SharedPuppetRuntimeTest < Minitest::Test
  Runtime = ProjectTools::Shared::PuppetRuntime
  Spec = Struct.new(:name, :version, :full_gem_path, :full_require_paths, :executables)

  def setup
    @root = Dir.mktmpdir('runtime simulation ')
    FileUtils.mkdir_p(File.join(@root, 'lib'))
    FileUtils.mkdir_p(File.join(@root, 'bin'))
    File.write(File.join(@root, 'lib/puppet.rb'), '')
    File.write(File.join(@root, 'bin/puppet'), '')
  end

  def teardown
    FileUtils.remove_entry(@root)
  end

  def specification(name, version)
    Spec.new(name, Gem::Version.new(version), @root, [File.join(@root, 'lib')], ['puppet'])
  end

  def test_simulated_releases_select_the_activated_gem_and_exact_executable
    [%w[puppet 8.10.0], %w[openvox 8.29.0], %w[openvox 9.0.0], %w[openvox 42.0.0.pre]].each do |name, version|
      assert_selected_runtime(name, version)
    end
  end

  def assert_selected_runtime(name, version)
    spec = specification(name, version)
    runtime = Runtime.detect(specs: { name => spec }, features: [File.join(@root, 'lib/puppet.rb')])
    assert_equal version, runtime.version
    assert_equal(name == 'openvox' ? 'OpenVox' : 'Puppet', runtime.name)
    resolver = lambda do |*arguments|
      assert_equal [name, 'puppet', version], arguments
      File.join(@root, 'bin/puppet')
    end
    assert_equal File.join(@root, 'bin/puppet'), runtime.executable(resolver: resolver)
    assert_version_log(runtime)
  end

  def assert_version_log(runtime)
    output = StringIO.new
    ProjectTools::Shared::Console.software('synthetic', version: '1.2.3', runtime: runtime, output: output)
    assert_equal ['Tool: synthetic 1.2.3', "Runtime: #{runtime}", "Ruby: #{RUBY_VERSION}"],
                 output.string.lines.map(&:chomp)
  end

  def test_missing_conflicting_and_shadowed_runtime_fail
    assert_raises(Runtime::Error) { Runtime.detect(specs: {}, features: []) }
    specs = %w[puppet openvox].to_h { |name| [name, specification(name, '8.0.0')] }
    assert_raises(Runtime::Error) { Runtime.detect(specs: specs, features: []) }
    assert_raises(Runtime::Error) do
      Runtime.detect(specs: specs.slice('puppet'), features: ['/missing/lib/puppet.rb'])
    end
  end

  def test_existing_foreign_runtime_code_is_rejected
    foreign = File.join(@root, 'foreign/lib/puppet.rb')
    FileUtils.mkdir_p(File.dirname(foreign))
    File.write(foreign, '')
    error = assert_raises(Runtime::Error) do
      Runtime.detect(specs: { 'puppet' => specification('puppet', '8.0.0') }, features: [foreign])
    end
    assert_includes error.message, 'does not belong'
  end

  def test_module_extensions_are_allowed_but_shadowed_core_files_are_not
    plugin = File.join(@root, 'module/lib/puppet/functions/synthetic.rb')
    FileUtils.mkdir_p(File.dirname(plugin))
    File.write(plugin, '')
    runtime = Runtime.detect(specs: { 'puppet' => specification('puppet', '8.0.0') }, features: [plugin])
    assert_equal '8.0.0', runtime.version
    core = File.join(@root, 'lib/puppet/functions/synthetic.rb')
    FileUtils.mkdir_p(File.dirname(core))
    File.write(core, '')
    assert_raises(Runtime::Error) { runtime.verify_features([plugin]) }
  end

  def test_missing_or_foreign_executable_is_rejected
    runtime = Runtime.new(specification('openvox', '9.0.0'))
    assert_raises(Runtime::Error) { runtime.executable(resolver: ->(*) { '/missing/puppet' }) }
    assert_raises(Runtime::Error) { runtime.executable(resolver: ->(*) { RbConfig.ruby }) }
  end
end
