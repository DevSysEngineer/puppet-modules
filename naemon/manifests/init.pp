class naemon () {
  # Set some values
  $monitoring_enable = defined(Class['basic_settings::monitoring'])

  if (defined(Package['openitcockpit'])) {
    $package = 'openitcockpit-naemon'
    package { $package:
      ensure          => installed,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
      require         => Package['openitcockpit'],
    }
  }

  # Disable service
  if (defined(Package['systemd'])) {
    # Disable service
    service { 'naemon':
      ensure  => undef,
      enable  => false,
      require => Package[$package],
    }

    # Reload systemd deamon
    exec { 'naemon_systemd_daemon_reload':
      command     => '/usr/bin/systemctl daemon-reload',
      refreshonly => true,
      require     => Package['systemd'],
    }

    # Create drop in for x target
    if (defined(Class['basic_settings::systemd'])) {
      basic_settings::systemd_drop_in { 'naemon_dependency':
        target_unit   => "${basic_settings::systemd::cluster_id}-helpers.target",
        unit          => {
          'BindsTo'   => 'naemon.service',
        },
        daemon_reload => 'naemon_systemd_daemon_reload',
        require       => Basic_settings::Systemd_target["${basic_settings::systemd::cluster_id}-helpers"],
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

    # Create drop in for openitcockpit-node service
    basic_settings::systemd_drop_in { 'naemon_settings':
      target_unit   => 'naemon.service',
      unit          => $unit,
      service       => {
        'PrivateDevices' => 'true',
        'PrivateTmp'     => 'true',
        'ProtectHome'    => 'true',
        'ProtectSystem'  => 'full',
      },
      daemon_reload => 'naemon_systemd_daemon_reload',
      require       => Package[$package],
    }
  } else {
    # Enable service
    service { 'naemon':
      ensure  => true,
      enable  => true,
      require => Package[$package],
    }
  }
}
