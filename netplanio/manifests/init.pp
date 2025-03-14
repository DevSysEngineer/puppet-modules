class netplanio (
) {
  # Check if systemd is not installed
  if (!defined(Package['netplan.io'])) {
    # Install netplan.io package
    package { 'netplan.io':
      ensure          => installed,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
    }
  }

  # Check if we have network class
  if (!defined(Class['basic_settings::network'])) {
    $dhcp_enable = true
    if (defined(Class['basic_settings::kernel'])) {
      $ip_version = $basic_settings::kernel::ip_version
      $ip_ra_enable = ($basic_settings::kernel::ip_version_v6 and $basic_settings::kernel::ip_ra_enable)
    } else {
      $ip_version = 'all'
      $ip_ra_enable = false
    }
  } else {
    $dhcp_enable = $basic_settings::network::dhcp_enable
    $ip_ra_enable = $basic_settings::network::ip_ra_enable
    $ip_version = $basic_settings::network::ip_version
  }

  # Check if we have systemd
  if (defined(Package['systemd'])) {
    $renderer = 'networkd'
  } else {
    $renderer = undef
  }

  # Setup audit rules
  if (defined(Package['auditd'])) {
    basic_settings::security_audit { 'netplanio':
      rules => [
        '-a always,exit -F arch=b32 -F path=/etc/netplan -F perm=wa -F key=netplanio',
        '-a always,exit -F arch=b64 -F path=/etc/netplan -F perm=wa -F key=netplanio',
      ],
      order => 20,
    }
  }
