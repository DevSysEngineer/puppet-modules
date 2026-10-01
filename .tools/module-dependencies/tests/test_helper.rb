# frozen_string_literal: true

require_relative '../../shared/test_support/bootstrap'
require 'rexml/document'
require 'project_tools/module_dependencies/cli'

# Synthetic metadata tests the tool contract without executing any Puppet module code.
module DependencyTestSupport
  def setup
    @project = Dir.mktmpdir('dependency project ')
    @first = File.join(@project, 'first modules')
    @second = File.join(@project, 'second modules')
    FileUtils.mkdir_p([@first, @second])
    write_root([])
    @env = { 'PROJECT_TOOLS_MODULEPATH' => [@first, @second].join(File::PATH_SEPARATOR),
             'PUPPETLIB' => nil, 'PROJECT_METADATA_MODULES_PATH' => nil, 'PROJECT_METADATA_PREFIX' => nil }
    @report = File.join(@project, 'reports/dependencies.xml')
  end

  def teardown
    FileUtils.remove_entry(@project)
  end

  def dependency(name = 'example-library', range = '>= 2.0.0 < 3.0.0')
    { 'name' => name, 'version_requirement' => range }
  end

  def write_root(dependencies)
    File.write(File.join(@project, 'metadata.json'), JSON.generate({ 'dependencies' => dependencies }))
  end

  def write_module(name, version: '1.0.0', dependencies: [], owner: 'example', base: @first)
    directory = File.join(base, name)
    FileUtils.mkdir_p(directory)
    data = { 'name' => "#{owner}-#{name}", 'version' => version, 'dependencies' => dependencies,
             'source' => 'https://example.org/modules', 'author' => owner, 'license' => 'Apache-2.0' }
    File.write(File.join(directory, 'metadata.json'), JSON.generate(data))
    directory
  end

  def dependency_executable
    Gem.bin_path('project-tools-module-dependencies', 'project-tools-module-dependencies')
  end

  def error_types
    junit_errors.map { |node| node.attributes['type'] }
  end

  def scan(expected)
    @output, @errors, status = Open3.capture3(@env, RbConfig.ruby,
                                              dependency_executable,
                                              '--junit', @report, chdir: @project)
    assert_equal expected, status.exitstatus, @output + @errors
    @suite = read_suite
    assert_equal 'project-tools-module-dependencies', @suite.attributes['name']
    @suite
  end

  def read_suite
    REXML::Document.new(File.read(@report)).root.elements['testsuite']
  end

  def junit_failures
    @suite.get_elements('testcase/failure')
  end

  def junit_errors
    @suite.get_elements('testcase/error')
  end

  def native_list
    output, errors, status = Open3.capture3(@env, RbConfig.ruby, Gem.bin_path('openvox', 'puppet'),
                                            'module', 'list', '--modulepath', @env.fetch('PROJECT_TOOLS_MODULEPATH'),
                                            '--strict=error', '--render-as', 'json', '--color=false', chdir: @project)
    assert_equal 0, status.exitstatus, output + errors
    JSON.parse(output)
  end
end
