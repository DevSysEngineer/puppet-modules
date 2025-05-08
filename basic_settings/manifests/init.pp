class basic_settings (
  Optional[String]                      $antivirus_package                          = undef,
  Boolean                               $backports                                  = false,
  String                                $cluster_id                                 = 'core',
  Enum['allow-downgrade','no']          $dns_dnssec                                 = 'allow-downgrade',
  Boolean                               $docs_enable                                = false,
  String                                $environment                                = 'production',
  String                                $firewall_package                           = 'nftables',
  Boolean                               $getty_enable                               = false,
  Boolean                               $gitlab_enable                              = false,
  Boolean                               $guest_agent_enable                         = false,
  Enum['none','kiosk','adwaita-icon']   $gui_mode                                   = 'none',
  Enum['none','netplan.io']             $ip_configurator_package                    = 'none',
  Boolean                               $ip_dhcp_enable                             = true,
  Enum['all','4']                       $ip_version                                 = 'all',
  Boolean                               $ip_ra_enable                               = true,
  Boolean                               $ip_ra_learn_prefix                         = true,
  Integer                               $kernel_connection_max                      = 4096,
  Integer                               $kernel_hugepages                           = 0,
  Boolean                               $kernel_mglru_enable                        = true,
  String                                $kernel_network_mode                        = 'strict',
  Enum['initramfs','dracut']            $kernel_ram_disk_package                    = 'initramfs',
  String                                $kernel_security_lockdown                   = 'integrity',
  String                                $kernel_tcp_congestion_control              = 'brr',
  Integer                               $kernel_tcp_fastopen                        = 3,
  Optional[Boolean]                     $keyboard_enable                            = undef,
  Boolean                               $locale_enable                              = false,
  Boolean                               $lvm_enable                                 = false,
  String                                $mail_package                               = 'postfix',
  Boolean                               $mongodb_enable                             = false,
  Float                                 $mongodb_version                            = 8.0,
  Boolean                               $mozilla_enable                             = false,
  Boolean                               $mysql_enable                               = false,
  Float                                 $mysql_version                              = 8.0,
  Boolean                               $nginx_enable                               = false,
  Boolean                               $nodejs_enable                              = false,
  Integer                               $nodejs_version                             = 20,
  Boolean                               $non_free                                   = false,
  Boolean                               $openjdk_enable                             = false,
  String                                $openjdk_version                            = 'default',
  Boolean                               $pro_enable                                 = false,
  Boolean                               $pro_monitoring_enable                      = false,
  Boolean                               $proxmox_enable                             = false,
  Optional[Enum['distro','remote']]     $puppet_repo                                = undef,
  Boolean                               $puppetserver_enable                        = false,
  Enum['openvox','perforce']            $puppetserver_source                        = 'perforce',
  Boolean                               $rabbitmq_enable                            = false,
  String                                $server_fdqn                                = $facts['networking']['fqdn'],
  String                                $server_timezone                            = 'UTC',
  String                                $smtp_server                                = 'localhost',
  Boolean                               $snap_enable                                = false,
  Boolean                               $sudoers_dir_enable                         = true,
  Boolean                               $sury_enable                                = false,
  String                                $systemd_default_target                     = 'helpers',
  String                                $systemd_notify_mail                        = 'root',
  Array                                 $systemd_ntp_extra_pools                    = [],
  Array                                 $unattended_upgrades_block_extra_packages   = [],
  Array                                 $unattended_upgrades_block_packages         = [
    'libmysql*',
    'mysql*',
    'nginx',
    'nodejs',
    'php*',
    'rabbitmq-server',
  ],
  Boolean                               $wireless_enable                            = false,
  Boolean                               $voxpupuli_enable                           = false
) {
  # Get puppet prefix
  case $puppetserver_source {
    'perforce': {
      $puppetserver_prefix = 'puppet'
      $puppetserver_master = 'puppet-master'
    }
    'openvox': {
      $puppetserver_prefix = 'openvox-'
      $puppetserver_master = 'openvox-server'
    }
  }

  # Get OS name
  case $facts['os']['name'] {
    'Ubuntu': {
      # Set some variables
      $os_parent = 'ubuntu'
      $os_repo = 'main universe restricted'
      if ($facts['os']['architecture'] == 'amd64') {
        $os_url = 'http://archive.ubuntu.com/ubuntu/'
        $os_url_security = 'http://security.ubuntu.com/ubuntu'
      } else {
        $os_url = 'http://ports.ubuntu.com/ubuntu-ports/'
        $os_url_security = 'http://ports.ubuntu.com/ubuntu-ports/'
      }

      # Do thing based on version
      if ($facts['os']['release']['major'] == '24.04') { # LTS
        $backports_allow = false
        $deb_version = '822'
        $gcc_version = 14
        $gitlab_allow = true
        $mongodb_allow = true
        $mozilla_allow = true
        if ($facts['os']['architecture'] == 'amd64') {
          $mysql_allow = true
          $rabbitmq_allow = true
        } else {
          $mysql_allow = false
          $rabbitmq_allow = false
        }
        $nginx_allow = true
        $nodejs_allow = true
        $openjdk_allow = true
        $os_name = 'noble'
        $ram_disk_package = 'initramfs'
        $proxmox_allow = false
        $puppetserver_dir = 'puppetserver'
        $puppetserver_jdk = true
        $puppetserver_package = "${puppetserver_prefix}server"
        $sury_allow = true
        $voxpupuli_allow = true
      } elsif ($facts['os']['release']['major'] == '23.04') { # Stable
        $backports_allow = false
        $deb_version = 'list'
        $gcc_version = 12
        $gitlab_allow = true
        $mongodb_allow = true
        $mozilla_allow = true
        if ($facts['os']['architecture'] == 'amd64') {
          $mysql_allow = true
          $rabbitmq_allow = true
        } else {
          $mysql_allow = false
          $rabbitmq_allow = true
        }
        $nginx_allow = true
        $nodejs_allow = true
        $openjdk_allow = true
        $os_name = 'lunar'
        $ram_disk_package = 'initramfs'
        $proxmox_allow = false
        $puppetserver_dir = 'puppetserver'
        $puppetserver_jdk = true
        $puppetserver_package = "${puppetserver_prefix}server"
        $sury_allow = false
        $voxpupuli_allow = true
      } elsif ($facts['os']['release']['major'] == '22.04') { # LTS
        $backports_allow = false
        $deb_version = 'list'
        $gcc_version = 12
        $gitlab_allow = true
        $mongodb_allow = true
        $mozilla_allow = true
        if ($facts['os']['architecture'] == 'amd64') {
          $mysql_allow = true
          $rabbitmq_allow = true
        } else {
          $mysql_allow = false
          $rabbitmq_allow = false
        }
        $nginx_allow = true
        $nodejs_allow = true
        $openjdk_allow = true
        $os_name = 'jammy'
        $ram_disk_package = 'initramfs'
        $proxmox_allow = false
        $puppetserver_dir = 'puppet'
        $puppetserver_jdk = false
        $puppetserver_package = $puppetserver_master
        $sury_allow = true
        $voxpupuli_allow = true
      } else {
        $backports_allow = false
        $deb_version = 'list'
        $gcc_version = undef
        $gitlab_allow = false
        $mongodb_allow = false
        $mozilla_allow = false
        $mysql_allow = false
        $nginx_allow = false
        $nodejs_allow = false
        $openjdk_allow = false
        $os_name = 'unknown'
        $ram_disk_package = 'initramfs'
        $rabbitmq_allow = false
        $proxmox_allow = false
        $puppetserver_dir = 'puppet'
        $puppetserver_jdk = false
        $puppetserver_package = $puppetserver_master
        $sury_allow = false
        $voxpupuli_allow = false
      }
    }
    'Debian': {
      # Set some variables
      $os_parent = 'debian'
      $os_repo = 'main contrib non-free-firmware'
      $os_url = 'http://deb.debian.org/debian/'
      $os_url_security = 'http://deb.debian.org/debian-security/'

      # Do thing based on version
      if ($facts['os']['release']['major'] == '12') {
        $backports_allow = false
        $deb_version = 'list'
        $gcc_version = undef
        $gitlab_allow = true
        $mongodb_allow = true
        $mozilla_allow = true
        if ($facts['os']['architecture'] == 'amd64') {
          $mysql_allow = true
        } else {
          $mysql_allow = false
        }
        $nginx_allow = true
        $nodejs_allow = true
        $openjdk_allow = true
        $os_name = 'bookworm'
        $ram_disk_package = 'initramfs'
        $rabbitmq_allow = true
        $proxmox_allow = false
        $puppetserver_dir = 'puppetserver'
        $puppetserver_jdk = true
        $puppetserver_package = "${puppetserver_prefix}server"
        $sury_allow = true
        $voxpupuli_allow = true
      } else {
        $backports_allow = false
        $deb_version = 'list'
        $gcc_version = undef
        $gitlab_allow = false
        $mongodb_allow = false
        $mozilla_allow = false
        $mysql_allow = false
        $nginx_allow = false
        $nodejs_allow = false
        $openjdk_allow = false
        $os_name = 'unknown'
        $ram_disk_package = 'initramfs'
        $rabbitmq_allow = false
        $proxmox_allow = false
        $puppetserver_dir = 'puppet'
        $puppetserver_jdk = false
        $puppetserver_package = $puppetserver_master
        $sury_allow = false
        $voxpupuli_allow = false
      }
    }
    default: {
      $backports_allow = false
      $deb_version = 'list'
      $gcc_version = undef
      $gitlab_allow = false
      $mongodb_allow = false
      $mozilla_allow = false
      $mysql_allow = false
      $nginx_allow = false
      $nodejs_allow = false
      $openjdk_allow = false
      $os_name = 'unknown'
      $ram_disk_package = 'initramfs'
      $rabbitmq_allow = false
      $proxmox_allow = false
      $puppetserver_dir = 'puppet'
      $puppetserver_jdk = false
      $puppetserver_package = $puppetserver_master
      $sury_allow = false
    }
  }

  # Get ramdisk package
  if ($kernel_ram_disk_package == undef) {
    $kernel_ram_disk_package_correct = $ram_disk_package
  } else {
    $kernel_ram_disk_package_correct = $kernel_ram_disk_package
  }

  # Get snap state
  if ($pro_enable and !$snap_enable) {
    $snap_correct = true
  } else {
    $snap_correct = $snap_enable
  }

  # Get IP RA state
  if ($ip_dhcp_enable and $ip_ra_enable) {
    $ip_ra_enable_correct = $ip_ra_enable
  } else {
    $ip_ra_enable_correct = false
  }

  # Get audio state
  case $gui_mode {
    'kiosk': {
      $audio_enable = true
    }
    default: {
      $audio_enable = false
    }
  }

  # Basic system packages; This packages needed to be installed first
  package { ['apt', 'bc', 'coreutils', 'dpkg', 'grep', 'lsb-release', 'kmod', 'sed', 'util-linux']:
    ensure          => installed,
    install_options => ['--no-install-recommends', '--no-install-suggests'],
  }

  # Basic system packages
  package { 'sysstat':
    ensure          => installed,
    install_options => ['--no-install-recommends', '--no-install-suggests'],
  }

  # Reload source list
  exec { 'basic_settings_source_reload':
    command     => '/usr/bin/apt-get update',
    refreshonly => true,
  }

  # Check if we need newer format for APT
  if ($deb_version == '822') {
    # Based on OS parent use correct source list
    file { '/etc/apt/sources.list':
      ensure  => file,
      path    => '/etc/apt/sources.list',
      mode    => '0600',
      owner   => 'root',
      group   => 'root',
      content => "# Managed by puppet\n# ${facts['os']['name']} sourcess have to moved to /etc/apt/sources.list.d/${os_parent}.sources\n",
      require => Package['apt'],
    }

    # Based on OS parent use correct source list
    file { 'basic_settings_source':
      ensure  => file,
      path    => "/etc/apt/sources.list.d/${os_parent}.sources",
      mode    => '0600',
      owner   => 'root',
      group   => 'root',
      content => template("basic_settings/source/${os_parent}.sources"),
      require => [Package['apt'], File['/etc/apt/sources.list']],
    }

    # Check if we need backports
    if ($backports and $backports_allow) {
      $backports_install_options = ['-t', "${os_name}-backports"]
    } else {
      $backports_install_options = []
    }
  } else {
    # Check if we need backports
    if ($backports and $backports_allow) {
      $backports_install_options = ['-t', "${os_name}-backports"]
      exec { 'basic_settings_source_backports':
        command => "/usr/bin/printf \"deb ${os_url} ${os_name}-backports ${os_repo}\\n\" > /etc/apt/sources.list.d/${os_name}-backports.list", #lint:ignore:140chars
        unless  => "[ -e /etc/apt/sources.list.d/${os_name}-backports.list ]",
        notify  => Exec['basic_settings_source_reload'],
        require => [Package['apt'], Package['coreutils']],
      }
    } else {
      $backports_install_options = []
      exec { 'basic_settings_source_backports':
        command => "/usr/bin/rm /etc/apt/sources.list.d/${os_name}-backports.list",
        onlyif  => "[ -e /etc/apt/sources.list.d/${os_name}-backports.list ]",
        notify  => Exec['basic_settings_source_reload'],
        require => [Package['apt'], Package['coreutils']],
      }
    }

    # Based on OS parent use correct source list
    file { 'basic_settings_source':
      ensure  => file,
      path    => '/etc/apt/sources.list',
      mode    => '0600',
      owner   => 'root',
      group   => 'root',
      content => template("basic_settings/source/${os_parent}.list"),
      require => Exec['basic_settings_source_backports'],
    }
  }

  # Set systemd
  class { 'basic_settings::systemd':
    cluster_id      => $cluster_id,
    default_target  => $systemd_default_target,
    install_options => $backports_install_options,
    require         => File['basic_settings_source']
  }

  # Setup message
  class { 'basic_settings::message':
    mail_to         => $systemd_notify_mail,
    mail_package    => $mail_package,
    server_fdqn     => $server_fdqn,
    require         => Class['basic_settings::systemd']
  }

  # Setup security
  class { 'basic_settings::security':
    mail_to     => $systemd_notify_mail,
    server_fdqn => $server_fdqn,
    require     => Class['basic_settings::message'],
  }

  # Set IO
  class { 'basic_settings::io':
    lvm_enable => $lvm_enable,
    require    => Class['basic_settings::message'],
  }

  # Setup APT
  class { 'basic_settings::packages':
    unattended_upgrades_block_extra_packages => $unattended_upgrades_block_extra_packages,
    unattended_upgrades_block_packages       => $unattended_upgrades_block_packages,
    server_fdqn                              => $server_fdqn,
    snap_enable                              => $snap_correct,
    mail_to                                  => $systemd_notify_mail,
    require                                  => [
      File['/etc/apt/sources.list'],
      Class['basic_settings::message']
    ],
  }

  # Set Pro
  class { 'basic_settings::pro':
    enable            => $pro_enable,
    monitoring_enable => $pro_monitoring_enable,
    require           => Class['basic_settings::message']
  }

  # Set timezone
  class { 'basic_settings::timezone':
    timezone        => $server_timezone,
    ntp_extra_pools => $systemd_ntp_extra_pools,
    install_options => $backports_install_options,
    require         => [File['basic_settings_source'], Class['basic_settings::message']],
  }

  # Setup kernel
  class { 'basic_settings::kernel':
    antivirus_package       => $antivirus_package,
    connection_max          => $kernel_connection_max,
    guest_agent_enable      => $guest_agent_enable,
    hugepages               => $kernel_hugepages,
    install_options         => $backports_install_options,
    ip_version              => $ip_version,
    ip_ra_enable            => $ip_ra_enable_correct,
    ip_ra_learn_prefix      => $ip_ra_learn_prefix,
    mglru_enable            => $kernel_mglru_enable,
    network_mode            => $kernel_network_mode,
    ram_disk_package        => $kernel_ram_disk_package_correct,
    security_lockdown       => $kernel_security_lockdown,
    tcp_congestion_control  => $kernel_tcp_congestion_control,
    tcp_fastopen            => $kernel_tcp_fastopen
  }

  # Set network
  class { 'basic_settings::network':
    antivirus_package    => $antivirus_package,
    dhcp_enable          => $ip_dhcp_enable,
    dns_dnssec           => $dns_dnssec,
    firewall_package     => $firewall_package,
    install_options      => $backports_install_options,
    configurator_package => $ip_configurator_package,
    wireless_enable      => $wireless_enable,
    require              => [File['basic_settings_source'], Class['basic_settings::message']],
  }

  # Set timezone
  class { 'basic_settings::locale':
    enable              => $locale_enable,
    docs_enable         => $docs_enable
  }

  # Set assistent
  class { 'basic_settings::assistent':
    audio_enable    => $audio_enable,
    keyboard_enable => $keyboard_enable,
  }

  # Check if variable gitlab is true; if true, install new source list and key
  if ($gitlab_enable and $gitlab_allow) {
    class { 'basic_settings::package_gitlab':
      deb_version => $deb_version,
      enable      => true,
      os_parent   => $os_parent,
      os_name     => $os_name,
    }
  } else {
    class { 'basic_settings::package_gitlab':
      deb_version => $deb_version,
      enable      => false,
      os_parent   => $os_parent,
      os_name     => $os_name,
    }
  }

  # Check if variable mysql is true; if true, install new source list and key
  if ($mongodb_enable and $mongodb_allow) {
    class { 'basic_settings::package_mongodb':
      deb_version => $deb_version,
      enable      => true,
      os_parent   => $os_parent,
      os_name     => $os_name,
      version     => $mongodb_version,
    }
  } else {
    class { 'basic_settings::package_mongodb':
      deb_version => $deb_version,
      enable      => false,
      os_parent   => $os_parent,
      os_name     => $os_name,
    }
  }

  # Check if variable mozilla is true; if true, install new source list and key
  if ($mozilla_enable and $mozilla_allow) {
    class { 'basic_settings::package_mozilla':
      deb_version => $deb_version,
      enable      => true,
      os_parent   => $os_parent,
      os_name     => $os_name,
    }
  } else {
    class { 'basic_settings::package_mozilla':
      deb_version => $deb_version,
      enable      => false,
      os_parent   => $os_parent,
      os_name     => $os_name,
    }
  }

  # Check if variable mysql is true; if true, install new source list and key
  if ($mysql_enable and $mysql_allow) {
    class { 'basic_settings::package_mysql':
      deb_version => $deb_version,
      enable      => true,
      os_parent   => $os_parent,
      os_name     => $os_name,
      version     => $mysql_version,
    }
  } else {
    class { 'basic_settings::package_mysql':
      deb_version => $deb_version,
      enable      => false,
      os_parent   => $os_parent,
      os_name     => $os_name,
    }
  }

  # Check if variable nginx is true; if true, install new source list and key
  if ($nginx_enable and $nginx_allow) {
    class { 'basic_settings::package_nginx':
      deb_version => $deb_version,
      enable      => true,
      os_parent   => $os_parent,
      os_name     => $os_name,
    }
  } else {
    class { 'basic_settings::package_nginx':
      deb_version => $deb_version,
      enable      => false,
      os_parent   => $os_parent,
      os_name     => $os_name,
    }
  }

  # Check if variable nodejs is true; if true, install new source list and key
  if ($nodejs_enable and $nodejs_allow) {
    class { 'basic_settings::package_node':
      enable  => true,
      version => $nodejs_version,
    }
  } else {
    class { 'basic_settings::package_node':
      enable  => false,
    }
  }

  # Check if variable proxmox is true; if true, install new source list and key
  if ($proxmox_enable and $proxmox_allow) {
    class { 'basic_settings::package_proxmox':
      deb_version => $deb_version,
      enable      => true,
      os_parent   => $os_parent,
      os_name     => $os_name,
    }
  } else {
    class { 'basic_settings::package_proxmox':
      deb_version => $deb_version,
      enable      => false,
      os_parent   => $os_parent,
      os_name     => $os_name,
    }
  }

  # Check if variable rabbitmq is true; if true, install new source list and key
  if ($rabbitmq_enable and $rabbitmq_allow) {
    class { 'basic_settings::package_rabbitmq':
      deb_version => $deb_version,
      enable      => true,
      os_parent   => $os_parent,
      os_name     => $os_name,
    }
  } else {
    class { 'basic_settings::package_rabbitmq':
      deb_version => $deb_version,
      enable      => false,
      os_parent   => $os_parent,
      os_name     => $os_name,
    }
  }

  # Check if variable rabbitmq is true; if true, install new source list and key
  if ($sury_enable and $sury_allow) {
    class { 'basic_settings::package_sury':
      deb_version => $deb_version,
      enable      => true,
      os_parent   => $os_parent,
      os_name     => $os_name,
    }
  } else {
    class { 'basic_settings::package_sury':
      deb_version => $deb_version,
      enable      => false,
      os_parent   => $os_parent,
      os_name     => $os_name,
    }
  }

  # Check if variable sury is true; if true, install new source list and key
  if ($voxpupuli_enable and $voxpupuli_allow) {
    class { 'basic_settings::package_voxpupuli':
      deb_version => $deb_version,
      enable      => true,
      os_parent   => $os_parent,
      os_version  => $facts['os']['release']['major'],
    }
  } else {
    class { 'basic_settings::package_voxpupuli':
      deb_version => $deb_version,
      enable      => false,
      os_parent   => $os_parent,
      os_version  => $facts['os']['release']['major'],
    }
  }

  # Try to get puppet repo
  if ($puppet_repo == undef) {
    if ($voxpupuli_enable and $voxpupuli_allow) {
      $puppet_repo_correct = 'remote'
    } else {
      $puppet_repo_correct = 'distro'
    }
  } else {
    $puppet_repo_correct = 'distro'
  }

  # Check if variable openjdk is true; if true, install new package
  if (($puppetserver_enable and $puppetserver_jdk) or ($openjdk_enable and $openjdk_allow)) {
    # Get package name
    if ($puppetserver_enable or $openjdk_version == 'default') {
      $openjdk_package = 'default-jdk'
    } else {
      $openjdk_package = "openjdk-${openjdk_version}-jdk"
    }

    # Install openjdk package
    package { 'openjdk':
      ensure          => installed,
      name            => $openjdk_package,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
    }

    # Install java extensions
    package { ['adwaita-icon-theme', 'ca-certificates-java', 'dconf-service']:
      ensure          => installed,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
      require         => Package['openjdk'],
    }
  } else {
    # Remove openjdk package
    package { 'openjdk':
      ensure => purged,
      name   => 'openjdk*',
    }

    # Setup GUI mode
    case $gui_mode {
      'kiosk': {
        $adwaita_icon_theme_enable = true
        $dconf_service_enable = true
      }
      'adwaita-icon': {
        $adwaita_icon_theme_enable = true
        $dconf_service_enable = false
      }
      default: {
        $adwaita_icon_theme_enable = false
        $dconf_service_enable = false
      }
    }

    if ($adwaita_icon_theme_enable) {
      # Install adwaita icon package
      package { 'adwaita-icon-theme':
        ensure          => installed,
        install_options => ['--no-install-recommends', '--no-install-suggests'],
        require         => Package['openjdk'],
      }
    } else {
      # Remove adwaita icon package
      package { 'adwaita-icon-theme':
        ensure  => purged,
        require => Package['openjdk'],
      }
    }

    if ($dconf_service_enable) {
      # Install dconf service package
      package { 'dconf-service':
        ensure          => installed,
        install_options => ['--no-install-recommends', '--no-install-suggests'],
        require         => Package['openjdk'],
      }
    } else {
      # Remove dconf service package
      package { 'dconf-service':
        ensure  => purged,
        require => Package['openjdk'],
      }
    }

    # Remove java extensions
    package { ['ca-certificates-java']:
      ensure  => purged,
      require => Package['openjdk'],
    }
  }

  # Setup development
  class { 'basic_settings::development':
    gcc_version     => $gcc_version,
    install_options => $backports_install_options,
    require         => File['basic_settings_source']
  }

  # Setup Puppet
  class { 'basic_settings::puppet':
    repo           => $puppet_repo_correct,
    server_dir     => $puppetserver_dir,
    server_enable  => $puppetserver_enable,
    server_package => $puppetserver_package,
  }

  # Setup login
  class { 'basic_settings::login':
    environment        => $environment,
    getty_enable       => $getty_enable,
    gui_mode           => $gui_mode,
    mail_to            => $systemd_notify_mail,
    server_fdqn        => $server_fdqn,
    sudoers_dir_enable => $sudoers_dir_enable,
  }
}
