class basic_settings::puppet (
  Enum['distro', 'remote']              $repo           = 'distro',
  Boolean                               $server_enable  = false,
  Enum[
    'openvox-server',
    'puppet-master',
    'puppetserver'
  ]                                     $server_package = 'puppetserver',
  String                                $server_dirname = 'puppetserver',
) {
  # Set some values
  $basic_settings_enable = defined(Class['basic_settings'])
  $monitoring_enable = defined(Class['basic_settings::monitoring'])
  $systemd_enable = defined(Package['systemd'])
  if ($monitoring_enable) {
    $monitoring_package = $basic_settings::monitoring::package
  } else {
    $monitoring_package = 'none'
  }

  # Get puppet service name
  case $server_package {
    'openvox-server': {
      $server_service = 'puppetserver'
    }
    default: {
      $server_service = $server_package
    }
  }

  # Do some things based on server repo
  case $repo {
    'remote': {
      # Set some values
      $package_etc_dir = '/etc/puppetlabs'
      $agent_bin_dir = '/opt/puppetlabs/bin'
      $agent_etc_dir = "${package_etc_dir}/puppet"
      $server_dir = '/opt/puppetlabs/server'
      $server_etc_dir = "${package_etc_dir}/${server_dirname}"
      $server_report_dir = "/var/log/puppetlabs/${server_dirname}/reports"
      $server_var_dir = "${server_dir}/data/${server_dirname}"
      $server_var_extra = "/var/lib/puppetlabs/${server_dirname}"
      $cache_dir = '/opt/puppetlabs/puppet/cache'

      # Set list
      $require_dirs = [
        $server_report_dir,
        '/var/lib/puppetlabs',
        $server_var_extra,
        "${server_var_extra}/temp",
      ]

      # Install some puppet packages
      package { ['augeas-tools', 'facter']:
        ensure  => purged,
      }
    }
    default: {
      # Set some values
      $package_etc_dir = '/etc'
      $agent_bin_dir = '/usr/bin'
      $agent_etc_dir = "${package_etc_dir}/puppet"
      $server_dir = "/var/lib/${server_dirname}"
      $server_etc_dir = "${package_etc_dir}/${server_dirname}"
      $server_report_dir = "/var/log/${server_dirname}/reports"
      $server_var_dir = $server_dir
      $server_var_extra = $server_var_dir

      # Get clean filebucket dir
      if ($server_enable) {
        $cache_dir = "/var/cache/${server_dirname}"
      } else {
        $cache_dir = '/var/cache/puppet'
      }

      # Set list
      $require_dirs = [
        $server_report_dir,
        $server_var_extra,
        "${server_var_extra}/temp",
      ]

      # Install some puppet packages
      package { ['augeas-tools', 'facter']:
        ensure          => installed,
        install_options => ['--no-install-recommends', '--no-install-suggests'],
      }
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

  # Disable service
  service { 'puppet':
    ensure => undef,
    enable => false,
  }

  # Create drop in for services target
  if ($basic_settings_enable) {
    basic_settings::systemd_drop_in { 'puppet_dependency':
      target_unit => "${basic_settings::cluster_id}-system.target",
      unit        => {
        'Wants'   => 'puppet.service',
      },
      require     => Basic_settings::Systemd_target["${basic_settings::cluster_id}-system"],
    }
  }

  # Check if monitoring is enabled
  if ($monitoring_enable) {
    # Set unit
    $unit = {
      'OnFailure' => 'notify-failed@%i.service',
    }

    # Create service check
    if ($monitoring_package != 'none') {
      basic_settings::monitoring_custom { 'puppet_agent':
        content  => template('basic_settings/monitoring/puppet/check_agent'),
        friendly => 'Puppet Agent',
        timeout  => 60,
        interval => 600,
      }
    }
  } else {
    $unit = {}
  }

  if ($systemd_enable) {
    # Create drop in for puppet service
    basic_settings::systemd_drop_in { 'puppet_settings':
      target_unit => 'puppet.service',
      unit        => $unit,
      service     => {
        'Nice'        => 19,
        'LimitNOFILE' => 10000,
      },
    }

    # Create systemd puppet clean bucket service
    basic_settings::systemd_service { 'puppet-clean-filebucket':
      description => 'Clean puppet filebucket service',
      service     => {
        'Type'      => 'oneshot',
        'User'      => 'root',
        'ExecStart' => "/usr/bin/find ${cache_dir}/clientbucket/ -type f -mtime +14 -atime +14 -delete", #lint:ignore:140chars # Last dir separator (/) very important
        'Nice'      => '19',
      },
    }

    if ($basic_settings_enable) {
      # Create systemd puppet server clean reports timer
      basic_settings::systemd_timer { 'puppet-clean-filebucket':
        description        => 'Clean puppet filebucket timer',
        monitoring_enable  => $monitoring_enable,
        monitoring_package => $monitoring_package,
        timer              => {
          'OnCalendar' => '*-*-* 10:00',
        },
      }

      # Create drop in for services target
      basic_settings::systemd_drop_in { 'puppet_clean_filebucket_dependency':
        target_unit => "${basic_settings::cluster_id}-helpers.target",
        unit        => {
          'BindsTo'   => 'puppet-clean-filebucket.timer',
        },
        require     => Basic_settings::Systemd_target["${basic_settings::cluster_id}-helpers"],
      }
    } else {
      # Create systemd puppet server clean reports timer
      basic_settings::systemd_timer { 'puppet-clean-filebucket':
        description        => 'Clean puppet filebucket timer',
        monitoring_enable  => $monitoring_enable,
        monitoring_package => $monitoring_package,
        state              => 'running',
        timer              => {
          'OnCalendar' => '*-*-* 10:00',
        },
      }
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

    # Create service check
    if ($monitoring_enable and $basic_settings::monitoring::package != 'none') {
      basic_settings::monitoring_service { 'puppetserver':
        services => [$server_service],
      }
    }

    # Create puppet dirs
    file { $require_dirs:
      ensure  => directory,
      mode    => '0700',
      owner   => 'puppet',
      group   => 'puppet',
      require => Package[$server_package],
    }

    # Create symlink
    file { 'puppet_reports_symlink':
      ensure  => 'link',
      path    => "${server_var_dir}/reports",
      target  => $server_report_dir,
      force   => true,
      require => File[$server_report_dir],
    }

    # Check if we have systemd
    if (defined(Package['systemd'])) {
      # Create env file
      file { '/etc/default/puppetserver':
        ensure  => file,
        mode    => '0600',
        owner   => 'puppet',
        group   => 'puppet',
        content => template('basic_settings/puppet/environment'),
        notify  => Service[$server_service],
      }

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
          'ExecStart' => "/usr/bin/find ${server_var_dir}/reports/ -type f -name '*.yaml' -ctime +1 -delete", #lint:ignore:140chars # Last dir separator (/) very important
          'Nice'      => '19',
        },
      }

      if ($basic_settings_enable) {
        # Create systemd puppet x clean reports timer
        basic_settings::systemd_timer { "${server_service}-clean-reports":
          description        => "Clean ${server_service} reports timer",
          monitoring_enable  => $monitoring_enable,
          monitoring_package => $monitoring_package,
          timer              => {
            'OnCalendar' => '*-*-* 10:00',
          },
        }

        # Create drop in for services target
        basic_settings::systemd_drop_in { "${server_service}_clean_reports_dependency":
          target_unit => "${basic_settings::cluster_id}-helpers.target",
          unit        => {
            'BindsTo'   => "${server_service}-clean-reports.timer",
          },
          require     => Basic_settings::Systemd_target["${basic_settings::cluster_id}-helpers"],
        }
      } else {
        # Create systemd puppet x clean reports timer
        basic_settings::systemd_timer { "${server_service}-clean-reports":
          description        => "Clean ${server_service} reports timer",
          monitoring_enable  => $monitoring_enable,
          monitoring_package => $monitoring_package,
          state              => 'running',
          timer              => {
            'OnCalendar' => '*-*-* 10:00',
          },
        }
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
          "-a always,exit -F arch=b32 -F path=${server_etc_dir}/ssl -F perm=wa -F key=puppet_ssl",
          "-a always,exit -F arch=b64 -F path=${server_etc_dir}/ssl -F perm=wa -F key=puppet_ssl",
          "-a always,exit -F arch=b32 -F path=${package_etc_dir}/code -F perm=r -F auid!=unset -F key=puppet_code",
          "-a always,exit -F arch=b64 -F path=${package_etc_dir}/code -F perm=r -F auid!=unset -F key=puppet_code",
          "-a always,exit -F arch=b32 -F path=${package_etc_dir}/code -F perm=wa -F key=puppet_code",
          "-a always,exit -F arch=b64 -F path=${package_etc_dir}/code -F perm=wa -F key=puppet_code",
        ],
      }
    }
  } elsif (defined(Package['auditd'])) {
    basic_settings::security_audit { 'puppet':
      rules => [
        "-a always,exit -F arch=b32 -F path=${agent_etc_dir}/ssl -F perm=wa -F key=puppet_ssl",
        "-a always,exit -F arch=b64 -F path=${agent_etc_dir}/ssl -F perm=wa -F key=puppet_ssl",
      ],
    }
  }
}
