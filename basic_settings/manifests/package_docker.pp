class basic_settings::package_docker (
  Enum['list','822']  $deb_version,
  Boolean             $enable,
  String              $os_parent,
  String              $os_name
) {
  # Check if we need newer format for APT
  if ($deb_version == '822') {
    $file = '/etc/apt/sources.list.d/docker.sources'
  } else {
    $file = '/etc/apt/sources.list.d/docker.list'
  }

  # Set keyrings file
  $key = '/usr/share/keyrings/docker.gpg'

  if ($enable) {
    # Set url
    $url = "https://download.docker.com/linux/${os_parent}"

    # Get source
    if ($deb_version == '822') {
      $source  = "Types: deb\nURIs: ${url}\nSuites: ${os_name}\nComponents: main\nSigned-By:${key}\n"
    } else {
      $source = "deb [signed-by=${key}] ${url} ${os_name} stable\n"
    }

    # Install docker repo
    exec { 'package_docker_source':
      command => "/usr/bin/printf \"# Managed by puppet\n${source}\" > ${file}; /usr/bin/curl -fsSL https://download.docker.com/linux/${os_parent}/gpg | gpg --dearmor | tee ${key} >/dev/null; chmod 644 ${key}; /usr/bin/apt-get update",
      unless  => "[ -e ${file} ]",
      require => Package['apt', 'apt-transport-https', 'curl', 'gnupg'],
    }
  } else {
    # Remove docker repo
    exec { 'package_docker_source':
      command => "/usr/bin/bash -c '/usr/bin/rm ${file} && /usr/bin/apt-get update'",
      onlyif  => "[ -e ${file} ]",
      require => Package['apt'],
    }

    # Remove docker key
    file { 'package_docker_key':
      ensure => absent,
      path   => $key,
    }
  }
}
