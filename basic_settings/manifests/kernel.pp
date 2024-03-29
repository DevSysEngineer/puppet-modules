class basic_settings::kernel(
    $hugepages              = 0,
    $tcp_congestion_control = 'brr',
    $tcp_fastopen           = 3
) {
    /* Install extra packages when Ubuntu */
    if ($operatingsystem == 'Ubuntu') {
        $os_version = $::os['release']['major']
        if ($os_version != '24.04') {
            package { ["linux-image-generic-hwe-${os_version}", "linux-headers-generic-hwe-${os_version}"]:
                ensure  => installed
            }
        }
    }

    /* Create group for hugetlb only when hugepages is given */
    if (defined(Package['systemd']) and $hugepages > 0) {
        # Set variable 
        $hugepages_shm_group = 7000

        /* Install libhugetlbfs package */
        package { 'libhugetlbfs-bin':
            ensure => installed
        }

        # Remove group 
        group { 'hugetlb':
            ensure      => present,
            gid         => $hugepages_shm_group,
            require     => Package['libhugetlbfs-bin']
        }

        /* Create drop in for dev-hugepages mount */
        basic_settings::systemd_drop_in { 'hugetlb_hugepages':
            target_unit     => 'dev-hugepages.mount',
            mount         => {
                'Options' => "mode=1770,gid=${hugepages_shm_group}"
            },
            require         => Group['hugetlb']
        }

        /* Create systemd service */
        basic_settings::systemd_service { 'dev-hugepages-shmmax':
            description => 'Hugespages recommended shmmax service',
            service     => {
                'Type'      => 'oneshot',
                'ExecStart' => '/usr/bin/hugeadm --set-recommended-shmmax'
            },
            unit        => {
                'Requires'  => 'dev-hugepages.mount',
                'After'     => 'dev-hugepages.mount'
            },
            install     => {
                'WantedBy' => 'dev-hugepages.mount'
            }
        }

        /* Reload sysctl deamon */
        exec { 'kernel_sysctl_reload':
            command => 'bash -c "/usr/bin/systemctl start dev-hugepages-shmmax.service && sysctl --system"',
            refreshonly => true
        }
    } else {
        # Set variable
        $hugepages_shm_group = 0

        /* Install libhugetlbfs package */
        package { 'libhugetlbfs-bin':
            ensure => purged
        }

        # Remove group 
        group { 'hugetlb':
            ensure  => absent,
            require => Package['libhugetlbfs-bin']
        }

        /* Remove drop in for dev-hugepages mount */
        if (defined(Package['systemd'])) {
            basic_settings::systemd_drop_in { 'hugetlb_hugepages':
                ensure          => absent,
                target_unit     => 'dev-hugepages.mount',
                require         => Group['hugetlb']
            }
        }

        /* Reload sysctl deamon */
        exec { 'kernel_sysctl_reload':
            command => 'sysctl --system',
            refreshonly => true
        }
    }

    /* Remove unnecessary packages */
    package { ['apport', 'installation-report', 'linux-tools-common', 'thermald', 'upower']:
        ensure  => purged
    }

    /* Basic system packages */
    package { ['bc', 'coreutils', 'lsb-release']:
        ensure  => installed
    }

    /* Create sysctl config  */
    file { '/etc/sysctl.conf':
        ensure  => file,
        content  => template('basic_settings/kernel/sysctl.conf'),
        owner   => 'root',
        group   => 'root',
        mode    => '0600',
        notify  => Exec['kernel_sysctl_reload']
    }

    /* Create sysctl config  */
    file { '/etc/sysctl.d':
        ensure  => directory,
        owner   => 'root',
        group   => 'root',
        mode    => '0600'
    }

    /* Create sysctl network config  */
    file { '/etc/sysctl.d/20-network-security.conf':
        ensure  => file,
        content  => template('basic_settings/kernel/sysctl/network.conf'),
        owner   => 'root',
        group   => 'root',
        mode    => '0600',
        notify  => Exec['kernel_sysctl_reload']
    }

    /* Setup TCP */
    case $tcp_congestion_control {
        'bbr': {
            exec { 'tcp_congestion_control':
                command     => 'printf "net.core.default_qdisc=fq\nnet.ipv4.tcp_congestion_control=bbr" > /etc/sysctl.d/20-tcp_congestion_control.conf; chmod 600 /etc/sysctl.d/20-tcp_congestion_control.conf; sysctl -p /etc/sysctl.d/20-tcp_congestion_control.conf',
                onlyif      => ['test ! -f /etc/sysctl.d/20-tcp_congestion_control.conf', 'test 4 -eq $(cat /boot/config-$(uname -r) | grep -c -E \'CONFIG_TCP_CONG_BBR|CONFIG_NET_SCH_FQ\')']
            }
        }
        default: {
            exec { 'tcp_congestion_control':
                command     => 'rm /etc/sysctl.d/20-tcp_congestion_control.conf',
                onlyif      => '[ -e /etc/sysctl.d/20-tcp_congestion_control.conf]',
                notify      => Exec['kernel_sysctl_reload']
            }
        }
    }

    /* Activate performance modus */
    exec { 'kernel_performance':
        command     => "bash -c 'for (( i=0; i<`nproc`; i++ )); do if [ -d /sys/devices/system/cpu/cpu\${i}/cpufreq ]; then echo \"performance\" > /sys/devices/system/cpu/cpu\${i}/cpufreq/scaling_governor; fi; done > /tmp/kernel_performance.state'",
        onlyif      => "bash -c 'if [[ ! $(grep ^vendor_id /proc/cpuinfo) ]]; then exit 1; fi; if [[ $(grep ^vendor_id /proc/cpuinfo | uniq | awk \"(\$3!='GenuineIntel' && \$3!='AuthenticAMD')\") ]]; then exit 1; fi; if [ -f /tmp/kernel_performance.state ]; then exit 1; else exit 0; fi'"
    }

    /* Activate turbo modus */
    exec { 'kernel_turbo':
        command => "bash -c 'echo \"1\" > /sys/devices/system/cpu/cpufreq/boost'",
        onlyif  => "bash -c 'if [ ! -f /sys/devices/system/cpu/cpufreq/boost ]; then exit 1; fi; if [ $(cat /sys/devices/system/cpu/cpufreq/boost) -eq \"1\" ]; then exit 1; else exit 0; fi'"
    }

    /* Disable CPU core C states */
    exec { 'kernel_c_states':
        command => "bash -c 'for (( i=0; i<`nproc`; i++ )); do if [ -d /sys/devices/system/cpu/cpu\${i}/cpuidle/state2 ]; then echo \"1\" > /sys/devices/system/cpu/cpu\${i}/cpuidle/state2/disable; fi; done > /tmp/kernel_c_states.state'",
        onlyif  => "bash -c 'if [[ ! $(grep ^vendor_id /proc/cpuinfo) ]]; then exit 1; fi; if [ $(grep ^vendor_id /proc/cpuinfo | uniq | \"(\$3!='GenuineIntel')\") ]; then exit 1; fi; if [ -f /tmp/kernel_c_states.state ]; then exit 1; else exit 0; fi'"
    }

    /* Improve kernel io */
    exec { 'kernel_io':
        command => 'bash -c "dev=$(cat /tmp/kernel_io.state); echo \'none\' > /sys/block/\$dev/queue/scheduler;"',
        onlyif  => 'bash -c "dev=$(eval $(lsblk -oMOUNTPOINT,PKNAME -P -M | grep \'MOUNTPOINT="/"\'); echo $PKNAME | sed \'s/[0-9]*$//\'); echo \$dev > /tmp/kernel_io.state; if [ $(grep -c \'\\[none\\]\' /sys/block/$(cat /tmp/kernel_io.state)/queue/scheduler) -eq 0 ]; then exit 0; fi; exit 1"'
    }

    /* Activate transparent hugepage modus */
    exec { 'kernel_transparent_hugepage':
        command => "bash -c 'echo \"madvise\" > /sys/kernel/mm/transparent_hugepage/enabled'",
        onlyif  => 'bash -c "if [ $(grep -c \'\\[madvise\\]\' /sys/kernel/mm/transparent_hugepage/enabled) -eq 0 ]; then exit 0; fi; exit 1"'
    }

    /* Activate transparent hugepage modus */
    exec { 'kernel_transparent_hugepage_defrag':
        command => "bash -c 'echo \"madvise\" > /sys/kernel/mm/transparent_hugepage/defrag'",
        onlyif  => 'bash -c "if [ $(grep -c \'\\[madvise\\]\' /sys/kernel/mm/transparent_hugepage/defrag) -eq 0 ]; then exit 0; fi; exit 1"'
    }
}
