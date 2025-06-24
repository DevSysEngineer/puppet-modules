define basic_settings::monitoring_service (
  Optional[String] $friendly = undef,
  Optional[Array]  $services = undef,
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

  # Do thing based on package
  case $package_correct {
    'ncpa': {
      # Get list of services
      if ($services == undef) {
        $services_correct = $name
      } else {
        $services_correct = join($services, '&service=')
      }

      # Create check
      file { "/usr/local/ncpa/etc/ncpa.cfg.d/${name}_service.cfg":
        ensure  => file,
        owner   => 'root',
        group   => 'nagios',
        content => "# Managed by puppet\n[passive checks]\n%HOSTNAME%|${friendly_correct} Service = services?service=${services_correct}&status=running&check=1\n",
        require => File['monitoring_location_config'],
      }
    }
  }
}
