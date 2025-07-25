class openitcockpit::agent (

) {
  # Set variables
  $monitoring_enable = defined(Class['basic_settings::monitoring'])
  $systemd_enable = defined(Package['systemd'])

  # Check if we have systemd
  if ($monitoring_enable) {
    $monitoring_package = $basic_settings::monitoring::package
  } else {
    $monitoring_package = 'none'
  }

  # Install OpenITCockpit agent
  if (!defined(Package['openitcockpit-agent'])) {
    package { 'openitcockpit-agent':
      ensure          => installed,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
    }
  }

  # Check if monitoring package is not configured
  if ($monitoring_package == 'none') {
    if ($systemd_enable) {
      # Disable service
      service { 'openitcockpit-agent':
        ensure  => undef,
        enable  => false,
        require => Package['openitcockpit-agent'],
      }

      # Reload systemd deamon
      exec { 'openitcockpit_agent_systemd_daemon_reload':
        command     => '/usr/bin/systemctl daemon-reload',
        refreshonly => true,
        require     => Package['systemd'],
      }

      # Create drop in for x target
      if (defined(Class['basic_settings::systemd'])) {
        basic_settings::systemd_drop_in { 'openitcockpit_agent_dependency':
          target_unit   => "${basic_settings::systemd::cluster_id}-services.target",
          unit          => {
            'BindsTo'   => 'openitcockpit-agent.service',
          },
          daemon_reload => 'openitcockpit_agent_systemd_daemon_reload',
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

      # Create symlink
      file { '/usr/lib/systemd/system/openitcockpit-agent.service':
        ensure  => 'link',
        target  => '/etc/openitcockpit-agent/init/openitcockpit-agent.service',
        force   => true,
        notify  => Exec['openitcockpit_agent_systemd_daemon_reload'],
        require => Package['openitcockpit-agent'],
      }

      # Create drop in for ncpa service
      basic_settings::systemd_drop_in { 'openitcockpit_agent_settings':
        target_unit   => 'openitcockpit-agent.service',
        unit          => $unit,
        service       => {
          'PrivateDevices' => 'true',
          'PrivateTmp'     => 'true',
          'ProtectHome'    => 'true',
          'ProtectSystem'  => 'full',
        },
        daemon_reload => 'openitcockpit_agent_systemd_daemon_reload',
        require       => File['/usr/lib/systemd/system/openitcockpit-agent.service'],
      }
    } else {
      # Eanble service
      service { 'openitcockpit-agent':
        ensure  => true,
        enable  => true,
        require => Package['openitcockpit-agent'],
      }
    }

    # Create root directory
    file { 'monitoring_location':
      ensure => directory,
      path   => '/etc/openitcockpit-agent',
      mode   => '0755', # Important
      owner  => 'root',
      group  => 'root',
    }

    # Create plugin directory
    file { 'monitoring_location_plugins':
      ensure  => directory,
      path    => '/etc/openitcockpit-agent/plugins',
      mode    => '0700',
      owner   => 'root',
      group   => 'root',
      require => File['monitoring_location'],
    }

    # Create config config
    concat { '/etc/openitcockpit-agent/customchecks.ini':
      owner   => 'root',
      group   => 'root',
      mode    => '0600',
      require => File['monitoring_location'],
    }

    # Create fragment 
    concat::fragment { 'monitoring_customchecks_default':
      target  => '/etc/openitcockpit-agent/customchecks.ini',
      content => "# Managed by puppet\n[default]\n",
      order   => '01',
    }
  }
}
