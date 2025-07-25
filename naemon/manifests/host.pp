define naemon::host (
  String                    $address,
  Enum['present','absent']  $ensure     = present,
  Optional[String]          $friendly   = undef,
  Hash                      $checks     = {},
) {
  # Create host file
  file { "${naemon::config_dir}/20-host${name}.cfg":
    ensure  => $ensure,
    owner   => $naemon::webserver_uid,
    group   => $naemon::webserver_gid,
    mode    => '0600',
    content => template('naemon/host.cfg'),
    notify  => Service['naemon'],
    require => File[$naemon::config_dir],
  }
}
