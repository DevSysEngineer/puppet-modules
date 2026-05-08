class basic_settings::package_voxpupuli (
  Enum['list','822']  $deb_version,
  Boolean             $enable,
  String              $os_parent,
  String              $os_version
) {
  # Check if we need newer format for APT
  if ($deb_version == '822') {
    $file = '/etc/apt/sources.list.d/voxpupuli.sources'
  } else {
    $file = '/etc/apt/sources.list.d/voxpupuli.list'
  }

  # Set keyrings file
  $key = '/usr/share/keyrings/openvox-keyring.gpg'

  # Escape repository paths before using them in exec commands and guards.
  $file_shell = stdlib::shell_escape($file)
  $key_shell = stdlib::shell_escape($key)

  if ($enable) {
    # Set URL
    $url = 'https://apt.voxpupuli.org'

    # Get source
    if ($deb_version == '822') {
      $source  = "Types: deb\nURIs: ${url}\nSuites: ${os_parent}${os_version}\nComponents: openvox8\nSigned-By:${key}\n"
    } else {
      $source = "deb [signed-by=${key}] ${url} ${os_parent}${os_version} openvox8\n"
    }

    # Escape generated repo content before the shell writes it.
    $source_shell = stdlib::shell_escape("# Managed by puppet\n${source}")

    # Install voxpupuli repo
    exec { 'package_voxpupuli_source':
      command => "/usr/bin/printf %s ${source_shell} > ${file_shell}; /usr/bin/curl -fsSLo ${key_shell} https://apt.voxpupuli.org/openvox-keyring.gpg; chmod 644 ${key_shell}; /usr/bin/apt-get update", #lint:ignore:140chars
      unless  => "/usr/bin/test -e ${file_shell}",
      require => Package['apt', 'apt-transport-https', 'curl'],
    }
  } else {
    # Remove voxpupuli repo
    exec { 'package_voxpupuli_source':
      command => "/usr/bin/rm ${file_shell} && /usr/bin/apt-get update",
      onlyif  => "/usr/bin/test -e ${file_shell}",
      require => Package['apt'],
    }

    # Remove voxpupuli key
    file { 'package_voxpupuli_key':
      ensure => absent,
      path   => $key,
    }
  }
}
