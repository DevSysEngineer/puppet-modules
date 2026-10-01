# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name = 'project-tools-ruby-lint'
  spec.version = '0.1.0'
  spec.summary = 'Shared RuboCop profile and native Ruby lint tooling'
  spec.authors = ['Puppet modules maintainers']
  spec.license = 'Apache-2.0'
  spec.homepage = 'https://github.com/DevSysEngineer/puppet-modules'
  spec.required_ruby_version = '>= 3.2'
  spec.files = Dir.chdir(__dir__) { Dir['config/*', 'README.md', 'LICENSE'] }
  spec.add_dependency 'rubocop', '~> 1.91'
end
