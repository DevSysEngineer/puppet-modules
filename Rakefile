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
  desc 'Validate first-party Puppet manifests, optionally writing JUnit to the supplied path'
  task :puppet, [:junit] do |_task, args|
    manifests = FileList['**/*.pp'].exclude('.tools/**/*', 'vendor/**/*', 'concat/**/*', 'debconf/**/*',
                                            'reboot/**/*', 'stdlib/**/*')
    if args[:junit]
      sh 'bundle', 'exec', 'validate-junit', args[:junit], *manifests, verbose: false do |ok, status|
        raise SignalException, status.termsig if status.signaled?

        exit status.exitstatus unless ok
      end
    else
      require 'project_tools/shared/console'
      console = ProjectTools::Shared::Console.new('Puppet validation', scope: "#{manifests.size} files selected")
      console.during do
        abort 'No Puppet manifests selected.' if manifests.empty?
        sh 'bundle', 'exec', 'puppet', 'parser', 'validate', '--color=false', *manifests, verbose: false do |ok, status|
          console.finish(status: ok ? 'PASSED' : 'Result not classified', execution: ok ? 'complete' : 'unknown',
                         facts: ["Original exit status: #{status}", 'Native parser diagnostics are shown above.'])
          raise SignalException, status.termsig if status.signaled?

          exit status.exitstatus unless ok
        end
      end
    end
  end
end

task default: :test
