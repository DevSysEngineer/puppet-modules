define basic_settings::monitoring_service (
  Enum['present','absent']  $ensure         = present,
  Optional[String]          $active_windows = undef,
  Optional[String]          $active_days    = undef,
  Optional[String]          $friendly       = undef,
  Optional[Array]           $services       = undef,
  Optional[String]          $package        = undef
) {
  # Get friendly name
  if ($friendly == undef) {
    $friendly_correct = capitalize($name)
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
    $sudoers_dir_enable = $basic_settings::monitoring::sudoers_dir_enable
  } else {
    $package_correct = 'none'
    $sudoers_dir_enable = false
  }

  # Get sudoers prefix
  if ($sudoers_dir_enable) {
    $sudoers_prefix = ''
  } else {
    $sudoers_prefix = 'z'
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
    'openitcockpit': {
      # Set some values
      $script_path = '/etc/openitcockpit-agent/plugins/check_systemd_service'
      $script_exists = defined(File[$script_path])
      $uid = 'root'
      $gid = 'root'

      # Check services
      if ($services != undef) {
        $services_correct = $services
        if (length($services) == 1) {
          $parent_force = true
        }
      } else {
        $services_correct = $name
        $parent_force = false
      }

      # Create monitoring service parts
      basic_settings::monitoring_service_part { $services_correct:
        ensure         => $ensure,
        package        => 'openitcockpit',
        parent_force   => $parent_force,
        parent_name    => $name,
        script_path    => $script_path,
        friendly       => $friendly_correct,
        active_windows => $active_windows,
        active_days    => $active_days,
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
      source => 'puppet:///modules/basic_settings/monitoring/check_systemd_service',
      owner  => $uid,
      group  => $gid,
      mode   => '0700',
    }

    # Create sudo
    if ($uid != 'root') {
      $sudo_cmnd = regsubst("monitoring_service_${name}", '[^A-Za-z0-9]', '_', 'G').upcase
      file { "/etc/sudoers.d/${sudoers_prefix}25-monitoring_service_${name}":
        ensure  => $file_ensure,
        owner   => 'root',
        group   => $gid,
        mode    => '0440',
        content => "# Managed by puppet\nCmnd_Alias ${sudo_cmnd} = ${script_path} * \nDefaults!${sudo_cmnd} !mail_always\n${uid} ALL=(root) NOPASSWD: ${sudo_cmnd}\n",
        require => Package['sudo'],
      }
    }
  }
}
