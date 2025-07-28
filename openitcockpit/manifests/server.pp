class openitcockpit::server (
  Sensitive[String] $grafana_password,
  Optional[String]  $install_dir              = undef,
  Optional[String]  $server_fdqn              = undef,
  Optional[String]  $ssl_certificate          = undef,
  Optional[String]  $ssl_certificate_key      = undef,
  Optional[String]  $webserver_uid            = undef,
  Optional[String]  $webserver_gid            = undef,
) {
  # Set some values
  $log_dir = '/var/log/openitc'
  $lib_dir = '/var/lib/openitcockpit'
  $monitoring_enable = defined(Class['basic_settings::monitoring'])
  $nginx_enable = defined(Class['nginx'])
  $php_fpm_enable = defined(Class['php8::fpm'])

  # Try to get uid and gid
  if ($webserver_uid == undef or $webserver_gid == undef) {
    if ($nginx_enable) {
      $webserver_uid_correct = $nginx::run_user
      $webserver_gid_correct = $nginx::run_group
    } else {
      $webserver_uid_correct = 'www-data'
      $webserver_gid_correct = 'www-data'
    }
  } else {
    $webserver_uid_correct = $webserver_uid
    $webserver_gid_correct = $webserver_gid
  }

  # Try to get server fdqn
  if ($server_fdqn == undef) {
    if (defined(Class['basic_settings'])) {
      $server_fdqn_correct = $basic_settings::server_fdqn
    } else {
      $server_fdqn_correct = $facts['networking']['fqdn']
    }
  } else {
    $server_fdqn_correct = $server_fdqn
  }

  # Check if sudo package is not defined
  if (!defined(Package['sudo'])) {
    package { 'sudo':
      ensure          => installed,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
    }
  }

  # Create sudoers file
  file { '/etc/sudoers.d/openitc_cake':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0440',
    content => "# Managed by puppet\nCmnd_Alias OPENITC_CAKE_CMD = /opt/openitc/frontend/bin/cake *\nDefaults!OPENITC_CAKE_CMD !mail_always\nDefaults!OPENITC_CAKE_CMD root_sudo\nroot ALL = (ALL) SETENV: OPENITC_CAKE_CMD\n",
    require => Package['sudo'],
  }

  # Create sudoers file
  file { '/etc/sudoers.d/openitc_nagios':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0440',
    content => "# Managed by puppet\nCmnd_Alias OPENITC_NAGIOS_CMD = /opt/openitc/nagios/bin/nagios -v /opt/openitc/nagios/etc/nagios.cfg\nDefaults!OPENITC_NAGIOS_CMD !mail_always\nDefaults!OPENITC_NAGIOS_CMD root_sudo\nnagios ALL = (root) OPENITC_NAGIOS_CMD\n",
    require => Package['sudo'],
  }

  # Check if installation dir is given
  if ($install_dir != undef) {
    # Create directory
    $install_dir_correct = $install_dir
    file { 'openitcockpit_install_dir':
      ensure => directory,
      path   => $install_dir,
      owner  => 'root',
      group  => 'root',
      mode   => '0755', # Important for internal scripts
    }

    # Create symlink
    file { '/opt/openitc':
      ensure  => 'link',
      target  => $install_dir,
      force   => true,
      require => File['openitcockpit_install_dir'],
    }
  } else {
    # Create directory
    $install_dir_correct = '/opt/openitc'
    file { $install_dir_correct:
      ensure => directory,
      owner  => 'root',
      group  => 'root',
      mode   => '0755', # Important for internal scripts
    }
  }

  # Set requirements
  if ($php_fpm_enable) {
    $requirements = [File['/opt/openitc'], Class['php8::fpm']]
  } else {
    $requirements = File['/opt/openitc']
  }

  # Create dirs
  file { [
      "${install_dir_correct}/etc",
      "${install_dir_correct}/etc/carbon",
      "${install_dir_correct}/etc/grafana",
      "${install_dir_correct}/etc/mod_gearman",
      "${install_dir_correct}/etc/mysql",
      "${install_dir_correct}/etc/nagios",
      "${install_dir_correct}/etc/nsta",
      "${install_dir_correct}/etc/statusengine",
      "${install_dir_correct}/nagios",
      "${install_dir_correct}/receiver",
      $lib_dir,
      "${lib_dir}/nagios",
      "${lib_dir}/nagios/backup",
      "${lib_dir}/nagios/etc",
      "${lib_dir}/receiver",
      "${lib_dir}/receiver/etc",
      "${lib_dir}/var",
      $log_dir,
    ]:
      ensure  => directory,
      owner   => 'root',
      group   => 'root',
      mode    => '0755', # Important for internal scripts
      require => $requirements,
  }

  # Create admin password file
  file { "${install_dir_correct}/etc/grafana/admin_password":
    ensure  => file,
    content => Sensitive.new('admin'),
    replace => false,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    require => File["${install_dir_correct}/etc/grafana"],
  }

  # Create symlink
  file { "${install_dir_correct}/nagios/backup":
    ensure  => 'link',
    target  => "${lib_dir}/nagios/backup",
    force   => true,
    require => File[
      "${install_dir_correct}/nagios",
      "${lib_dir}/nagios/backup"
    ],
  }

  # Create symlink
  file { "${install_dir_correct}/nagios/etc":
    ensure  => 'link',
    target  => "${lib_dir}/nagios/etc",
    force   => true,
    require => File[
      "${install_dir_correct}/nagios",
      "${lib_dir}/nagios/etc"
    ],
  }

  # Create symlink
  file { "${install_dir_correct}/receiver/etc":
    ensure  => 'link',
    target  => "${lib_dir}/receiver/etc",
    force   => true,
    require => File[
      "${install_dir_correct}/receiver",
      "${lib_dir}/receiver/etc"
    ],
  }

  # Create symlink
  file { "${install_dir_correct}/var":
    ensure  => 'link',
    target  => "${lib_dir}/var",
    force   => true,
    require => File[
      $install_dir_correct,
      "${lib_dir}/var"
    ],
  }

  # Create symlink
  file { "${install_dir_correct}/logs":
    ensure  => 'link',
    target  => $log_dir,
    force   => true,
    require => File[
      $install_dir_correct,
      $log_dir
    ],
  }

  # Install package
  package { [
      'openitcockpit',
      'openitcockpit-frontend-angular',
      'openitcockpit-mod-gearman-worker-go-local',
      'openitcockpit-module-design',
      'openitcockpit-module-grafana',
      'openitcockpit-monitoring-plugins',
    ]:
      ensure          => installed,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
      require         => File[
        "${install_dir_correct}/etc/grafana/admin_password",
        "${install_dir_correct}/nagios/backup",
        "${install_dir_correct}/nagios/etc",
        "${install_dir_correct}/receiver/etc",
        "${install_dir_correct}/var",
        "${install_dir_correct}/logs"
      ],
  }

  # Create dirs
  file { [
      "${lib_dir}/nagios/etc/config",
      "${lib_dir}/nagios/etc/config/servicedependencies",
      "${lib_dir}/nagios/etc/config/hostdependencies",
      "${lib_dir}/nagios/etc/config/serviceescalations",
      "${lib_dir}/nagios/etc/config/servicegroups",
      "${lib_dir}/nagios/etc/config/services",
      "${lib_dir}/nagios/etc/config/servicetemplates",
      "${lib_dir}/nagios/etc/config/hostescalations",
      "${lib_dir}/nagios/etc/config/hostgroups",
      "${lib_dir}/nagios/etc/config/timeperiods",
      "${lib_dir}/nagios/etc/config/contactgroups",
      "${lib_dir}/nagios/etc/config/contacts",
      "${lib_dir}/nagios/etc/config/commands",
      "${lib_dir}/nagios/etc/config/hosts",
      "${lib_dir}/nagios/etc/config/hosttemplates",
      "${lib_dir}/nagios/etc/config/defaults",
      "${lib_dir}/nagios/var",
      "${lib_dir}/nagios/var/archives",
      "${lib_dir}/nagios/var/cache",
      "${lib_dir}/nagios/var/log",
      "${lib_dir}/nagios/var/rw",
      "${lib_dir}/nagios/var/spool",
      "${lib_dir}/nagios/var/spool/checkresults",
      "${lib_dir}/nagios/var/spool/perfdata",
      "${lib_dir}/nagios/var/stats",
    ]:
      ensure  => directory,
      owner   => 'nagios',
      group   => $webserver_gid,
      mode    => '0755', # Important for internal scripts
      require => Package['openitcockpit'],
  }

  # Create symlink
  file { "${install_dir_correct}/nagios/var":
    ensure  => 'link',
    target  => "${lib_dir}/nagios/var",
    force   => true,
    require => File[
      "${install_dir_correct}/nagios",
      "${lib_dir}/nagios/var"
    ],
  }

  # Create resource config
  file { [
      "${install_dir_correct}/etc/nagios/nagios.cfg",
      "${lib_dir}/nagios/etc/resource.cfg",
    ]:
      ensure  => file,
      replace => false,
      owner   => 'nagios',
      group   => $webserver_gid_correct,
      mode    => '0644',
      require => File[
        "${install_dir_correct}/etc/nagios",
        "${lib_dir}/nagios/etc",
      ],
  }

  # Set proper permissions
  file { [
      "${install_dir_correct}/etc/grafana/grafana.ini",
      "${install_dir_correct}/etc/mod_gearman/mod_gearman_neb.conf",
      "${install_dir_correct}/etc/statusengine/statusengine.toml",
    ]:
      ensure  => file,
      replace => false,
      owner   => 'root',
      group   => $webserver_gid_correct,
      mode    => '0644',
      require => Package['openitcockpit'],
  }

  # Create dirs
  file { [
      "${install_dir_correct}/frontend",
      "${install_dir_correct}/frontend/config",
      "${lib_dir}/frontend",
      "${lib_dir}/frontend/tmp",
      "${lib_dir}/frontend/webroot",
    ]:
      ensure  => directory,
      owner   => $webserver_uid_correct,
      group   => $webserver_gid_correct,
      mode    => '0755', # Important for internal scripts
      require => Package['openitcockpit'],
  }

  # Create symlink
  file { "${install_dir_correct}/frontend/tmp":
    ensure  => 'link',
    target  => "${lib_dir}/frontend/tmp",
    force   => true,
    require => File["${lib_dir}/frontend/tmp"],
  }

  # Create symlink
  file { "${install_dir_correct}/frontend/webroot":
    ensure  => 'link',
    target  => "${lib_dir}/frontend/webroot",
    force   => true,
    require => File["${lib_dir}/frontend/webroot"],
  }

  # Create email config file
  file { "${install_dir_correct}/frontend/config/email.php":
    ensure  => file,
    content => template('openitcockpit/frontend/email.php'),
    owner   => $webserver_uid_correct,
    group   => $webserver_gid_correct,
    mode    => '0664',
    require => File["${install_dir_correct}/frontend/config"],
  }

  # Get SSL content
  if ($ssl_certificate != undef and $ssl_certificate_key != undef) {
    $ssl_content = template('openitcockpit/nginx/ssl_cert.conf')
  } else {
    $ssl_content = ''
  }

  # Create openitc directory
  file { '/etc/nginx/openitc':
    ensure  => directory,
    owner   => 'root',
    group   => 'root',
    mode    => '0700',
    require => Package['openitcockpit'],
  }

  # Set nginx config
  file { '/etc/nginx/sites-enabled/openitc':
    ensure  => file,
    replace => false,
    owner   => 'root',
    group   => 'root',
    mode    => '0600',
    require => File['/etc/nginx/openitc'],
  }

  # Create SSL config file
  file { '/etc/nginx/openitc/ssl_cert.conf':
    ensure  => file,
    content => $ssl_content,
    owner   => 'root',
    group   => 'root',
    mode    => '0600',
    require => File['/etc/nginx/openitc'],
  }

  # Check if php FPM is enabled
  if ($php_fpm_enable) {
    php8::fpm_pool { 'oitc':
      listen => '/run/php/php-fpm-oitc.sock',
    }
  }

  # Disable service
  if (defined(Package['systemd'])) {
    # Disable service
    service { [
        'gearman-job-server',
        'gearman_worker',
        'openitcockpit-node',
        'openitcockpit-graphing',
        'oitc_cmd',
        'oitc_cronjobs.timer',
        'push_notification',
        'statusengine',
        'sudo_server',
      ]:
        ensure  => undef,
        enable  => false,
        require => Package['openitcockpit'],
    }

    # Reload systemd deamon
    exec { 'openitcockpit_systemd_daemon_reload':
      command     => '/usr/bin/systemctl daemon-reload',
      refreshonly => true,
      require     => Package['systemd'],
    }

    # Create drop in for x target
    if (defined(Class['basic_settings::systemd'])) {
      basic_settings::systemd_drop_in { 'openitcockpit_gearman_job_server_dependency':
        target_unit   => "${basic_settings::systemd::cluster_id}-services.target",
        unit          => {
          'BindsTo'   => 'gearman-job-server.service',
        },
        daemon_reload => 'openitcockpit_systemd_daemon_reload',
        require       => Basic_settings::Systemd_target["${basic_settings::systemd::cluster_id}-services"],
      }

      basic_settings::systemd_drop_in { 'openitcockpit_gearman_worker_dependency':
        target_unit   => "${basic_settings::systemd::cluster_id}-services.target",
        unit          => {
          'BindsTo'   => 'gearman_worker.service',
        },
        daemon_reload => 'openitcockpit_systemd_daemon_reload',
        require       => Basic_settings::Systemd_target["${basic_settings::systemd::cluster_id}-services"],
      }

      basic_settings::systemd_drop_in { 'openitcockpit_node_dependency':
        target_unit   => "${basic_settings::systemd::cluster_id}-production.target",
        unit          => {
          'BindsTo'   => 'openitcockpit-node.service',
        },
        daemon_reload => 'openitcockpit_systemd_daemon_reload',
        require       => Basic_settings::Systemd_target["${basic_settings::systemd::cluster_id}-production"],
      }

      basic_settings::systemd_drop_in { 'openitcockpit_graphing_dependency':
        target_unit   => "${basic_settings::systemd::cluster_id}-production.target",
        unit          => {
          'BindsTo'   => 'openitcockpit-graphing.service',
        },
        daemon_reload => 'openitcockpit_systemd_daemon_reload',
        require       => Basic_settings::Systemd_target["${basic_settings::systemd::cluster_id}-production"],
      }

      basic_settings::systemd_drop_in { 'openitcockpit_oitc_cmd_dependency':
        target_unit   => "${basic_settings::systemd::cluster_id}-services.target",
        unit          => {
          'BindsTo'   => 'oitc_cmd.service',
        },
        daemon_reload => 'openitcockpit_systemd_daemon_reload',
        require       => Basic_settings::Systemd_target["${basic_settings::systemd::cluster_id}-services"],
      }

      basic_settings::systemd_drop_in { 'openitcockpit_oitc_cronjobs_dependency':
        target_unit   => "${basic_settings::cluster_id}-helpers.target",
        unit          => {
          'BindsTo'   => 'oitc_cronjobs.timer',
        },
        daemon_reload => 'openitcockpit_systemd_daemon_reload',
        require       => Basic_settings::Systemd_target["${basic_settings::cluster_id}-helpers"],
      }

      basic_settings::systemd_drop_in { 'openitcockpit_push_notification_dependency':
        target_unit   => "${basic_settings::systemd::cluster_id}-services.target",
        unit          => {
          'BindsTo'   => 'push_notification.service',
        },
        daemon_reload => 'openitcockpit_systemd_daemon_reload',
        require       => Basic_settings::Systemd_target["${basic_settings::systemd::cluster_id}-services"],
      }

      basic_settings::systemd_drop_in { 'openitcockpit_statusengine_dependency':
        target_unit   => "${basic_settings::systemd::cluster_id}-services.target",
        unit          => {
          'BindsTo'   => 'statusengine.service',
        },
        daemon_reload => 'openitcockpit_systemd_daemon_reload',
        require       => Basic_settings::Systemd_target["${basic_settings::systemd::cluster_id}-services"],
      }

      basic_settings::systemd_drop_in { 'openitcockpit_sudo_server_dependency':
        target_unit   => "${basic_settings::systemd::cluster_id}-services.target",
        unit          => {
          'BindsTo'   => 'sudo_server.service',
        },
        daemon_reload => 'openitcockpit_systemd_daemon_reload',
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

    # Set service
    $service = {
      'PrivateDevices' => 'true',
      'PrivateTmp'     => 'true',
      'ProtectHome'    => 'true',
      'ProtectSystem'  => 'full',
    }

    basic_settings::systemd_drop_in { 'openitcockpit_gearman_job_server_settings':
      target_unit   => 'gearman-job-server.service',
      unit          => $unit,
      service       => $service,
      daemon_reload => 'openitcockpit_systemd_daemon_reload',
      require       => Package['openitcockpit'],
    }

    basic_settings::systemd_drop_in { 'openitcockpit_gearman_worker_settings':
      target_unit   => 'gearman_worker.service',
      unit          => $unit,
      service       => $service,
      daemon_reload => 'openitcockpit_systemd_daemon_reload',
      require       => Package['openitcockpit'],
    }

    basic_settings::systemd_drop_in { 'openitcockpit_node_settings':
      target_unit   => 'openitcockpit-node.service',
      unit          => $unit,
      service       => $service,
      daemon_reload => 'openitcockpit_systemd_daemon_reload',
      require       => Package['openitcockpit'],
    }

    basic_settings::systemd_drop_in { 'openitcockpit_graphing_settings':
      target_unit   => 'openitcockpit-graphing.service',
      unit          => $unit,
      service       => $service,
      daemon_reload => 'openitcockpit_systemd_daemon_reload',
      require       => Package['openitcockpit'],
    }

    basic_settings::systemd_drop_in { 'openitcockpit_oitc_cmd_settings':
      target_unit   => 'oitc_cmd.service',
      unit          => $unit,
      service       => $service,
      daemon_reload => 'openitcockpit_systemd_daemon_reload',
      require       => Package['openitcockpit'],
    }

    basic_settings::systemd_drop_in { 'openitcockpit_oitc_cronjobs_settings':
      target_unit   => 'oitc_cronjobs.service', # oitc_cronjobs.timer
      unit          => $unit,
      service       => $service,
      daemon_reload => 'openitcockpit_systemd_daemon_reload',
      require       => Package['openitcockpit'],
    }

    basic_settings::systemd_drop_in { 'openitcockpit_push_notification_settings':
      target_unit   => 'push_notification.service',
      unit          => $unit,
      service       => $service,
      daemon_reload => 'openitcockpit_systemd_daemon_reload',
      require       => Package['openitcockpit'],
    }

    basic_settings::systemd_drop_in { 'openitcockpit_statusengine_settings':
      target_unit   => 'statusengine.service',
      unit          => $unit,
      service       => $service,
      daemon_reload => 'openitcockpit_systemd_daemon_reload',
      require       => Package['openitcockpit'],
    }

    basic_settings::systemd_drop_in { 'openitcockpit_sudo_server_settings':
      target_unit   => 'sudo_server.service',
      unit          => $unit,
      service       => $service,
      daemon_reload => 'openitcockpit_systemd_daemon_reload',
      require       => Package['openitcockpit'],
    }
  } else {
    # Enable service
    service { [
        'gearman-job-server',
        'gearman_worker',
        'openitcockpit-node',
        'openitcockpit-graphing',
        'oitc_cmd',
        'oitc_cronjobs.timer',
        'push_notification',
        'statusengine',
        'sudo_server',
      ]:
        ensure  => true,
        enable  => true,
        require => Package['openitcockpit'],
    }
  }

  # Update grafana admin password
  exec { 'openitcockpit_grafana_admin_pw':
    command => Sensitive.new("/bin/sh -c '/usr/bin/printf %s ${grafana_password.unwrap} > ${install_dir_correct}/etc/grafana/admin_password && cd ${install_dir_correct}/docker/container/graphing && /usr/bin/docker exec -i graphing-grafana-1 grafana-cli --homepath=/usr/share/grafana --config=/etc/openitcockpit/grafana/grafana.ini admin reset-admin-password ${grafana_password.unwrap}'"),
    onlyif  => Sensitive.new( "/bin/sh -c '/usr/bin/test -f ${install_dir_correct}/etc/.installation_done && ( ! [ -f ${install_dir_correct}/etc/grafana/admin_password ] || ! /usr/bin/grep -qxF \"${grafana_password.unwrap}\" ${install_dir_correct}/etc/grafana/admin_password )'"),
    require => Package['coreutils', 'grep', 'openitcockpit'],
  }
}
