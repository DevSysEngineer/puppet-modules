# frozen_string_literal: true

# Isolated project fixtures execute the real Rakefile and catalog runner.
module CiTaskSupport
  include ProjectToolsPackageSupport

  def setup
    @project = Dir.mktmpdir('ci-task-boundaries-')
    write('Rakefile', File.read(File.join(ROOT, 'Rakefile')))
    FileUtils.mkdir_p(File.join(@project, '.tools/catalog'))
    FileUtils.cp_r(File.join(ROOT, '.tools/catalog/lib'), File.join(@project, '.tools/catalog/lib'))
    write_scenarios
    write_probe
    write('invoke.rb', invocation)
  end

  def write_scenarios
    write('modules/sample/manifests/init.pp', "class sample {}\n")
    write('modules/sample/tests/manifests/default.pp', "include sample\n")
    write('modules/sample/tests/facts/synthetic.json', '{}')
    write('examples/example.pp', "notify { 'example': }\n")
    %w[.tools vendor concat debconf reboot stdlib].each { |dir| write("#{dir}/excluded.pp", 'class {') }
  end

  def write_probe
    write('.tools/sample/tests/probe_test.rb', <<~RUBY)
      require #{File.join(ROOT, '.tools/shared/test_support/bootstrap').dump}
      File.open('events', 'a') { |file| file.puts 'tools' }
      class PhaseProbe < Minitest::Test
        def test_probe
          assert true
        end
      end
    RUBY
  end

  def invocation
    <<~RUBY
      require 'rake'
      require 'json'
      load 'Rakefile'
      original = method(:sh)
      define_singleton_method(:sh) do |*arguments, **options, &block|
        if arguments.take(4) == %w[bundle exec project-tools-secrets --puppet]
          File.open('events', 'a') { |file| file.puts 'scan' }
          File.write('selection.json', JSON.generate(arguments.drop(4)))
          if ENV['PROBE_SCAN_STATUS']
            status = Struct.new(:exitstatus) do
              def signaled? = false
            end.new(Integer(ENV.fetch('PROBE_SCAN_STATUS')))
            block.call(false, status)
            next
          end
        end
        original.call(*arguments, **options, &block)
      end
      task = Rake::Task[ARGV.fetch(0)]
      File.write('prerequisites.json', JSON.generate(task.all_prerequisite_tasks.map(&:name)))
      task.invoke(*ARGV.drop(1))
    RUBY
  end

  def invoke(task, report = nil, code: nil)
    env = { 'TEST' => nil, 'TESTOPTS' => nil, 'PROBE_SCAN_STATUS' => code&.to_s,
            'MINITEST_REPORTERS_REPORTS_DIR' => 'reports',
            'PROJECT_TOOLS_MODULEPATH' => File.join(@project, 'modules') }
    @output, @errors, @status = Open3.capture3(env, Gem.ruby, 'invoke.rb', task, *Array(report), chdir: @project)
  end

  def events
    File.exist?(File.join(@project, 'events')) ? read('events').lines.map(&:strip) : []
  end
end
