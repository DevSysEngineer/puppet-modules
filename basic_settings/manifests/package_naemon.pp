class basic_settings::package_naemon (
  Enum['list','822']  $deb_version,
  Boolean             $enable,
  String              $os_parent,
  String              $os_version
) {
  # Check if we need newer format for APT
  if ($deb_version == '822') {
    $file = '/etc/apt/sources.list.d/naemon.sources'
  } else {
    $file = '/etc/apt/sources.list.d/naemon.list'
  }

  # Set keyrings file
  $key = '/usr/share/keyrings/naemon.gpg'

  if ($enable) {
    # Get variables
    case $os_parent {
      'ubuntu': {
        $url = "https://download.opensuse.org/repositories/home:/naemon/xUbuntu_${os_version}"
      }
      default: {
        $url = "https://download.opensuse.org/repositories/home:/naemon/Debian_${os_version}"
      }
    }

    # Get source
    if ($deb_version == '822') {
      $source  = "Types: deb\nURIs: ${url}\nSuites: /\nSigned-By:${key}\n"
    } else {
      $source = "deb [signed-by=${key}] ${url} /\n"
    }

    # Install naemon repo
    exec { 'package_naemon_source':
      command => "/usr/bin/printf \"# Managed by puppet\n${source}\" > ${file}; /usr/bin/curl -fsSL https://build.opensuse.org/projects/home:naemon/signing_keys/download?kind=gpg | gpg --dearmor | tee ${key} >/dev/null; chmod 644 ${key}; /usr/bin/apt-get update",
      unless  => "[ -e ${file} ]",
      require => Package['apt', 'apt-transport-https', 'curl'],
    }
  } else {
    # Remove naemon repo
    exec { 'package_naemon_source':
      command => "/usr/bin/bash -c '/usr/bin/rm ${file} && /usr/bin/apt-get update'",
      onlyif  => "[ -e ${file} ]",
      require => Package['apt'],
    }

    # Remove naemon key
    file { 'package_naemon_key':
      ensure => absent,
      path   => $key,
    }
  }
}
