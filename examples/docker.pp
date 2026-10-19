# Docker scenarios require Engine >= 29.0.0 without Swarm and a consumer-managed forward filter loaded before forwarding.
# Arrange firewall activation and boot ordering as described in README; ip_version selects the forwarding families.
# Docker-focused examples for Compose stacks, reverse proxies, bundled apps, Nextcloud AIO, and GitLab Runner.
# Replace hostnames, paths, checksums, and secrets with environment data.

node 'container-basic.example.org' {
  class { 'basic_settings':
    docker_enable              => true,
    ip_forwarding              => true,
    monitoring_package         => 'openitcockpit',
    monitoring_package_install => true,
  }

  # Install the container runtime after preparing the host package sources.
  class { 'docker':
    edition => 'ce',
    require => Class['basic_settings'],
  }

  # Back up the db service; credentials stay in the existing container environment.
  # Deploy the stack with database backups and health requirements for long-running services.
  docker::compose { 'example':
    backup_database_type       => 'postgresql',
    backup_service             => 'db',
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
    systemd_service            => { 'TimeoutStartSec' => '600' },
    target                     => 'services',
    require                    => Class['docker'],
  }

  # The application's own read-only status command prevents repeating initialization.
  docker::compose_exec { 'initialize-example':
    command      => ['/usr/local/bin/app', 'initialize'],
    compose_name => 'example',
    service      => 'web',
    unless       => ['/usr/local/bin/app', 'initialized'],
  }
}

node 'container-cleanup.example.org' {
  class { 'docker': }

  # Back up required data, detach the systemd target binding, reload systemd and stop the stack before applying this removal.
  # Stop the backup timer and service; central directory management removes undeclared unit files.
  # This deletes the entire project directory, including backups; copy required data elsewhere first.
  docker::compose { 'old-example':
    ensure  => absent,
    require => Class['docker'],
  }
}

node 'container-proxy.example.org' {
  class { 'basic_settings':
    docker_enable              => true,
    ip_forwarding              => true,
    monitoring_package         => 'openitcockpit',
    monitoring_package_install => true,
    nginx_enable               => true,
  }

  # Prepare the runtime before creating proxied application stacks.
  class { 'docker':
    require => Class['basic_settings'],
  }

  # Provide the webserver that terminates TLS for container applications.
  class { 'nginx':
    securitytxt_contacts => ['mailto:security@example.org'],
    require              => Class['basic_settings'],
  }

  # Expose the stack through Nginx with verified upstream TLS and WebSocket support.
  docker::compose_proxy { 'custom':
    client_max_body_size          => '100m',
    compose_checksum              => '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
    compose_source                => 'puppet:///modules/profile/custom/docker-compose.yml',
    content_security_policy       => "default-src 'self'; object-src 'none'; base-uri 'self'",
    env_content                   => lookup('examples::docker::env_content', Sensitive[String]),
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
    ssl_session_cache             => 'shared:SSL:10m',
    ssl_session_timeout           => '10m',
    strict_transport_security     => 'max-age=31536000; includeSubDomains',
    target                        => 'services',
    x_content_type_options        => 'nosniff',
    x_frame_options               => 'DENY',
    require                       => [Class['docker'], Package['nginx']],
  }
}

node 'authentik.example.org' {
  class { 'basic_settings':
    docker_enable => true,
    ip_forwarding => true,
    nginx_enable  => true,
  }

  # Prepare the container runtime used by the identity service.
  class { 'docker':
    require => Class['basic_settings'],
  }

  # Provide TLS termination and security contact information for the identity service.
  class { 'nginx':
    securitytxt_contacts => ['mailto:security@example.org'],
    require              => Class['basic_settings'],
  }

  # Deploy the identity service with its database, mail and public TLS settings.
  docker::authentik { 'authentik':
    akadmin_remove             => true,
    database_password          => lookup('examples::docker::database_password', Sensitive[String]),
    secret_key                 => lookup('examples::docker::secret_key', Sensitive[String]),
    image_tag                  => '2026.2.2',
    monitoring_detail_limit    => 6000,
    monitoring_expected_exited => ['worker'],
    monitoring_health_required => ['server'],
    monitoring_interval        => 300,
    monitoring_orphan_critical => true,
    monitoring_profiles        => [],
    monitoring_starting_grace  => 600,
    monitoring_timeout         => 90,
    port                       => 9443,
    server_name                => 'auth.example.org',
    smtp_from                  => 'authentik@example.org',
    smtp_password              => lookup('examples::docker::smtp_password', Sensitive[String]),
    smtp_port                  => 587,
    smtp_security              => 'tls',
    smtp_server                => 'smtp.example.org',
    smtp_username              => 'authentik@example.org',
    ssl_certificate            => '/etc/letsencrypt/live/auth.example.org/fullchain.pem',
    ssl_certificate_key        => '/etc/letsencrypt/live/auth.example.org/privkey.pem',
    ssl_certificate_trusted    => '/etc/letsencrypt/live/auth.example.org/chain.pem',
    ssl_verify                 => false,
    target                     => 'services',
    require                    => [Class['docker'], Package['nginx']],
  }

  # Create the named administrator after deploying the identity service.
  docker::authentik_admin { 'platform.admin':
    compose_name => 'authentik',
    email        => 'info@example.org',
    password     => lookup('examples::docker::password', Sensitive[String]),
    require      => Docker::Authentik['authentik'],
  }

  # Remove the retired administrator from the same identity service.
  docker::authentik_admin { 'old.admin':
    ensure       => absent,
    compose_name => 'authentik',
    require      => Docker::Authentik['authentik'],
  }
}

