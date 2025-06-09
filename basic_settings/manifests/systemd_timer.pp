define basic_settings::systemd_timer (
  String                    $description,
  String                    $daemon_reload  = 'systemd_daemon_reload',
  Boolean                   $enable         = true,
  Enum['present','absent']  $ensure         = present,
  Hash                      $unit           = {},
  Hash                      $timer          = {},
  Hash                      $install        = {
    'WantedBy'  => 'timers.target',
  },
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

  if ($ensure == present) {
    # Enable timer
    service { "${title}.timer":
      ensure  => true,
      enable  => $enable,
      require => File["/etc/systemd/system/${title}.timer"],
    }
  }
}
