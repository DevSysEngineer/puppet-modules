define basic_settings::monitoring_service_part (
  String                    $friendly,
  String                    $package,
  String                    $parent_name,
  String                    $script_path,
  Optional[String]          $active_days    = undef,
  Optional[String]          $active_windows = undef,
  Enum['present','absent']  $ensure         = present,
  Boolean                   $parent_force   = false
) {
  case $package {
    'openitcockpit': {
      # Create fragment for plugin
      if ($ensure == present) {
        # Build some values
        if ($parent_name == $name or $parent_force) {
          $friendly_correct = $friendly
          $script_name = "check_${parent_name}"
        } else {
          $friendly_correct = "${friendly} ${name}"
          $script_name = "check_${parent_name}_${name}"
        }

        # Build active window parameter
        if ($active_windows != undef) {
          $script_active_window = "-W ${active_windows} "
        } else {
          $script_active_window = ''
        }

        # Build active days parameter
        if ($active_days != undef) {
          $script_active_days = "-D ${active_days} "
        } else {
          $script_active_days = ''
        }

        # Add fragment
        concat::fragment { "monitoring_service_part_${name}":
          target  => '/etc/openitcockpit-agent/customchecks.ini',
          content => "\n[${script_name}] # ${friendly_correct}\ncommand = ${script_path} ${script_active_window}${script_active_days}${name}.service\ninterval = 300\ntimeout = 10\nenabled = true\n",
          order   => '10',
        }
      }
    }
  }
}
