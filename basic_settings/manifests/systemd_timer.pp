define basic_settings::systemd_timer (
  String                                $description,
  String                                $daemon_reload        = 'systemd_daemon_reload',
  Boolean                               $enable               = true,
  Enum['present','absent']              $ensure               = present,
  Hash                                  $install              = {
    'WantedBy'  => 'timers.target',
  },
  Optional[Boolean]                     $monitoring_enable    = undef,
  Optional[String]                      $monitoring_package   = undef,
  Optional[Enum['running','stopped']]   $state                = undef,
  Hash                                  $timer                = {},
  Hash                                  $unit                 = {},
) {
  # Create timer file
  file { "/etc/systemd/system/${title}.timer":
    ensure  => $ensure,
    content => template('basic_settings/systemd/timer'),
    owner   => 'root',
    group   => 'root',
    mode    => '0644', # See issue https://github.com/systemd/systemd/issues/770
    notify  => Exec[$daemon_reload],
    require => Package['systemd'],
  }

  # Check if we need to monitoring this timer
  if ($monitoring_enable != undef and $monitoring_package != 'none') {
    monitoring_timer { $title:
      package => $monitoring_package,
    }
  }

  # Set service
  if ($ensure == present) {
    service { "${title}.timer":
      ensure  => $state,
      enable  => $enable,
      require => File["/etc/systemd/system/${title}.timer"],
    }
  }
}
