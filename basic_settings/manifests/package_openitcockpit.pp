class basic_settings::package_openitcockpit (
  Enum['list','822']  $deb_version,
  Boolean             $enable,
  String              $os_parent,
  String              $os_name
) {
  # Check if we need newer format for APT
  if ($deb_version == '822') {
    $file = '/etc/apt/sources.list.d/openitcockpit.sources'
  } else {
    $file = '/etc/apt/sources.list.d/openitcockpit.list'
  }

  # Set keyrings file
  $key = '/usr/share/keyrings/openitcockpit.gpg'

  if ($enable) {
    # Set url
    $url = "https://packages5.openitcockpit.io/openitcockpit/${os_name}/stable"

    # Get source
    if ($deb_version == '822') {
      $source  = "Types: deb\nURIs: ${url}\nSuites: ${os_name}\nComponents: main\nSigned-By:${key}\n"
    } else {
      $source = "deb [signed-by=${key}] ${url} ${os_name} main\n"
    }

    # Install openitcockpit repo
    exec { 'package_openitcockpit_source':
      command => "/usr/bin/printf \"# Managed by puppet\n${source}\" > ${file}; /usr/bin/curl -fsSL https://packages5.openitcockpit.io/repokey.txt | tee ${key} >/dev/null; chmod 644 ${key}; /usr/bin/apt-get update",
      unless  => "[ -e ${file} ]",
      require => Package['apt', 'apt-transport-https', 'curl'],
    }
  } else {
    # Remove openitcockpit repo
    exec { 'package_openitcockpit_source':
      command => "/usr/bin/bash -c '/usr/bin/rm ${file} && /usr/bin/apt-get update'",
      onlyif  => "[ -e ${file} ]",
      require => Package['apt'],
    }

    # Remove openitcockpit key
    file { 'package_openitcockpit_key':
      ensure => absent,
      path   => $key,
    }
  }
}
