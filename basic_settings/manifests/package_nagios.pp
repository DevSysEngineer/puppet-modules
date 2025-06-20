class basic_settings::package_nagios (
  Enum['list','822']  $deb_version,
  Boolean             $enable,
  String              $os_parent,
  String              $os_name
) {
  # Check if we need newer format for APT
  if ($deb_version == '822') {
    $file = '/etc/apt/sources.list.d/nagios.sources'
  } else {
    $file = '/etc/apt/sources.list.d/nagios.list'
  }

  # Set keyrings file
  $key = '/usr/share/keyrings/nagios.gpg'

  if ($enable) {
    # Get source
    if ($deb_version == '822') {
      $source  = "Types: deb\nURIs: https://repo.nagios.com/deb/${os_name}\nSuites: /\nSigned-By:${key}\n"
    } else {
      $source = "deb [signed-by=${key}] https://repo.nagios.com/deb/${os_name} /\n"
    }

    # Install nagios repo
    exec { 'package_nagios_source':
      command => "/usr/bin/printf \"# Managed by puppet\n${source}\" > ${file}; /usr/bin/curl -fsSL https://repo.nagios.com/GPG-KEY-NAGIOS-V3 | gpg --dearmor | tee ${key} >/dev/null; chmod 644 ${key}; /usr/bin/apt-get update",
      unless  => "[ -e ${file} ]",
      require => Package['apt', 'apt-transport-https', 'curl', 'gnupg'],
    }
  } else {
    # Remove nagios repo
    exec { 'package_nagios_source':
      command => "/usr/bin/bash -c '/usr/bin/rm ${file} && /usr/bin/apt-get update'",
      onlyif  => "[ -e ${file} ]",
      require => Package['apt'],
    }

    # Remove nagios key
    file { 'package_nagios_key':
      ensure => absent,
      path   => $key,
    }
  }
}
