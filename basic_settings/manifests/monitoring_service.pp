define basic_settings::monitoring_service (
  Optional[String] $friendly = undef
) {
  if ($friendly == undef) {
    $friendly_correct = $name
  } else {
    $friendly_correct = $friendly
  }

  case $basic_settings::monitoring::package {
    'ncpa': {
      file { "/usr/local/ncpa/etc/ncpa.cfg.d/${name}_service.cfg":
        ensure  => file,
        owner   => 'root',
        group   => 'nagios',
        content => "# Managed by puppet\n[passive checks]\n%HOSTNAME%|${friendly_correct} Service = services?service=${name}&status=running&check=1",
        notify  => $basic_settings::monitoring::notify,
        require => File['monitoring_location_config'],
      }
    }
  }
}
