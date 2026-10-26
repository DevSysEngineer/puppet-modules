# Docker scenarios require Engine >= 29.0.0 without Swarm and a consumer-managed forward filter loaded before forwarding.
# Arrange firewall activation and boot ordering as described in README; ip_version selects the forwarding families.
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

  # Prepare the webserver and its security contact information.
  class { 'nginx':
    securitytxt_contacts => ['mailto:security@example.org'],
    require              => Class['basic_settings'],
  }

  # Install the PHP extensions required by the web application.
  class { 'php8':
    curl          => true,
    mbstring      => true,
    mysql         => true,
    xml           => true,
    minor_version => 2,
  }

  # Run the application through PHP-FPM with a bounded memory limit.
  class { 'php8::fpm':
    ini_settings => {
      'memory_limit' => '256M',
    },
    require      => Class['php8'],
  }

  # Provide the default socket used by the application vhost below.
  php8::fpm_pool { 'app':
    require => Package['php8.2-fpm'],
  }

  # Serve the application over HTTPS using its deployed certificate.
  nginx::server { 'app.example.org':
    docroot             => '/var/www/app.example.org',
    https_enable        => true,
    https_force         => true,
    server_name         => 'app.example.org',
    ssl_certificate     => '/etc/letsencrypt/live/app.example.org/fullchain.pem',
    ssl_certificate_key => '/etc/letsencrypt/live/app.example.org/privkey.pem',
    require             => [
      Package['nginx'],
      Class['php8::fpm'],
    ],
  }

  # Restrict SSH access to administration and deployment accounts using keys.
  class { 'ssh':
    allow_users                   => ['admin', 'deploy'],
    password_authentication_users => [],
    permit_root_login             => false,
  }

  # Create the administrator account with credentials supplied by the profile.
  basic_settings::login_user { 'admin':
    gid             => 1001,
    home            => '/home/admin',
    password        => lookup('examples::site::password', Sensitive[String]),
    uid             => 1001,
    authorized_keys => ['ssh-ed25519 AAAA... admin@example.org'],
    require         => Class['basic_settings'],
  }
}

node 'container01.example.org' {
  class { 'basic_settings':
    docker_enable              => true,
    ip_forwarding              => true,
    monitoring_package         => 'openitcockpit',
    monitoring_package_install => true,
  }

  # Install the runtime used by the application stack.
  class { 'docker':
    require => Class['basic_settings'],
  }

  # Deploy the stack and require healthy web and database services.
  docker::compose { 'example':
    compose                    => 'puppet:///modules/profile/example/docker-compose.yml',
    env                        => lookup('examples::site::env_content', Sensitive[String]),
    monitoring_health_required => ['web', 'db'],
    require                    => Class['docker'],
  }
}

# Enable keyboard package and configuration management on a virtual machine without an explicit console reload.
node 'console01.example.org' {
  class { 'basic_settings':
    keyboard_enable => true,
  }
}

# Configure the MySQL lookup keys with convert_to: Sensitive in Hiera data; see the README migration guide.
node 'database01.example.org' {
  class { 'basic_settings':
    mysql_enable => true,
  }

  # Configure database administration and backup credentials after preparing packages.
  class { 'mysql':
    automysqlbackup_password => lookup('examples::site::automysqlbackup_password', Sensitive[String]),
    root_password            => lookup('mysql::root_password', Sensitive[String]),
    require                  => Class['basic_settings'],
  }

  # Create the schema before granting application access.
  mysql::database { 'app':
    ensure  => present,
    require => Class['mysql'],
  }

  # Provision the application identity from protected Hiera data.
  mysql::user { 'app':
    ensure   => present,
    password => lookup('mysql::app_password', Sensitive[String]),
    username => 'app',
    require  => Class['mysql'],
  }

  # Grant access only after the application schema and identity exist.
  mysql::grant { 'app':
    ensure   => present,
    database => 'app',
    username => 'app',
    require  => [
      Mysql::Database['app'],
      Mysql::User['app'],
    ],
  }
}

# Network example for a host that lets Netplan own the primary interface.
node 'network01.example.org' {
  include netplanio

  netplanio::ethernet { 'primary':
    addresses   => ['192.0.2.20/24'],
    interface   => 'ens18',
    nameservers => { 'addresses' => ['192.0.2.53'] },
    routes      => { 'default' => { 'via' => '192.0.2.1' } },
  }
}

# GitLab credentials use protected Hiera data because the current public parameter is a String.
node 'gitlab.example.org' {
  class { 'basic_settings':
    gitlab_enable => true,
  }

  # Install GitLab with the protected administrator password and explicit public hostname.
  class { 'gitlab':
    root_password => lookup('gitlab::root_password'),
    server_fdqn   => 'gitlab.example.org',
    require       => Class['basic_settings'],
  }

  # Enable HTTPS in the installed GitLab configuration.
  class { 'gitlab::config':
    https   => true,
    require => Class['gitlab'],
  }
}

# Proxmox changes kernels and schedules a reboot; provide its repository without reusing paths owned by basic_settings.
node 'proxmox01.example.org' {
  include basic_settings

  class { 'proxmox':
    require => Class['basic_settings'],
  }
}

# Choose OpenVox 9 explicitly and configure the agent after bootstrap connectivity is already available.
node 'agent09.example.org' {
  class { 'basic_settings':
    environment        => 'acceptance',
    puppet_version     => '9',
    puppetserver_names => ['puppet01.example.org:8141', 'puppet02.example.org'],
    voxpupuli_enable   => true,
  }
}

# Keep externally maintained agent configuration intact while retaining the other baseline functions.
node 'external-agent.example.org' {
  class { 'basic_settings':
    puppet_conf_enable => false,
  }
}
