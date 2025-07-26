define basic_settings::monitoring_service (
  Enum['present','absent']  $ensure     = present,
  Optional[String]          $friendly   = undef,
  Optional[Array]           $services   = undef,
  Optional[String]          $package    = undef
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
  } else {
    $package_correct = 'none'
  }

  # Do thing based on package
  $file_ensure = $ensure ? { 'present' => 'file', default => $ensure }
  case $package_correct {
    'openitcockpit': {
      # Checks can be selected in GUI portal
    }
    default: {
      $script_path = undef
      $script_exists = true
      $uid = undef
      $gid = undef
    }
  }
}
