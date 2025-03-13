define netplanio::network (
  Optional[Array]           $addresses       = undef,
  Optional[Boolean]         $dhcp_enable     = undef,
  Enum['present','absent']  $ensure          = present,
  Optional[String]          $interface       = undef,
) {
  if ($ensure) {
    # Get interface
    if ($interface == undef) {
      $interface_correct = $name
    } else {
      $interface_correct = $interface
    }

    # Check dhcp value
    if ($dhcp_enable == undef) {
      if (defined(Class['basic_settings::network'])) {
        $dhcpc_correct = $basic_settings::network::dhcpc_enable
      } else {
        $dhcpc_correct = true
      }
    } else {
      $dhcpc_correct = $dhcp_enable
    }

    # Convert boolean to string
    $dhcpc_string = bool2str($dhcpc_correct, 'yes', 'no')

    # Config file
    file { "/etc/netplan/${name}.yaml":
      ensure  => file,
      content => template('netplanio/network.yaml'),
      owner   => 'root',
      group   => 'root',
      mode    => '0600',
    }
  } else {
    # Remove config
    file { "/etc/netplan/${name}.yaml":
      ensure  => absent,
    }
  }
}
