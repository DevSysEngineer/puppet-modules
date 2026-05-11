class basic_settings::package_mongodb (
  Enum['list','822']  $deb_version,
  Boolean             $enable,
  String              $os_name,
  String              $os_parent,
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

  # Escape repository paths before using them in exec commands and guards.
  $file_shell = stdlib::shell_escape($file)
  $key_shell = stdlib::shell_escape($key)

  if ($enable) {
    # Get source
    if ($deb_version == '822') {
      $source  = "Types: deb\nURIs: https://repo.mongodb.org/apt/${os_parent}\nSuites: ${os_name}/mongodb-org/${version}\nComponents: main\nSigned-By:${key}\n"
    } else {
      $source = "deb [signed-by=${key}] https://repo.mongodb.org/apt/${os_parent} ${os_name}/mongodb-org/${version} main\n"
    }

    # Escape generated repo content and key URL before the shell writes or fetches them.
    $source_shell = stdlib::shell_escape("# Managed by puppet\n${source}")
    $key_url_shell = stdlib::shell_escape("https://pgp.mongodb.com/server-${version}.asc")

    # Install mongodb repo
    exec { 'package_mongodb_source':
      command => "/usr/bin/printf %s ${source_shell} > ${file_shell}; /usr/bin/curl -fsSL ${key_url_shell} | gpg --dearmor | tee ${key_shell} >/dev/null; chmod 644 ${key_shell}; /usr/bin/apt-get update", #lint:ignore:140chars
      unless  => "/usr/bin/test -e ${file_shell}",
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
      command => "/usr/bin/rm ${file_shell} && /usr/bin/apt-get update",
      onlyif  => "/usr/bin/test -e ${file_shell}",
      require => [Package['apt'], Package['mongodb-org-server']],
    }

    # Remove Gitlab key
    file { 'package_mongodb_key':
      ensure => absent,
      path   => $key,
    }
  }
}
