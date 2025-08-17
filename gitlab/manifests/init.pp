class gitlab (
  String              $root_password,
  Optional[String]    $install_dir    = undef,
  Integer             $nice_level     = 12,
  Optional[String]    $root_email     = undef,
  Optional[String]    $server_fdqn    = undef
) {
  # Set some values
  $suspicious_packages = ['/usr/bin/gitlab-ctl']
  $monitoring_enable = defined(Class['basic_settings::monitoring'])

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

  # Try to get root email
  if ($root_email == undef) {
    if ($monitoring_enable) {
      $root_email_found = $basic_settings::monitoring::mail_to
    } else {
      $root_email_found = 'root'
    }
  } else {
    $root_email_found = $root_email
  }

  # Set email
  if ($root_email_found == 'root') {
    $root_email_correct = "root@${server_fdqn_correct}"
  } else {
    $root_email_correct = $root_email_found
  }

  # Check if installation dir is given
  if ($install_dir != undef) {
    # Create ssl directory
    $install_dir_correct = $install_dir
    file { 'gitlab_install_dir':
      ensure => directory,
      path   => $install_dir,
      owner  => 'root',
      group  => 'root',
      mode   => '0755', # Important for internal scripts
    }

    # Create symlink
    file { '/opt/gitlab':
      ensure  => 'link',
      target  => $install_dir,
      force   => true,
      require => File['gitlab_install_dir'],
    }

    # Set requirements
    $requirements = [File['/opt/gitlab'], Package['dpkg'], Package['grep']]
  } else {
    # Set requirements
    $install_dir_correct = '/opt/gitlab'
    $requirements = [Package['dpkg'], Package['grep']]
  }

  # Check if gitlab is installed exists
  exec { 'gitlab_install':
    command => Sensitive.new("/usr/bin/bash -c 'GITLAB_ROOT_EMAIL=\"${root_email_correct}\" GITLAB_ROOT_PASSWORD=\"${root_password}\" EXTERNAL_URL=\"http://${server_fdqn}\" /usr/bin/apt-get install gitlab-ee'"), #lint:ignore:140chars 
    unless  => '/usr/bin/dpkg -l | /usr/bin/grep gitlab-ee',
    timeout => 0,
    require => $requirements,
  }

  # Create ssl directory
  file { 'gitlab_ssl':
    ensure  => directory,
    path    => '/etc/gitlab/ssl',
    owner   => 'root',
    group   => 'root',
    mode    => '0700',
    require => Exec['gitlab_install'],
  }

  if (defined(Package['systemd'])) {
    # Reload systemd deamon
    exec { 'gitlab_systemd_daemon_reload':
      command     => '/usr/bin/systemctl daemon-reload',
      refreshonly => true,
      require     => Package['systemd'],
    }

    # Check if basic settings is defined
    if (defined(Class['basic_settings'])) {
      # Disable Gitlab service
      service { 'gitlab-runsvdir':
        ensure  => undef,
        enable  => false,
        require => Exec['gitlab_install'],
      }

      # Create drop in for services target
      basic_settings::systemd_drop_in { 'gitlab_dependency':
        target_unit   => "${basic_settings::cluster_id}-services.target",
        unit          => {
          'BindsTo'   => 'gitlab-runsvdir.service',
        },
        daemon_reload => 'gitlab_systemd_daemon_reload',
        require       => Basic_settings::Systemd_target["${basic_settings::cluster_id}-services"],
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

    # Create drop in for nginx service
    basic_settings::systemd_drop_in { 'gitlab_settings':
      target_unit   => 'gitlab-runsvdir.service',
      unit          => $unit,
      service       => {
        'Nice'          => "-${nice_level}",
      },
      daemon_reload => 'gitlab_systemd_daemon_reload',
      require       => Exec['gitlab_install'],
    }
  }

  # Create service check
  if ($monitoring_enable and $basic_settings::monitoring::package != 'none') {
    basic_settings::monitoring_custom { 'gitlab':
      source   => 'puppet:///modules/gitlab/check_gitlab',
      friendly => 'GitLab',
      timeout  => 300,
      interval => 600,
    }
  }

  # Setup audit rules
  basic_settings::security_audit { 'gitlab_exclude':
    rules   => [
      '-a never,exit -F arch=b32 -S adjtimex -F gid=gitlab-prometheus',
      '-a never,exit -F arch=b64 -S adjtimex -F gid=gitlab-prometheus',
      '-a never,exit -F arch=b32 -S chmod -F exe=/usr/local/lib/gitlab/embedded/bin/ruby -F auid=unset',
      '-a never,exit -F arch=b64 -S chmod -F exe=/usr/local/lib/gitlab/embedded/bin/ruby -F auid=unset',
    ],
    order   => 2,
    require => Exec['gitlab_install'],
  }
  basic_settings::security_audit { 'gitlab_packages':
    rule_suspicious_packages => $suspicious_packages,
    require                  => Exec['gitlab_install'],
  }
}
