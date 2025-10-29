class basic_settings::security (
  Optional[String]  $antivirus_package        = undef,
  String            $mail_to                  = 'root',
  String            $server_fdqn              = $facts['networking']['fqdn']
) {
  # Set some values
  $systemd_enable = defined(Package['systemd'])
  $monitoring_enable = defined(Class['basic_settings::monitoring'])

  # Check if auditd package is not defined
  if (!defined(Package['auditd'])) {
    package { 'auditd':
      ensure          => installed,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
    }
  }

  # Install default security packages
  package { ['apparmor', 'pwgen']:
    ensure          => installed,
    install_options => ['--no-install-recommends', '--no-install-suggests'],
  }

  # Enable apparmor service
  service { 'apparmor':
    ensure  => true,
    enable  => true,
    require => Package['apparmor'],
  }

  # Enable auditd service
  if (!defined(Service['auditd'])) {
    service { 'auditd':
      ensure  => true,
      enable  => true,
      require => Package['auditd'],
    }
  }

  # Setup monitoring
  if ($monitoring_enable and $basic_settings::monitoring::package != 'none') {
    basic_settings::monitoring_custom { 'audit':
      content  => template('basic_settings/monitoring/check_audit'),
      timeout  => 300,
      interval => 600,
    }
  }

  # Setup virusscanner
  case $antivirus_package { #lint:ignore:case_without_default
    'eset': {
      # Setup audit rules
      basic_settings::security_audit { 'eset':
        rules => [
          '-a never,exit -F exe=/opt/eset/efs/lib/odfeeder',
          '-a never,exit -F exe=/opt/eset/efs/lib/schedd',
          '-a never,exit -F exe=/opt/eset/efs/lib/utild',
        ],
        order => 2,
      }

      # Setup monitoring
      if ($monitoring_enable and $basic_settings::monitoring::package != 'none') {
        basic_settings::monitoring_custom { 'antivirus':
          friendly => 'ESET Server Security',
          content  => template('basic_settings/monitoring/check_eset'),
          timeout  => 60,
        }
      }
    }
  }

  # Create service check
  if ($monitoring_enable and $basic_settings::monitoring::package != 'none') {
    basic_settings::monitoring_service { 'apparmor': }
  }

  # Create auditd config file */
  file { '/etc/audit/auditd.conf':
    ensure  => file,
    content => template('basic_settings/security/auditd.conf'),
    owner   => 'root',
    group   => 'root',
    mode    => '0600',
    notify  => Service['auditd'],
  }

  # Create rules dir
  if (!defined(File['/etc/audit/rules.d'])) {
    file { '/etc/audit/rules.d':
      ensure  => directory,
      recurse => true,
      force   => true,
      purge   => true,
      mode    => '0700',
    }
  }

  # Create default audit rule file */
  file { '/etc/audit/rules.d/audit.rules':
    ensure  => file,
    content => template('basic_settings/security/audit.rules'),
    owner   => 'root',
    group   => 'root',
    mode    => '0600',
    notify  => Service['auditd'],
    require => File['/etc/audit/rules.d'],
  }

  # Create systemd exclude rules
  if (defined(Package['systemd-cron'])) {
    basic_settings::security_audit { 'systemd_exclude':
      rules   => [
        '-a never,exit -F arch=b32 -F exe=/usr/bin/systemd-tmpfiles -F auid=unset',
        '-a never,exit -F arch=b64 -F exe=/usr/bin/systemd-tmpfiles -F auid=unset',
      ],
      order   => 2,
      require => File['/etc/audit/rules.d'],
    }
  }

  # Create main audit rule file */
  file { '/etc/audit/rules.d/10-main.rules':
    ensure  => file,
    content => template('basic_settings/security/main.rules'),
    owner   => 'root',
    group   => 'root',
    mode    => '0600',
    notify  => Service['auditd'],
    require => File['/etc/audit/rules.d'],
  }

  # Create default audit file */
  file { '/usr/local/sbin/auditmail':
    ensure  => file,
    content => template('basic_settings/security/auditmail'),
    owner   => 'root',
    group   => 'root',
    mode    => '0700', # Only root
    notify  => Service['auditd'],
  }

  # Check if systemd and message class exists
  if ($systemd_enable) {
    # Create systemctl daemon reload
    exec { 'security_systemd_daemon_reload':
      command     => '/usr/bin/systemctl daemon-reload',
      refreshonly => true,
      require     => Package['systemd'],
    }

    # Create unit
    if (defined(Class['basic_settings::monitoring'])) {
      $unit = {
        'OnFailure' => 'notify-failed@%i.service',
      }

      # Create drop in for apparmor service
      basic_settings::systemd_drop_in { 'apparmor_notify_failed':
        target_unit   => 'apparmor.service',
        unit          => $unit,
        daemon_reload => 'security_systemd_daemon_reload',
        require       => Package['apparmor'],
      }
    } else {
      $unit = {}
    }

    # Create drop in for auditd service
    basic_settings::systemd_drop_in { 'auditd_settings':
      target_unit   => 'auditd.service',
      unit          => $unit,
      service       => {
        'PrivateTmp'  => 'true',
        'ProtectHome' => 'false' # Important for monitoring home dirs
      },
      daemon_reload => 'security_systemd_daemon_reload',
      require       => Package['auditd'],
    }

    # Create systemd service
    basic_settings::systemd_service { 'auditmail':
      description   => 'Audit mail service',
      unit          => $unit,
      service       => {
        'Type'          => 'oneshot',
        'User'          => 'root',
        'ExecStart'     => '/usr/local/sbin/auditmail',
        'Nice'          => '-20', # Important process
        'PrivateTmp'    => 'true',
        'ProtectHome'   => 'true',
        'ProtectSystem' => 'full',
      },
      daemon_reload => 'security_systemd_daemon_reload',
      enable        => false,
    }

    # Create systemd timer
    basic_settings::systemd_timer { 'auditmail':
      description   => 'Audit mail timer',
      state         => 'running',
      timer         => {
        'OnCalendar' => '*-*-* 0:30',
      },
      daemon_reload => 'security_systemd_daemon_reload',
    }
  }
}
