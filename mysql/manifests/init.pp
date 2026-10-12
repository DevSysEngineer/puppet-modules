# @summary Installs and configures MySQL plus local automated backups.
#
# This class installs the MySQL server package, writes MySQL defaults, manages a root-only grant helper, configures
# `automysqlbackup`, creates a hardened backup service and timer, integrates with `php8::fpm`, Puppet, systemd targets,
# monitoring, logrotate, and audit rules when those local modules are available.
# Backup and root credentials should be supplied from Hiera or profiles as sensitive data.
#
# @example Install MySQL with backups and a root password
#   class { 'mysql':
#     automysqlbackup_password => Sensitive('replace-with-backup-password'),
#     root_password            => Sensitive('replace-with-root-password'),
#   }
#
# @param automysqlbackup_password
#   Password used by the generated automysqlbackup configuration. This value is sensitive because it can decrypt or
#   protect backup material. Supply a Sensitive string without NUL, CR or LF, at most 1023 UTF-8 bytes, because
#   OpenSSL reads a single bounded passphrase line. An empty value preserves the existing unencrypted-backup behavior.
#
# @param automysqlbackup_backupdir
#   Directory where automysqlbackup stores backup output. The default is `/var/lib/automysqlbackup`.
#
# @param automysqlbackup_settings
#   Hash of settings merged over the module's automysqlbackup defaults.
#   The template uses only `mysql_dump_compression`, `mysql_dump_single_transaction`, and `mysql_dump_skip_lock_tables`.
#   Encryption uses `automysqlbackup_password` when it is non-empty; `encrypt` and `encrypt_password` entries have no
#   effect.
#
# @param nice_level
#   Positive nice value converted to a negative service priority in the MySQL systemd drop-in. The default is 12.
#
# @param package_name
#   Service/package family name used for dependencies. The default is `mysql`.
#
# @param package_version
#   MySQL version used when no `basic_settings::package_mysql` class is present.
#
# @param root_authentication
#   Optional explicit authentication for root@localhost on MySQL 8.0 or 8.4. `auth_socket` uses the OS root identity
#   over the local Unix socket and ignores root_password; the plugin must already be loaded on the server.
#   `caching_sha2_password` requires root_password and explicitly selects that password plugin.
#   With undef, root_password retains the existing version-dependent behavior; both undef leave root unmanaged.
#   Switching methods requires working administrative access and changes how external root clients authenticate.
#
# @param root_password
#   Optional Sensitive root password managed through `mysql::user`, ignored with root_authentication => auth_socket.
#   Without an explicit root_authentication, undef leaves root unmanaged; automatic parameter lookup can still supply
#   a value when an explicit argument is undef.
#   The existing defaults file must provide working administrative access for initial setup or rotation. Desired
#   credentials are tried first to recover interrupted rotations. No password reset or implicit bootstrap is attempted.
#   The combined server/client configuration remains readable by mysql and OS root, with Puppet backups disabled.
#
# @param settings
#   Hash of MySQL server settings merged over the module defaults and rendered into the MySQL configuration template.
#
# @api public
class mysql (
  Sensitive[String]                                      $automysqlbackup_password,
  String                                                 $automysqlbackup_backupdir = '/var/lib/automysqlbackup',
  Hash                                                   $automysqlbackup_settings  = {},
  Integer                                                $nice_level                = 12,
  String                                                 $package_name              = 'mysql',
  Float                                                  $package_version           = 8.0,
  Optional[Enum['auth_socket', 'caching_sha2_password']] $root_authentication       = undef,
  Optional[Sensitive[String]]                            $root_password             = undef,
  Hash                                                   $settings                  = {},
) {
  # Both explicit socket authentication and password management own the administrative configuration.
  $root_managed = $root_authentication != undef or $root_password != undef

  # Reuse the existing baseline selection for systemd settings and the monitoring template.
  $basic_settings_enable = defined(Class['basic_settings'])
  $systemd_enable = defined(Package['systemd'])

  # Resolve backup contact details and backend selection from available monitoring settings.
  $monitoring_enable = defined(Class['basic_settings::monitoring']);
  if ($monitoring_enable) {
    # Reuse the monitoring identity, contact, and backend for database-backup reporting.
    $automysqlbackup_host_friendly = $basic_settings::monitoring::server_fdqn
    $automysqlbackup_mail_address = $basic_settings::monitoring::mail_to
    $monitoring_package = $basic_settings::monitoring::package
  } else {
    # The standalone backup configuration must use the same structured host fact as the shared monitoring class.
    $automysqlbackup_host_friendly = $facts['networking']['fqdn']
    $automysqlbackup_mail_address = 'root'
    $monitoring_package = 'none'
  }

  # Set mysqld default values
  $default_values = {
    'binlog_cache_size'             => '2M',
    'binlog_format'                 => 'MIXED',
    'binlog_expire_logs_auto_purge' => 'ON',
    'binlog_expire_logs_seconds'    => 172800, # 2 days
    'innodb_buffer_pool_chunk_size' => '256M', # innodb_buffer_pool_size / innodb_buffer_pool_instances
    'innodb_buffer_pool_instances'  => 1, # innodb_buffer_pool_size <= 1 GiB, then value is 1
    'innodb_buffer_pool_size'       => '256M',
    'innodb_flush_method'           => 1, # O_DSYNC
    'innodb_redo_log_capacity'      => '256M',
    'join_buffer_size'              => '2M',
    'max_allowed_packet'            => '128M',
    'max_binlog_size'               => '1G',
    'max_connections'               => 1000,
    'read_buffer_size'              => '2M',
    'read_rnd_buffer_size'          => '2M',
    'sort_buffer_size'              => '2M',
    'table_open_cache'              => 8000,
    'thread_cache_size'             => 16,
    'thread_stack'                  => '2M',
  }

  # Set automysqlbackup default values
  $automysqlbackup_values = {
    'encrypt'                       => 'no',
    'encrypt_password'              => '',
    'mysql_dump_compression'        => 'bzip2',
    'mysql_dump_single_transaction' => 'yes',
    'mysql_dump_skip_lock_tables'   => 'yes',
  }

  # Merge default settings with user settings
  $mysqld_default = stdlib::merge($default_values, $settings)
  $automysqlbackup_default = stdlib::merge($automysqlbackup_values, $automysqlbackup_settings)

  # Basic variable
  $script_path = '/usr/local/lib/puppet/mysql-grant.sh'
  $user_script_path = '/usr/local/lib/puppet/mysql-user.sh'

  # Get version
  if (defined(Class['basic_settings::package_mysql'])) {
    # Use the MySQL version selected by the managed repository.
    $version = $basic_settings::package_mysql::version
  } else {
    # Fall back to the caller's package version without a managed MySQL repository.
    $version = $package_version
  }

  # Account management, grants and backup encryption need these tools independently of monitoring.
  $management_packages = ['bash', 'coreutils', 'dash', 'grep', 'mawk', 'mysql-client', 'openssl', 'sed']
  ensure_packages($management_packages, {
    'ensure'          => 'installed',
    'install_options' => ['--no-install-recommends', '--no-install-suggests'],
  })

  # Do only the following steps when package name is mysql
  if ($package_name == 'mysql') {
    # Default file is different than normal install
    $defaults_file = '/etc/mysql/mysql.conf.d/mysqld.cnf'

    # Create list of packages that is suspicious
    $suspicious_packages = ['/usr/bin/mysql']

    # Install MySQL server
    package { 'mysql-server':
      ensure          => present,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
    }

    # Setup audit rules
    if (defined(Package['auditd'])) {
      basic_settings::security_audit { 'mysql':
        rule_suspicious_packages => $suspicious_packages,
        rule_options             => ['-F auid!=unset'],
      }
    }

    # Enable hugepages
    if ($basic_settings_enable and $basic_settings::kernel_hugepages > 0) {
      # getent and usermod are required independently of the group and server resources.
      $hugetlb_packages = ['libc-bin', 'passwd']
      ensure_packages($hugetlb_packages, {
        'ensure'          => 'installed',
        'install_options' => ['--no-install-recommends', '--no-install-suggests'],
      })
      $hugetlb_required_packages = concat($hugetlb_packages, ['coreutils', 'dash', 'grep', 'mysql-server'])

      # Add the database user only after its group and command prerequisites are available.
      exec { 'mysql_hugetlb':
        unless  => '/bin/getent group hugetlb | /bin/cut -d: -f4 | /bin/grep -q mysql',
        command => '/usr/sbin/usermod -a -G hugetlb mysql',
        require => [Group['hugetlb'], Package[$hugetlb_required_packages]],
      }
    }

    # Disable automatic MySQL startup only when systemd owns service ordering.
    if ($systemd_enable) {
      # Disable MySQL server service
      service { 'mysql':
        ensure  => undef,
        enable  => false,
        require => Package['mysql-server'],
      }

      # Reload systemd deamon
      exec { 'mysql_systemd_daemon_reload':
        command     => '/usr/bin/systemctl daemon-reload',
        refreshonly => true,
        require     => Package['systemd'],
      }

      # Create drop in for PHP FPM service
      if (defined(Class['php8::fpm'])) {
        basic_settings::systemd_drop_in { "php8_${$php8::minor_version}_mysql_dependency":
          target_unit   => "php8.${$php8::minor_version}-fpm.service",
          unit          => {
            'After'   => 'mysql.service',
            'BindsTo' => 'mysql.service',
          },
          daemon_reload => 'mysql_systemd_daemon_reload',
          require       => Class['php8::fpm'],
        }
      } elsif ($basic_settings_enable) {
        # Create drop in for services target
        basic_settings::systemd_drop_in { 'mysql_dependency':
          target_unit   => "${basic_settings::cluster_id}-services.target",
          unit          => {
            'BindsTo'   => 'mysql.service',
          },
          daemon_reload => 'mysql_systemd_daemon_reload',
          require       => Basic_settings::Systemd_target["${basic_settings::cluster_id}-services"],
        }
      }

      # Get unit
      if ($monitoring_enable) {
        # Route unit failures through the configured monitoring notification service.
        $unit = {
          'OnFailure' => 'notify-failed@%i.service',
        }
      } else {
        # Leave unit failure hooks empty when monitoring is unavailable.
        $unit = {}
      }

      # Create drop in for nginx service
      basic_settings::systemd_drop_in { 'mysql_settings':
        target_unit   => 'mysql.service',
        unit          => $unit,
        service       => {
          'LimitNOFILE'  => 'infinity',
          'LimitMEMLOCK' => 'infinity',
          'Nice'         => "-${nice_level}",
        },
        daemon_reload => 'mysql_systemd_daemon_reload',
        require       => Package['mysql-server'],
      }

      # Create drop in for puppet service
      basic_settings::systemd_drop_in { 'puppet_mysql_dependency':
        target_unit   => 'puppet.service',
        unit          => {
          'Wants' => 'mysql.service',
        },
        daemon_reload => 'mysql_systemd_daemon_reload',
        require       => Package['mysql-server'],
      }
    } else {
      # Enable service
      service { 'mysql':
        ensure  => true,
        enable  => true,
        require => Package['mysql-server'],
      }
    }

    # Create service check
    if ($monitoring_enable and $basic_settings::monitoring::package != 'none') {
      # Install the check tools and the selected systemd or process inspection interface.
      $monitoring_packages = concat(['mysql-client'], $systemd_enable ? {
        true    => ['systemd'],
        default => ['procps'],
      })
      ensure_packages($monitoring_packages, {
        'ensure'          => 'installed',
        'install_options' => ['--no-install-recommends', '--no-install-suggests'],
      })
      $monitoring_required_packages = concat($monitoring_packages, ['dash', 'mawk'])

      # Register the check after its runtime packages.
      basic_settings::monitoring_custom { 'mysql':
        content => template('mysql/check_mysql'),
        require => Package[$monitoring_required_packages],
      }
    }

    # Check if logrotate package exists
    if (defined(Package['logrotate'])) {
      basic_settings::io_logrotate { 'mysql-server':
        path        => "/var/log/mysql.log\n/var/log/mysql/*log",
        frequency   => 'daily',
        create_user => 'mysql',
        rotate_post => join([
          'test -x /usr/bin/mysqladmin || exit 0',
          'MYADMIN="/usr/bin/mysqladmin --defaults-file=/etc/mysql/debian.cnf"',
          'if [ -z "$($MYADMIN ping 2>/dev/null)" ]; then',
          "\tif killall -q -s0 -umysql mysqld; then",
          "\t\texit 1",
          "\tfi",
          'else',
          "\t\$MYADMIN flush-logs",
          'fi',
        ], "\n\t"),
      }
    }
  } else {
    # Default file for normal install
    $defaults_file = '/etc/mysql/debian.cnf'
    $suspicious_packages = undef
  }

  # Install package for automysqlbackup
  case $automysqlbackup_default['mysql_dump_compression'] {
    'gzip': {
      # Install package for automysqlbackup
      if (!defined(Package['pigz'])) {
        package { 'pigz':
          ensure          => installed,
          install_options => ['--no-install-recommends', '--no-install-suggests'],
        }
      }
    }
    'bzip2': {
      # Install package for automysqlbackup
      if (!defined(Package['pbzip2'])) {
        package { 'pbzip2':
          ensure          => installed,
          install_options => ['--no-install-recommends', '--no-install-suggests'],
        }
      }
    }
    default: {
      # Other compression selections do not need an additional parallel compressor.
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

  # Create script
  file { $script_path:
    ensure  => file,
    content => template('mysql/grant.sh'), # Keep this file below version and defaults_file variable
    owner   => 'root',
    group   => 'root',
    mode    => '0700',
    require => [File['/usr/local/lib/puppet'], Package[$management_packages]],
  }

  # Retire the helper's old private inputs and confirmation records without making backups.
  file { '/usr/local/lib/puppet/mysql-users':
    ensure    => absent,
    force     => true,
    backup    => false,
    show_diff => false,
  }

  # The helper reads native MySQL files; its arguments never contain credentials.
  file { $user_script_path:
    ensure  => file,
    source  => 'puppet:///modules/mysql/mysql-user.sh',
    owner   => 'root',
    group   => 'root',
    mode    => '0700',
    require => [File['/usr/local/lib/puppet'], Package[$management_packages]],
  }

  # Set config file
  file { '/etc/default/automysqlbackup.conf':
    ensure    => file,
    content   => Sensitive.new(template('mysql/automysqlbackup.config')),
    backup    => false,
    show_diff => false,
    owner     => 'root',
    group     => 'root',
    mode      => '0600', # Only root
  }

  # Create automysqlbackup script
  file { '/usr/local/sbin/automysqlbackup':
    ensure  => file,
    source  => 'puppet:///modules/mysql/automysqlbackup',
    owner   => 'root',
    group   => 'root',
    mode    => '0700', # Only root
    require => Package[$management_packages],
  }

  # Use the same systemd selection for database backups, service settings, and monitoring.
  if ($systemd_enable) {
    # Create systemd service
    basic_settings::systemd_service { 'automysqlbackup':
      description   => 'Automysqlbackup service',
      service       => {
        'ExecStart'               => '/usr/local/sbin/automysqlbackup',
        'LockPersonality'         => 'true',
        'MemoryDenyWriteExecute'  => 'true',
        'Nice'                    => '19',
        'NoNewPrivileges'         => 'true',
        'PrivateDevices'          => 'true',
        'PrivateTmp'              => 'true',
        'ProtectClock'            => 'true',
        'ProtectHome'             => 'true',
        'ProtectHostname'         => 'true',
        'ProtectControlGroups'    => 'true',
        'ProtectKernelLogs'       => 'true',
        'ProtectKernelModules'    => 'true',
        'ProtectKernelTunables'   => 'true',
        'ProtectSystem'           => 'full',
        'RestrictSUIDSGID'        => 'true',
        'SystemCallArchitectures' => 'native',
        'Type'                    => 'oneshot',
        'UMask'                   => '0077',
        'User'                    => 'root',
      },
      unit          => {
        'After'   => "${package_name}.service",
        'BindsTo' => "${package_name}.service",
      },
      daemon_reload => 'mysql_systemd_daemon_reload',
      enable        => false,
      require       => File['/etc/default/automysqlbackup.conf', '/usr/local/sbin/automysqlbackup'],
    }

    # Create systemd timer
    $timer_state = $basic_settings_enable ? { true => undef, default => 'running' }

    # Schedule the daily backup with the startup state selected for the host's service management.
    basic_settings::systemd_timer { 'automysqlbackup':
      description        => 'Automysqlbackup timer',
      monitoring_enable  => $monitoring_enable,
      monitoring_package => $monitoring_package,
      state              => $timer_state,
      timer              => {
        'OnCalendar' => '*-*-* 5:00',
      },
      unit               => {
        'After'   => "${package_name}.service",
        'BindsTo' => "${package_name}.service",
      },
      daemon_reload      => 'mysql_systemd_daemon_reload',
    }

    # Bind the backup timer to the shared services target when that target is available.
    if ($basic_settings_enable) {
      # Create drop in for services target
      basic_settings::systemd_drop_in { 'automysqlbackup_dependency':
        target_unit   => "${basic_settings::cluster_id}-services.target",
        unit          => {
          'BindsTo'   => 'automysqlbackup.timer',
        },
        daemon_reload => 'mysql_systemd_daemon_reload',
        require       => Basic_settings::Systemd_target["${basic_settings::cluster_id}-services"],
      }
    }
  }

  # Create mysql cnf
  file { 'mysql_cnf':
    path    => '/etc/mysql/mysql.cnf',
    owner   => 'mysql',
    group   => 'mysql',
    mode    => '0600',
    content => template('mysql/mysql.cnf'),
  }

  # Manage root when either explicit authentication or the existing password interface requests it.
  if ($root_managed) {
    # Explicit plugin selection uses the supported MySQL 8 account columns and SQL syntax.
    if ($root_authentication == undef or $version in [8.0, 8.4]) {
      # Socket authentication needs no password; every managed password mode requires one.
      if ($root_authentication == 'auth_socket' or $root_password != undef) {
        # Share the option-file encoder with account credential checks without unwrapping in Puppet scope.
        $client_username = 'root'
        $client_password = $root_authentication ? {
          'auth_socket' => undef,
          default       => $root_password,
        }

        # Create mysql user
        mysql::user { 'root':
          ensure   => present,
          hostname => 'localhost',
          password => $client_password,
          username => 'root',
        }

        # Create config cnf
        file { 'mysql_debian_cnf':
          path      => $defaults_file,
          content   => Sensitive.new(template('mysql/debian.cnf', 'mysql/client.cnf')),
          backup    => false,
          show_diff => false,
          owner     => 'mysql',
          group     => 'mysql',
          mode      => '0600', # Only readably for user mysql
          require   => Mysql::User['root'],
        }

        # Create debian cnf
        if ($package_name == 'mysql') {
          file { 'mysql_debian_cnf_extra':
            path    => '/etc/mysql/debian.cnf',
            owner   => 'mysql',
            group   => 'mysql',
            mode    => '0600',
            content => template('mysql/mysql.cnf'),
            require => File['mysql_debian_cnf'],
          }
        }

        # Set mysql grant for user root
        mysql::grant { 'root_privileges':
          ensure       => present,
          hostname     => 'localhost',
          grant_option => true,
          username     => 'root',
          require      => File['mysql_debian_cnf'],
        }
      } else {
        fail('mysql::root_authentication caching_sha2_password requires root_password')
      }
    } else {
      fail('mysql::root_authentication requires MySQL 8.0 or 8.4')
    }
  }
}
