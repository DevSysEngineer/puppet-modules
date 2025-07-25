define naemon::hostgroup (
  Enum['present','absent']  $ensure      = present,
  Optional[String]          $description = undef,
) {
  # Create host file
  file { "${naemon::config_dir}/10-hostgroup_${name}.cfg":
    ensure  => $ensure,
    owner   => $naemon::webserver_uid,
    group   => $naemon::webserver_gid,
    mode    => '0600',
    content => template('openitcockpit/hostgroup.cfg'),
    notify  => Service['naemon'],
  }
}