node 'twenty.example.org' {
  class { 'basic_settings':
    docker_enable => true,
    ip_forwarding => true,
    nginx_enable  => true,
  }

  # Prepare the container runtime used by the CRM application.
  class { 'docker':
    require => Class['basic_settings'],
  }

  # Provide TLS termination and security contact information for the CRM application.
  class { 'nginx':
    securitytxt_contacts => ['mailto:security@example.org'],
    require              => Class['basic_settings'],
  }

  # Deploy the CRM stack with external object storage and explicit health requirements.
  docker::twenty { 'twenty':
    database_password            => lookup('examples::docker::database_password', Sensitive[String]),
    secret_key                   => lookup('examples::docker::secret_key', Sensitive[String]),
    database_host                => 'db',
    database_port                => 5432,
    database_user                => 'postgres',
    host                         => '127.0.0.1',
    monitoring_detail_limit      => 6000,
    monitoring_expected_exited   => ['worker'],
    monitoring_health_required   => ['server', 'worker'],
    monitoring_interval          => 300,
    monitoring_orphan_critical   => true,
    monitoring_profiles          => [],
    monitoring_starting_grace    => 600,
    monitoring_timeout           => 90,
    port                         => 3000,
    redis_url                    => 'redis://redis:6379',
    secret_key_fallback          => lookup('examples::docker::secret_key_fallback', Sensitive[String]),
    server_name                  => 'twenty.example.org',
    ssl_certificate              => '/etc/letsencrypt/live/twenty.example.org/fullchain.pem',
    ssl_certificate_key          => '/etc/letsencrypt/live/twenty.example.org/privkey.pem',
    ssl_certificate_trusted      => '/etc/letsencrypt/live/twenty.example.org/chain.pem',
    storage_s3_access_key_id     => lookup('examples::docker::storage_s3_access_key_id', Sensitive[String]),
    storage_s3_endpoint          => 'https://s3.example.org',
    storage_s3_name              => 'twenty',
    storage_s3_region            => 'eu-central-1',
    storage_s3_secret_access_key => lookup('examples::docker::storage_s3_secret_access_key', Sensitive[String]),
    storage_type                 => 's3',
    image_tag                    => 'latest',
    target                       => 'services',
    require                      => [Class['docker'], Package['nginx']],
  }
}

