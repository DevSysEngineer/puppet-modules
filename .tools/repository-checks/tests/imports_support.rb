# frozen_string_literal: true

# Synthetic project and package-source preparation for repository integration tests.
module ImportsSupport
  def write_consumer
    write('VERSION', "7.4.0\n")
    data = { name: 'example-control', version: '7.4.0', author: 'Synthetic maintainers',
             summary: 'Synthetic project', license: 'Apache-2.0', source: 'https://example.org/control',
             project_page: 'https://example.org/control', issues_url: 'https://example.org/control/issues',
             dependencies: [], requirements: [], operatingsystem_support: [], tags: [] }
    write('metadata.json', JSON.generate(data))
    write('modules/profile/metadata.json', JSON.generate(data.merge(name: 'example-profile')))
    write('manifests/site.pp', "$values = concat([1], [2])\n")
    @env.merge!('PROJECT_TOOLS_MODULEPATH' => File.join(@project, 'modules'),
                'PROJECT_METADATA_MODULES_PATH' => 'modules', 'PROJECT_METADATA_PREFIX' => 'example')
  end

  def git_worktree
    repository = File.join(@project, 'source')
    run_success('git', 'clone', '--quiet', '--no-hardlinks', ProjectToolsPackageSupport::ROOT, repository)
    run_success('git', '-C', repository, 'rev-parse', 'HEAD')
    revision = @output.strip
    prepare_git_worktree(repository)
    [repository, revision]
  end

  def prepare_git_worktree(repository)
    self.class::PACKAGES.each do |tool, name|
      FileUtils.rm_rf(File.join(repository, '.tools', tool))
      copy_package_source(tool, name, repository)
    end
    # Exercise the pending working tree without creating a commit or inventing a published revision.
    @env['BUNDLE_LOCAL__PROJECT___TOOLS___SHARED'] = repository
    @env['BUNDLE_DISABLE_LOCAL_BRANCH_CHECK'] = 'true'
  end

  def replace_consumer_dependency(dependency)
    @env.delete('BUNDLE_FROZEN')
    @env.delete('RUBYOPT')
    @env.delete('RUBYLIB')
    # Offline gem caches do not provide registry checksums for a new lockfile.
    @env['BUNDLE_LOCKFILE_CHECKSUMS'] = 'false'
    FileUtils.rm_f(File.join(@project, 'Gemfile.lock'))
    write('Gemfile', "source 'https://rubygems.org'\n#{dependency}\n")
    run_success('bundle', 'install', '--local')
    run_success('bundle', 'info', '--path', 'lint-project')
    @installed = @output.strip
    @env['BUNDLE_FROZEN'] = 'true'
  end
end
