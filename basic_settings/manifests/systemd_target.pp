define basic_settings::systemd_target (
  String                    $description,
  Array                     $parent_targets,
  Boolean                   $allow_isolate          = false,
  Enum['present','absent']  $ensure                 = present,
  Hash                      $install                = {},
  Boolean                   $stronger_requirements  = true,
  Hash                      $unit                   = {}
) {
  # Check if systemd package is not defined
  if (!defined(Package['systemd'])) {
    package { 'systemd':
      ensure          => installed,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
    }
  }

  # Create systemd target file
  file { "/etc/systemd/system/${title}.target":
    ensure  => $ensure,
    content => template('basic_settings/systemd/target'),
    owner   => 'root',
    group   => 'root',
    mode    => '0644', # See issue https://github.com/systemd/systemd/issues/770
    notify  => Exec['systemd_daemon_reload'],
    require => Package['systemd'],
  }
}
