# frozen_string_literal: true

require_relative 'test_helper'
require_relative '../../shared/test_support/packages'

# Installed scanner and writer consumers share one isolated package environment.
class ExternalSecretsTestCase < Minitest::Test
  include ProjectToolsPackageSupport

  def setup
    @project = File.realpath(Dir.mktmpdir('secrets-consumer-'))
    consumer_environment
    prepare_environment
    build_install('shared', 'project-tools-shared')
    build_install('secrets', 'project-tools-secrets')
    write('Gemfile', "source 'https://rubygems.org'\ngem 'project-tools-secrets', '= 0.4.0'\n")
    run_success('bundle', 'install', '--local')
  end
end
