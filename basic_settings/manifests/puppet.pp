class basic_settings::puppet (
  Boolean                               $server_enable  = false,
  Enum[
    'openvox-server',
    'puppet-master',
    'puppetserver'
  ]                                     $server_package = 'puppetserver',
  String                                $server_dir     = 'puppetserver'
) {
  # Get puppet service name
  case $server_package {
    'openvox-server': {
      $server_service = 'puppetserver'
    }
    default: {
      $server_service = $server_package
    }
  }

  # Remove unnecessary packages
  package { ['cloud-init', 'tasksel']:
    ensure  => purged,
  }

  # Remove unnecessary files
  file { '/boot/firmware/user-data':
    ensure  => absent,
    require => Package['cloud-init'],
  }

  # Install augeas-tools package
  package { 'augeas-tools':
    ensure          => installed,
    install_options => ['--no-install-recommends', '--no-install-suggests'],
  }

  # Disable service
  service { 'puppet':
    ensure => undef,
    enable => false,
  }

  # Create drop in for services target
  if (defined(Class['basic_settings'])) {
    basic_settings::systemd_drop_in { 'puppet_dependency':
      target_unit => "${basic_settings::cluster_id}-system.target",
      unit        => {
        'Wants'   => 'puppet.service',
      },
      require     => Basic_settings::Systemd_target["${basic_settings::cluster_id}-system"],
    }
  }

  if (defined(Package['systemd'])) {
    # Create drop in for puppet service
    basic_settings::systemd_drop_in { 'puppet_settings':
      target_unit => 'puppet.service',
      unit        => {
        'OnFailure' => 'notify-failed@%i.service',
      },
      service     => {
        'Nice'        => 19,
        'LimitNOFILE' => 10000,
      },
    }

    # Get clean filebucket dir
    if ($server_enable) {
      $clean_filebucket_dir = $server_dir
    } else {
      $clean_filebucket_dir = 'puppet'
    }

    # Create systemd puppet clean bucket service
    basic_settings::systemd_service { 'puppet-clean-filebucket':
      description => 'Clean puppet filebucket service',
      service     => {
        'Type'      => 'oneshot',
        'User'      => 'root',
        'ExecStart' => "/usr/bin/find /var/cache/${clean_filebucket_dir}/clientbucket/ -type f -mtime +14 -atime +14 -delete", #lint:ignore:140chars # Last dir separator (/) very important
        'Nice'      => '19',
      },
    }

    # Create systemd puppet server clean reports timer
    basic_settings::systemd_timer { 'puppet-clean-filebucket':
      description => 'Clean puppet filebucket timer',
      timer       => {
        'OnCalendar' => '*-*-* 10:00',
      },
    }
  }

  # Do only the next steps when we are puppet server
  if ($server_enable) {
    # Install package
    package { $server_package:
      ensure          => installed,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
    }

    # Remove other package
    case $server_package {
      'openvox-server': {
        package { ['puppet-master', 'puppetserver']:
          ensure  => purged,
          require => Package[$server_package],
        }
      }
      'puppetserver': {
        package { ['openvox-server', 'puppet-master']:
          ensure  => purged,
          require => Package[$server_package],
        }
      }
      'puppet-master': {
        package { ['openvox-server', 'puppetserver']:
          ensure  => purged,
          require => Package[$server_package],
        }
      }
    }

    # Disable service
    service { $server_service:
      ensure  => undef,
      enable  => false,
      require => Package[$server_package],
    }

    # Create drop in for services target
    if (defined(Class['basic_settings'])) {
      basic_settings::systemd_drop_in { "${server_service}_dependency":
        target_unit => "${basic_settings::cluster_id}-system.target",
        unit        => {
          'Wants'   => "${server_service}.service",
        },
        require     => Basic_settings::Systemd_target["${basic_settings::cluster_id}-system"],
      }
    }

    # Create log dir
    file { 'puppet_reports':
      ensure => directory,
      path   => "/var/log/${server_dir}/reports",
      owner  => 'puppet',
      group  => 'puppet',
      mode   => '0700',
    }

    # Create symlink
    file { "/var/lib/${server_dir}/reports":
      ensure  => 'link',
      target  => "/var/log/${server_dir}/reports",
      force   => true,
      require => File['puppet_reports'],
    }

    if (defined(Package['systemd'])) {
      # Create drop in for puppet x service
      basic_settings::systemd_drop_in { "${server_service}_settings":
        target_unit => "${server_service}.service",
        unit        => {
          'OnFailure' => 'notify-failed@%i.service',
        },
        service     => {
          'Nice'          => '-8',
        },
      }

      # Create systemd puppet x clean reports service
      basic_settings::systemd_service { "${server_service}-clean-reports":
        description => "Clean ${server_service} reports service",
        service     => {
          'Type'      => 'oneshot',
          'User'      => 'puppet',
          'ExecStart' => "/usr/bin/find /var/lib/${server_dir}/reports/ -type f -name '*.yaml' -ctime +1 -delete", #lint:ignore:140chars # Last dir separator (/) very important
          'Nice'      => '19',
        },
      }

      # Create systemd puppet x clean reports timer
      basic_settings::systemd_timer { "${server_service}-clean-reports":
        description => "Clean ${server_service} reports timer",
        timer       => {
          'OnCalendar' => '*-*-* 10:00',
        },
      }

      # Create drop in for puppet service
      basic_settings::systemd_drop_in { "puppet_${server_service}_dependency":
        target_unit => 'puppet.service',
        unit        => {
          'After'   => "${server_service}.service",
          'BindsTo' => "${server_service}.service",
        },
      }
    }

    # Setup audit rules
    if (defined(Package['auditd'])) {
      basic_settings::security_audit { 'puppet':
        rules => [
          '-a always,exit -F arch=b32 -F path=/etc/puppet/ssl -F perm=wa -F key=puppet_ssl',
          '-a always,exit -F arch=b64 -F path=/etc/puppet/ssl -F perm=wa -F key=puppet_ssl',
          '-a always,exit -F arch=b32 -F path=/etc/puppet/code -F perm=r -F auid!=unset -F key=puppet_code',
          '-a always,exit -F arch=b64 -F path=/etc/puppet/code -F perm=r -F auid!=unset -F key=puppet_code',
          '-a always,exit -F arch=b32 -F path=/etc/puppet/code -F perm=wa -F key=puppet_code',
          '-a always,exit -F arch=b64 -F path=/etc/puppet/code -F perm=wa -F key=puppet_code',
        ],
      }
    }
  } elsif (defined(Package['auditd'])) {
    basic_settings::security_audit { 'puppet':
      rules => [
        '-a always,exit -F arch=b32 -F path=/etc/puppet/ssl -F perm=wa -F key=puppet_ssl',
        '-a always,exit -F arch=b64 -F path=/etc/puppet/ssl -F perm=wa -F key=puppet_ssl',
      ],
    }
  }
}
