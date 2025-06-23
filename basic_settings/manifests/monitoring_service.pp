define basic_settings::monitoring_service (
  Optional[String] $friendly = undef,
  Optional[Array]  $services = undef
) {
  # Get friendly name
  if ($friendly == undef) {
    $friendly_correct = $name
  } else {
    $friendly_correct = $friendly
  }

  # Get list of services
  if ($services == undef) {
    $services_correct = $name
  } else {
    $services_correct = join($services, '&service=')
  }

  case $basic_settings::monitoring::package {
    'ncpa': {
      file { "/usr/local/ncpa/etc/ncpa.cfg.d/${name}_service.cfg":
        ensure  => file,
        owner   => 'root',
        group   => 'nagios',
        content => "# Managed by puppet\n[passive checks]\n%HOSTNAME%|${friendly_correct} Service = services?service=${services_correct}&status=running&check=1\n",
        notify  => $basic_settings::monitoring::notify,
        require => File['monitoring_location_config'],
      }
    }
  }
}
