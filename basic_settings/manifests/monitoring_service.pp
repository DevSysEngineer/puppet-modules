define basic_settings::monitoring_service (
  Enum['present','absent']  $ensure     = present,
  Optional[String]          $friendly   = undef,
  Optional[Array]           $services   = undef,
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

  # Do thing based on package
  $file_ensure = $ensure ? { 'present' => 'file', default => $ensure }
  case $package_correct {
    'ncpa': {
      # Get list of services
      if ($services == undef) {
        $services_correct = $name
      } else {
        $services_correct = join($services, '&service=')
      }

      # Create check
      file { "/usr/local/ncpa/etc/ncpa.cfg.d/service_${name}.cfg":
        ensure  => $file_ensure,
        owner   => 'root',
        group   => 'nagios',
        mode    => '0600',
        content => "# Managed by puppet\n[passive checks]\n%HOSTNAME%|${friendly_correct} Service = services?service=${services_correct}&status=running&check=1\n",
      }
    }
  }
}
