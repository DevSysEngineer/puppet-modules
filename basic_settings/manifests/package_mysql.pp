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
  $key_rebuild = "cat /usr/share/keyrings/mysql.key | gpg --dearmor | tee ${key_file} >/dev/null; chmod 644 ${key_file}; /usr/bin/apt-get update" #lint:ignore:140chars

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

    # Rebuild key
    exec { 'package_mysql_key_build':
      command     => $key_rebuild,
      onlyif      => "[ -e ${key_file} ]",
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
      command => "/usr/bin/printf \"# Managed by puppet\n${source_content}\" > ${source_file}; ${key_rebuild}", #lint:ignore:140chars
      unless  => "[ -e ${source_file} ]",
      require => [Package['apt', 'apt-transport-https', 'gnupg'], File['package_mysql_key_filename']],
    }

    # Set preference
    exec { 'package_mysql_preference':
      command => "/usr/bin/printf \"# Managed by puppet\nPackage: mysql*\nPin: origin repo.mysql.com\nPin-Priority: 990\n\" > ${file_preference}; chmod 644 ${file_preference}; /usr/bin/apt-get update", #lint:ignore:140chars
      unless  => "[ -e ${file_preference} ]",
      require => Exec['package_mysql_source'],
    }
  } else {
    # Remove mysql repo
    exec { 'package_mysql_source':
      command => "/usr/bin/bash -c '/usr/bin/rm ${source_file} && /usr/bin/apt-get update'",
      onlyif  => "[ -e ${source_file} ]",
      require => Package['apt'],
    }

    # Remove mysql preference
    exec { 'package_mysql_preference':
      command => "/usr/bin/bash -c '/usr/bin/rm ${file_preference} && /usr/bin/apt-get update'",
      onlyif  => "[ -e ${file_preference} ]",
      require => Package['apt'],
    }

    # Remove MySQL key
    file { 'package_mysql_key_filename':
      ensure => absent,
      path   => '/usr/share/keyrings/mysql.key',
    }
    file { 'package_mysql_key':
      ensure => absent,
      path   => $key,
    }
  }
}
