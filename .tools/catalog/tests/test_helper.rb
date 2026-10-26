# frozen_string_literal: true

require_relative '../../shared/test_support/bootstrap'
require_relative '../lib/catalog'
require 'json'
require 'rexml/document'
require 'stringio'

# Shared temporary inputs for the catalog runner tests.
module CatalogTestSupport
  def setup
    @root = Dir.mktmpdir('catalog runner ')
    @console = StringIO.new
    @errors = StringIO.new
    @facts = File.join(@root, 'facts.json')
    File.write(@facts, JSON.generate('os' => { 'name' => 'Debian', 'family' => 'Debian' }))
  end

  def teardown
    FileUtils.remove_entry(@root)
  end

  def scenario(name, code, facts: @facts)
    path = File.join(@root, "#{name}.pp")
    File.write(path, code)
    { name: name, manifest: path, facts: facts }
  end

  def run_catalogs(scenarios, report: nil)
    ProjectTools::Catalog.new(modulepath: @root, scenarios: scenarios, console: @console,
                              errors: @errors).run(report: report)
  end

  def report_suite
    REXML::Document.new(File.read(File.join(@root, 'reports', 'catalog.xml'))).root.elements['testsuite']
  end

  def module_inputs(name, base: @root, code: "notify { '#{name}': }")
    directory = File.join(base, name)
    FileUtils.mkdir_p(File.join(directory, 'manifests'))
    %w[facts manifests].each { |part| FileUtils.mkdir_p(File.join(directory, 'tests', part)) }
    FileUtils.cp(@facts, File.join(directory, 'tests', 'facts', 'debian.json'))
    File.write(File.join(directory, 'tests', 'manifests', 'default.pp'), code)
    directory
  end
end
