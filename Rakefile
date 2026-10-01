# frozen_string_literal: true

require 'rake/testtask'

{
  test: ['Run all tool tests', '.tools/*/tests/**/*_test.rb'],
  'test:metadata' => ['Run metadata tool tests', '.tools/metadata/tests/**/*_test.rb'],
  'test:ruby_lint' => ['Run Ruby lint package tests', '.tools/ruby-lint/tests/**/*_test.rb'],
  'test:repository_checks' => ['Run repository integration checks', '.tools/repository-checks/tests/**/*_test.rb'],
  'test:lint' => ['Run linter tests', '.tools/lint/tests/**/*_test.rb'],
  'test:validate' => ['Run Puppet validator tests', '.tools/validate/tests/**/*_test.rb'],
  'test:shared' => ['Run shared library tests', '.tools/shared/tests/**/*_test.rb'],
  'test:module_dependencies' => ['Run dependency tool tests', '.tools/module-dependencies/tests/**/*_test.rb']
}.each do |name, (description, pattern)|
  Rake::TestTask.new(name) do |task|
    task.description = description
    task.pattern = pattern
    task.warning = false
  end
end

namespace :validate do
  desc 'Validate first-party Puppet manifests and write a JUnit report'
  task :puppet do
    manifests = FileList['**/*.pp'].exclude('.tools/**/*', 'vendor/**/*', 'concat/**/*', 'debconf/**/*',
                                            'reboot/**/*', 'stdlib/**/*')
    sh 'bundle', 'exec', 'validate-junit', '.tools/validate/results/validate-report.xml',
       *manifests
  end
end

task default: :test
