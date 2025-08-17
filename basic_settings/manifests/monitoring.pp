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
    'openitcockpit': {
      # Check if we can install package
      if ($package_install) {
        # Install OpenITCockpit agent
        package { 'openitcockpit-agent':
          ensure          => installed,
          install_options => ['--no-install-recommends', '--no-install-suggests'],
        }

        # Check if we have systemd
        if (defined(Package['systemd'])) {
          # Disable service
          service { 'monitoring_service':
            ensure  => undef,
            name    => 'openitcockpit-agent',
            enable  => false,
            require => Package['openitcockpit-agent'],
          }

          # Create drop in for x target
          if (defined(Class['basic_settings::systemd'])) {
            basic_settings::systemd_drop_in { 'openitcockpit_agent_dependency':
              target_unit   => "${basic_settings::systemd::cluster_id}-services.target",
              unit          => {
                'BindsTo'   => 'openitcockpit-agent.service',
              },
              daemon_reload => 'monitoring_systemd_daemon_reload',
              require       => Basic_settings::Systemd_target["${basic_settings::systemd::cluster_id}-services"],
            }
          }

          # Create drop in for ncpa service
          basic_settings::systemd_drop_in { 'openitcockpit_agent_settings':
            target_unit   => 'openitcockpit-agent.service',
            unit          => {
              'OnFailure' => 'notify-failed@%i.service',
            },
            service       => {
              'PrivateDevices' => 'true',
              'PrivateTmp'     => 'true',
              'ProtectHome'    => 'true',
              'ProtectSystem'  => 'full',
              'ReadWritePaths' => '/etc/openitcockpit-agent',
            },
            daemon_reload => 'monitoring_systemd_daemon_reload',
            require       => Package['openitcockpit-agent'],
          }
        } else {
          # Enable service
          service { 'monitoring_service':
            ensure  => true,
            name    => 'openitcockpit-agent',
            enable  => true,
            require => Package['openitcockpit-agent'],
          }
        }

        # Setup security audit rules
        basic_settings::security_audit { 'monitoring':
          rules => [
            '-a never,exit -F arch=b32 -S adjtimex -F exe=/usr/bin/openitcockpit-agent -F auid=unset',
            '-a never,exit -F arch=b64 -S adjtimex -F exe=/usr/bin/openitcockpit-agent -F auid=unset',
          ],
          order => 2,
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
        mode    => '0755', # Important
        owner   => 'root',
        group   => 'root',
        require => File['monitoring_location'],
      }

      # Create config config
      concat { '/etc/openitcockpit-agent/customchecks.ini':
        owner   => 'root',
        group   => 'root',
        mode    => '0600',
        notify  => Service['monitoring_service'],
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

  # Create service check
  basic_settings::monitoring_service { 'mail':
    services => [$mail_package],
  }
}
