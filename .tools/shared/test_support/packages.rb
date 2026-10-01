# frozen_string_literal: true

require 'bundler'
require 'rubygems/package'

# Build independent, offline consumer bundles without loading a tool's policies.
module ProjectToolsPackageSupport
  ROOT = File.expand_path('../../..', __dir__)

  ISOLATED_VARIABLES = %w[DEBUG RUBYOPT RUBYLIB PROJECT_TOOLS_MODULEPATH PROJECT_METADATA_MODULES_PATH GITHUB_ACTION
                          PUPPETLIB PROJECT_METADATA_PREFIX CODECLIMATE_REPORT_FILE
                          MINITEST_REPORTERS_REPORTS_DIR].freeze

  def consumer_environment
    @gem_home = File.join(@project, 'installed gems')
    @env = Bundler.unbundled_env.reject do |key, _|
      key.start_with?('BUNDLE_') || ISOLATED_VARIABLES.include?(key)
    end
  end

  def build_install(tool, name)
    package = File.join(@project, "#{name}.gem")
    run_success('gem', 'build', "#{name}.gemspec", '--output', package,
                directory: File.join(ROOT, '.tools', tool))
    run_success('gem', 'install', '--local', '--ignore-dependencies', '--no-document',
                '--install-dir', @gem_home, package)
  end

  def copy_package_source(tool, name, checkout)
    root = File.join(ROOT, '.tools', tool)
    spec = Gem::Specification.load(File.join(root, "#{name}.gemspec"))
    [*spec.files, "#{name}.gemspec"].each do |relative|
      destination = File.join(checkout, '.tools', tool, relative)
      FileUtils.mkdir_p(File.dirname(destination))
      FileUtils.cp(File.join(root, relative), destination)
    end
  end

  def prepare_environment
    @env['PATH'] = [Gem.bindir, @env.fetch('PATH')].join(File::PATH_SEPARATOR)
    @env.merge!('BUNDLE_IGNORE_CONFIG' => '1', 'BUNDLE_USER_HOME' => File.join(@project, 'bundle home'),
                'GEM_HOME' => @gem_home, 'GEM_PATH' => ([@gem_home] + Gem.path).join(File::PATH_SEPARATOR))
    # New offline lockfiles cannot obtain registry checksums from installed gems.
    @env['BUNDLE_LOCKFILE_CHECKSUMS'] = 'false'
  end

  def teardown
    FileUtils.remove_entry(@project) if @project
  end

  def write(relative, content)
    path = File.join(@project, relative)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, content)
  end

  def read(relative)
    File.read(File.join(@project, relative))
  end

  def command(*command, directory: @project)
    @output, @errors, @status = Open3.capture3(@env, *command, chdir: directory, unsetenv_others: true)
  end

  def run_success(*command, **options)
    command(*command, **options)
    assert @status.success?, @output + @errors
  end
end