# Complete domain validation and initialization in AIO before expecting OCC defaults, SMTP and S3 registration to succeed.
# AIO requires one installation per Docker daemon; the Compose title does not isolate its fixed container names.
node 'nextcloud.example.org' {
  class { 'basic_settings':
    docker_enable        => true,
    ip_forwarding        => true,
    nginx_enable         => true,
    openitcockpit_enable => true,
    smtp_server          => 'smtp.example.org',
  }

  # Prepare the runtime and systemd integration used by the AIO mastercontainer.
  class { 'docker':
    require => Class['basic_settings'],
  }

  # Terminate application TLS on the host; AIO's Apache upstream speaks HTTP on loopback.
  class { 'nginx':
    securitytxt_contacts => ['mailto:security@example.org'],
    require              => Class['basic_settings'],
  }

  # Publish admin access only for trusted addresses; the certificate must cover both names.
  # Configure backups separately in the AIO interface.
  # SMTP uses basic_settings::smtp_server above; no mail settings are needed on this resource.
  # Prepare migration before selecting primary storage on an existing installation; these settings do not move files.
  docker::nextcloud { 'nextcloud-aio':
    admin_server_name   => 'cloud-admin.example.org',
    admin_whitelist_ips => ['192.0.2.10', '2001:db8::/32'],
    appstore_link_shown => false,
    objectstore_default => 'server2',
    objectstore_root    => 'server1',
    server_name         => 'cloud.example.org',
    ssl_certificate     => '/etc/letsencrypt/live/cloud.example.org/fullchain.pem',
    ssl_certificate_key => '/etc/letsencrypt/live/cloud.example.org/privkey.pem',
    require             => [Class['docker'], Package['nginx']],
  }

  # Install and enable OIDC; configure one working provider separately before requesting login redirection.
  # Keep administrative access through /login?direct=1 while available; omit the option to leave it unmanaged.
  class { 'docker::nextcloud_user_oidc':
    compose_name                 => 'nextcloud-aio',
    allow_multiple_user_backends => false,
  }

  # Nextcloud 35 / Talk 35 with integration_openai 5.0.0 and a working AIO Talk recording server.
  # Deploy and test the Spark APIs first; cross-host readiness cannot be expressed with catalog dependencies.
  # AIO supplies taskprocessing-worker; do not create a second host worker.
  $completion_parameter = '0'
  $completion_limit = '4096'
  $ai_settings = {
    'url'                             => 'https://ai.example.org/llm/v1',
    'service_name'                    => 'Spark verslag',
    'default_completion_model_id'     => 'nextcloud-verslag',
    'stt_url'                         => 'https://ai.example.org/stt/v1',
    'stt_service_name'                => 'Spark transcriptie',
    'default_stt_model_id'            => 'whisper-1',
    'llm_provider_enabled'            => '1',
    'stt_provider_enabled'            => '1',
    'chat_endpoint_enabled'           => '1',
    'use_max_completion_tokens_param' => $completion_parameter,
    'max_tokens'                      => $completion_limit,
    'request_timeout'                 => '3600',
    'stt_request_timeout'             => '3600',
    'use_basic_auth'                  => '0',
    'stt_use_basic_auth'              => '0',
    'llm_extra_params'                => '{"chat_template_kwargs":{"enable_thinking":false},"temperature":0.2}',
  }
  $ai_setting_descriptors = $ai_settings.reduce({}) |$result, $entry| {
    $result + { $entry[0] => { 'type' => 'string', 'value' => $entry[1] } }
  }

  # Additional apps use the shared app lifecycle; the AIO-owned spreed app is already installed.
  docker::nextcloud_app { 'assistant':
    ensure       => true,
    compose_name => 'nextcloud-aio',
  }

  # Keep provider configuration separate from the two native sensitive app values below.
  docker::nextcloud_app { 'integration_openai':
    ensure       => true,
    compose_name => 'nextcloud-aio',
    settings     => $ai_setting_descriptors,
  }

  # The same secret lookup is used on Spark; protect both the OCC argument and the decrypted details comparison.
  $ai_api_key = lookup('profile::nextcloud_ai::api_key', Sensitive[String])
  $api_value = $ai_api_key.unwrap
  $value_argument = "--value=${api_value}"
  $ai_api_key_argument = Sensitive($value_argument)
  ['api_key', 'stt_api_key'].each |$config_key| {
    # Correct an equal existing value when its storage type or native lazy/sensitive flags differ.
    $details_json = stdlib::to_json({
      'app'       => 'integration_openai',
      'key'       => $config_key,
      'value'     => $api_value,
      'type'      => 'string',
      'lazy'      => true,
      'sensitive' => true,
    })
    $expected_details = Sensitive($details_json)
    docker::nextcloud_occ { "nextcloud_ai_${config_key}":
      compose_name => 'nextcloud-aio',
      command      => [
        'config:app:set', 'integration_openai', $config_key,
        '--type=string', '--sensitive', '--lazy', $ai_api_key_argument,
      ],
      unless       => ['config:app:get', 'integration_openai', $config_key, '--details'],
      unless_json  => $expected_details,
      require      => Docker::Nextcloud_app['integration_openai'],
    }
  }

  # Keep the language and reporting instruction in consumer data; the README supplies a suggested Dutch prompt.
  $talk_summary_prompt = lookup('profile::nextcloud_ai::talk_summary_prompt', String[1])
  $talk_settings = {
    'call_recording_transcription'  => 'yes',
    'call_recording_summary'        => 'yes',
    'call_recording_summary_prompt' => $talk_summary_prompt,
  }
  $talk_settings.each |$config_key, $config_value| {
    docker::nextcloud_occ { "nextcloud_ai_talk_${config_key}":
      compose_name => 'nextcloud-aio',
      command      => [
        'config:app:set', 'spreed', $config_key,
        '--type=string', "--value=${config_value}",
      ],
      unless       => ['config:app:get', 'spreed', $config_key],
      unless_json  => stdlib::to_json($config_value),
      require      => [
        Docker::Nextcloud_app['integration_openai'],
        Docker::Nextcloud_occ['nextcloud_ai_api_key', 'nextcloud_ai_stt_api_key'],
      ],
    }
  }

  # In AI administration select integration_openai-audio2text for core:audio2text and integration_openai-text2text for core:text2text.
  # Preserve other provider preferences; enable a previously disabled task type explicitly instead of replacing preference JSON.

  # Register a path-style endpoint, preserving an explicit false option and fractional connection timeout.
  # Opt in to read-only HeadBucket monitoring; provision its permission and a host curl with certificate output.
  docker::nextcloud_s3 { 'server1':
    compose_name         => 'nextcloud-aio',
    bucket               => 'nextcloud-01',
    hostname             => 's3.example.org',
    key                  => 'replace-with-first-access-key',
    secret               => lookup('examples::docker::secret', Sensitive[String]),
    connect_timeout      => 4.2,
    monitoring_enable    => true,
    port                 => 8443,
    use_path_style       => true,
    verify_bucket_exists => false,
  }

  # Register an Amazon store independently; Nextcloud supplies defaults for all unspecified options.
  docker::nextcloud_s3 { 'server2':
    compose_name                => 'nextcloud-aio',
    bucket                      => 'nextcloud-02',
    region                      => 'eu-central-1',
    key                         => lookup('examples::docker::key', Sensitive[String]),
    secret                      => lookup('examples::docker::secret', Sensitive[String]),
    monitoring_enable           => true,
    monitoring_interval         => 600,
    monitoring_response_warning => 1.5,
  }
}

