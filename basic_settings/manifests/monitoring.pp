class basic_settings::monitoring (
  String                        $mail_to          = 'root',
  String                        $mail_package     = 'postfix',
  Enum['none','openitcockpit']  $package          = 'none',
  Boolean                       $package_install  = false,
  String                        $server_fdqn      = $facts['networking']['fqdn']
) {
  # Install package
  package { [$mail_package, 'mailutils']:
    ensure          => installed,
    install_options => ['--no-install-recommends', '--no-install-suggests'],
  }

  # Do thing based on mail package
  case $mail_package {
    'postfix': {
      exec { 'monitoring_newaliases':
        command => '/usr/bin/newaliases',
        creates => '/etc/aliases.db',
      }
    }
  }

  # Enable mail service
  service { $mail_package:
    ensure  => true,
    enable  => true,
    require => Package[$mail_package],
  }

  if (defined(Package['systemd'])) {
    # Reload systemd deamon
    exec { 'monitoring_systemd_daemon_reload':
      command     => '/usr/bin/systemctl daemon-reload',
      refreshonly => true,
      require     => Package['systemd'],
    }

    # Create systemd service for notification
    basic_settings::systemd_service { 'notify-failed@':
      description   => 'Send systemd notifications to mail',
      service       => {
        'Type'      => 'oneshot',
        'ExecStart' => "/usr/bin/bash -c 'LC_CTYPE=C systemctl status --full %i | /usr/bin/mail -s \"Service %i failed on ${server_fdqn}\" -r \"systemd@${server_fdqn}\" \"${mail_to}\"'", #lint:ignore:140chars
      },
      daemon_reload => 'monitoring_systemd_daemon_reload',
      enable        => false,
      require       => Package[$mail_package],
    }

    # Create drop in for notify-failed service
    basic_settings::systemd_drop_in { "notify-failed_${mail_package}_dependency":
      target_unit   => 'notify-failed@',
      unit          => {
        'Wants' => "${mail_package}.service",
      },
      daemon_reload => 'monitoring_systemd_daemon_reload',
      require       => [Package[$mail_package], Basic_settings::Systemd_service['notify-failed@']],
    }
  }

  # Monitoring package 
  case $package {
    'ncpa': {
      # Set some values
      $plugins_dir = '/usr/local/ncpa/plugins'
      $uid  = 'nagios'
      $gid  = 'nagios'

      # Check if we can install package
      if ($package_install) {
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

          # Create drop in for x target
          if (defined(Class['basic_settings::systemd'])) {
            basic_settings::systemd_drop_in { 'ncpa_dependency':
              target_unit   => "${basic_settings::systemd::cluster_id}-services.target",
              unit          => {
                'BindsTo'   => 'ncpa.service',
              },
              daemon_reload => 'monitoring_systemd_daemon_reload',
              require       => Basic_settings::Systemd_target["${basic_settings::systemd::cluster_id}-services"],
            }
          }

          # Create drop in for ncpa service
          basic_settings::systemd_drop_in { 'ncpa_settings':
            target_unit   => 'ncpa.service',
            unit          => {
              'OnFailure' => 'notify-failed@%i.service',
            },
            service       => {
              'Nice'           => '19',
              'ProtectHome'    => 'true',
              'ProtectSystem'  => 'full',
              'ReadWritePaths' => '/usr/local/ncpa',
            },
            daemon_reload => 'monitoring_systemd_daemon_reload',
            require       => Package['ncpa'],
          }

          # Set notify
          $notify = Service['ncpa']
        } else {
          # Eanble service
          service { 'ncpa':
            ensure  => true,
            enable  => true,
            require => Package['ncpa'],
          }
          $notify = undef
        }
      }

      # Create root directory
      file { 'monitoring_location':
        ensure => directory,
        path   => '/usr/local/ncpa',
        mode   => '0755', # Important
        owner  => 'root',
        group  => 'root',
      }

      file { 'monitoring_location_etc':
        ensure  => directory,
        path    => '/usr/local/ncpa/etc',
        mode    => '0700',
        owner   => 'root',
        group   => $gid,
        notify  => $notify,
        require => File['monitoring_location'],
      }

      # Create config directory
      file { 'monitoring_location_config':
        ensure  => directory,
        path    => '/usr/local/ncpa/etc/ncpa.cfg.d',
        purge   => true,
        force   => true,
        recurse => true,
        owner   => 'root',
        group   => $gid,
        notify  => $notify,
        require => File['monitoring_location_etc'],
      }

      # Create plugin directory
      file { 'monitoring_location_plugins':
        ensure  => directory,
        path    => $plugins_dir,
        mode    => '0755', # Important
        owner   => 'root',
        group   => 'root',
        require => File['monitoring_location'],
      }
    }
  }

  # Create service check
  basic_settings::monitoring_service { 'mail':
    services => [$mail_package],
  }
}
