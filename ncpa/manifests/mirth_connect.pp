class ncpa::mirth_connect (
  Enum['present','absent']  $ensure     = present,
  Optional[String]          $package    = undef
) {
  $systemd_enable = $ncpa::systemd_enable
  basic_settings::monitoring_custom { 'mirth_connect':
    ensure   => $ensure,
    package  => $package,
    friendly => 'Mirth Connect',
    content  => template('mysql/check_mysql'),
  }
}
