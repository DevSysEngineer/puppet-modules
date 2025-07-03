define basic_settings::monitoring_custom (
  Optional[String]          $source         = undef,
  Optional[String]          $content        = undef,
  Enum['present','absent']  $ensure         = present,
  Optional[String]          $friendly       = undef,
  Optional[String]          $package        = undef,
  Boolean                   $root_required  = true,
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
  if ($root_required and !defined(Package['sudo'])) {
    package { 'sudo':
      ensure          => installed,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
    }
  }

  # Do thing based on package
  $file_ensure = $ensure ? { 'present' => 'file', default => $ensure }
  case $package_correct {
    'ncpa': {
      # Get script path
      if ($root_required) {
        $script_path = "/usr/local/ncpa/plugins/check_${name}.root"
      } else {
        $script_path = "/usr/local/ncpa/plugins/check_${name}"
      }

      # Set some values
      $uid = 'nagios'
      $gid = 'nagios'

      # Create check
      file { "/usr/local/ncpa/etc/ncpa.cfg.d/timer_${name}.cfg":
        ensure  => $file_ensure,
        owner   => 'root',
        group   => $gid,
        mode    => '0600',
        content => "# Managed by puppet\n[passive checks]\n%HOSTNAME%|${friendly_correct} Timer = plugins/check_${name}\n",
      }

      # Create plugin settings
      $plugin_settings =  '/usr/local/ncpa/etc/ncpa.cfg.d/90-plugins.cfg'
      if ($root_required and !defined(File[$plugin_settings])) {
        file { $plugin_settings:
          ensure  => file,
          owner   => 'root',
          group   => $gid,
          mode    => '0600',
          content => "# Managed by puppet\n[plugin directives]\n.root = /usr/bin/sudo \$plugin_name \$plugin_args\n",
        }
      }
    }
    default: {
      $script_path = undef
      $uid = undef
      $gid = undef
    }
  }

  # Check if script path is not defined
  if ($script_path != undef) {
    # Create script
    file { $script_path:
      ensure  => $file_ensure,
      source  => $source,
      content => $content,
      owner   => $uid,
      group   => $gid,
      mode    => '0700',
    }

    # Create sudo
    if ($root_required) {
      file { "/etc/sudoers.d/monitoring_plugin_${name}":
        ensure  => $file_ensure,
        owner   => 'root',
        group   => 'root',
        mode    => '0440',
        content => "# Managed by puppet\nnagios ALL=(root) NOPASSWD: ${script_path} *\n",
        require => Package['sudo'],
      }
    }
  }
}
