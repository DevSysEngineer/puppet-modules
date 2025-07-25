define openitcockpit::host (
  Optional[String]          $address    = undef,
  Enum['present','absent']  $ensure     = present,
  Optional[String]          $friendly   = undef,
  Hash                      $checks     = {},
) {
  # Create host file
  file { "/etc/openitcockpit/conf.d/host_${name}.cfg":
    ensure  => $ensure,
    owner   => 'openitcockpit',
    group   => 'openitcockpit',
    mode    => '0600',
    content => template('openitcockpit/host.cfg'),
    require => File['/etc/openitcockpit/conf.d'],
  }
}
