define basic_settings::systemd_service (
  String                    $description,
  String                    $daemon_reload        = 'systemd_daemon_reload',
  Boolean                   $enable               = true,
  Enum['present','absent']  $ensure               = present,
  Hash                      $install              = {
    'WantedBy'  => 'multi-user.target',
  }
  Optional[Boolean]         $monitoring_enable    = undef,
  Optional[String]          $monitoring_package   = undef,
  Hash                      $service              = {},
  Hash                      $unit                 = {},
) {
  file { "/etc/systemd/system/${title}.service":
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
    service { $title:
      enable  => $enable,
      require => File["/etc/systemd/system/${title}.service"],
    }

    # Check if we need to monitoring this service
    if ($monitoring_enable != undef and $monitoring_package != 'none') {
      $monitoring_ensure = $monitoring_enable ? { true => 'present', default => absent }
      basic_settings::monitoring_service { $title:
        ensure  => $monitoring_ensure,
        package => $monitoring_package,
      }
    }
  } elsif ($monitoring_package != 'none') {
    basic_settings::monitoring_service { $title:
      ensure  => $ensure,
      package => $monitoring_package,
    }
  }
}
