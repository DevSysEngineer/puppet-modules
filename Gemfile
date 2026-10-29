# frozen_string_literal: true

source 'https://rubygems.org'

gem 'lint-project', path: '.tools/lint/puppet', require: false
gem 'project-tools-metadata', path: '.tools/metadata', require: false
gem 'project-tools-module', path: '.tools/module', require: false
gem 'project-tools-ruby-lint', path: '.tools/lint/ruby', require: false
gem 'project-tools-secrets', path: '.tools/secrets', require: false
gem 'project-tools-shared', path: '.tools/shared', require: false
gem 'project-tools-syntax', path: '.tools/syntax', require: false

# Select one Puppet-compatible runtime; the lockfile fixes the tested resolution.
gem 'openvox', require: false
# The selected runtime uses JSON::PRETTY_STATE_PROTOTYPE and Ruby no longer bundles syslog.
gem 'json', '< 3', require: false
gem 'syslog', '~> 0.4', platforms: :ruby, require: false

gem 'metadata-json-lint', require: false
gem 'minitest'
gem 'minitest-reporters'
gem 'rake'
gem 'rexml'
