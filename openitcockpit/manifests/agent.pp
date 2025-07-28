class openitcockpit::agent (
  Boolean                     $cpustats_enable      = true,
  Boolean                     $diskstats_enable     = true,
  Boolean                     $dockerstats_enable   = true,
  Boolean                     $libvirt_enable       = true,
  Boolean                     $memory_enable        = true,
  Boolean                     $netstats_enable      = true,
  Boolean                     $ntp_enable           = true,
  Boolean                     $processstats_enable  = true,
  Optional[Boolean]           $sensorstats_enable   = undef,
  Boolean                     $services_enable      = true,
  Boolean                     $swap_enable          = true,
  Boolean                     $userstats_enable     = true,
  Boolean                     $push_enable          = false,
  Optional[String]            $push_url             = undef,
  Optional[Sensitive[String]] $push_apikey          = undef,
) {
  # Set variables
  $monitoring_enable = defined(Class['basic_settings::monitoring'])
  $systemd_enable = defined(Package['systemd'])

  # Check if we have systemd
  if ($monitoring_enable) {
    $monitoring_package = $basic_settings::monitoring::package
  } else {
    $monitoring_package = 'none'
  }

  # Check if we have sensorstats
  if ($sensorstats_enable == undef) {
    if ($facts['is_virtual']) {
      $sensorstats_correct = false
    } else {
      $sensorstats_correct = true
    }
  } else {
    $sensorstats_correct = $sensorstats_enable
  }

  # Get push state
  if ($push_enable and $push_url != undef and $push_apikey != undef) {
    $push_correct = true
    $push_url_correct = $push_url
    $push_apikey_correct = $push_apikey
  } else {
    $push_correct = false
    $push_url_correct = ''
    $push_apikey_correct = ''
  }

  # Convert string to boolean
  $cpustats_string = bool2str($cpustats_enable, 'True', 'False')
  $diskstats_string = bool2str($diskstats_enable, 'True', 'False')
  $dockerstats_string = bool2str($dockerstats_enable, 'True', 'False')
  $libvirt_string = bool2str($libvirt_enable, 'True', 'False')
  $memory_string = bool2str($memory_enable, 'True', 'False')
  $netstats_string = bool2str($netstats_enable, 'True', 'False')
  $ntp_string = bool2str($ntp_enable, 'True', 'False')
  $processstats_string = bool2str($processstats_enable, 'True', 'False')
  $sensorstats_stirng = bool2str($sensorstats_correct, 'True', 'False')
  $services_string = bool2str($services_enable, 'True', 'False')
  $swap_string = bool2str($swap_enable, 'True', 'False')
  $userstats_string = bool2str($userstats_enable, 'True', 'False')
  $push_string = bool2str($push_correct, 'True', 'False')

  # Install OpenITCockpit agent
  if (!defined(Package['openitcockpit-agent'])) {
    package { 'openitcockpit-agent':
      ensure          => installed,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
    }
  }

  # Check if monitoring package is not configured
  if ($monitoring_package == 'none') {
    if ($systemd_enable) {
      # Disable service
      service { 'openitcockpit-agent':
        ensure  => undef,
        enable  => false,
        require => Package['openitcockpit-agent'],
      }

      # Reload systemd deamon
      exec { 'openitcockpit_agent_systemd_daemon_reload':
        command     => '/usr/bin/systemctl daemon-reload',
        refreshonly => true,
        require     => Package['systemd'],
      }

      # Create drop in for x target
      if (defined(Class['basic_settings::systemd'])) {
        basic_settings::systemd_drop_in { 'openitcockpit_agent_dependency':
          target_unit   => "${basic_settings::systemd::cluster_id}-services.target",
          unit          => {
            'BindsTo'   => 'openitcockpit-agent.service',
          },
          daemon_reload => 'openitcockpit_agent_systemd_daemon_reload',
          require       => Basic_settings::Systemd_target["${basic_settings::systemd::cluster_id}-services"],
        }
      }

      # Get unit
      if ($monitoring_enable) {
        $unit = {
          'OnFailure' => 'notify-failed@%i.service',
        }
      } else {
        $unit = {}
      }

      # Create symlink
      file { '/usr/lib/systemd/system/openitcockpit-agent.service':
        ensure  => 'link',
        target  => '/etc/openitcockpit-agent/init/openitcockpit-agent.service',
        force   => true,
        notify  => Exec['openitcockpit_agent_systemd_daemon_reload'],
        require => Package['openitcockpit-agent'],
      }

      # Create drop in for ncpa service
      basic_settings::systemd_drop_in { 'openitcockpit_agent_settings':
        target_unit   => 'openitcockpit-agent.service',
        unit          => $unit,
        service       => {
          'PrivateDevices' => 'true',
          'PrivateTmp'     => 'true',
          'ProtectHome'    => 'true',
          'ProtectSystem'  => 'full',
          'ReadWritePaths' => '/etc/openitcockpit-agent',
        },
        daemon_reload => 'openitcockpit_agent_systemd_daemon_reload',
        require       => File['/usr/lib/systemd/system/openitcockpit-agent.service'],
      }
    } else {
      # Eanble service
      service { 'openitcockpit-agent':
        ensure  => true,
        enable  => true,
        require => Package['openitcockpit-agent'],
      }
    }

    # Create root directory
    file { 'monitoring_location':
      ensure => directory,
      path   => '/etc/openitcockpit-agent',
      mode   => '0755', # Important
      owner  => 'root',
      group  => 'root',
    }

    # Create plugin directory
    file { 'monitoring_location_plugins':
      ensure  => directory,
      path    => '/etc/openitcockpit-agent/plugins',
      mode    => '0700',
      owner   => 'root',
      group   => 'root',
      require => File['monitoring_location'],
    }

    # Create config config
    concat { '/etc/openitcockpit-agent/customchecks.ini':
      owner   => 'root',
      group   => 'root',
      mode    => '0600',
      require => File['monitoring_location'],
    }

    # Create fragment 
    concat::fragment { 'monitoring_customchecks_default':
      target  => '/etc/openitcockpit-agent/customchecks.ini',
      content => "# Managed by puppet\n[default]\n",
      order   => '01',
    }
  }

  # Create config file
  file { '/etc/openitcockpit-agent/config.ini':
    ensure  => file,
    content => template('openitcockpit/agent/config.ini'),
    owner   => 'root',
    group   => 'root',
    mode    => '0600',
    notifiy => Service['openitcockpit-agent'],
    require => File['monitoring_location'],
  }
}
