class ncpa (
  Sensitive[String]                   $community_string,
  String                              $server_url,
  Sensitive[String]                   $server_token,
  Optional[Array]                     $handlers_extra     = undef,
  Optional[String]                    $server_fdqn        = undef,
  Integer                             $nice_level         = -19,
) {
  # Set variables
  $log_path = '/var/log/ncpa'
  $systemd_enable = defined(Package['systemd'])

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

  # Check if we have systemd
  $monitoring_enable = defined(Class['basic_settings::monitoring'])
  if ($monitoring_enable) {
    $monitoring_package = $basic_settings::monitoring::package
  } else {
    $monitoring_package = false
  }

  # Install Nagios Cross-Platform Agent
  if (!defined(Package['ncpa'])) {
    package { 'ncpa':
      ensure          => installed,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
    }
  }

  # Check if monitoring package is not configured
  if ($monitoring_package == 'none') {
    if ($systemd_enable) {
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
      if ($monitoring_enable) {
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
          'Nice'           => $nice_level,
          'ProtectHome'    => 'true',
          'ProtectSystem'  => 'full',
          'ReadWritePaths' => '/usr/local/ncpa',
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

    # Create config directory
    file { '/usr/local/ncpa/etc':
      ensure  => directory,
      purge   => true,
      force   => true,
      recurse => true,
      owner   => 'root',
      group   => 'nagios',
      require => Package['ncpa'],
    }

    # Create config directory
    file { '/usr/local/ncpa/etc/ncpa.cfg.d':
      ensure  => directory,
      purge   => true,
      force   => true,
      recurse => true,
      owner   => 'root',
      group   => 'nagios',
      notify  => Service['ncpa'],
      require => File['/usr/local/ncpa/etc'],
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
    ensure => directory,
    mode   => '0700',
    owner  => 'nagios',
    group  => 'nagios',
  }

  # Create settings file
  file { '/usr/local/ncpa/etc/ncpa.cfg.d/99-settings.cfg':
    ensure  => file,
    content => Sensitive.new(template('ncpa/settings.cfg')),
    owner   => 'root',
    group   => 'nagios',
    mode    => '0600',
    notify  => Service['ncpa'],
    require => Package['ncpa'],
  }
}
