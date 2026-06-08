# Docker-focused examples for Compose stacks, reverse proxies, and bundled app defined types.
# Replace hostnames, paths, checksums, and secrets with environment data.

node 'container-basic.example.org' {
  class { 'basic_settings':
    docker_enable              => true,
    monitoring_package         => 'openitcockpit',
    monitoring_package_install => true,
  }

  class { 'docker':
    edition => 'ce',
    require => Class['basic_settings'],
  }

  docker::compose { 'example':
    compose_checksum           => '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
    compose_source             => 'https://downloads.example.org/example/docker-compose.yml',
    env_source                 => 'puppet:///modules/profile/example.env',
    monitoring_detail_limit    => 6000,
    monitoring_expected_exited => ['migrate'],
    monitoring_health_required => ['web', 'db'],
    monitoring_interval        => 300,
    monitoring_orphan_critical => true,
    monitoring_profiles        => ['production'],
    monitoring_starting_grace  => 600,
    monitoring_timeout         => 90,
    target                     => 'services',
    require                    => Class['docker'],
  }
}

node 'container-cleanup.example.org' {
  class { 'docker': }

  docker::compose { 'old-example':
    ensure  => absent,
    require => Class['docker'],
  }
}

node 'container-proxy.example.org' {
  class { 'basic_settings':
    docker_enable              => true,
    monitoring_package         => 'openitcockpit',
    monitoring_package_install => true,
    nginx_enable               => true,
  }

  class { 'docker':
    require => Class['basic_settings'],
  }

  class { 'nginx':
    securitytxt_contacts => ['mailto:security@example.org'],
    require              => Class['basic_settings'],
  }

  docker::compose_proxy { 'custom':
    client_max_body_size          => '100m',
    compose_checksum              => '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
    compose_source                => 'puppet:///modules/profile/custom/docker-compose.yml',
    content_security_policy       => "default-src 'self'; object-src 'none'; base-uri 'self'",
    env_content                   => Sensitive.new("COMPOSE_PROJECT_NAME=custom\nAPP_SECRET=replace-with-secret\n"),
    http2_enable                  => true,
    http3_enable                  => false,
    http_enable                   => true,
    https_force                   => true,
    monitoring_detail_limit       => 6000,
    monitoring_expected_exited    => ['migrate'],
    monitoring_health_required    => ['web'],
    monitoring_interval           => 300,
    monitoring_orphan_critical    => true,
    monitoring_profiles           => ['production'],
    monitoring_starting_grace     => 600,
    monitoring_timeout            => 90,
    proxy_extra_directives        => [
      'proxy_buffering off;',
    ],
    proxy_host                    => '127.0.0.1',
    proxy_port                    => 9443,
    proxy_read_timeout            => '86400',
    proxy_scheme                  => 'https',
    proxy_ssl_trusted_certificate => '/etc/ssl/certs/internal-ca.pem',
    proxy_ssl_verify              => true,
    proxy_websocket               => true,
    referrer_policy               => 'same-origin',
    server_name                   => 'custom.example.org',
    ssl_certificate               => '/etc/letsencrypt/live/custom.example.org/fullchain.pem',
    ssl_certificate_key           => '/etc/letsencrypt/live/custom.example.org/privkey.pem',
    ssl_certificate_trusted       => '/etc/letsencrypt/live/custom.example.org/chain.pem',
    strict_transport_security     => 'max-age=31536000; includeSubDomains',
    target                        => 'services',
    x_content_type_options        => 'nosniff',
    x_frame_options               => 'DENY',
    require                       => [Class['docker'], Class['nginx']],
  }
}

