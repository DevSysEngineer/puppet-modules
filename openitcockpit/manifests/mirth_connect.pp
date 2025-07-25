class openitcockpit::agent_mirth_connect (
  Enum['present','absent']  $ensure     = present,
  Optional[String]          $package    = undef
) {
  basic_settings::monitoring_custom { 'mirth_connect':
    ensure   => $ensure,
    package  => $package,
    friendly => 'Mirth Connect',
    content  => template('openitcockpit/agent/check_mysql'),
  }
}
