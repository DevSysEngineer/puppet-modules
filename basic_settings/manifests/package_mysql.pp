class basic_settings::package_mysql (
  Enum['list','822']  $deb_version,
  Boolean             $enable,
  String              $os_parent,
  String              $os_name,
  Float               $version = 8.0
) {
  # Check if we need newer format for APT
  if ($deb_version == '822') {
    $file = '/etc/apt/sources.list.d/mysql.sources'
  } else {
    $file = '/etc/apt/sources.list.d/mysql.list'
  }
  $file_preference = '/etc/apt/preferences.d/90-mysql'

  # Set keyrings file
  $key = '/usr/share/keyrings/mysql.gpg'

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
      $source  = "Types: deb\nURIs: https://repo.mysql.com/apt/${os_parent}\nSuites: ${os_name}\nComponents: mysql-${version_correct}\nSigned-By:${key}\n"
    } else {
      $source = "deb [signed-by=${key}] https://repo.mysql.com/apt/${os_parent} ${os_name} mysql-${version_correct}\n"
    }

    # Create MySQL key
    file { 'package_mysql_key_filename':
      ensure => file,
      path   => '/usr/share/keyrings/mysql.key',
      source => "puppet:///modules/basic_settings/mysql/${key_filename}",
      owner  => 'root',
      group  => 'root',
      mode   => '0600',
    }

    # Set source
    exec { 'package_mysql_source':
      command => "/usr/bin/printf \"# Managed by puppet\n${source}\" > ${file}; cat /usr/share/keyrings/mysql.key | gpg --dearmor | tee ${key} >/dev/null; chmod 644 ${key}; /usr/bin/apt-get update", #lint:ignore:140chars
      unless  => "[ -e ${file} ]",
      require => [Package['apt', 'apt-transport-https', 'curl', 'gnupg'], File['package_mysql_key_filename']],
    }

    # Set source
    exec { 'package_mysql_source':
      command => "/usr/bin/printf \"# Managed by puppet\n${source}\" > ${file}; cat /usr/share/keyrings/mysql.key | gpg --dearmor | tee ${key} >/dev/null; chmod 644 ${key}; /usr/bin/apt-get update", #lint:ignore:140chars
      unless  => "[ -e ${file} ]",
      require => [Package['apt', 'apt-transport-https', 'curl', 'gnupg'], File['package_mysql_key_filename']],
    }

    # Set source
    exec { 'package_mysql_preference':
      command => "/usr/bin/printf \"# Managed by puppet\nPackage: mysql*\nPin: origin repo.mysql.com\nPin-Priority: 990\n\" > ${file_preference}; chmod 644 ${file_preference}; /usr/bin/apt-get update", #lint:ignore:140chars
      unless  => "[ -e ${file_preference} ]",
      require => Exec['package_mysql_source'],
    }

    # Install default locale file
    file { '/etc/default/locale':
      ensure  => file,
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      content => "Package: mysql*\nPin: release o=MySQL,a=noble",
    }
  } else {
    # Remove mysql repo
    exec { 'package_mysql_source':
      command => "/usr/bin/bash -c '/usr/bin/rm ${file} && /usr/bin/apt-get update'",
      onlyif  => "[ -e ${file} ]",
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
