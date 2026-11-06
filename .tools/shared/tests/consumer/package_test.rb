# frozen_string_literal: true

require_relative 'support'

# Shipping optional testing must not initialize a framework for runtime consumers.
class SharedConsumerPackageTest < Minitest::Test
  include SharedConsumerSupport

  def test_public_task_loads_without_framework_initialization_or_runtime
    run_success('bundle', 'exec', 'ruby', '-e', <<~RUBY)
      require 'project_tools/shared/test_task'
      require 'project_tools/shared/command_pool'
      require 'project_tools/shared/atomic_file'
      abort 'framework loaded' if defined?(Minitest) || defined?(Puppet) || defined?(Rake)
      abort 'runtime dependency' if Gem.loaded_specs.key?('puppet') || Gem.loaded_specs.key?('openvox')
    RUBY
    assert_empty @output + @errors
    assert_package
  end

  def test_installed_atomic_writer_preserves_binary_bytes_and_cleans_up
    run_success('bundle', 'exec', 'ruby', '-e', <<~RUBY)
      require 'project_tools/shared/atomic_file'
      ProjectTools::Shared::AtomicFile.write('report.xml') { |output| output.binmode; output.write("new\\r\\n\\xFF") }
    RUBY
    assert_equal "new\r\n\xFF".b, File.binread(File.join(@project, 'report.xml'))
    assert_empty Dir[File.join(@project, '.project-tools-*')]
  end

  def assert_package
    package = Gem::Package.new(File.join(@project, 'project-tools-shared.gem')).spec
    refute_includes package.files, 'test_support/bootstrap.rb'
    refute_includes package.files, 'test_support/packages.rb'
    assert_empty package.files.grep(%r{\A(?:tests|results)/})
  end

  def test_path_bundle_uses_packaged_sources_for_parallel_workers
    checkout = File.join(@project, 'global-modules')
    copy_package_source('shared', 'project-tools-shared', checkout)
    source = "gem 'project-tools-shared', path: 'global-modules/.tools/shared'"
    write('Gemfile', read('Gemfile').sub("gem 'project-tools-shared'", source))
    run_success('bundle', 'install', '--local')
    run_suite(2)
    assert @status.success?, @output + @errors
    assert_includes @output, '4 tests, 12 assertions'
  end

  def test_native_fallback_does_not_evaluate_parallel_presentation
    replacement = "wrap(tests, software: -> { raise 'parallel header requested' })"
    write('Rakefile', read('Rakefile').sub('wrap(tests)', replacement))
    run_suite(2, 'TEST' => 'tests/probe0_test.rb')
    assert @status.success?, @output + @errors
    assert_includes @output, '1 tests, 3 assertions'
  end
end
