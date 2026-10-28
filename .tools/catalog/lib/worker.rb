# frozen_string_literal: true

require 'json'
require 'tmpdir'
require 'puppet'
require 'project_tools/shared/modulepath'
require_relative 'coverage'
require_relative 'hiera'

# Reserve stdout for the result; native output stays on the diagnostic stream.
result_output = $stdout.dup
$stdout.reopen($stderr)
result = {}
compiling = false

# A fresh process and settings directory prevent Puppet state leaking between scenarios.
begin
  modulepath, manifest, facts_path, module_directory, hiera = ARGV
  paths = ProjectTools::Shared::Modulepath.parse(modulepath)

  code = File.read(manifest)
  facts = JSON.parse(File.read(facts_path))
  raise ArgumentError, 'Expected a JSON object of facts.' unless facts.is_a?(Hash)

  ENV.delete('PUPPETLIB')
  Dir.mktmpdir('catalog-compile-') do |directory|
    Puppet.initialize_settings(['--confdir', directory, '--vardir', directory, '--logdir', directory,
                                '--codedir', directory, '--color=false'])
    Puppet::Util::Log.newdestination(:console)
    Puppet[:hiera_config] = File.join(directory, 'hiera.yaml')
    File.write(Puppet[:hiera_config], "version: 5\nhierarchy: []\n", mode: 'w', perm: 0o600)
    Puppet[:node_terminus] = 'plain'
    Puppet[:code] = code
    environment = Puppet::Node::Environment.create(:catalog_check, paths)
    environment_directory = File.join(directory, 'environment')
    FileUtils.mkdir_p(environment_directory, mode: 0o700)
    node = Puppet::Node.new('node.example.test', environment: environment)
    node.fact_merge(Puppet::Node::Facts.new(node.name, facts))
    unless hiera.nil? || hiera.empty?
      scope = Puppet::Parser::Compiler.new(node).topscope
      scope.set_facts(node.facts.values)
      ProjectTools::Catalog::HieraFixture.new(hiera).copy_to(environment_directory, scope)
    end
    # The environment provider resolves its own hiera.yaml through this directory loader.
    loader = Puppet::Environments::StaticDirectory.new(environment.name, environment_directory, environment)
    compiling = true
    catalog = Puppet.override(environments: loader) { Puppet::Parser::Compiler.compile(node) }
    compiling = false
    result[:resources] = catalog.resources.size
    unless module_directory.nil? || module_directory.empty?
      result[:coverage] = ProjectTools::Catalog::Coverage.new(module_directory).result(catalog)
    end
  end
rescue Puppet::Error => e
  # The native compiler logs its own exception, including source location.
  warn e.message unless compiling
  exit 1
rescue StandardError => e
  warn "Compiler could not run: #{e.class}: #{e.message}"
  exit 2
ensure
  result_output.puts JSON.generate(result)
  result_output.close
end
