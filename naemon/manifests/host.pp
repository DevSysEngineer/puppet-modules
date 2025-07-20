define naemon::host (
  Optional[String]          $address    = undef,
  Enum['present','absent']  $ensure     = present,
  Optional[String]          $friendly   = undef,
  Hash                      $checks     = {},
) {
  # Create host file
  file { "/etc/naemon/conf.d/host_${name}.cfg":
    ensure  => $ensure,
    owner   => 'naemon',
    group   => 'naemon',
    mode    => '0600',
    content => template('naemon/host.cfg'),
    require => File['/etc/naemon/conf.d'],
  }
}
