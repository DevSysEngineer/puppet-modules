# @summary Manages the Sury/Ondrej PHP APT repository.
#
# This private helper writes or removes the PHP package source. Debian and Ubuntu systems install the Sury archive
# keyring package through a root-only temporary file. Existing sources are updated when their content differs.
# Requires Exec['basic_settings_source_reload'] to refresh APT after removing an alternative source file.
#
# @example Internal use from basic_settings
#   class { 'basic_settings::package_sury':
#     deb_version => 'list',
#     enable      => true,
#     os_name     => 'bookworm',
#     os_parent   => 'debian',
#   }
#
# @param deb_version
#   APT source format to manage: `list` or `822`. The alternative format is always removed, including when disabled.
#
# @param enable
#   Creates the repository and imports its key when `true`; removes repository files when `false`.
#
# @param os_name
#   Distribution codename used in the repository suite.
#
# @param os_parent
#   Distribution family used to remove the legacy Ubuntu PPA key when disabled.
#
# @api private
class basic_settings::package_sury (
  Enum['list', '822'] $deb_version,
  Boolean             $enable,
  String              $os_name,
  String              $os_parent,
) {
  # Provide the shell and source-list tools on both installation and removal paths.
  $source_packages = ['apt', 'coreutils', 'dash']
  ensure_packages($source_packages, {
    'ensure'          => 'installed',
    'install_options' => ['--no-install-recommends', '--no-install-suggests'],
  })

  # Check if we need newer format for APT
  if ($deb_version == '822') {
    # Use the .sources filename for a deb822 repository definition.
    $file = '/etc/apt/sources.list.d/sury_php.sources'
    $alternative = '/etc/apt/sources.list.d/sury_php.list'
  } else {
    # Use the .list filename for a one-line APT repository definition.
    $file = '/etc/apt/sources.list.d/sury_php.list'
    $alternative = '/etc/apt/sources.list.d/sury_php.sources'
  }

  # Remove the unused source format on both lifecycle paths before any source exec refreshes APT.
  file { $alternative:
    ensure  => absent,
    require => Package[$source_packages],
    before  => Exec['package_sury_source'],
    notify  => Exec['basic_settings_source_reload'],
  }

  # Even cleanup without a source exec change must refresh APT after source handling has finished.
  Exec['package_sury_source'] -> Exec['basic_settings_source_reload']

  # Set keyrings file
  $key = '/usr/share/keyrings/debsuryorg-archive-keyring.gpg'

  # Escape repository paths before using them in exec commands and guards.
  $file_shell = stdlib::shell_escape($file)
  $key_shell = stdlib::shell_escape($key)

  # Check if enabled
  if ($enable) {
    # Install the download and signing tools only while this repository is enabled.
    $repository_packages = ['apt-transport-https', 'bash', 'ca-certificates', 'curl', 'diffutils', 'dpkg']
    ensure_packages($repository_packages, {
      'ensure'          => 'installed',
      'install_options' => ['--no-install-recommends', '--no-install-suggests'],
    })
    $repository_required_packages = concat($source_packages, $repository_packages)

    # Debian and Ubuntu use the same Sury repository and archive keyring.
    $url = 'https://packages.sury.org/php/'

    # Get source
    if ($deb_version == '822') {
      # Render the selected repository and signing key in deb822 format.
      $source  = "Types: deb\\nURIs: ${url}\\nSuites: ${os_name}\\nComponents: main\\nSigned-By:${key}\\n"
    } else {
      # Render the selected repository and signing key in one-line APT format.
      $source = "deb [signed-by=${key}] ${url} ${os_name} main\\n"
    }

    # Escape generated repo content as literal newline sequences before the shell writes it.
    $source_shell = stdlib::shell_escape("# Managed by puppet\\n${source}")

    # Install the archive keyring through a root-only tempfile and always clean it up on exit.
    $source_install_script = "set -e; umask 077; tmpfile=\$(/usr/bin/mktemp /root/debsuryorg-archive-keyring.XXXXXX.deb) || exit 1; trap \"rm -f \\\"\$tmpfile\\\"\" EXIT; /usr/bin/curl -fsSL https://packages.sury.org/debsuryorg-archive-keyring.deb -o \"\$tmpfile\"; dpkg -i \"\$tmpfile\"; /usr/bin/printf %b ${source_shell} > ${file_shell}; /usr/bin/apt-get update" # lint:ignore:140chars

    # Reuse the Debian installation for both platforms and migrate existing source content before refreshing APT.
    $source_install_script_shell = stdlib::shell_escape($source_install_script)
    exec { 'package_sury_source':
      provider => shell,
      command  => "/usr/bin/bash -c ${source_install_script_shell}",
      unless   => "/usr/bin/test -s ${key_shell} && /usr/bin/printf %b ${source_shell} | /usr/bin/cmp -s - ${file_shell}",
      require  => Package[$repository_required_packages],
    }
  } else {
    # Remove sury php repo
    exec { 'package_sury_source':
      command => "/usr/bin/rm ${file_shell} && /usr/bin/apt-get update",
      onlyif  => "/usr/bin/test -e ${file_shell}",
      require => Package[$source_packages],
    }

    # Remove the legacy Ubuntu PPA key, retaining the package-managed archive keyring.
    if ($os_parent == 'ubuntu') {
      file { 'package_sury_key':
        ensure => absent,
        path   => '/usr/share/keyrings/sury.gpg',
      }
    }
  }
}
