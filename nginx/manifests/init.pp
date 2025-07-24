class nginx (
  Array                       $events_directives          = [],
  Array                       $global_directives          = [],
  Array                       $http_directives            = [],
  Boolean                     $ssl_prefer_server_ciphers  = true,
  Integer                     $keepalive_requests         = 1000,
  Integer                     $limit_file                 = 10000,
  Integer                     $nice_level                 = 10,
  Integer                     $types_hash_max_size        = 2048,
  String                      $keepalive_timeout          = '75s',
  Enum['nginx','nginx-full']  $package                    = 'nginx',
  String                      $run_group                  = 'www-data',
  String                      $run_user                   = 'www-data',
  String                      $ssl_protocols              = 'TLSv1.2 TLSv1.3',
  String                      $target                     = 'services'
) {
  # Set some values
  $monitoring_enable = defined(Class['basic_settings::monitoring'])
  $nginx_config = '/etc/nginx/conf.d'

  # Remove unnecessary package
  package { 'apache2':
    ensure => purged,
  }

  # Install Nginx
  case $package {
    'nginx-full': {
      # Install Nginx package
      package { ['nginx', 'nginx-full']:
        ensure          => installed,
        install_options => ['--no-install-recommends', '--no-install-suggests'],
        require         => Package['apache2'],
      }
    }
    default: {
      # Remove unnecessary package
      package { 'nginx-full':
        ensure => purged,
      }

      # Install Nginx package
      package { 'nginx':
        ensure          => installed,
        install_options => ['--no-install-recommends', '--no-install-suggests'],
        require         => Package['apache2', 'nginx-full'],
      }
    }
  }

  # Check if letsencrypt class is defined
  if (defined(Class['letsencrypt'])) {
    package { 'python3-certbot-nginx':
      ensure          => installed,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
      require         => Package['apache2'],
    }
  }

  # Set PID file
  $pid = '/run/nginx.pid'

  # Disable service
  if (defined(Package['systemd'])) {
    # Disable service
    service { 'nginx':
      ensure  => undef,
      enable  => false,
      require => Package['nginx'],
    }

    # Reload systemd deamon
    exec { 'nginx_systemd_daemon_reload':
      command     => '/usr/bin/systemctl daemon-reload',
      refreshonly => true,
      require     => Package['systemd'],
    }

    # Create drop in for x target
    if (defined(Class['basic_settings::systemd'])) {
      basic_settings::systemd_drop_in { 'nginx_dependency':
        target_unit   => "${basic_settings::systemd::cluster_id}-${target}.target",
        unit          => {
          'BindsTo'   => 'nginx.service',
        },
        daemon_reload => 'nginx_systemd_daemon_reload',
        require       => Basic_settings::Systemd_target["${basic_settings::systemd::cluster_id}-${target}"],
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
    basic_settings::systemd_drop_in { 'nginx_settings':
      target_unit   => 'nginx.service',
      unit          => $unit,
      service       => {
        'LimitNOFILE'    => $limit_file,
        'Nice'           => "-${nice_level}",
        'PIDFile'        => $pid,
        'PrivateDevices' => 'true',
        'PrivateTmp'     => 'true',
        'ProtectHome'    => 'true',
        'ProtectSystem'  => 'full',
      },
      daemon_reload => 'nginx_systemd_daemon_reload',
      require       => Package['nginx'],
    }
  } else {
    # Enable service
    service { 'nginx':
      ensure  => true,
      enable  => true,
      require => Package['nginx'],
    }
  }

  # Create service check
  if ($monitoring_enable and $basic_settings::monitoring::package != 'none') {
    basic_settings::monitoring_service { 'nginx': }
  }

  # Create log file
  file { '/var/log/nginx':
    ensure  => directory,
    owner   => $run_user,
    require => Package['nginx'],
  }

  # Create cache directory
  file { '/var/cache/nginx':
    ensure  => directory,
    owner   => $run_user,
    group   => $run_group,
    require => Package['nginx'],
  }

  # Create nginx config file
  file { '/etc/nginx/nginx.conf':
    ensure  => file,
    content => template('nginx/global.conf'),
    notify  => Service['nginx'],
    require => Package['nginx'],
  }

  # Create sites config directory
  file { $nginx_config:
    ensure  => directory,
    purge   => true,
    force   => true,
    recurse => true,
    require => Package['nginx'],
  }

  # Create symlink
  file { '/etc/nginx/sites-enabled':
    ensure  => 'link',
    target  => $nginx_config,
    force   => true,
    require => File[$nginx_config],
  }

  # Create snippets directory
  file { 'nginx_snippets':
    ensure  => directory,
    path    => '/etc/nginx/snippets',
    owner   => 'root',
    group   => 'root',
    mode    => '0700',
    require => Package['nginx'],
  }

  # Create ssl directory
  file { 'nginx_ssl':
    ensure  => directory,
    path    => '/etc/nginx/ssl',
    owner   => 'root',
    group   => 'root',
    mode    => '0700',
    require => Package['nginx'],
  }

  # Create FastCGI config
  file { 'nginx_fastcgi_params':
    ensure => file,
    path   => '/etc/nginx/fastcgi_params',
    source => 'puppet:///modules/nginx/fastcgi_params',
    owner  => 'root',
    group  => 'root',
    mode   => '0600',
    notify => Service['nginx'],
  }

  # Create FastCGI PHP config
  file { 'nginx_fastcgi_php':
    ensure  => file,
    path    => '/etc/nginx/snippets/fastcgi_php.conf',
    source  => 'puppet:///modules/nginx/fastcgi_php.conf',
    owner   => 'root',
    group   => 'root',
    mode    => '0600',
    require => [File['nginx_fastcgi_params'], File['nginx_snippets']],
    notify  => Service['nginx'],
  }

  # Remove wrong FastCGI config
  file { ['/etc/nginx/fastcgi.conf', '/etc/nginx/snippets/fastcgi-php.conf', '/etc/nginx/snippets/fastcgi_params-php']:
    ensure  => absent,
    require => File['nginx_snippets'],
  }

  # Check if logrotate package exists
  if (defined(Package['logrotate'])) {
    basic_settings::io_logrotate { 'nginx':
      path           => '/var/log/nginx/*.log',
      frequency      => 'daily',
      compress_delay => true,
      create_user    => $run_user,
      rotate_post    => "if [ -f /var/run/nginx.pid ]; then\n\t\tkill -USR1 `cat /var/run/nginx.pid`\n\tfi",
    }
  }
}
