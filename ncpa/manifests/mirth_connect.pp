class ncpa::mirth_connect (
  Enum['present','absent']  $ensure     = present,
  Optional[String]          $package    = undef
) {
  basic_settings::monitoring_custom { 'mirth_connect':
    ensure   => $ensure,
    package  => $package,
    friendly => 'Mirth Connect',
    source   => 'puppet:///modules/ncpa/check_mirth_conect',
  }
}
