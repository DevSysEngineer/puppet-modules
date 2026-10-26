# frozen_string_literal: true

require 'json'
require 'tmpdir'
require 'puppet'

# A fresh process and settings directory prevent Puppet state leaking between scenarios.
begin
  root, manifest, facts_path = ARGV
  raise ArgumentError, 'Expected an existing module directory.' unless root && File.directory?(root)

  code = File.read(manifest)
  facts = JSON.parse(File.read(facts_path))
  raise ArgumentError, 'Expected a JSON object of facts.' unless facts.is_a?(Hash)

  Dir.mktmpdir('catalog-compile-') do |directory|
    Puppet.initialize_settings(['--confdir', directory, '--vardir', directory, '--logdir', directory,
                                '--codedir', directory, '--color=false'])
    Puppet[:hiera_config] = File.join(directory, 'hiera.yaml')
    Puppet[:node_terminus] = 'plain'
    Puppet[:code] = code
    environment = Puppet::Node::Environment.create(:catalog_check, [File.expand_path(root)])
    node = Puppet::Node.new('node.example.test', environment: environment)
    node.fact_merge(Puppet::Node::Facts.new(node.name, facts))
    catalog = Puppet::Parser::Compiler.compile(node)
    puts "Compiled #{catalog.resources.size} resources."
  end
rescue Puppet::Error => e
  warn e.message
  exit 1
rescue StandardError => e
  warn "Compiler could not run: #{e.class}: #{e.message}"
  exit 2
end
