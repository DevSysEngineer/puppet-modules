define basic_settings::monitoring_custom (
  Optional[String]          $source         = undef,
  Optional[String]          $content        = undef,
  Enum['present','absent']  $ensure         = present,
  Optional[String]          $friendly       = undef,
  Integer                   $interval       = 300,
  Optional[String]          $package        = undef,
  Boolean                   $root_required  = true,
  Integer                   $timeout        = 30
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
  if ($root_required and !defined(Package['sudo'])) {
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
      $script_name = "check_${name}"
      $script_path = "/etc/openitcockpit-agent/plugins/${script_name}"
      $uid = 'root'
      $gid = 'root'

      # Create fragment for plugin
      if ($ensure == present) {
        concat::fragment { "monitoring_plugin_${name}":
          target  => '/etc/openitcockpit-agent/customchecks.ini',
          content => "\n[${script_name}] # ${friendly_correct}\ncommand = ${script_path}\ninterval = ${interval}\ntimeout = ${timeout}\nenabled = true\n",
          order   => '10',
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
    if ($root_required and $uid != 'root') {
      $sudo_cmnd = regsubst("monitoring_plugin_${name}", '[^A-Za-z0-9]', '_', 'G').upcase
      file { "/etc/sudoers.d/${sudoers_prefix}25-monitoring_plugin_${name}":
        ensure  => $file_ensure,
        owner   => 'root',
        group   => 'root',
        mode    => '0440',
        content => "# Managed by puppet\nCmnd_Alias ${sudo_cmnd} = ${script_path} * \nDefaults!${sudo_cmnd} !mail_always \n${uid} ALL=(root) NOPASSWD: ${sudo_cmnd}\n",
        require => Package['sudo'],
      }
    }
  }
}
