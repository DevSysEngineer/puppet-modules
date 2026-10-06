# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name = 'project-tools-metadata'
  spec.version = '0.1.0'
  spec.summary = 'Project metadata validation and VERSION synchronization with JUnit reports'
  spec.authors = ['Puppet modules maintainers']
  spec.license = 'Apache-2.0'
  spec.homepage = 'https://github.com/DevSysEngineer/puppet-modules'
  spec.required_ruby_version = '>= 3.2'
  spec.files = Dir.chdir(__dir__) { Dir['lib/**/*.rb', 'bin/*', 'README.md', 'LICENSE'] }
  spec.bindir = 'bin'
  spec.executables = ['project-tools-metadata']
  spec.require_paths = ['lib']

  spec.add_dependency 'project-tools-shared', '>= 0.1.1', '< 0.2.0'
  spec.add_dependency 'json', '>= 2.21', '< 4'
end
