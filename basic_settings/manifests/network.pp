class basic_settings::network (
  Enum['nftables','iptables','firewalld']     $firewall_package,
  Optional[String]                            $antivirus_package      = undef,
  Optional[String]                            $communication_name     = undef,
  Enum['none','netplan.io']                   $configurator_package   = 'none',
  Boolean                                     $dhcp_enable            =  true,
  Enum['allow-downgrade','no']                $dns_dnssec             = 'allow-downgrade',
  Array                                       $dns_fallback           = [
    '8.8.8.8',
    '8.8.4.4',
    '2001:4860:4860::8888',
    '2001:4860:4860::8844',
  ],
  String                                      $environment            = 'production',
  String                                      $firewall_path          = '/etc/firewall.conf',
  Boolean                                     $firewall_remove        = true,
  Array                                       $install_options        = [],
  String                                      $interfaces             = 'eth* ens* wlan*',
  String                                      $server_fdqn            = $facts['networking']['fqdn'],
  Boolean                                     $wireless_enable        = false,
) {
  # Set some default values
  $kernel_enable = defined(Class['basic_settings::kernel'])
  $monitoring_enable = defined(Class['basic_settings::monitoring'])
  $systemd_enable = defined(Package['systemd'])

  # Get IP data
  if ($kernel_enable) {
    $ip_version = $basic_settings::kernel::ip_version
    if ($basic_settings::kernel::ip_version_v6 and $dhcp_enable and $basic_settings::kernel::ip_ra_enable) {
      $ip_ra_enable = true
    } else {
      $ip_ra_enable = false
    }
  } else {
    $ip_version = 'all'
    if ($dhcp_enable) {
      $ip_ra_enable = true
    } else {
      $dhcp_enable = false
    }
  }

  # Get LLDP data
  $lldp_platform = $facts['os']['name']
  $lldp_description = "${lldp_platform} ${environment} server"
  if ($communication_name == undef) {
    $lldp_hostname = $lldp_platform.downcase()
    $lldp_fqdn = "${lldp_hostname}.${environment}.server"
  } else {
    $lldp_hostname = regsubst($communication_name.downcase, '\s+', '-', 'G')
    $lldp_fqdn = "${communication_name}.${environment}.server"
  }

  # Default suspicious packages
  $default_packages = [
    '/usr/bin/ip',
    '/usr/bin/mtr',
    '/usr/bin/nc',
    '/usr/bin/netcat',
    '/usr/bin/ping',
    '/usr/bin/ping4',
    '/usr/bin/ping6',
    '/usr/bin/tcptraceroute',
    '/usr/bin/tcpdump',
    '/usr/bin/telnet',
    '/usr/sbin/arp',
    '/usr/sbin/route',
    '/usr/sbin/traceroute',
  ]

  # Based on firewall package do special commands
  case $firewall_package { #lint:ignore:case_without_default
    'nftables': {
      $firewall_command = ''
      if ($firewall_remove) {
        package { ['iptables', 'firewalld']:
          ensure => purged,
        }

        # Remove unnecessary files
        file { '/etc/firewalld':
          ensure  => absent,
          recurse => true,
          force   => true,
          require => Package['firewalld'],
        }
      }

      # Create list of packages that is suspicious
      $suspicious_packages = flatten($default_packages, ['/usr/sbin/nft'])
    }
    'iptables': {
      $firewall_command = "iptables-restore < ${firewall_path}"
      if ($firewall_remove) {
        package { ['nftables', 'firewalld']:
          ensure => purged,
        }
      }

      # Create list of packages that is suspicious
      $suspicious_packages = flatten($default_packages, ['/usr/sbin/iptables'])
    }
    'firewalld': {
      $firewall_command = ''
      case $antivirus_package {
        'eset': {
          if ($firewall_remove) {
            package { 'iptables':
              ensure => purged,
            }
          }
          package { 'nftables':
            ensure          => installed,
            install_options => ['--no-install-recommends', '--no-install-suggests'],
          }

          # Create list of packages that is suspicious
          $suspicious_packages = flatten($default_packages, ['/usr/bin/firewall-cmd', '/usr/sbin/nft'])
        }
        default:  {
          if ($firewall_remove) {
            package { ['nftables', 'iptables']:
              ensure => purged,
            }
          }

          # Create list of packages that is suspicious
          $suspicious_packages = flatten($default_packages, ['/usr/bin/firewall-cmd'])
        }
      }
    }
  }

  # Install package
  package { $firewall_package:
    ensure          => installed,
    install_options => union($install_options, ['--no-install-recommends', '--no-install-suggests']),
  }

  # Remove unnecessary packages
  package { ['ifupdown', 'iw', 'netcat-traditional', 'wireless-tools']:
    ensure  => purged,
  }

  # Install package
  package { [
      'dnsutils',
      'ethtool',
      'iputils-ping',
      'lldpd',
      'mtr-tiny',
      'netcat-openbsd',
      'net-tools',
      'telnet',
      'tcpdump',
      'iproute2',
      'tcptraceroute',
      'traceroute',
    ]:
      ensure  => installed,
      require => Package['ifupdown'],
  }

  # Check if dhcpc is needed on this server
  $dhcp_state = ($dhcp_enable or ($kernel_enable and $basic_settings::kernel::ram_disk_package == 'initramfs'))
  if ($dhcp_state) {
    # Install dhcpcd-base
    if (!defined(Package['dhcpcd-base'])) {
      package { 'dhcpcd-base':
        ensure          => installed,
        install_options => ['--no-install-recommends', '--no-install-suggests'],
      }
    }

    # Install dhcpcd
    package { ['dhcpcd']:
      ensure          => installed,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
      require         => [Package['dhcpcd-base'], Package['ifupdown']],
    }

    # Enable dhcpcd service
    service { 'dhcpcd':
      ensure  => true,
      enable  => true,
      require => Package['dhcpcd'],
    }

    # DHCP is disabled, but we need dhcpd package because kernel package
    if (!$dhcp_enable and $kernel_enable) {
      # Create config file
      file { '/etc/dhcpcd.conf':
        ensure  => file,
        owner   => 'root',
        group   => 'root',
        mode    => '0600',
        content => "# Managed by puppet\ndenyinterfaces *\n",
        notify  => Service['dhcpcd'],
      }
    }
  } else {
    # Purge dhcpcd
    package { ['dhcpcd', 'dhcpcd-base']:
      ensure  => purged,
      require => Package['ifupdown'],
    }
  }

  # Try to get network configurator
  case $configurator_package {
    'netplan.io': {
      package { 'netplan.io':
        ensure          => installed,
        install_options => ['--no-install-recommends', '--no-install-suggests'],
      }
    }
    default: {
      package { 'netplan.io':
        ensure  => purged,
      }
    }
  }

  # Check if we need to install wireless packages
  if ($wireless_enable) {
    package { 'wpasupplicant':
      ensure          => installed,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
    }
  } else {
    package { 'wpasupplicant':
      ensure  => purged,
    }
  }

  # Reload systemd deamon
  if (defined(Class['basic_settings::systemd']) or $monitoring_enable) {
    exec { 'network_firewall_systemd_daemon_reload':
      command     => '/usr/bin/systemctl daemon-reload',
      refreshonly => true,
      require     => Package['systemd'],
    }
  }

  # Check which firewall we have
  if ($firewall_package == 'nftables' or $firewall_package == 'firewalld') {
    # Start service 
    service { $firewall_package:
      ensure  => running,
      enable  => true,
      require => Package[$firewall_package],
    }

    if ($monitoring_enable) {
      # Create service check
      if ($basic_settings::monitoring::package != 'none') {
        if ($firewall_package == 'nftables') {
          basic_settings::monitoring_custom { 'firewall':
            content => template("basic_settings/monitoring/check_${firewall_package}"),
          }
        } else {
          basic_settings::monitoring_service { 'firewall':
            services => [$firewall_package],
          }
        }
      }

      if ($systemd_enable) {
        # Create drop in for firewall service
        basic_settings::systemd_drop_in { "${firewall_package}_notify_failed":
          target_unit   => "${firewall_package}.service",
          unit          => {
            'OnFailure' => 'notify-failed@%i.service',
          },
          daemon_reload => 'network_firewall_systemd_daemon_reload',
          require       => Package[$firewall_package],
        }
      }
    }
  }

  # Create RX buffer script
  file { '/usr/local/sbin/rxbuffer':
    ensure => file,
    source => 'puppet:///modules/basic_settings/network/rxbuffer',
    owner  => 'root',
    group  => 'root',
    mode   => '0755', # High important
  }

  if ($systemd_enable) {
    # If DHCP is disabled, force system not to use DHCP
    if ($interfaces != '' and !$dhcp_enable) {
      basic_settings::systemd_network { '90-dhcpc':
        interface     => $interfaces,
        network       => {
          'DHCP' => 'no',
        },
        daemon_reload => 'network_firewall_systemd_daemon_reload',
      }
    } else {
      basic_settings::systemd_network { '90-dhcpc':
        ensure        => absent,
        daemon_reload => 'network_firewall_systemd_daemon_reload',
      }
    }

    # Setup default router advertisement settings
    if ($interfaces != '') {
      if ($ip_ra_enable) {
        $ip_learn_prefix = bool2str($basic_settings::kernel::ip_ra_learn_prefix, 'yes', 'no')
        basic_settings::systemd_network { '90-router-advertisement':
          interface      => $interfaces,
          ipv6_accept_ra => {
            'UseAutonomousPrefix' => $ip_learn_prefix,
            'UseOnLinkPrefix'     => $ip_learn_prefix,
          },
          network        => {
            'IPv6AcceptRA'        => 'yes',
            'LinkLocalAddressing' => 'ipv6',
          },
          daemon_reload  => 'network_firewall_systemd_daemon_reload',
        }
      } else {
        basic_settings::systemd_network { '90-router-advertisement':
          interface     => $interfaces,
          network       => {
            'IPv6AcceptRA'        => 'no',
            'LinkLocalAddressing' => 'no',
          },
          daemon_reload => 'network_firewall_systemd_daemon_reload',
        }
      }
    } else {
      basic_settings::systemd_network { '90-router-advertisement':
        ensure        => absent,
        daemon_reload => 'network_firewall_systemd_daemon_reload',
      }
    }

    # Set networkd rules
    $networkd_rules = [
      '-a always,exit -F arch=b32 -F path=/etc/networkd-dispatcher -F perm=wa -F key=network',
      '-a always,exit -F arch=b64 -F path=/etc/networkd-dispatcher -F perm=wa -F key=network',
    ]

    # Install package
    package { 'networkd-dispatcher':
      ensure          => installed,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
      require         => Package['ifupdown'],
    }

    # Set script that's set the firewall
    if ($firewall_command != '') {
      file { 'firewall_networkd_dispatcher':
        ensure  => file,
        path    => "/etc/networkd-dispatcher/routable.d/${firewall_package}",
        mode    => '0755',
        content => "#!/bin/bash\n\ntest -r ${firewall_path} && ${firewall_command}\n\nexit 0\n",
        require => Package[$firewall_package],
      }
    } else {
      # Remove firewall package
      case $firewall_package {
        'nftables', 'firewalld': {
          file { 'firewall_networkd_dispatcher':
            ensure  => absent,
            path    => '/etc/networkd-dispatcher/routable.d/iptables',
            require => Package[$firewall_package],
          }
        }
      }
    }

    # Create RX buffer script
    file { '/etc/networkd-dispatcher/routable.d/rxbuffer':
      ensure  => file,
      content => template('basic_settings/network/rxbuffer'),
      owner   => 'root',
      group   => 'root',
      mode    => '0755', # High important,
      require => [Package['networkd-dispatcher'], File['/usr/local/sbin/rxbuffer']],
    }

    # Check if systemd resolved package exists
    case $facts['os']['name'] {
      'Ubuntu': {
        $os_version = $facts['os']['release']['major']
        if ($os_version == '24.04') {
          $systemd_resolved_package = true
        } else {
          $systemd_resolved_package = false
        }
      }
      default: {
        $systemd_resolved_package = true
      }
    }

    # Set settings
    $systemd_resolved_settings = {
      'Cache'         => 'yes',
      'DNSOverTLS'    => 'opportunistic',
      'DNSSEC'        => $dns_dnssec,
      'FallbackDNS'   => join($dns_fallback, ' '),
      'LLMNR'         => 'no',
      'MulticastDNS'  => 'no',
      'ReadEtcHosts'  => 'yes',
    }

    # Check if we need to install a systemd resolved package or if it's all built-in
    if ($systemd_resolved_package) {
      package { 'systemd-resolved':
        ensure          => installed,
        install_options => union($install_options, ['--no-install-recommends', '--no-install-suggests']),
      }

      # Ensure that networkd services is always running
      service { ['systemd-networkd.service', 'systemd-resolved.service', 'networkd-dispatcher.service']:
        ensure  => running,
        enable  => true,
        require => [Package['systemd'], Package['systemd-resolved'], Package['networkd-dispatcher']],
      }

      # Create drop in for systemd resolved service
      basic_settings::systemd_drop_in { 'resolved_settings':
        target_unit   => 'resolved.conf',
        path          => '/etc/systemd',
        resolve       => $systemd_resolved_settings,
        daemon_reload => 'network_firewall_systemd_daemon_reload',
        require       => Package['systemd-resolved'],
      }
    } else {
      # Ensure that networkd services is always running
      service { ['systemd-networkd.service', 'systemd-resolved.service', 'networkd-dispatcher.service']:
        ensure  => running,
        enable  => true,
        require => [Package['systemd'], Package['networkd-dispatcher']],
      }

      # Create drop in for systemd resolved service
      basic_settings::systemd_drop_in { 'resolved_settings':
        target_unit   => 'resolved.conf',
        path          => '/etc/systemd',
        resolve       => $systemd_resolved_settings,
        daemon_reload => 'network_firewall_systemd_daemon_reload',
      }
    }

    # Create service check
    if ($monitoring_enable and $basic_settings::monitoring::package != 'none') {
      if ($dhcp_state) {
        basic_settings::monitoring_service { 'network':
          services => ['dhcpcd', 'systemd-networkd', 'systemd-resolved', 'networkd-dispatcher'],
        }
      } else {
        basic_settings::monitoring_service { 'network':
          services => ['systemd-networkd', 'systemd-resolved', 'networkd-dispatcher'],
        }
      }
    }

    # Create symlink to network service
    if (defined(Package['dbus'])) {
      file { '/usr/lib/systemd/system/dbus-org.freedesktop.network1.service':
        ensure  => 'link',
        target  => '/usr/lib/systemd/system/systemd-networkd.service',
        notify  => Exec['network_firewall_systemd_daemon_reload'],
        require => Package['dbus'],
      }
    }
  } else {
    $networkd_rules = []
    if ($monitoring_enable and $basic_settings::monitoring::package != 'none' and $dhcp_state) {
      # Create service check
      basic_settings::monitoring_service { 'network':
        services => ['dhcpcd'],
      }
    }
  }

  # Enable lldpd service
  service { 'lldpd':
    ensure  => true,
    enable  => true,
    require => Package['lldpd'],
  }

  # Create lldpd config file
  file { '/etc/lldpd.conf':
    ensure  => file,
    content => template('basic_settings/network/lldpd'),
    owner   => '_lldpd',
    group   => '_lldpd',
    mode    => '0600',
    notify  => Service['lldpd'],
    require => Package['lldpd'],
  }

  # Setup audit rules
  if (defined(Package['auditd'])) {
    $suspicious_filter = delete($suspicious_packages, '/usr/bin/ip')
    basic_settings::security_audit { 'network':
      rules                    => $networkd_rules,
      rule_suspicious_packages => $suspicious_filter,
      order                    => 20,
    }
    basic_settings::security_audit { 'network-root':
      rule_suspicious_packages => delete($suspicious_packages, $suspicious_filter),
      rule_options             => ['-F auid!=unset'],
      order                    => 20,
    }
  }
}
