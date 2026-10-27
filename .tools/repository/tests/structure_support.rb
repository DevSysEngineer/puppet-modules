# frozen_string_literal: true

# Inspect declared component interfaces within the existing repository structure tests.
module RepositoryStructureSupport
  def gemspecs(root)
    Dir.glob('.tools/**/*.gemspec', base: root).reject { |path| path.include?('/fixtures/') }.to_h do |path|
      spec = Gem::Specification.load(File.join(root, path))
      refute_nil spec, "Cannot load gemspec: #{path}"
      [path, spec]
    end
  end

  def component_errors(root)
    selections = File.read(File.join(root, 'Rakefile')).scan(%r{(\.tools/[\w/-]+)/tests/\*\*/\*_test\.rb}).flatten
    components = (selections + gemspecs(root).keys.map { |path| File.dirname(path) } + cli_components(root)).uniq
    components.flat_map { |component| component_file_errors(root, component, selections) }
  end

  def cli_components(root)
    Dir.glob('.tools/**/bin/*', base: root).reject { |path| path.include?('/fixtures/') }
       .map { |path| File.dirname(File.dirname(path)) }
  end

  def component_file_errors(root, component, selections)
    errors = %w[README.md AGENTS.md].filter_map do |name|
      path = File.join(component, name)
      "Missing component file: #{path}" unless File.file?(File.join(root, path))
    end
    tests = Dir.glob("#{component}/tests/**/*_test.rb", base: root).reject { |path| path.include?('/fixtures/') }
    errors << "Missing tool tests: #{component}/tests/**/*_test.rb" if tests.empty?
    errors << "Missing Rake test selection: #{component}/tests/**/*_test.rb" unless selections.include?(component)
    errors
  end

  def executable_errors(root, path)
    full_path = File.join(root, path)
    return ["Missing CLI executable: #{path}"] unless File.file?(full_path)

    errors = []
    errors << "Expected mode 0755: #{path}" unless (File.stat(full_path).mode & 0o7777) == 0o755
    errors << "Expected Ruby shebang: #{path}" unless File.open(full_path, &:gets).to_s.chomp == '#!/usr/bin/env ruby'
    errors
  end

  def registered_executable_errors(root)
    gemspecs(root).flat_map do |path, spec|
      next [] if spec.executables.empty?

      errors = spec.bindir == 'bin' ? [] : ["Expected bindir bin: #{path}"]
      errors + spec.executables.flat_map do |name|
        executable_errors(root, File.join(File.dirname(path), spec.bindir, name))
      end
    end
  end

  def assert_task_selection(task, expected)
    # A targeted outer test run must not override this independent task selection.
    environment = { 'TEST' => nil, 'TESTOPTS' => nil }
    output, errors, status = Open3.capture3(environment, Gem.ruby, Gem.bin_path('rake', 'rake'), task,
                                            chdir: @directory)
    assert status.success?, output + errors
    assert_equal expected, output.lines.map(&:strip).grep(%r{\A\.tools/}).sort, task
  end

  def assert_cli_loads(path)
    assert_empty executable_errors(ProjectToolsPackageSupport::ROOT, path)
    help = %w[-h --help].map { |flag| assert_cli_help(path, flag) }
    assert_equal help.first, help.last, "#{path}: -h and --help must agree"
    output, errors, status = Open3.capture3(File.join(ProjectToolsPackageSupport::ROOT, path), '--unknown-option',
                                            chdir: @project)
    refute_equal 0, status.exitstatus, "#{path} must reject unknown options"
    refute_empty output + errors, "#{path} must explain invalid arguments"
    assert_empty Dir.children(@project), "#{path} help and invalid options must not create files"
  end

  def assert_cli_help(path, flag)
    output, errors, status = Open3.capture3(File.join(ProjectToolsPackageSupport::ROOT, path), flag, chdir: @project)
    assert_equal 0, status.exitstatus, "#{path} #{flag}: #{output}#{errors}"
    assert_empty errors, "#{path} #{flag} must keep stderr empty"
    assert_match(/\AUsage:/i, output, "#{path} #{flag} must show usage without running the tool")
    assert_includes output, '-h, --help', "#{path} must document both help options"
    refute_match(/\[(?:START|ERROR|PASSED|FAILED)\]/, output, "#{path} must not run a check for help")
    output
  end
end
