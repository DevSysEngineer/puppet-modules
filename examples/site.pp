# Example profile-style usage for the first-party modules in this repository.
# Replace hostnames, secrets, package choices, and paths with environment data.

node 'web01.example.org' {
  class { 'basic_settings':
    monitoring_package         => 'openitcockpit',
    monitoring_package_install => true,
    nginx_enable               => true,
    sury_enable                => true,
    systemd_ntp_extra_pools    => ['ntp.example.org'],
  }

  class { 'nginx':
    securitytxt_contacts => ['mailto:security@example.org'],
    require              => Class['basic_settings'],
  }

  class { 'php8':
    curl          => true,
    mbstring      => true,
    mysql         => true,
    xml           => true,
    minor_version => 2,
  }

  class { 'php8::fpm':
    ini_settings => {
      'memory_limit' => '256M',
    },
    require      => Class['php8'],
  }

  nginx::server { 'app.example.org':
    docroot             => '/var/www/app.example.org',
    https_enable        => true,
    https_force         => true,
    server_name         => 'app.example.org',
    ssl_certificate     => '/etc/letsencrypt/live/app.example.org/fullchain.pem',
    ssl_certificate_key => '/etc/letsencrypt/live/app.example.org/privkey.pem',
    require             => Class['nginx', 'php8::fpm'],
  }

  class { 'ssh':
    allow_users                   => ['admin', 'deploy'],
    password_authentication_users => [],
    permit_root_login             => false,
  }
}

node 'container01.example.org' {
  class { 'basic_settings':
    docker_enable              => true,
    monitoring_package         => 'openitcockpit',
    monitoring_package_install => true,
  }

  class { 'docker':
    require => Class['basic_settings'],
  }

  docker::compose { 'example':
    compose_source             => 'puppet:///modules/profile/example/docker-compose.yml',
    env_content                => Sensitive("COMPOSE_PROJECT_NAME=example\n"),
    monitoring_health_required => ['web', 'db'],
    require                    => Class['docker'],
  }
}

node 'database01.example.org' {
  class { 'basic_settings':
    mysql_enable => true,
  }

  class { 'mysql':
    automysqlbackup_password => Sensitive('replace-with-backup-password'),
    root_password           => 'replace-with-root-password',
    require                 => Class['basic_settings'],
  }

  mysql::database { 'app':
    ensure  => present,
    require => Class['mysql'],
  }

  mysql::user { 'app':
    ensure   => present,
    password => 'replace-with-app-password',
    username => 'app',
    require  => Class['mysql'],
  }

  mysql::grant { 'app':
    ensure   => present,
    database => 'app',
    username => 'app',
    require  => [Mysql::Database['app'], Mysql::User['app']],
  }
}
