define basic_settings::systemd_service (
  String                    $description,
  String                    $daemon_reload              = 'systemd_daemon_reload',
  Boolean                   $enable                     = true,
  Enum['present','absent']  $ensure                     = present,
  Hash                      $install                    = {
    'WantedBy'  => 'multi-user.target',
  },
  Optional[Boolean]         $monitoring_enable          = undef,
  Optional[String]          $monitoring_package         = undef,
  Optional[String]          $monitoring_active_windows  = undef,
  Optional[String]          $monitoring_active_days     = undef,
  Hash                      $service                    = {},
  Optional[Array]           $service_subscribe          = undef,
  Hash                      $unit                       = {},
) {
  # Check if systemd package is not defined
  if (!defined(Package['systemd'])) {
    package { 'systemd':
      ensure          => installed,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
    }
  }

  # Create systemd service file
  file { "/etc/systemd/system/${name}.service":
    ensure  => $ensure,
    content => template('basic_settings/systemd/service'),
    owner   => 'root',
    group   => 'root',
    mode    => '0644', # See issue https://github.com/systemd/systemd/issues/770
    notify  => Exec[$daemon_reload],
    require => Package['systemd'],
  }

  # Set service
  if ($ensure == present) {
    # Enable service
    service { $name:
      enable    => $enable,
      require   => File["/etc/systemd/system/${name}.service"],
      subscribe => $service_subscribe,
    }

    # Check if we need to monitoring this service
    if ($monitoring_enable != undef and $monitoring_package != 'none') {
      $monitoring_ensure = $monitoring_enable ? { true => 'present', default => absent }
    } else {
      $monitoring_ensure = absent
    }
  } elsif ($monitoring_package != 'none') {
    $monitoring_ensure = absent
  }

  # Setup monitoring for this service
  basic_settings::monitoring_service { $name:
    ensure         => $monitoring_ensure,
    package        => $monitoring_package,
    active_windows => $monitoring_active_windows,
    active_days    => $monitoring_active_days,
  }

  # Check if service is using node executable in ExecStart
  if (has_key($service, 'ExecStart') and $service['ExecStart'] =~ /^(?:node|\.{1,2}\/node|\/(?:[^\/\s]+\/)+node)\s+/) {
    if (has_key($service, 'WorkingDirectory')) {
      basisc_settings::monitoring_npm_audit { $name:
        ensure  => $monitoring_ensure,
        dir     => $service['WorkingDirectory'],
        package => $monitoring_package,
      }
    } else {
      basisc_settings::monitoring_npm_audit { $name:
        ensure  => absent,
        dir     => '',
        package => $monitoring_package,
      }
    }
  }
}
