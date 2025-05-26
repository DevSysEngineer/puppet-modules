class basic_settings::package_mongodb (
  Enum['list','822']  $deb_version,
  Boolean             $enable,
  String              $os_parent,
  String              $os_name,
  Float               $version = 8.0
) {
  # Check if we need newer format for APT
  if ($deb_version == '822') {
    $file = '/etc/apt/sources.list.d/mongodb.sources'
  } else {
    $file = '/etc/apt/sources.list.d/mongodb.list'
  }

  # Set keyrings file
  $key = '/usr/share/keyrings/mongodb.gpg'

  if ($enable) {
    # Get source
    if ($deb_version == '822') {
      $source  = "Types: deb\nURIs: https://repo.mongodb.org/apt/${os_parent}\nSuites: ${os_name}/mongodb-org/${version}\nComponents: main\nSigned-By:${key}\n"
    } else {
      $source = "deb [signed-by=${key}] https://repo.mongodb.org/apt/${os_parent} ${os_name}/mongodb-org/${version} main\n"
    }

    # Install mongodb repo
    exec { 'package_mongodb_source':
      command => "/usr/bin/printf \"# Managed by puppet\n${source}\" > ${file}; /usr/bin/curl -fsSL https://pgp.mongodb.com/server-${version}.asc | gpg --dearmor | tee ${key} >/dev/null; chmod 644 ${key}; /usr/bin/apt-get update",
      unless  => "[ -e ${file} ]",
      require => Package['apt', 'apt-transport-https', 'curl', 'gnupg'],
    }

    # Install mongodb-org-server package
    package { 'mongodb-org-server':
      ensure          => installed,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
      require         => Exec['package_mongodb_source'],
    }
  } else {
    # Remove mongodb-org-server package
    package { 'mongodb-org-server':
      ensure  => purged,
    }

    # Remove mongodb repo
    exec { 'package_mongodb_source':
      command => "/usr/bin/bash -c '/usr/bin/rm ${file} && /usr/bin/apt-get update'",
      onlyif  => "[ -e ${file} ]",
      require => [Package['apt'], Package['mongodb-org-server']],
    }

    # Remove Gitlab key
    file { 'package_mongodb_key':
      ensure => absent,
      path   => $key,
    }
  }
}