# Use a dedicated host or VM for trusted builds: the Runner manager's Docker socket grants host-level access.
node 'gitlab-runner.example.org' {
  class { 'basic_settings':
    docker_enable => true,
    ip_forwarding => true,
  }

  # Install Docker after basic_settings prepares its APT source and systemd targets.
  class { 'docker':
    require => Class['basic_settings'],
  }

  # Create the runner in GitLab first; this protected lookup must return its authentication token as Sensitive[String].
  # For encrypted Hiera returning a String, set lookup_options with convert_to: Sensitive for this profile key.
  # Configure tags, protected access and untagged-job acceptance in GitLab when creating or editing the runner.
  # For an internal GitLab, change runner_url and set runner_ip to its IPv4/IPv6 address; see the parameter's network requirements.
  docker::gitlab_runner { 'gitlab-runner':
    auto_register      => true,
    image_tag          => 'latest',
    runner_description => 'docker-runner',
    runner_token       => lookup('profile::gitlab_runner::runner_token', Sensitive[String]),
    runner_url         => 'https://gitlab.com/',
    require            => Class['docker'],
  }

  # After successful registration, remove runner_token and its mandatory lookup; Puppet removes only the bootstrap copy.
  # Before relying on the runner, test checkout, a job with an explicit image and artifact upload on an isolated Linux host.
  # Verify actual manager/job/helper mounts, TLS and cache separately, then repeat Puppet, noop, replacement and reboot checks.
  # Pause and drain jobs before maintenance; follow docker::gitlab_runner's recovery and removal guidance before deleting state.
}

# Minimal vLLM declaration; use nvidia_dgx_spark.pp for the complete host, model tuning and TLS routing scenario.
# Supply Docker and NVIDIA APT sources and matching kernel headers before applying this Ubuntu 24.04 ARM64 node.
node 'vllm.example.org' {
  include basic_settings::systemd

  class { 'nvidia':
    pinning => lookup('profile::nextcloud_ai::driver_branch', Integer[1]),
  }

  # Declare the driver first so Docker installs and registers the NVIDIA Container Toolkit.
  class { 'docker': }

  # Supply tested official vllm/vllm-openai tags, model commits and GPU arguments from deployment data.
  # Verify ARM64 availability, the vllm serve entrypoint and real text/audio requests before deployment.
  docker::vllm { 'nextcloud-ai':
    api_key               => lookup('profile::nextcloud_ai::api_key', Sensitive[String]),
    llm_image_tag         => lookup('profile::nextcloud_ai::llm_image_tag', String[1]),
    llm_model             => 'Qwen/Qwen3-14B',
    llm_served_model_name => 'nextcloud-verslag',
    stt_image_tag         => lookup('profile::nextcloud_ai::stt_image_tag', String[1]),
    stt_model             => 'openai/whisper-large-v3-turbo',
    stt_served_model_name => 'whisper-1',
    llm_arguments         => lookup('profile::nextcloud_ai::llm_arguments', Array[String[1]]),
    stt_arguments         => lookup('profile::nextcloud_ai::stt_arguments', Array[String[1]]),
  }
}
