class basic_settings::package_rabbitmq (
  Enum['list','822']  $deb_version,
  Boolean             $enable,
  String              $os_parent,
  String              $os_name
) {
  # Reload source list
  exec { 'package_rabbitmq_source_reload':
    command     => '/usr/bin/apt-get update',
    refreshonly => true,
  }

  # Check if we need newer format for APT
  if ($deb_version == '822') {
    $file_erlang = '/etc/apt/sources.list.d/rabbitmq-erlang.sources'
    $file_server = '/etc/apt/sources.list.d/rabbitmq-server.sources'
  } else {
    $file_erlang = '/etc/apt/sources.list.d/rabbitmq-erlang.list'
    $file_server = '/etc/apt/sources.list.d/rabbitmq-server.list'
  }

  # Set keys
  $key_erlang = '/usr/share/keyrings/rabbitmq-erlang.gpg'
  $key_server = '/usr/share/keyrings/rabbitmq-server.gpg'

  if ($enable) {
    # Get source
    if ($deb_version == '822') {
      $source_erlang  = "Types: deb\nURIs: https://dl.cloudsmith.io/public/rabbitmq/rabbitmq-erlang/deb/${os_parent}\nSuites: ${os_name}\nComponents: main\nSigned-By:${key_erlang}\n"
      $source_server  = "Types: deb\nURIs: https://dl.cloudsmith.io/public/rabbitmq/rabbitmq-server/deb/${os_parent}\nSuites: ${os_name}\nComponents: main\nSigned-By:${key_server}\n"
    } else {
      $source_erlang = "deb [signed-by=${key_erlang}] https://dl.cloudsmith.io/public/rabbitmq/rabbitmq-erlang/deb/${os_parent} ${os_name} main\n"
      $source_server = "deb [signed-by=${key_server}] https://dl.cloudsmith.io/public/rabbitmq/rabbitmq-server/deb/${os_parent} ${os_name} main\n"
    }

    # Install Rabbitmq erlang repo
    exec { 'package_rabbitmq_erlang_source':
      command => "/usr/bin/printf \"# Managed by puppet\n${source_erlang}\" > ${file_erlang}; /usr/bin/curl -fsSL https://dl.cloudsmith.io/public/rabbitmq/rabbitmq-erlang/gpg.E495BB49CC4BBE5B.key | gpg --dearmor | tee ${key_erlang} >/dev/null; chmod 644 ${key_erlang}",
      unless  => "[ -e ${file_erlang} ]",
      notify  => Exec['package_rabbitmq_source_reload'],
      require => [Package['apt'], Package['curl'], Package['gnupg']],
    }

    # Install Rabbitmq server repo
    exec { 'package_rabbitmq_server_source':
      command => "/usr/bin/printf \"# Managed by puppet\n${source_server}\" >  ${file_server}; /usr/bin/curl -fsSL https://dl.cloudsmith.io/public/rabbitmq/rabbitmq-server/gpg.9F4587F226208342.key | gpg --dearmor | tee ${key_server} >/dev/null; chmod 644 ${key_server}",
      unless  => "[ -e  ${file_server} ]",
      notify  => Exec['package_rabbitmq_source_reload'],
      require => [Package['apt'], Package['curl'], Package['gnupg']],
    }
  } else {
    # Remove Rabbitmq erlang repo
    exec { 'package_rabbitmq_erlang_source':
      command => "/usr/bin/rm ${file_erlang}",
      onlyif  => "[ -e ${file_erlang} ]",
      notify  => Exec['package_rabbitmq_source_reload'],
    }

    # Remove Rabbitmq server repo
    exec { 'package_rabbitmq_server_source':
      command => "/usr/bin/rm  ${file_server}",
      onlyif  => "[ -e  ${file_server} ]",
      notify  => Exec['package_rabbitmq_source_reload'],
      require => Package['apt'],
    }

    # Remove rabbitmq key
    file { 'package_proxmox_key_erlang':
      ensure => absent,
      path   => $key_erlang,
    }
    file { 'package_proxmox_key_server':
      ensure => absent,
      path   => $key_server,
    }
  }
}
