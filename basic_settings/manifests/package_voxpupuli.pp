# @summary Manages the Vox Pupuli OpenVox APT repository.
#
# This private helper writes or removes the OpenVox APT source and signing key.
# It is called by `basic_settings` when OpenVox packages should be available for Puppet agent or server installation.
# Requires Exec['basic_settings_source_reload'] to refresh APT after removing an alternative source file.
#
# @example Internal use from basic_settings
#   class { 'basic_settings::package_voxpupuli':
#     deb_version => 'list',
#     enable      => true,
#     os_parent   => 'debian',
#     os_version  => '12',
#   }
#
# @param deb_version
#   APT source format to manage: `list` or `822`. The alternative format is always removed, including when disabled.
#
# @param enable
#   Creates the repository and imports its key when `true`; removes both when `false`.
#
# @param os_parent
#   Distribution family used in the OpenVox repository suite.
#
# @param os_version
#   Distribution major version appended to the repository suite.
#
# @param puppet_version
#   OpenVox APT component major, `8` or `9`; undef selects 8. This does not enable the source, pin packages,
#   or request an installed agent upgrade or downgrade.
#
# @api private
class basic_settings::package_voxpupuli (
  Enum['list', '822']      $deb_version,
  Boolean                  $enable,
  String                   $os_parent,
  String                   $os_version,
  Optional[Enum['8', '9']] $puppet_version = undef,
) {
  # Keep the effective repository default here for direct and parent-class use.
  $puppet_version_effective = $puppet_version ? {
    undef   => '8',
    default => $puppet_version,
  }

  # Provide the shell and source-list tools on both installation and removal paths.
  $source_packages = ['apt', 'coreutils', 'dash']
  ensure_packages($source_packages, {
    'ensure'          => 'installed',
    'install_options' => ['--no-install-recommends', '--no-install-suggests'],
  })

  # Check if we need newer format for APT
  if ($deb_version == '822') {
    # Use the .sources filename for a deb822 repository definition.
    $file = '/etc/apt/sources.list.d/voxpupuli.sources'
    $alternative = '/etc/apt/sources.list.d/voxpupuli.list'
  } else {
    # Use the .list filename for a one-line APT repository definition.
    $file = '/etc/apt/sources.list.d/voxpupuli.list'
    $alternative = '/etc/apt/sources.list.d/voxpupuli.sources'
  }

  # Remove the unused source format on both lifecycle paths before any source exec refreshes APT.
  file { $alternative:
    ensure  => absent,
    require => Package[$source_packages],
    before  => Exec['package_voxpupuli_source'],
    notify  => Exec['basic_settings_source_reload'],
  }

  # Even cleanup without a source exec change must refresh APT after source handling has finished.
  Exec['package_voxpupuli_source'] -> Exec['basic_settings_source_reload']

  # Set keyrings file
  $key = '/usr/share/keyrings/openvox-keyring.gpg'

  # Escape repository paths before using them in exec commands and guards.
  $file_shell = stdlib::shell_escape($file)
  $key_shell = stdlib::shell_escape($key)

  # Install the OpenVox repository when enabled and remove its managed source otherwise.
  if ($enable) {
    # Install the download and signing tools only while this repository is enabled.
    $repository_packages = ['apt-transport-https', 'ca-certificates', 'curl', 'diffutils']
    ensure_packages($repository_packages, {
      'ensure'          => 'installed',
      'install_options' => ['--no-install-recommends', '--no-install-suggests'],
    })
    $repository_required_packages = concat($source_packages, $repository_packages)

    # Set URL
    $url = 'https://apt.voxpupuli.org'

    # Get source
    if ($deb_version == '822') {
      # Render the selected repository and signing key in deb822 format.
      $source  = "Types: deb\\nURIs: ${url}\\nSuites: ${os_parent}${os_version}\\nComponents: openvox${puppet_version_effective}\\nSigned-By:${key}\\n" # lint:ignore:140chars Keep the literal source format intact.
    } else {
      # Render the selected repository and signing key in one-line APT format.
      $source = "deb [signed-by=${key}] ${url} ${os_parent}${os_version} openvox${puppet_version_effective}\\n"
    }

    # Escape generated repo content as literal newline sequences before the shell writes it.
    $source_shell = stdlib::shell_escape("# Managed by puppet\\n${source}")

    # Install voxpupuli repo
    exec { 'package_voxpupuli_source':
      provider => shell,
      command  => "/usr/bin/printf %b ${source_shell} > ${file_shell}; /usr/bin/curl -fsSLo ${key_shell} https://apt.voxpupuli.org/openvox-keyring.gpg; chmod 644 ${key_shell}; /usr/bin/apt-get update", # lint:ignore:140chars
      unless   => "/usr/bin/test -e ${file_shell} && /usr/bin/printf %b ${source_shell} | /usr/bin/cmp -s - ${file_shell}",
      require  => Package[$repository_required_packages],
    }
  } else {
    # Remove voxpupuli repo
    exec { 'package_voxpupuli_source':
      command => "/usr/bin/rm ${file_shell} && /usr/bin/apt-get update",
      onlyif  => "/usr/bin/test -e ${file_shell}",
      require => Package[$source_packages],
    }

    # Remove voxpupuli key
    file { 'package_voxpupuli_key':
      ensure => absent,
      path   => $key,
    }
  }
}
