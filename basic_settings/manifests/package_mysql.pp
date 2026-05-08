class basic_settings::package_mysql (
  Enum['list','822']  $deb_version,
  Boolean             $enable,
  String              $os_parent,
  String              $os_name,
  Float               $version = 8.0
) {
  # Check if we need newer format for APT
  if ($deb_version == '822') {
    $source_file = '/etc/apt/sources.list.d/mysql.sources'
  } else {
    $source_file = '/etc/apt/sources.list.d/mysql.list'
  }
  $file_preference = '/etc/apt/preferences.d/90-mysql'

  # Set keyrings file
  $key_file = '/usr/share/keyrings/mysql.gpg'

  # Escape repository paths before using them in exec commands and guards.
  $source_file_shell = stdlib::shell_escape($source_file)
  $file_preference_shell = stdlib::shell_escape($file_preference)
  $key_file_shell = stdlib::shell_escape($key_file)
  $key_rebuild = "cat /usr/share/keyrings/mysql.key | gpg --dearmor | tee ${key_file_shell} >/dev/null; chmod 644 ${key_file_shell}; /usr/bin/apt-get update" #lint:ignore:140chars

  if ($enable) {
    # Get source name
    case $version {
      8.0: {
        $key_filename = 'mysql-8.key'
        $version_correct = $version
      }
      8.4: {
        $key_filename = 'mysql-8.key'
        $version_correct = "${version}-lts"
      }
      default: {
        $key_filename = 'mysql-7.key'
        $version_correct = $version
      }
    }

    # Get source
    if ($deb_version == '822') {
      $source_content  = "Types: deb\nURIs: https://repo.mysql.com/apt/${os_parent}\nSuites: ${os_name}\nComponents: mysql-${version_correct}\nSigned-By:${key_file}\n"
    } else {
      $source_content = "deb [signed-by=${key_file}] https://repo.mysql.com/apt/${os_parent} ${os_name} mysql-${version_correct}\n"
    }

    # Escape generated repo and preference content before the shell writes it.
    $source_content_shell = stdlib::shell_escape("# Managed by puppet\n${source_content}")
    $preference_content_shell = stdlib::shell_escape("# Managed by puppet\nPackage: mysql*\nPin: origin repo.mysql.com\nPin-Priority: 990\n")

    # Rebuild key
    exec { 'package_mysql_key_build':
      command     => $key_rebuild,
      onlyif      => "/usr/bin/test -e ${key_file_shell}",
      refreshonly => true,
      require     => Package['apt', 'apt-transport-https', 'gnupg'],
    }

    # Create MySQL key
    file { 'package_mysql_key_filename':
      ensure => file,
      path   => '/usr/share/keyrings/mysql.key',
      source => "puppet:///modules/basic_settings/mysql/${key_filename}",
      owner  => 'root',
      group  => 'root',
      mode   => '0600',
      notify => Exec['package_mysql_key_build'],
    }

    # Set source
    exec { 'package_mysql_source':
      command => "/usr/bin/printf %s ${source_content_shell} > ${source_file_shell}; ${key_rebuild}", #lint:ignore:140chars
      unless  => "/usr/bin/test -e ${source_file_shell}",
      require => [Package['apt', 'apt-transport-https', 'gnupg'], File['package_mysql_key_filename']],
    }

    # Set preference
    exec { 'package_mysql_preference':
      command => "/usr/bin/printf %s ${preference_content_shell} > ${file_preference_shell}; chmod 644 ${file_preference_shell}; /usr/bin/apt-get update", #lint:ignore:140chars
      unless  => "/usr/bin/test -e ${file_preference_shell}",
      require => Exec['package_mysql_source'],
    }
  } else {
    # Remove mysql repo
    exec { 'package_mysql_source':
      command => "/usr/bin/rm ${source_file_shell} && /usr/bin/apt-get update",
      onlyif  => "/usr/bin/test -e ${source_file_shell}",
      require => Package['apt'],
    }

    # Remove mysql preference
    exec { 'package_mysql_preference':
      command => "/usr/bin/rm ${file_preference_shell} && /usr/bin/apt-get update",
      onlyif  => "/usr/bin/test -e ${file_preference_shell}",
      require => Package['apt'],
    }

    # Remove MySQL key
    file { 'package_mysql_key_filename':
      ensure => absent,
      path   => '/usr/share/keyrings/mysql.key',
    }
    file { 'package_mysql_key':
      ensure => absent,
      path   => $key_file,
    }
  }
}
