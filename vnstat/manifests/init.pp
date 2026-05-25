class vnstat (
  Integer           $nice_level = 8,
  String            $target     = 'services',
) {
  # Install vnstat
  package { 'vnstat':
    ensure          => installed,
    install_options => ['--no-install-recommends', '--no-install-suggests'],
  }

  # Check if we have systemd
  if (defined(Package['systemd'])) {
    # Reload systemd deamon
    exec { 'vnstat_systemd_daemon_reload':
      command     => '/usr/bin/systemctl daemon-reload',
      refreshonly => true,
      require     => Package['systemd'],
    }

    # Get unit
    if (defined(Class['basic_settings::monitoring'])) {
      $unit = {
        'OnFailure' => 'notify-failed@%i.service',
      }
    } else {
      $unit = {}
    }

    # Create drop in for vnstat service
    basic_settings::systemd_drop_in { 'vnstat_settings':
      target_unit   => 'vnstat.service',
      unit          => $unit,
      service       => {
        'Nice'         => "-${nice_level}",
      },
      daemon_reload => 'vnstat_systemd_daemon_reload',
      require       => Package['vnstat'],
    }

    # Create drop in for x target
    if (defined(Class['basic_settings::systemd'])) {
      basic_settings::systemd_drop_in { 'vnstat_dependency':
        target_unit   => "${basic_settings::systemd::cluster_id}-${target}.target",
        unit          => {
          'BindsTo'   => 'vnstat.service',
        },
        daemon_reload => 'vnstat_systemd_daemon_reload',
        require       => Basic_settings::Systemd_target["${basic_settings::systemd::cluster_id}-${target}"],
      }
    }
  }

  # Check if logrotate package exists
  if (defined(Package['logrotate'])) {
    basic_settings::io_logrotate { 'vnstat':
      path           => '/var/log/vnstat/vnstat.log',
      frequency      => 'weekly',
      compress_delay => true,
      create_group   => 'vnstat',
      create_user    => 'vnstat',
      rotate_copy    => true,
    }
  }

  # Set config file
  file { '/etc/vnstat.conf':
    ensure  => file,
    content => template('vnstat/config.conf'),
    owner   => 'root',
    group   => 'root',
    mode    => '0600', # Only root
    require => Package['vnstat'],
  }
}
