define basic_settings::monitoring_timer (
  Enum['present','absent']  $ensure     = present,
  Optional[String]          $friendly   = undef,
  Optional[String]          $package    = undef
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
  $file_ensure = $ensure ? { 'present' => 'file', default => $ensure }
  case $package_correct {
    'ncpa': {
      # Set some values
      $script_path = '/usr/local/ncpa/plugin/check_systemd_timer'
      $script_exists = defined(File[$script_path])
      $uid = 'nagios'
      $gid = 'nagios'

      # Check if script path is not defined
      if (!$script_exists) {
        # Create plugin
        file { '/usr/local/ncpa/etc/ncpa.cfg.d/plugin_check_systemd_timer.cfg':
          ensure  => $file_ensure,
          owner   => 'root',
          group   => $gid,
          content => "# Managed by puppet\n[plugin directives]\ncheck_systemd_timer = sudo \$plugin_path/check_systemd_timer \$plugin_args\n",
        }
      }

      # Create check
      file { "/usr/local/ncpa/etc/ncpa.cfg.d/timer_${name}.cfg":
        ensure  => $file_ensure,
        owner   => 'root',
        group   => $gid,
        content => "# Managed by puppet\n[passive checks]\n%HOSTNAME%|${friendly_correct} Timer = plugins/check_systemd_timer?args=${name}.timer\n",
      }
    }
    default: {
      $script_path = undef
      $script_exists = true
      $uid = undef
      $gid = undef
    }
  }

  # Check if script path is not defined
  if (!$script_exists) {
    # Create script
    file { $script_path:
      ensure => $file_ensure,
      source => 'puppet:///modules/basic_settings/monitoring/check_systemd_timer',
      owner  => $uid,
      group  => $gid,
      mode   => '0700',
    }

    # Create sudo
    file { "/etc/sudoers.d/monitoring_timer_${name}":
      ensure  => $file_ensure,
      owner   => 'root',
      group   => $gid,
      content => "# Managed by puppet\nnagios ALL=(root) NOPASSWD: ${script_path} *\n",
    }
  }
}
