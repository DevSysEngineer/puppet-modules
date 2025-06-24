define basic_settings::monitoring_timer (
  Optional[String] $friendly = undef,
  Optional[String] $package = undef
) {
  # Get friendly name
  if ($friendly == undef) {
    $friendly_correct = $name
  } else {
    $friendly_correct = $friendly
  }

  # Try to get package
  if (defined(Class['basic_settings::monitoring'])) {
    if ($package == undef) {
      $package_correct = $basic_settings::monitoring::package
    } else {
      $package_correct = $package
    }
  } else {
    $package_correct = 'none'
  }

  # Check if sudo package is not defined
  if (!defined(Package['sudo'])) {
    package { 'sudo':
      ensure          => installed,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
    }
  }

  # Do thing based on package
  case $package_correct {
    'ncpa': {
      # Create check script
      $script_path = '/usr/local/ncpa/plugin/check_systemd_timer'
      if (!defined(File[$script_path])) {
        file { $script_path:
          ensure => file,
          source => 'puppet:///modules/basic_settings/monitoring/check_systemd_timer',
          owner  => 'nagios',
          group  => 'nagios',
          mode   => '0700',
        }

        # Create plugin
        file { '/usr/local/ncpa/etc/ncpa.cfg.d/check_systemd_timer_plugin.cfg':
          ensure  => file,
          owner   => 'root',
          group   => 'nagios',
          content => "# Managed by puppet\n[plugin directives] check_systemd_timer = \$plugin_path/check_systemd_timer \$ARG1\n",
        }
      }

      # Create check
      file { "/usr/local/ncpa/etc/ncpa.cfg.d/${name}_timer.cfg":
        ensure  => file,
        owner   => 'root',
        group   => 'nagios',
        content => "# Managed by puppet\n[passive checks]\n%HOSTNAME%|${friendly_correct} Timer = plugins/check_systemd_timer ${name}.timer\n",
      }
    }
  }
}
