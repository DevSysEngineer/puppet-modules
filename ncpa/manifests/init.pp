class ncpa (
  Sensitive[String]                   $community_string,
  String                              $server_url,
  Sensitive[String]                   $server_token,
  Optional[Array]                     $handlers_extra     = undef,
  Optional[String]                    $server_fdqn        = undef,
  Integer                             $nice_level         = 12,
) {
  # Set variables
  $log_path = '/var/log/ncpa'

  # Try to get server fdqn
  if ($server_fdqn == undef) {
    if (defined(Class['basic_settings'])) {
      $server_fdqn_correct = $basic_settings::server_fdqn
    } else {
      $server_fdqn_correct = $facts['networking']['fqdn']
    }
  } else {
    $server_fdqn_correct = $server_fdqn
  }

  # Install Nagios Cross-Platform Agent
  package { 'ncpa':
    ensure          => installed,
    install_options => ['--no-install-recommends', '--no-install-suggests'],
  }

  # Check if we have systemd
  if (defined(Package['systemd'])) {
    # Disable service
    service { 'ncpa':
      ensure  => undef,
      enable  => false,
      require => Package['ncpa'],
    }

    # Reload systemd deamon
    exec { 'ncpa_systemd_daemon_reload':
      command     => '/usr/bin/systemctl daemon-reload',
      refreshonly => true,
      require     => Package['systemd'],
    }

    # Create drop in for x target
    if (defined(Class['basic_settings::systemd'])) {
      basic_settings::systemd_drop_in { 'ncpa_dependency':
        target_unit   => "${basic_settings::systemd::cluster_id}-services.target",
        unit          => {
          'BindsTo'   => 'ncpa.service',
        },
        daemon_reload => 'ncpa_systemd_daemon_reload',
        require       => Basic_settings::Systemd_target["${basic_settings::systemd::cluster_id}-services"],
      }
    }

    # Get unit
    if (defined(Class['basic_settings::message'])) {
      $unit = {
        'OnFailure' => 'notify-failed@%i.service',
      }
    } else {
      $unit = {}
    }

    # Create drop in for ncpa service
    basic_settings::systemd_drop_in { 'ncpa_settings':
      target_unit   => 'ncpa.service',
      unit          => $unit,
      service       => {
        'Nice'          => "-${nice_level}",
        'PrivateTmp'    => 'true',
        'ProtectHome'   => 'true',
        'ProtectSystem' => 'full',
      },
      daemon_reload => 'ncpa_systemd_daemon_reload',
      require       => Package['ncpa'],
    }
  } else {
    # Eanble service
    service { 'ncpa':
      ensure  => true,
      enable  => true,
      require => Package['ncpa'],
    }
  }

  # Get handlers
  if ($handlers_extra != undef) {
    $handlers_list = join($handlers_extra, ',')
    $handlers_correct = "nrdp,${handlers_list}"
  } else {
    $handlers_correct = 'nrdp'
  }

  # Create log directory
  file { $log_path:
    ensure  => directory,
    mode    => '0700',
    recurse => true,
    owner   => 'nagios',
    group   => 'nagios',
  }

  # Create config directory
  file { '/usr/local/ncpa/etc':
    ensure  => directory,
    purge   => true,
    force   => true,
    recurse => true,
    require => Package['ncpa'],
  }

  # Create settings file
  file { '/usr/local/ncpa/etc/ncpa.cfg.d/99-settings.conf':
    ensure  => file,
    content => Sensitive.new(template('ncpa/settings.conf')),
    owner   => 'root',
    group   => 'nagios',
    mode    => '0600',
    notify  => Service['ncpa'],
    require => Package['ncpa'],
  }
}
