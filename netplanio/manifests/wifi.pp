define netplanio::wifi (
  Hash                      $access_points,
  Optional[Array]           $addresses       = undef,
  Optional[Boolean]         $dhcp_enable     = undef,
  Enum['present','absent']  $ensure          = present,
  Optional[String]          $interface       = undef,
  Optional[String]          $ip_version      = undef,
) {
  if ($ensure) {
    # Check if wpasupplicant is not installed
    if (!defined(Package['wpasupplicant'])) {
      # Install wpasupplicant package
      package { 'wpasupplicant':
        ensure          => installed,
        install_options => ['--no-install-recommends', '--no-install-suggests'],
      }
    }

    # Get interface
    if ($interface == undef) {
      $interface_correct = $name
    } else {
      $interface_correct = $interface
    }

    # Try to get dhcp value
    if ($dhcp_enable == undef) {
      $dhcpc_correct = $netplanio::dhcp_enable
    } else {
      $dhcpc_correct = $dhcp_enable
    }

    # Get IP versions
    if ($ip_version == undef) {
      $ip_version_correct = $netplanio::ip_version
    } else {
      $ip_version_correct = $ip_version
    }

    # Set IP values
    case $ip_version_correct {
      '4': {
        $ip_version_v4 = true
        $ip_version_v6 = false
      }
      default: {
        $ip_version_v4 = true
        $ip_version_v6 = true
      }
    }

    # Try to get IP RA value
    if ($dhcpc_correct and $ip_version_v6) {
      $ip_ra_enable = $netplanio::ip_ra_enable
    } else {
      $ip_ra_enable = false
    }

    # Convert boolean to string
    $dhcpc_string = bool2str($dhcpc_correct, 'true', 'false')
    $ip_ra_string = bool2str($ip_ra_enable, 'true', 'false')

    # Set values
    $renderer = $netplanio::renderer

    # Config file
    file { "/etc/netplan/${name}.yaml":
      ensure  => file,
      content => Sensitive.new(template('netplanio/wifi.yaml')),
      owner   => 'root',
      group   => 'root',
      mode    => '0600',
      notify  => Exec['netplanio_apply'],
      require => Package['netplan.io'],
    }
  } else {
    # Remove config
    file { "/etc/netplan/${name}.yaml":
      ensure  => absent,
    }
  }
}
