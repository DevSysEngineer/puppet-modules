class basic_settings::login (
  String                                $environment              = 'production',
  Boolean                               $getty_enable             = false,
  Enum['none','kiosk','adwaita-icon']   $gui_mode                 = 'none',
  String                                $hostname                 = $facts['networking']['hostname'],
  String                                $mail_to                  = 'root',
  String                                $server_fdqn              = $facts['networking']['fqdn'],
  String                                $sudoers_banner_text      = "WARNING: You are running this command with elevated privileges.\nThis action is registered and sent to the server administrator(s). Unauthorized access will be fully investigated and reported to law enforcement authorities.",
  Boolean                               $sudoers_dir_enable       = false,
  Optional[String]                      $vulnerabilities_package  = undef,
  Optional[String]                      $vulnerabilities_user     = undef,
) {
  # Remove unnecessary packages
  package { ['tmux', 'xdg-user-dirs', 'xauth', 'x11-utils']:
    ensure  => purged,
  }

  # Install packages
  package { ['login', 'screen', 'libpam-modules']:
    ensure          => installed,
    install_options => ['--no-install-recommends', '--no-install-suggests'],
  }

  # Check if sudo package is not defined
  if (!defined(Package['sudo'])) {
    package { 'sudo':
      ensure          => installed,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
    }
  }

  # Create group wheel
  group { 'wheel':
    system => true,
  }

  # Create list of packages that is suspicious
  $suspicious_packages = ['/usr/bin/chage', '/usr/bin/sudo', '/usr/bin/last', '/usr/sbin/pam-auth-update']

  # Setup GUI mode
  case $gui_mode {
    'kiosk': {
      $getty_correct = true
      $polkitd_enable = true
      $session_migration_enable = true
    }
    default: {
      $getty_correct = $getty_enable
      $polkitd_enable = false
      $session_migration_enable = false
    }
  }

  if ($polkitd_enable) {
    # Install polkitd package
    package { 'polkitd':
      ensure          => installed,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
    }
  } else {
    # Remove polkitd package
    package { 'polkitd':
      ensure  => purged,
    }
  }

  if ($session_migration_enable) {
    # Install session-migration package
    package { 'session-migration':
      ensure          => installed,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
    }
  } else {
    # Remove session-migration package
    package { 'session-migration':
      ensure  => purged,
    }
  }

  # Create script dir
  if (!defined(File['/usr/local/lib/puppet'])) {
    file { '/usr/local/lib/puppet':
      ensure => directory,
      owner  => 'root',
      group  => 'root',
      mode   => '0755' # Important, not only root are executing this rule
    }
  }

  # Create su trigger
  $su_notify_path = '/usr/local/lib/puppet/su-notify'
  file { $su_notify_path:
    ensure  => file,
    content => template('basic_settings/login/pam/notify'),
    owner   => 'root',
    group   => 'root',
    mode    => '0755', # Important, not only root are executing this rule
    require => File['/usr/local/lib/puppet'],
  }

  # Run command when PAM file is changed
  exec { 'login_pam_auth_update':
    command     => '/usr/sbin/pam-auth-update --package',
    refreshonly => true,
    require     => Package['systemd'],
  }

  # Setup pam common-session file
  file { '/usr/share/pam-configs/custom':
    ensure  => file,
    mode    => '0664',
    owner   => 'root',
    group   => 'root',
    content => template('basic_settings/login/pam/custom'),
    notify  => Exec['login_pam_auth_update'],
  }

  # Setup su pam config file
  file { '/etc/pam.d/su':
    ensure  => file,
    mode    => '0664',
    owner   => 'root',
    group   => 'root',
    content => template('basic_settings/login/pam/su'),
    require => File[$su_notify_path],
  }

  # Sudoers banner by password prompt
  file { '/etc/sudoers.lecture':
    ensure  => file,
    mode    => '0644',
    content => "${sudoers_banner_text}\n\n",
    require => Package['sudo'],
  }

  # Setup sudoers config file
  file { '/etc/sudoers':
    ensure  => file,
    mode    => '0440',
    owner   => 'root',
    group   => 'root',
    content => template('basic_settings/login/sudoers'),
    require => File['/etc/sudoers.lecture'],
  }

  # Setup sudoers dir
  if ($sudoers_dir_enable) {
    file { '/etc/sudoers.d':
      ensure  => directory,
      purge   => true,
      recurse => true,
      force   => true,
      require => Package['sudo'],
    }
  }

  # Check if OS is Ubuntu
  if ($facts['os']['name'] == 'Ubuntu') {
    # Install packages
    package { 'update-motd':
      ensure  => installed,
    }

    # Disable motd news
    file { '/etc/default/motd-news':
      ensure  => file,
      mode    => '0600',
      content => "ENABLED=0\n",
      require => Package['update-motd'],
    }

    # Ensure that motd-news is stopped
    service { 'motd-news.timer':
      ensure    => stopped,
      enable    => false,
      require   => File['/etc/default/motd-news'],
      subscribe => File['/etc/default/motd-news'],
    }

    # Set welcome header
    file { '/etc/update-motd.d/00-header':
      ensure  => file,
      mode    => '0755',
      owner   => 'root',
      group   => 'root',
      content => template('basic_settings/login/motd/header'),
      notify  => Package['update-motd'],
    }
  }

  # Create profile trigger
  file { '/etc/profile.d/99-login-notify.sh':
    ensure  => file,
    content => template('basic_settings/login/login-notify.sh'),
    owner   => 'root',
    group   => 'root',
    mode    => '0755', # Important, not only root are executing this rule
  }

  # Ensure that getty is stopped or running
  if ($getty_correct) {
    service { 'getty@tty*':
      ensure => running,
      enable => true,
    }
  } else {
    service { 'getty@tty*':
      ensure => stopped,
      enable => false,
    }
  }

  # Check if we have systemd
  if (defined(Package['systemd'])) {
    # Reload systemd deamon
    exec { 'login_systemd_daemon_reload':
      command     => '/usr/bin/systemctl daemon-reload',
      refreshonly => true,
      require     => Package['systemd'],
    }

    # Create drop in for getty service
    basic_settings::systemd_drop_in { 'getty_settings':
      target_unit   => 'getty@.service',
      unit          => {
        'ConditionPathExists' => '/dev/%I',
      },
      daemon_reload => 'login_systemd_daemon_reload',
    }
  }

  # Check if we have vulnerabilities package and user
  if ($vulnerabilities_package != undef and $vulnerabilities_user != undef) {
    case $vulnerabilities_package { #lint:ignore:case_without_default
      'rapid7': {
        # Create sudoers file
        file { '/etc/sudoers.d/z90-vulnerabilities':
          ensure  => file,
          owner   => 'root',
          group   => 'root',
          mode    => '0440',
          content => "# Managed by puppet\nUser_Alias R7 = ${vulnerabilities_user}\nCmnd_Alias R7_BASH_CMD = /bin/bash, /bin/bash -c *\nR7 ALL=(ALL) ALL, NOMAIL: R7_BASH_CMD\n",
          require => Package['sudo'],
        }

        # Setup audit rules
        basic_settings::security_audit { 'login_vulnerabilities':
          rules => [
            "-a never,exit -F arch=b32 -S connect -F exe=/bin/bash -F auid=${vulnerabilities_user}",
            "-a never,exit -F arch=b64 -S connect -F exe=/bin/bash -F auid=${vulnerabilities_user}",
            "-a never,exit -F arch=b32 -S connect -F exe=/usr/bin/bash -F auid=${vulnerabilities_user}",
            "-a never,exit -F arch=b64 -S connect -F exe=/usr/bin/bash -F auid=${vulnerabilities_user}",
          ],
          order => 2,
        }
      }
    }
  }

  # Setup audit rules
  if (defined(Package['auditd'])) {
    basic_settings::security_audit { 'login':
      rules                    => [
        '# Login',
        '-a always,exit -F arch=b32 -F path=/etc/login.defs -F perm=wa -F key=login',
        '-a always,exit -F arch=b64 -F path=/etc/login.defs -F perm=wa -F key=login',
        '-a always,exit -F arch=b32 -F path=/var/log/faillog -F perm=wa -F key=login',
        '-a always,exit -F arch=b64 -F path=/var/log/faillog -F perm=wa -F key=login',
        '-a always,exit -F arch=b32 -F path=/var/log/lastlog -F perm=wa -F key=login',
        '-a always,exit -F arch=b64 -F path=/var/log/lastlog -F perm=wa -F key=login',
        '-a always,exit -F arch=b32 -F path=/var/log/auth.log -F perm=wa -F key=login',
        '-a always,exit -F arch=b64 -F path=/var/log/auth.log -F perm=wa -F key=login',
        '# User configuration',
        '-a always,exit -F arch=b32 -F path=/etc/security/limits.conf -F perm=wa  -F key=limits',
        '-a always,exit -F arch=b64 -F path=/etc/security/limits.conf -F perm=wa  -F key=limits',
        '-a always,exit -F arch=b32 -F path=/etc/security/namespace.conf -F perm=wa -F key=namespace',
        '-a always,exit -F arch=b64 -F path=/etc/security/namespace.conf -F perm=wa -F key=namespace',
        '-a always,exit -F arch=b32 -F path=/etc/security/namespace.init -F perm=wa -F key=namespace',
        '-a always,exit -F arch=b64 -F path=/etc/security/namespace.init -F perm=wa -F key=namespace',
        '# PAM configuration',
        '-a always,exit -F arch=b32 -F path=/etc/pam.d -F perm=wa -F key=pam',
        '-a always,exit -F arch=b64 -F path=/etc/pam.d -F perm=wa -F key=pam',
        '-a always,exit -F arch=b32 -F path=/etc/security/pam_env.conf -F perm=wa -F key=pam',
        '-a always,exit -F arch=b64 -F path=/etc/security/pam_env.conf -F perm=wa -F key=pam',
        '# Sudoers configuration',
        '-a always,exit -F arch=b32 -F path=/etc/sudoers -F perm=r -F auid!=unset -F key=sudoers',
        '-a always,exit -F arch=b64 -F path=/etc/sudoers -F perm=r -F auid!=unset -F key=sudoers',
        '-a always,exit -F arch=b32 -F path=/etc/sudoers.d -F perm=r -F auid!=unset -F key=sudoers',
        '-a always,exit -F arch=b64 -F path=/etc/sudoers.d -F perm=r -F auid!=unset -F key=sudoers',
        '-a always,exit -F arch=b32 -F path=/etc/sudoers -F perm=wa -F key=sudoers',
        '-a always,exit -F arch=b64 -F path=/etc/sudoers -F perm=wa -F key=sudoers',
        '-a always,exit -F arch=b32 -F path=/etc/sudoers.d -F perm=wa -F key=sudoers',
        '-a always,exit -F arch=b64 -F path=/etc/sudoers.d -F perm=wa -F key=sudoers',
      ],
      rule_suspicious_packages => $suspicious_packages,
    }
  }
}
