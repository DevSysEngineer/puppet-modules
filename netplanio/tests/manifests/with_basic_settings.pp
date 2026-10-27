# Let the baseline manage the packages required by both interface types.
class { 'basic_settings':
  ip_configurator_package => 'netplan.io',
  wireless_enable         => true,
}

# Evaluate network package ownership before Netplan checks for existing packages.
include basic_settings::network
include netplanio

netplanio::ethernet { 'eth0': }

# Use an open synthetic network; no wireless credentials are required to compile.
netplanio::wifi { 'wlan0':
  access_points => { 'compile-example' => {} },
}
