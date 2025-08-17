class basic_settings::kernel (
  Optional[String]            $antivirus_package          = undef,
  String                      $bootloader                 = 'grub',
  Integer                     $connection_max             = 4096,
  String                      $cpu_governor               = 'performance',
  Boolean                     $guest_agent_enable         = false,
  Optional[Boolean]           $hardware_passthrough       = undef,
  Integer                     $hugepages                  = 0,
  Array                       $install_options            = [],
  Enum['all','4']             $ip_version                 = 'all',
  Boolean                     $ip_ra_enable               = true,
  Boolean                     $ip_ra_learn_prefix         = true,
  String                      $network_mode               = 'strict',
  Boolean                     $mglru_enable               = true,
  Enum['initramfs','dracut']  $ram_disk_package           = 'initramfs',
  String                      $security_lockdown          = 'integrity',
  String                      $tcp_congestion_control     = 'brr',
  Integer                     $tcp_fastopen               = 3,
  Array                       $usb_whitelist              = [],
  Array                       $usb_expected               = [],
  Array                       $usb_any_requirements       = [],
) {
  # Set variables
  $os_name = $facts['os']['name'];
  $os_version = $facts['os']['release']['major']
  $kernel_type = $facts['kernelrelease'] ? {
    /-raspi$/   => 'raspi',
    /-generic$/ => 'generic',
    default     => 'other',
  }
  $monitoring_enable = defined(Class['basic_settings::monitoring'])
  $systemd_enable = defined(Package['systemd'])
  $usb_whitelist_correct = join($usb_whitelist, ' ')
  $usb_expected_correct = join($usb_expected, ' ')
  $usb_any_requirements_correct = join($usb_any_requirements, ' ')

  # Try to get some settings
  if ($facts['is_virtual']) {
    case $facts['virtual'] {
      'vmware': {
        $guest_agent_package = 'open-vm-tools'
      }
      default: {
        $guest_agent_package = 'qemu-guest-agent'
      }
    }

    # Check if we need extra tools for hardware passthrough
    if ($hardware_passthrough == undef) {
      $hardware_passthrough_correct = false
    } else {
      $hardware_passthrough_correct = $hardware_passthrough
    }
  } else {
    $hardware_passthrough_correct = true
    $guest_agent_package = undef
  }

  # When efi, the minimal lockdown state is integrity
  if (!$facts['secure_boot_enabled']) {
    # Override some settings when we have antivirus or we are virtual machine
    case $antivirus_package {
      'eset': {
        $security_lockdown_correct = 'none'
      }
      default: {
        if ($guest_agent_enable and $guest_agent_package != undef) {
          $security_lockdown_correct = 'none'
        } else {
          $security_lockdown_correct = $security_lockdown
        }
      }
    }
  } elsif ($security_lockdown != 'none') {
    $security_lockdown_correct = $security_lockdown
  } else {
    $security_lockdown_correct = 'integrity'
  }

  # Get IP versions
  case $ip_version {
    '4': {
      $ip_version_v4 = true
      $ip_version_v6 = false
    }
    default: {
      $ip_version_v4 = true
      $ip_version_v6 = true
    }
  }

  # Install extra packages when Ubuntu
  case $kernel_type {
    'generic': {
      # Install generic kernel
      package { 'linux-generic':
        ensure          => installed,
        install_options => ['--no-install-recommends', '--no-install-suggests'],
      }

      # Remove raspi kernel
      package { ['linux-raspi', 'linux-image-raspi']:
        ensure          => purged,
        install_options => ['--no-install-recommends', '--no-install-suggests'],
        require         => Package['linux-generic'],
      }

      # Install generic HWE kernel
      if ($os_name == 'Ubuntu' and $os_version != '26.04') {
        package { ["linux-image-generic-hwe-${os_version}", "linux-headers-generic-hwe-${os_version}"]:
          ensure          => installed,
          install_options => ['--no-install-recommends', '--no-install-suggests'],
        }
      }
    }
    'raspi': {
      # Install raspi kernel
      package { 'linux-raspi':
        ensure          => installed,
        install_options => ['--no-install-recommends', '--no-install-suggests'],
      }

      # Remove generic kernel
      package { ['linux-generic', 'linux-image-generic*']:
        ensure          => purged,
        install_options => ['--no-install-recommends', '--no-install-suggests'],
        require         => Package['linux-raspi'],
      }
    }
  }

  # Create group for hugetlb only when hugepages is given
  if ($systemd_enable and $hugepages > 0) {
    # Set variable 
    $hugepages_shm_group = 7000

    # Install libhugetlbfs package
    package { 'libhugetlbfs-bin':
      ensure          => installed,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
    }

    # Remove group 
    group { 'hugetlb':
      ensure  => present,
      gid     => $hugepages_shm_group,
      require => Package['libhugetlbfs-bin'],
    }

    # Create drop in for dev-hugepages mount
    basic_settings::systemd_drop_in { 'hugetlb_hugepages':
      target_unit => 'dev-hugepages.mount',
      mount       => {
        'Options' => "mode=1770,gid=${hugepages_shm_group}",
      },
      require     => Group['hugetlb'],
    }

    # Create systemd service
    basic_settings::systemd_service { 'dev-hugepages-shmmax':
      description => 'Hugespages recommended shmmax service',
      service     => {
        'Type'      => 'oneshot',
        'ExecStart' => '/usr/bin/hugeadm --set-recommended-shmmax',
      },
      unit        => {
        'Requires' => 'dev-hugepages.mount',
        'After'    => 'dev-hugepages.mount',
      },
      install     => {
        'WantedBy' => 'dev-hugepages.mount',
      },
    }

    # Reload sysctl deamon
    exec { 'kernel_sysctl_reload':
      command     => '/usr/bin/bash -c "/usr/bin/systemctl start dev-hugepages-shmmax.service && /usr/sbin/sysctl --system"',
      refreshonly => true,
    }
  } else {
    # Set variable
    $hugepages_shm_group = 0

    # Install libhugetlbfs package
    package { 'libhugetlbfs-bin':
      ensure => purged,
    }

    # Remove group 
    group { 'hugetlb':
      ensure  => absent,
      require => Package['libhugetlbfs-bin'],
    }

    # Remove drop in for dev-hugepages mount
    if (defined(Package['systemd'])) {
      basic_settings::systemd_drop_in { 'hugetlb_hugepages':
        ensure      => absent,
        target_unit => 'dev-hugepages.mount',
        require     => Group['hugetlb'],
      }
    }

    # Reload sysctl deamon
    exec { 'kernel_sysctl_reload':
      command     => '/usr/sbin/sysctl --system',
      refreshonly => true,
    }
  }

  # Remove unnecessary packages
  package { ['apport', 'installation-report', 'linux-tools-common', 'pemmican-common', 'plymouth', 'thermald', 'upower']:
    ensure  => purged,
  }

  # Install system package
  if (!defined(Package['bc'])) {
    package { 'bc':
      ensure          => installed,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
    }
  }

  # Install system package
  if (!defined(Package['coreutils'])) {
    package { 'coreutils':
      ensure          => installed,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
    }
  }

  # Install system package
  if (!defined(Package['findutils'])) {
    package { 'findutils':
      ensure          => installed,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
    }
  }

  # Install system package
  if (!defined(Package['grep'])) {
    package { 'grep':
      ensure          => installed,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
    }
  }

  # Install system package
  if (!defined(Package['lsb-release'])) {
    package { 'lsb-release':
      ensure          => installed,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
    }
  }

  # Install system package
  if (!defined(Package['lsof'])) {
    package { 'lsof':
      ensure          => installed,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
    }
  }

  # Install system package
  if (!defined(Package['kmod'])) {
    package { 'kmod':
      ensure          => installed,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
    }
  }

  # Install system package
  if (!defined(Package['sed'])) {
    package { 'sed':
      ensure          => installed,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
    }
  }

  # Install system package
  if (!defined(Package['util-linux'])) {
    package { 'util-linux':
      ensure          => installed,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
    }
  }

  # Create sysctl config
  file { '/etc/sysctl.conf':
    ensure  => file,
    content => template('basic_settings/kernel/sysctl.conf'),
    owner   => 'root',
    group   => 'root',
    mode    => '0600',
    notify  => Exec['kernel_sysctl_reload'],
  }

  # Create sysctl config
  file { '/etc/sysctl.d':
    ensure  => directory,
    owner   => 'root',
    group   => 'root',
    mode    => '0600',
    force   => true,
    purge   => true,
    recurse => true,
    notify  => Exec['kernel_sysctl_reload'],
  }

  # Create sysctl network config
  file { '/etc/sysctl.d/90-network.conf':
    ensure  => file,
    content => template('basic_settings/kernel/sysctl/network.conf'),
    owner   => 'root',
    group   => 'root',
    mode    => '0600',
    notify  => Exec['kernel_sysctl_reload'],
  }

  # Create sysctl memory config
  file { '/etc/sysctl.d/90-memory.conf':
    ensure  => file,
    content => template('basic_settings/kernel/sysctl/memory.conf'),
    owner   => 'root',
    group   => 'root',
    mode    => '0600',
    notify  => Exec['kernel_sysctl_reload'],
  }

  # Create symlink
  file { '/etc/sysctl.d/99-sysctl.conf':
    ensure => 'link',
    target => '/etc/sysctl.conf',
    force  => true,
    notify => Exec['kernel_sysctl_reload'],
  }

  # Set apparmor state
  if (defined(Package['apparmor'])) {
    $apparmor_enable = true
  } else {
    $apparmor_enable = false
  }

  # Get CPU processor
  if (empty($facts['processors']['models'])) {
    $cpu_processor = ''
  } else {
    $cpu_processor = $facts['processors']['models'][0]
  }

  # Set CPU manufacturer
  if ($cpu_processor =~ 'AMD') {
    $cpu_manufacturer = 'amd'
  } elsif ($cpu_processor =~ 'Intel') {
    $cpu_manufacturer = 'intel'
  } else {
    $cpu_manufacturer = undef
  }

  # Set CPU settings
  if (!$facts['is_virtual']) {
    # Get settings
    $cpu_governor_correct = $cpu_governor
    case $cpu_governor_correct {
      'performance': {
        case $cpu_manufacturer {
          'amd', 'intel': {
            $cpu_boost = 1
            $cpu_idle_max_cstate = 1
            $cpu_pstate = 'passive'
          }
          default: {
            $cpu_boost = undef
            $cpu_idle_max_cstate = undef
            $cpu_pstate = undef
          }
        }
      }
      default: {
        $cpu_boost = undef
        $cpu_idle_max_cstate = undef
        $cpu_pstate = undef
      }
    }

    # Check if boot value is given
    if ($cpu_boost != undef) {
      exec { 'kernel_cpu_boost':
        command => "/usr/bin/bash -c 'echo \"1\" > /sys/devices/system/cpu/cpufreq/boost'",
        onlyif  => "/usr/bin/bash -c 'if [ ! -f /sys/devices/system/cpu/cpufreq/boost ]; then exit 1; fi; if [ $(cat /sys/devices/system/cpu/cpufreq/boost) -eq \"${cpu_boost}\" ]; then exit 1; else exit 0; fi'", #lint:ignore:140chars
      }
    }
  } else {
    # Set some settings
    $cpu_governor_corect = undef
    $cpu_boost = undef
    $cpu_idle_max_cstate = undef
    $cpu_pstate = undef
  }

  # Check if we have hardware that is passthrough
  if ($hardware_passthrough_correct) {
    # Install firmware packages
    if ($facts['secure_boot_enabled']) {
      package { ['fwupd', 'fwupd-signed']:
        ensure  => installed,
      }
    } else {
      package { 'fwupd':
        ensure  => installed,
      }
    }

    # Set fwupd-refresh 
    service { 'fwupd-refresh.timer':
      ensure  => true,
      enable  => true,
      require => Package['fwupd'],
    }
  } else {
    # Remove firmware packages
    package { ['fwupd', 'fwupd-signed', 'rpi-eeprom-update']:
      ensure  => purged,
    }
  }

  # Install ram disk package
  case $ram_disk_package { #lint:ignore:case_without_default
    'dracut': {
      # Install packages
      package {['dracut', 'dracut-core']:
        ensure          => installed,
        install_options => ['--no-install-recommends', '--no-install-suggests'],
      }

      # Remove unused packages
      package {['initramfs-tools', 'initramfs-tools-bin', 'initramfs-tools-core']:
        ensure  => purged,
        require => Package['dracut-core'],
      }
    }
    'initramfs': {
      # Install packages 
      if ($os_name == 'Ubuntu') {
        if ($os_version == '24.04') {
          package {['dhcpcd-base', 'initramfs-tools', 'initramfs-tools-bin', 'initramfs-tools-core']:
            ensure          => installed,
            install_options => ['--no-install-recommends', '--no-install-suggests'],
          }
        } else {
          package {['dhcpcd-base', 'initramfs-tools', 'initramfs-tools-core']:
            ensure          => installed,
            install_options => ['--no-install-recommends', '--no-install-suggests'],
          }
        }
      } else {
        package {['dhcpcd-base', 'initramfs-tools', 'initramfs-tools-core']:
          ensure          => installed,
          install_options => ['--no-install-recommends', '--no-install-suggests'],
        }
      }

      # Remove unused packages
      package {['dracut', 'dracut-core']:
        ensure  => purged,
        require => Package['initramfs-tools-core'],
      }
    }
  }

  # Setup TCP
  case $bootloader {
    'grub': {
      # Set boot loader packages
      $bootloader_packages = ['/usr/sbin/update-grub']

      # Install package
      package { 'grub2-common':
        ensure          => installed,
        install_options => ['--no-install-recommends', '--no-install-suggests'],
        require         => Package['initramfs-tools-core'],
      }

      # Remove unnecessary packages
      package { 'systemd-boot':
        ensure  => purged,
        require => Package['grub2-common'],
      }

      # Reload sysctl deamon
      exec { 'kernel_grub_update':
        command     => '/usr/sbin/update-grub',
        refreshonly => true,
      }

      # Create custom grub config
      file { '/etc/default/grub':
        ensure  => file,
        content => template('basic_settings/kernel/grub'),
        owner   => 'root',
        group   => 'root',
        mode    => '0600',
        notify  => Exec['kernel_grub_update'],
      }
    }
    default: {
      $bootloader_packages = []
    }
  }

  # Create list of packages that is suspicious
  $suspicious_packages = flatten($bootloader_packages, ['/bin/su']);

  # Setup TCP
  case $tcp_congestion_control {
    'bbr': {
      exec { 'tcp_congestion_control':
        command => '/usr/bin/printf "net.core.default_qdisc=fq\nnet.ipv4.tcp_congestion_control=bbr" > /etc/sysctl.d/20-tcp_congestion_control.conf; chmod 600 /etc/sysctl.d/20-tcp_congestion_control.conf; sysctl -p /etc/sysctl.d/20-tcp_congestion_control.conf', #lint:ignore:140chars
        onlyif  => ['test ! -f /etc/sysctl.d/20-tcp_congestion_control.conf', 'test 4 -eq $(cat /boot/config-$(uname -r) | grep -c -E \'CONFIG_TCP_CONG_BBR|CONFIG_NET_SCH_FQ\')'], #lint:ignore:140chars
      }
    }
    default: {
      exec { 'tcp_congestion_control':
        command => '/usr/bin/rm /etc/sysctl.d/20-tcp_congestion_control.conf',
        onlyif  => '[ -e /etc/sysctl.d/20-tcp_congestion_control.conf ]',
        notify  => Exec['kernel_sysctl_reload'],
      }
    }
  }

  # Improve kernel io
  exec { 'kernel_io':
    command => '/usr/bin/bash -c "dev=$(cat /tmp/kernel_io.state); echo \'none\' > /sys/block/\$dev/queue/scheduler;"',
    onlyif  => '/usr/bin/bash -c "dev=$(eval $(lsblk -oMOUNTPOINT,PKNAME -P -M | grep \'MOUNTPOINT="/"\'); echo $PKNAME | sed \'s/[0-9]*$//\'); echo \$dev > /tmp/kernel_io.state; if [ $(grep -c \'\\[none\\]\' /sys/block/$(cat /tmp/kernel_io.state)/queue/scheduler) -eq 0 ]; then exit 0; fi; exit 1"', #lint:ignore:140chars
  }

  # Activate transparent hugepage modus
  exec { 'kernel_transparent_hugepage':
    command => "/usr/bin/bash -c 'echo \"madvise\" > /sys/kernel/mm/transparent_hugepage/enabled'",
    onlyif  => '/usr/bin/bash -c "if [ $(grep -c \'\\[madvise\\]\' /sys/kernel/mm/transparent_hugepage/enabled) -eq 0 ]; then exit 0; fi; exit 1"', #lint:ignore:140chars
  }

  # Activate transparent hugepage defrag
  exec { 'kernel_transparent_hugepage_defrag':
    command => "/usr/bin/bash -c 'echo \"madvise\" > /sys/kernel/mm/transparent_hugepage/defrag'",
    onlyif  => '/usr/bin/bash -c "if [ $(grep -c \'\\[madvise\\]\' /sys/kernel/mm/transparent_hugepage/defrag) -eq 0 ]; then exit 0; fi; exit 1"', #lint:ignore:140chars
  }

  # Kernel Multi-Gen LRU
  if ($mglru_enable) {
    $mglru_min_ttl_ms = 1000
    exec { 'kernel_mglru':
      command => "/usr/bin/bash -c 'echo \"y\" > /sys/kernel/mm/lru_gen/enabled'",
      onlyif  => '/usr/bin/bash -c "if [ $(grep -c \'0x0003\|0x0007\' /sys/kernel/mm/lru_gen/enabled) -eq 0 ]; then exit 0; fi; exit 1"', #lint:ignore:140chars
    }
  } else {
    $mglru_min_ttl_ms = 0
    exec { 'kernel_mglru':
      command => "/usr/bin/bash -c 'echo \"n\" > /sys/kernel/mm/lru_gen/enabled'",
      onlyif  => '/usr/bin/bash -c "if [ $(grep -c \'0x0000\' /sys/kernel/mm/lru_gen/enabled) -eq 0 ]; then exit 0; fi; exit 1"', #lint:ignore:140chars
    }
  }

  # Kernel Multi-Gen LRU thrashing prevention
  exec { 'kernel_mglru_min_ttl_ms':
    command => "/usr/bin/bash -c 'echo \"${mglru_min_ttl_ms}\" > /sys/kernel/mm/lru_gen/min_ttl_ms'",
    onlyif  => "/usr/bin/bash -c \"if [ $(grep -c \'${mglru_min_ttl_ms}\' /sys/kernel/mm/lru_gen/min_ttl_ms) -eq 0 ]; then exit 0; fi; exit 1\"", #lint:ignore:140chars
    require => Exec['kernel_mglru'],
  }

  # Kernel security lockdown
  exec { 'kernel_security_lockdown':
    command => "/usr/bin/bash -c 'echo \"${security_lockdown_correct}\" > /sys/kernel/security/lockdown'",
    onlyif  => "/usr/bin/bash -c \"if [ $(grep -c '\\[${security_lockdown_correct}\\]' /sys/kernel/security/lockdown) -eq 0 ]; then exit 0; fi; exit 1\"", #lint:ignore:140chars
  }

  # Guest agent
  if ($guest_agent_package != undef) {
    if ($guest_agent_enable) {
      package { $guest_agent_package:
        ensure          => installed,
        install_options => union($install_options, ['--no-install-recommends', '--no-install-suggests']),
      }
    } else {
      package { $guest_agent_package:
        ensure  => purged,
      }
    }
  }

  # Setup monitoring
  if ($monitoring_enable and $basic_settings::monitoring::package != 'none') {
    basic_settings::monitoring_custom { 'usb':
      friendly => 'USB',
      content  => template('basic_settings/monitoring/check_usb'),
    }
  }

  # Create kernel rules
  basic_settings::security_audit { 'kernel':
    rules                    => [
      '# Injection',
      '# These rules watch for code injection by the ptrace facility.',
      '# This could indicate someone trying to do something bad or just debugging',
      '-a always,exit -F arch=b64 -S ptrace -F a0=0x4 -F key=code_injection',
      '-a always,exit -F arch=b32 -S ptrace -F a0=0x4 -F key=code_injection',
      '-a always,exit -F arch=b64 -S ptrace -F a0=0x5 -F key=data_injection',
      '-a always,exit -F arch=b32 -S ptrace -F a0=0x5 -F key=data_injection',
      '-a always,exit -F arch=b64 -S ptrace -F a0=0x6 -F key=register_injection',
      '-a always,exit -F arch=b32 -S ptrace -F a0=0x6 -F key=register_injection',
      '-a always,exit -F arch=b64 -S ptrace -F key=tracing',
      '-a always,exit -F arch=b32 -S ptrace -F key=tracing',
    ],
    rule_suspicious_packages => $suspicious_packages,
    order                    => 15,
  }

  # Ignore current working directory records
  basic_settings::security_audit { 'kernel-cwd':
    rules => ['-a always,exclude -F msgtype=CWD'], # Special case, don't use never,exit
    order => 1,
  }
}
