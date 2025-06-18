class ncpa (
  $nice_level = 12
) {
  # Install Nagios Cross-Platform Agent
  package { 'ncpa':
    ensure          => installed,
    install_options => ['--no-install-recommends', '--no-install-suggests'],
  }

  # Check if we have systemd
  if (defined(Package['systemd'])) {
    # Reload systemd deamon
    exec { 'ncpa_systemd_daemon_reload':
      command     => '/usr/bin/systemctl daemon-reload',
      refreshonly => true,
      require     => Package['systemd'],
    }

    # Get unit
    if (defined(Class['basic_settings::message'])) {
      $unit = {
        'OnFailure' => 'notify-failed@%i.service',
      }
    } else {
      $unit = {}
    }

    # Create drop in for certbot service
    # basic_settings::systemd_drop_in { 'letsencrypt_settings':
    #   target_unit   => 'ncpa.service',
    #   unit          => $unit,
    #   service       => {
    #     'Nice'         => "-${nice_level}",
    #   },
    #   daemon_reload => 'ncpa_systemd_daemon_reload',
    # }
  }
}