node 'authentik.example.org' {
  class { 'basic_settings':
    docker_enable => true,
    nginx_enable  => true,
  }

  class { 'docker':
    require => Class['basic_settings'],
  }

  class { 'nginx':
    securitytxt_contacts => ['mailto:security@example.org'],
    require              => Class['basic_settings'],
  }

  docker::authentik { 'authentik':
    akadmin_remove             => true,
    image_tag                  => '2026.2.2',
    monitoring_detail_limit    => 6000,
    monitoring_expected_exited => ['worker'],
    monitoring_health_required => ['server'],
    monitoring_interval        => 300,
    monitoring_orphan_critical => true,
    monitoring_profiles        => [],
    monitoring_starting_grace  => 600,
    monitoring_timeout         => 90,
    pg_pass                    => Sensitive('replace-with-postgresql-password'),
    port                       => 9443,
    scheme                     => 'https',
    secret_key                 => Sensitive('replace-with-authentik-secret-key'),
    server_name                => 'auth.example.org',
    smtp_from                  => 'authentik@example.org',
    smtp_password              => Sensitive('replace-with-authentik-smtp-password'),
    smtp_port                  => 587,
    smtp_use_tls               => true,
    smtp_username              => 'authentik@example.org',
    ssl_certificate            => '/etc/letsencrypt/live/auth.example.org/fullchain.pem',
    ssl_certificate_key        => '/etc/letsencrypt/live/auth.example.org/privkey.pem',
    ssl_certificate_trusted    => '/etc/letsencrypt/live/auth.example.org/chain.pem',
    ssl_verify                 => false,
    target                     => 'services',
    require                    => [Class['docker'], Class['nginx']],
  }

  docker::authentik_admin { 'kevin.admin':
    compose_name => 'authentik',
    email        => 'info@example.org',
    password     => Sensitive('replace-with-authentik-admin-password'),
    require      => Docker::Authentik['authentik'],
  }

  docker::authentik_admin { 'old.admin':
    compose_name => 'authentik',
    ensure       => absent,
    require      => Docker::Authentik['authentik'],
  }
}

node 'twenty.example.org' {
  class { 'basic_settings':
    docker_enable => true,
    nginx_enable  => true,
  }

  class { 'docker':
    require => Class['basic_settings'],
  }

  class { 'nginx':
    securitytxt_contacts => ['mailto:security@example.org'],
    require              => Class['basic_settings'],
  }

  docker::twenty { 'twenty':
    encryption_key               => Sensitive('replace-with-encryption-key'),
    fallback_encryption_key      => Sensitive('replace-with-old-encryption-key'),
    host                         => '127.0.0.1',
    monitoring_detail_limit      => 6000,
    monitoring_expected_exited   => ['worker'],
    monitoring_health_required   => ['server', 'worker'],
    monitoring_interval          => 300,
    monitoring_orphan_critical   => true,
    monitoring_profiles          => [],
    monitoring_starting_grace    => 600,
    monitoring_timeout           => 90,
    pg_database_host             => 'db',
    pg_database_password         => Sensitive('replace-with-postgresql-password'),
    pg_database_port             => 5432,
    pg_database_user             => 'postgres',
    port                         => 3000,
    redis_url                    => 'redis://redis:6379',
    scheme                       => 'https',
    server_name                  => 'twenty.example.org',
    server_url                   => 'https://twenty.example.org',
    ssl_certificate              => '/etc/letsencrypt/live/twenty.example.org/fullchain.pem',
    ssl_certificate_key          => '/etc/letsencrypt/live/twenty.example.org/privkey.pem',
    ssl_certificate_trusted      => '/etc/letsencrypt/live/twenty.example.org/chain.pem',
    ssl_verify                   => false,
    storage_s3_access_key_id     => Sensitive('replace-with-s3-access-key-id'),
    storage_s3_endpoint          => 'https://s3.example.org',
    storage_s3_name              => 'twenty',
    storage_s3_region            => 'eu-central-1',
    storage_s3_secret_access_key => Sensitive('replace-with-s3-secret-access-key'),
    storage_type                 => 's3',
    image_tag                    => 'latest',
    target                       => 'services',
    require                      => [Class['docker'], Class['nginx']],
  }
}
