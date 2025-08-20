class basic_settings::io (
  Integer $log_rotate = 14,
  Boolean $lvm_enable = true,
  Boolean $multipath_enable = false,
  Boolean $nfs_server_enable = false
) {
  # Create list of packages that is suspicious
  $default_packages = [
    '/usr/bin/rsync',
    '/usr/sbin/fdisk',
    '/usr/sbin/parted',
    '/usr/bin/lsblk',
  ]
  $default_packages_root = [
    '/usr/bin/lsblk',
  ]

  # Install default development packages
  package { ['fuse', 'logrotate', 'pbzip2', 'pigz', 'rsync', 'unzip', 'xz-utils']:
    ensure          => installed,
    install_options => ['--no-install-recommends', '--no-install-suggests'],
  }

  # Remove package for connection with Windows environment / device
  package { ['ntfs-3g', 'smbclient']:
    ensure  => purged,
  }

  # Check if we need LVM
  if ($lvm_enable) {
    # Install LVM2 package
    package { 'lvm2':
      ensure          => installed,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
    }

    # Set suspicious packages
    $suspicious_packages = flatten($default_packages, [
        '/usr/sbin/fsadm',
        '/usr/sbin/lvchange',
        '/usr/sbin/lvconvert',
        '/usr/sbin/lvcreate',
        '/usr/sbin/lvdisplay',
        '/usr/sbin/lvextend',
        '/usr/sbin/lvm',
        '/usr/sbin/lvmconfig',
        '/usr/sbin/lvmdiskscan',
        '/usr/sbin/lvmdump',
        '/usr/sbin/lvmpolld',
        '/usr/sbin/lvmsadc',
        '/usr/sbin/lvmsar',
        '/usr/sbin/lvreduce',
        '/usr/sbin/lvremove',
        '/usr/sbin/lvrename',
        '/usr/sbin/lvresize',
        '/usr/sbin/lvs',
        '/usr/sbin/lvscan',
        '/usr/sbin/pvchange',
        '/usr/sbin/pvck',
        '/usr/sbin/pvcreate',
        '/usr/sbin/pvdisplay',
        '/usr/sbin/pvmove',
        '/usr/sbin/pvremove',
        '/usr/sbin/pvresize',
        '/usr/sbin/pvs',
        '/usr/sbin/pvscan',
        '/usr/sbin/vgcfgbackup',
        '/usr/sbin/vgcfgrestore',
        '/usr/sbin/vgchange',
        '/usr/sbin/vgck',
        '/usr/sbin/vgconvert',
        '/usr/sbin/vgcreate',
        '/usr/sbin/vgdisplay',
        '/usr/sbin/vgexport',
        '/usr/sbin/vgextend',
        '/usr/sbin/vgimport',
        '/usr/sbin/vgimportclone',
        '/usr/sbin/vgmerge',
        '/usr/sbin/vgmknodes',
        '/usr/sbin/vgreduce',
        '/usr/sbin/vgremove',
        '/usr/sbin/vgrename',
        '/usr/sbin/vgs',
        '/usr/sbin/vgscan',
        '/usr/sbin/vgsplit',
    ])
    $suspicious_packages_root = $default_packages_root
  } else {
    package { 'lvm2':
      ensure  => purged,
    }
    $suspicious_packages = $default_packages
    $suspicious_packages_root = $default_packages_root
  }

  # Check if we need multipatp
  if ($multipath_enable) {
    # Active multipatch
    exec { 'multipath_cmdline':
      command => "/usr/bin/sed 's/multipath=off//g' /boot/firmware/cmdline.txt",
      onlyif  => "/usr/bin/bash -c 'if [ ! -f /boot/firmware/cmdline.txt ]; then exit 1; fi; if [ $(grep -c \'multipath=off\' /boot/firmware/cmdline.txt) -eq 1 ]; then exit 0; fi; exit 1'", #lint:ignore:140chars
      require => Package['sed'],
    }

    # Install multipath
    package { ['multipath-tools', 'multipath-tools-boot']:
      ensure          => installed,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
      require         => Exec['multipath_cmdline'],
    }

    # Enable multipathd service
    service { 'multipathd':
      ensure  => true,
      enable  => true,
      require => Package['multipath-tools-boot'],
    }

    # Create service check
    if (defined(Class['basic_settings::monitoring']) and $basic_settings::monitoring::package != 'none') {
      basic_settings::monitoring_service { 'multipathd': }
    }

    # Create multipart config
    file { '/etc/multipath.conf':
      ensure => file,
      source => 'puppet:///modules/basic_settings/io/multipath.conf',
      owner  => 'root',
      group  => 'root',
      mode   => '0600',
      notify => Service['multipathd'],
    }
  } else {
    # Remove multipath
    package { ['multipath-tools', 'multipath-tools-boot']:
      ensure  => purged,
    }
  }

  # Check if we need NFS server
  if ($nfs_server_enable) {
    package { ['nfs-kernel-server', 'rpcbind']:
      ensure          => installed,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
    }
  } else {
    package { ['nfs-kernel-server', 'rpcbind']:
      ensure  => purged,
    }
  }

  # Disable floppy
  file { '/etc/modprobe.d/blacklist-floppy.conf':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0600',
    content => "# Managed by puppet\nblacklist floppy\n",
    require => Package['kmod'],
  }

  if (defined(Package['systemd'])) {
    # Reload systemd deamon
    exec { 'io_systemd_daemon_reload':
      command     => '/usr/bin/systemctl daemon-reload',
      refreshonly => true,
      require     => Package['systemd'],
    }

    # Create drop in for systemd journal service
    basic_settings::systemd_drop_in { 'journald_settings':
      target_unit   => 'journald.conf',
      path          => '/etc/systemd',
      journal       => {
        'MaxLevelSyslog'  => 'warning',
        'MaxLevelConsole' => 'warning',
      },
      daemon_reload => 'io_systemd_daemon_reload',
      require       => Package['systemd'],
    }
  }

  # Setup audit rules
  if (defined(Package['auditd'])) {
    basic_settings::security_audit { 'logrotate':
      rules => [
        '-a never,exit -F arch=b32 -F exe=/usr/sbin/logrotate -F auid=unset',
        '-a never,exit -F arch=b64 -F exe=/usr/sbin/logrotate -F auid=unset',
      ],
      order => 2,
    }
    $suspicious_filter = $suspicious_packages - $suspicious_packages_root
    basic_settings::security_audit { 'io':
      rules                    => $networkd_rules,
      rule_suspicious_packages => $suspicious_filter,
    }
    basic_settings::security_audit { 'io-root':
      rule_suspicious_packages => $suspicious_packages_root,
      rule_options             => ['-F auid!=unset'],
      order                    => 20,
    }
  }
}
