class mysql (
        $root_password = '',
        $settings = {},
        $install_server = true
    ) {

    /* Set mysqld default values */
    $default_values = {
        'key_buffer_size'         => '384M',
        'max_allowed_packet'      => '128M',
        'max_connections'         => 1000,
        'table_open_cache'        => 512,
        'sort_buffer_size'        => '2M',
        'read_buffer_size'        => '2M',
        'read_rnd_buffer_size'    => '8M',
        'myisam_sort_buffer_size' => '64M',
        'thread_cache_size'       => 16
    }

    # Merge default settings with user settings
    $mysqld_default = merge($default_values, $settings)

    /* Basic variable */
    $script_dir = '/var/local/puppet-mysql'
    $script_path = "${script_dir}/grant.sh"
    $version = $basic_settings::mysql_version

    /* Create script dir */
    file { $script_dir:
        ensure  => directory,
        owner   => 'root',
        group   => 'root'
    }

    /* Create script */
    file { $script_path:
        ensure  => file,
        content => template('mysql/grant.sh'),
        owner   => 'root',
        group   => 'root',
        mode    => '0755'
    }

    /* Do only the following steps when install server is active */
    if ($install_server) {
        /* Default file is different than normal install */
        $defaults_file = '/etc/mysql/mysql.conf.d/mysqld.cnf'

        /* Install MySQL server */
        package { 'mysql-server':
            ensure => present
        }

        /* Disable MySQL server service */
        service { 'mysql':
            ensure  => true,
            enable  => false,
            require => Package['mysql-server']
        }

        /* Reload systemd deamon */
        exec { 'mysql_systemd_daemon_reload':
            command     => 'systemctl daemon-reload',
            refreshonly => true,
            require     => Package['systemd']
        }

        /* Create drop in for PHP FPM service */
        if (defined(Class['php8::fpm'])) {
            basic_settings::systemd_drop_in { "php8_${$php8::minor_version}_mysql_dependency":
                target_unit     => "php8.${$php8::minor_version}-fpm.service",
                unit            => {
                    'After'     => 'mysql',
                    'BindsTo'   => 'mysql'
                },
                daemon_reload   => 'mysql_systemd_daemon_reload',
                require         => Class['php8::fpm']
            }
        }

        /* Create drop in for nginx service */
        basic_settings::systemd_drop_in { 'mysql_nice':
            target_unit     => 'mysql.service',
            service         => {
                'Nice' => '-12'
            },
            daemon_reload   => 'mysql_systemd_daemon_reload',
            require         => Package['mysql-server']
        }
    } else {
        /* Default file for normal install */
        $defaults_file = '/etc/mysql/debian.cnf'
    }

    # Actual root user
    if ($root_password != '') {
        /* Create mysql user */
        mysql::user { 'root':
            username    => 'root',
            hostname    => 'localhost',
            password    => $root_password,
            ensure      => present
        }

        /* Create debian cnf */
        file { 'mysql_debian_cnf':
            path        => $defaults_file,
            owner       => 'mysql',
            group       => 'mysql',
            mode        => '0600',
            content     => template('mysql/debian-cnf'),
            require     => Mysql::User['root']
        }

        /* Set mysql grant for user root */
        mysql::grant { 'root_privileges':
            username        => 'root',
            hostname        => 'localhost',
            grant_option    => true,
            ensure          => present,
            require         => File['mysql_debian_cnf']
        }
    }
}
