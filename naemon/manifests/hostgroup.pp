define naemon::hostgroup (
  Optional[String]          $description = undef,
  Enum['present','absent']  $ensure      = present
) {
  if (defined(Class['naemon'])) {
    # Create host file
    file { "${naemon::config_dir}/10-hostgroup-${name}.cfg":
      ensure  => $ensure,
      owner   => $naemon::webserver_uid,
      group   => $naemon::webserver_gid,
      mode    => '0600',
      content => template('naemon/hostgroup.cfg'),
      notify  => Service['naemon'],
      require => File[$naemon::config_dir],
    }
  } else {
    fail('The naemon class must be included before using the naemon::hostgroup defined type.')
  }
}
