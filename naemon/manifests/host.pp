define naemon::host (
  Optional[String]          $address    = undef,
  Enum['present','absent']  $ensure     = present,
  Optional[String]          $friendly   = undef,
  Hash                      $checks     = {},
) {
  # Create host file
  file { "/usr/local/nagios/etc/servers/${name}.cfg":
    ensure  => $ensure,
    owner   => 'nagios',
    group   => 'nagios',
    mode    => '0600',
    content => template('naemon/host.cfg'),
    require => File['/usr/local/nagios/etc/servers'],
  }
}
