class rabbitmq (
  Array     $deprecated_features  = [
    'transient_nonexcl_queues',
  ],
  String    $target               = 'services',
  Integer   $nice_level           = 12,
  Integer   $limit_file           = 10000
) {
  # Set some values
  $systemd_enable = defined(Package['systemd'])
  $monitoring_enable = defined(Class['basic_settings::monitoring'])

  # Install erlang
  package { 'erlang-base':
    ensure          => installed,
    install_options => ['--no-install-recommends', '--no-install-suggests'],
  }

  # Install rabbitmq
  package { 'rabbitmq-server':
    ensure          => installed,
    install_options => ['--no-install-recommends', '--no-install-suggests'],
    require         => Package['erlang-base'],
  }

  # Disable service
  if ($systemd_enable) {
    # Disable service
    service { 'rabbitmq-server':
      ensure  => undef,
      enable  => false,
      require => Package['rabbitmq-server'],
    }

    # Reload systemd deamon
    exec { 'rabbitmq_systemd_daemon_reload':
      command     => '/usr/bin/systemctl daemon-reload',
      refreshonly => true,
      require     => Package['systemd'],
    }

    # Create drop in for x target
    if (defined(Class['basic_settings::systemd'])) {
      basic_settings::systemd_drop_in { 'rabbitmq_dependency':
        target_unit   => "${basic_settings::systemd::cluster_id}-${target}.target",
        unit          => {
          'BindsTo'   => 'rabbitmq-server.service',
        },
        daemon_reload => 'rabbitmq_systemd_daemon_reload',
        require       => Basic_settings::Systemd_target["${basic_settings::systemd::cluster_id}-${target}"],
      }
    }

    # Get unit
    if ($monitoring_enable) {
      $unit = {
        'OnFailure' => 'notify-failed@%i.service',
      }
    } else {
      $unit = {}
    }

    # Create drop in for nginx service
    basic_settings::systemd_drop_in { 'rabbitmq_settings':
      target_unit   => 'rabbitmq-server.service',
      unit          => $unit,
      service       => {
        'LimitNOFILE'    => $limit_file,
        'Nice'           => "-${nice_level}",
        'PrivateDevices' => 'true',
        'PrivateTmp'     => 'true',
        'ProtectHome'    => 'true',
        'ProtectSystem'  => 'full',
      },
      daemon_reload => 'rabbitmq_systemd_daemon_reload',
      require       => Package['rabbitmq-server'],
    }
  } else {
    # Enable service
    service { 'rabbitmq-server':
      ensure  => true,
      enable  => true,
      require => Package['rabbitmq-server'],
    }
  }

  # Create config directory
  file { 'rabbitmq_config_dir':
    ensure  => directory,
    path    => '/etc/rabbitmq/conf.d',
    purge   => true,
    force   => true,
    recurse => true,
    owner   => 'rabbitmq',
    group   => 'rabbitmq',
    mode    => '0700',
    require => Package['rabbitmq-server'],
  }

  # Create deprecated_features conf
  file { '/etc/rabbitmq/conf.d/deprecated_features.conf':
    ensure  => file,
    content => template('rabbitmq/deprecated_features.conf'),
    owner   => 'rabbitmq',
    group   => 'rabbitmq',
    mode    => '0600',
    notify  => Service['rabbitmq-server'],
    require => File['rabbitmq_config_dir'],
  }

  # Create ssl directory
  file { 'rabbitmq_ssl':
    ensure  => directory,
    path    => '/etc/rabbitmq/ssl',
    owner   => 'rabbitmq',
    group   => 'rabbitmq',
    mode    => '0700',
    require => Package['rabbitmq-server'],
  }
}
