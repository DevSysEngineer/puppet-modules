# frozen_string_literal: true

require_relative 'metadata_support'

# Common CLI fixture preparation for the metadata regression suite.
module MetadataCliSupport
  include LintCliSupport
  include MetadataSupport

  def setup
    super
    prepare_metadata_project(@directory)
    copy_project_config(@directory)
    @modules_path = 'modules'
    FileUtils.mkdir_p(File.join(@directory, @modules_path))
  end

  def metadata(path, name: 'example-profile', version: '7.4.0')
    write_file(path, JSON.generate(project_metadata(version, name: name)))
  end

  def contents(path)
    File.read(File.join(@directory, path))
  end

  def assert_metadata_stable(paths, **options)
    before = paths.to_h { |path| [path, contents(path)] }
    scan('--fix', '.', **options)
    assert_equal(before, paths.to_h { |path| [path, contents(path)] })
    refute_includes @output, ': fixed:'
  end

  def repository_layout
    @modules_path = '.'
    modules = File.join(@directory, 'modules')
    FileUtils.rmdir(modules) if File.directory?(modules) && Dir.empty?(modules)
    write_file('.tools/lint/lint-project.gemspec', '')
    write_file('metadata.json', JSON.generate(project_metadata(name: 'puppet-modules')))
  end

  def scan(*arguments, prefix: 'example', modules_path: @modules_path)
    environment = { 'PROJECT_LINT_METADATA_PREFIX' => prefix, 'PROJECT_LINT_MODULES_PATH' => modules_path }
    capture_cli(*arguments, directory: @directory, env: environment)
  end

  def assert_metadata_error(path, message)
    assert_equal 1, @status.exitstatus, @output + @errors
    assert_includes @output, "#{path}:1:1: project_metadata: error: #{message}"
    assert_empty @errors
  end
end
