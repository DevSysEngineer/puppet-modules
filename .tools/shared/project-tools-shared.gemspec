# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name = 'project-tools-shared'
  spec.version = '0.1.1'
  spec.summary = 'Shared modulepath validation and JUnit XML for project Puppet tools'
  spec.authors = ['Puppet modules maintainers']
  spec.license = 'Apache-2.0'
  spec.homepage = 'https://github.com/DevSysEngineer/puppet-modules'
  spec.required_ruby_version = '>= 3.2'
  spec.files = Dir.chdir(__dir__) { Dir['lib/**/*.rb', 'README.md', 'LICENSE'] }
  spec.require_paths = ['lib']

  spec.add_dependency 'builder', '~> 3.3'
end
