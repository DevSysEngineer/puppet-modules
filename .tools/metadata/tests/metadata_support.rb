# frozen_string_literal: true

# Prepare independent project version sources without a Git repository.
module MetadataSupport
  def project_metadata(version = '7.4.0', name: 'example-control')
    {
      'name' => name, 'version' => version, 'author' => 'Synthetic maintainers',
      'summary' => 'Synthetic infrastructure project', 'license' => 'Apache-2.0',
      'source' => 'https://example.org/control', 'project_page' => 'https://example.org/control',
      'issues_url' => 'https://example.org/control/issues', 'dependencies' => [],
      'operatingsystem_support' => [{ 'operatingsystem' => 'Debian', 'operatingsystemrelease' => ['12'] }],
      'requirements' => [{ 'name' => 'puppet', 'version_requirement' => '>= 8.0.0 < 9.0.0' }],
      'tags' => ['infrastructure']
    }
  end

  def prepare_metadata_project(root, version = '7.4.0')
    prepare_version(root, version)
    File.write(File.join(root, 'metadata.json'), JSON.generate(project_metadata(version)))
  end

  def prepare_version(root, version = '7.4.0')
    File.write(File.join(root, 'VERSION'), "#{version}\n")
  end
end
