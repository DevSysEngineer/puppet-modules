# frozen_string_literal: true

require 'rake/testtask'
require 'project_tools/shared/test_task'

def project_manifests
  FileList['**/*.pp'].exclude('.tools/**/*', 'vendor/**/*', 'concat/**/*', 'debconf/**/*',
                              'reboot/**/*', 'stdlib/**/*')
end

{
  'test:tools' => ['Run all tool tests', '.tools/**/tests/**/*_test.rb'],
  'test:metadata' => ['Run metadata tool tests', '.tools/metadata/tests/**/*_test.rb'],
  'test:ruby_lint' => ['Run Ruby lint package tests', '.tools/lint/ruby/tests/**/*_test.rb'],
  'test:repository' => ['Run repository integration checks', '.tools/repository/tests/**/*_test.rb'],
  'test:lint' => ['Run linter tests', '.tools/lint/puppet/tests/**/*_test.rb'],
  'test:catalog' => ['Run catalog runner tests', '.tools/catalog/tests/**/*_test.rb'],
  'test:syntax' => ['Run Puppet syntax tests', '.tools/syntax/tests/**/*_test.rb'],
  'test:secrets' => ['Run sensitive-data scanner tests', '.tools/secrets/tests/**/*_test.rb'],
  'test:shared' => ['Run shared library tests', '.tools/shared/tests/**/*_test.rb'],
  'test:dependencies' => ['Run dependency tool tests', '.tools/dependencies/tests/**/*_test.rb']
}.each do |name, (description, pattern)|
  test_task = Rake::TestTask.new(name) do |task|
    task.description = description
    task.pattern = FileList.new(pattern).exclude(%r{(?:\A|/)fixtures/})
    task.warning = false
  end
  ProjectTools::Shared::TestTask.wrap(
    test_task,
    groups: [%w[.tools/repository/tests/parser_rake_reporting_test.rb
                .tools/repository/tests/consumer_parser_rake_reporting_test.rb]],
    software: -> { { tool: 'project-tools-tests', runtime: true, version: File.read('VERSION').strip } }
  )
end

namespace :secrets do
  desc 'Reject hardcoded secrets in first-party Puppet manifests'
  task :puppet do
    abort 'No Puppet manifests selected.' if project_manifests.empty?
    sh 'bundle', 'exec', 'project-tools-secrets', '--puppet', *project_manifests, verbose: false do |ok, status|
      raise SignalException, status.termsig if status.signaled?

      exit status.exitstatus unless ok
    end
  end
end

desc 'Check Puppet secrets, then run all tool tests locally'
task test: 'secrets:puppet'
task test: 'test:tools'

def project_syntax_jobs(args)
  require 'project_tools/shared/rake_jobs'
  jobs = ProjectTools::Shared::RakeJobs.count
  abort 'Parallel syntax requires an explicit JUnit report.' if jobs > 1 && !args[:junit]

  jobs
end

def project_syntax_report(report, manifests, jobs)
  sh 'bundle', 'exec', 'syntax-junit', '--jobs', jobs.to_s, report, *manifests, verbose: false do |ok, status|
    raise SignalException, status.termsig if status.signaled?

    exit status.exitstatus unless ok
  end
end

namespace :syntax do
  desc 'Check first-party Puppet syntax, optionally writing JUnit to the supplied path'
  task :puppet, [:junit] do |_task, args|
    jobs = project_syntax_jobs(args)
    manifests = project_manifests
    if args[:junit]
      project_syntax_report(args[:junit], manifests, jobs)
    else
      require 'project_tools/shared/console'
      console = ProjectTools::Shared::Console.new('Puppet syntax',
                                                  scope: "#{manifests.size} files selected",
                                                  software: { tool: 'project-tools-syntax', runtime: true })
      console.during do
        abort 'No Puppet manifests selected.' if manifests.empty?
        sh RbConfig.ruby, ProjectTools::Shared::PuppetRuntime.detect.executable, 'parser', 'validate',
           '--color=false', *manifests, verbose: false do |ok, status|
          console.finish(status: ok ? 'PASSED' : 'Result not classified', execution: ok ? 'complete' : 'unknown',
                         facts: ["Original exit status: #{status}", 'Native parser diagnostics are shown above.'])
          raise SignalException, status.termsig if status.signaled?

          exit status.exitstatus unless ok
        end
      end
    end
  end
end

namespace :catalog do
  desc 'Compile module scenarios and check dependency cycles, optionally writing JUnit to the supplied path'
  task :compile, [:junit] do |_task, args|
    require_relative '.tools/catalog/lib/catalog'
    runner = ProjectTools::Catalog.new(jobs: ProjectTools::Shared::RakeJobs.count)
    status = runner.run(report: args[:junit])
    exit status unless status.zero?
  end
end

task default: :test
