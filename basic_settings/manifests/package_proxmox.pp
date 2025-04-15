class basic_settings::package_proxmox (
  Enum['list','822']  $deb_version,
  Boolean             $enable,
  String              $os_parent,
  String              $os_name
) {
  # Reload source list
  exec { 'package_proxmox_source_reload':
    command     => '/usr/bin/apt-get update',
    refreshonly => true,
  }

  # Check if we need newer format for APT
  if ($deb_version == '822') {
    $file = '/etc/apt/sources.list.d/proxmox.sources'
  } else {
    $file = '/etc/apt/sources.list.d/proxmox.list'
  }

  # Set keyrings file
  $key = '/usr/share/keyrings/proxmox.gpg'

  if ($enable) {
    # Get source
    if ($deb_version == '822') {
      $source  = "Types: deb\nURIs: http://download.proxmox.com/debian/pve\nSuites: ${os_name}\nComponents: pve-no-subscription\nSigned-By:${key}\n"
    } else {
      $source = "deb [signed-by=${key}] http://download.proxmox.com/debian/pve ${os_name} pve-no-subscription\n"
    }

    # Install proxmox repo
    exec { 'package_proxmox_source':
      command => "/usr/bin/printf \"# Managed by puppet\n${source}\" > ${file}; /usr/bin/curl -fsSLo ${key} https://enterprise.proxmox.com/debian/proxmox-release-${os_name}.gpg; chmod 644 ${key}",
      unless  => "[ -e ${file} ]",
      notify  => Exec['package_proxmox_source_reload'],
      require => [Package['apt'], Package['curl'], Package['gnupg']],
    }
  } else {
    # Remove proxmox repo
    exec { 'package_proxmox_source':
      command => "/usr/bin/rm ${file}",
      onlyif  => "[ -e ${file} ]",
      notify  => Exec['package_proxmox_source_reload'],
      require => Package['apt'],
    }

    # Remove proxmox key
    file { 'package_proxmox_key':
      ensure => absent,
      path   => $key,
    }
  }
}
