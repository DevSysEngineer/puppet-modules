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

  if ($enable) {
    # Set URL
    $url = 'https://apt.voxpupuli.org'

    # Get source
    if ($deb_version == '822') {
      $source  = "Types: deb\nURIs: ${url}\nSuites: ${os_parent}${os_version}\nComponents: openvox8\nSigned-By:${key}\n"
    } else {
      $source = "deb [signed-by=${key}] ${url} ${os_parent}${os_version} openvox8\n"
    }

    # Install voxpupuli repo
    exec { 'package_voxpupuli_source':
      command => "/usr/bin/printf \"# Managed by puppet\n${source}\" > ${file}; /usr/bin/curl -fsSLo ${key} https://apt.voxpupuli.org/openvox-keyring.gpg; chmod 644 ${key}; /usr/bin/apt-get update",
      unless  => "[ -e ${file} ]",
      require => Package['apt', 'apt-transport-https', 'curl'],
    }
  } else {
    # Remove voxpupuli repo
    exec { 'package_voxpupuli_source':
      command => "/usr/bin/bash -c '/usr/bin/rm ${file} && /usr/bin/apt-get update'",
      onlyif  => "[ -e ${file} ]",
      require => Package['apt'],
    }

    # Remove nginx key
    file { 'package_nginx_key':
      ensure => absent,
      path   => $key,
    }
  }
}
