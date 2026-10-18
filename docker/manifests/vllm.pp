# @summary Deploys text and/or speech-to-text vLLM servers in one ARM64 Compose project, with optional HTTPS access.
#
# Declare docker and basic_settings::systemd first. The host owns its NVIDIA driver and Container Toolkit;
# this resource requires a working NVIDIA runtime and images supporting `vllm serve` on linux/arm64.
# An image enables its service; undef disables it. Present stacks need at least one enabled service and its model
# settings.
# APIs listen only on host loopback. Set server_name, TLS certificates and whitelist_ips to publish the enabled APIs.
# The proxy uses docker::compose_proxy. Declare nginx before selecting it.
# DNS, certificates and host firewall rules remain consumer responsibilities.
# Containers run as root to use their image's default caches, without privileged mode or the Docker socket.
# vLLM downloads missing revisions into hf-cache; each enabled service also gets its own engine-cache directory.
# Existing caches survive disabling a service and container replacement. Plan storage and download access separately.
# No Nextcloud configuration, model download exec, host worker or driver installation is managed here.
#
# @example Deploy only a text model on a host with Docker, systemd targets and the NVIDIA runtime already configured
#   docker::vllm { 'text-ai':
#     api_key               => lookup('profile::nextcloud_ai::api_key', Sensitive[String]),
#     llm_image             => lookup('profile::nextcloud_ai::llm_image', String[1]),
#     llm_model             => 'Qwen/Qwen3-14B',
#     llm_served_model_name => 'nextcloud-verslag',
#     llm_arguments         => ['--gpu-memory-utilization', '0.45'],
#   }
#
# @example Deploy only transcription with the same host prerequisites
#   docker::vllm { 'speech-ai':
#     api_key               => lookup('profile::nextcloud_ai::api_key', Sensitive[String]),
#     stt_image             => lookup('profile::nextcloud_ai::stt_image', String[1]),
#     stt_model             => 'openai/whisper-large-v3-turbo',
#     stt_served_model_name => 'whisper-1',
#     stt_arguments         => ['--gpu-memory-utilization', '0.10'],
#   }
#
# @param api_key
#   Shared Bearer token for enabled APIs, supplied as Sensitive from the consumer's secret store.
#   Must contain exactly 64 hexadecimal characters. Written only to the private Compose environment file.
#
# @param client_max_body_size
#   Nginx upload limit when server_name is set. Default 1100m allows the example's audio uploads.
#
# @param engine_ready_timeout Seconds allowed for each vLLM engine to initialize; must be below startup_timeout.
#
# @param ensure
#   Present prepares the project without forcing a running state. Start it explicitly after provisioning.
#   File changes refresh only an active stack; the shared services target owns boot startup.
#   Absent deletes the project directory and all caches without stopping containers first.
#   Stop the stack and preserve required data before removal; central management removes undeclared units and vhosts.
#
# @param llm_arguments
#   Additional text-server argv elements, including revision, dtype, context and memory settings. Ignored without
#   llm_image.
#   Do not include secrets or redefine host, port, model, served-model-name or api-key, including abbreviations.
#   Configuration-file options are reserved because they can replace authentication settings.
#   Cache-location overrides change persistent-cache behavior and remain the consumer's responsibility.
#
# @param llm_image Text server image reference. Undef disables LLM. Pin a tested ARM64 image digest in deployment data.
#
# @param llm_model Hugging Face text model ID. Required with llm_image; vLLM downloads missing files itself.
#
# @param llm_port Loopback host port for text. Must differ from stt_port when both services are enabled.
#
# @param llm_served_model_name Stable text API model name. Required with llm_image; ignored when LLM is disabled.
#
# @param proxy_timeout Nginx read and send timeout in seconds when server_name is set. Default 3600.
#
# @param pull Stack-wide image pull policy passed unchanged to docker::compose.
#
# @param server_name
#   Optional server name passed to docker::compose_proxy. Undef creates no proxy and requires no nginx class.
#   When set, requires nginx and both TLS paths; publishes only enabled /llm/v1/ and /stt/v1/ routes over HTTPS.
#   Other application paths return 404. An empty whitelist_ips denies all clients.
#
# @param shm_size Shared memory size per container in Compose byte-value syntax, for example 8gb.
#
# @param ssl_certificate Certificate-chain path used by Nginx; required with server_name. Provision the file separately.
#
# @param ssl_certificate_key Private-key path used by Nginx; required with server_name. Provision the file separately.
#
# @param startup_timeout
#   Default systemd startup timeout, including image pulls and waiting for LLM health when both services are enabled.
#   Also sets healthcheck start periods and Compose monitoring startup grace. Must exceed engine_ready_timeout.
#   Size for downloads and cold starts. systemd_service can override TimeoutStartSec without changing those grace
#   periods.
#
# @param stt_arguments
#   Additional transcription argv elements, under the same restrictions as llm_arguments. Ignored without stt_image.
#
# @param stt_environment
#   Additional non-secret transcription environment strings, for example audio upload and decode limits.
#   Empty adds none; ignored without stt_image. VLLM_API_KEY and VLLM_ENGINE_READY_TIMEOUT_S are reserved.
#   HF_HOME and HF_HUB_CACHE overrides change persistent-cache behavior.
#
# @param stt_image
#   Transcription image reference. Undef disables STT. The image must support the chosen audio input formats.
#
# @param stt_model Hugging Face transcription model ID. Required with stt_image; vLLM downloads missing files itself.
#
# @param stt_port Loopback host port for transcription. Must differ from llm_port when both services are enabled.
#
# @param stt_served_model_name
#   Stable transcription API model name. Required with stt_image; ignored when STT is disabled.
#
# @param systemd_service
#   [Service] overrides passed to docker::compose, merged over the startup_timeout-derived TimeoutStartSec.
#   Other Compose defaults remain unchanged. Review lifecycle, hardening and complete directive replacements there.
#
# @param systemd_unit
#   [Unit] overrides passed unchanged to docker::compose; empty preserves its ordering and monitoring hooks.
#
# @param whitelist_ips
#   Client addresses or CIDR ranges allowed by the optional Nginx proxy. Default [] denies all remote clients.
#   Use the source address seen by Nginx. API-token authentication is still required for requests.
#
# @api public
define docker::vllm (
  Sensitive[String]                  $api_key,
  String[1]                          $client_max_body_size  = '1100m',
  Integer[1]                         $engine_ready_timeout  = 1800,
  Enum['present', 'absent']          $ensure                = 'present',
  Array[String[1]]                   $llm_arguments         = [],
  Optional[String[1]]                $llm_image             = undef,
  Optional[String[1]]                $llm_model             = undef,
  Integer[1, 65535]                  $llm_port              = 8000,
  Optional[String[1]]                $llm_served_model_name = undef,
  Integer[1]                         $proxy_timeout         = 3600,
  Enum['always', 'missing', 'never'] $pull                  = 'missing',
  Optional[String[1]]                $server_name           = undef,
  String[1]                          $shm_size              = '8gb',
  Optional[String[1]]                $ssl_certificate       = undef,
  Optional[String[1]]                $ssl_certificate_key   = undef,
  Integer[1]                         $startup_timeout       = 3600,
  Array[String[1]]                   $stt_arguments         = [],
  Hash[String[1], String]            $stt_environment       = {},
  Optional[String[1]]                $stt_image             = undef,
  Optional[String[1]]                $stt_model             = undef,
  Integer[1, 65535]                  $stt_port              = 8001,
  Optional[String[1]]                $stt_served_model_name = undef,
  Hash                               $systemd_service       = {},
  Hash                               $systemd_unit          = {},
  Array[String[1]]                   $whitelist_ips         = [],
) {
  # Docker owns shared prerequisites; a present stack also needs the target ladder and Compose daemon reload.
  if (defined(Class['docker'])) {
    # Removal follows Compose without requiring a retired credential, enabled models or proxy prerequisites.
    if ($ensure == 'present' and defined(Class['basic_settings::systemd'])) {
      # Image selection drives container rendering, monitoring, cache management and proxy routes together.
      $llm_enabled = $llm_image != undef
      $stt_enabled = $stt_image != undef
      $enabled_services = { 'llm' => $llm_enabled, 'stt' => $stt_enabled }.filter |$service, $enabled| { $enabled }.keys
      $model_settings_valid = (!$llm_enabled or ($llm_model != undef and $llm_served_model_name != undef))
        and (!$stt_enabled or ($stt_model != undef and $stt_served_model_name != undef))

      # Require a usable model configuration for each selected service.
      if (!$enabled_services.empty and $model_settings_valid) {
        # Validate only arguments of enabled services; unused service settings do not prevent switching modes.
        $active_arguments = concat($llm_enabled ? { true => $llm_arguments, default => [] },
          $stt_enabled ? { true => $stt_arguments, default => [] })
        $managed_options = ['--host', '--port', '--model', '--served-model-name', '--api-key', '--config']
        $reserved_arguments = $active_arguments.filter |$argument| {
          # vLLM accepts underscores and argparse abbreviations, as well as option=value syntax.
          $option_name = regsubst(split($argument, '=')[0], '_', '-', 'G')
          $managed_options.any |$managed_option| {
            $option_name != '--' and $managed_option[0, $option_name.length] == $option_name
          } or $argument =~ /\A-(?:p|c)(?:=|[^-]|\z)/
        }

        # Authentication remains required for every enabled API, including when no reverse proxy is selected.
        if ($api_key.unwrap =~ /\A[0-9a-fA-F]{64}\z/) {
          # A single-service deployment may reuse either host port; only simultaneous listeners need distinct ports.
          if ((!$llm_enabled or !$stt_enabled or $llm_port != $stt_port) and $startup_timeout > $engine_ready_timeout) {
            # Keep listener identity and authentication under their dedicated parameters.
            if ($reserved_arguments.empty and (!$stt_enabled
              or (!('VLLM_API_KEY' in $stt_environment) and !('VLLM_ENGINE_READY_TIMEOUT_S' in $stt_environment)))) {
              # Remote access requires the existing Nginx class and an explicitly provisioned TLS certificate pair.
              if ($server_name == undef or (defined(Class['nginx']) and $ssl_certificate != undef and $ssl_certificate_key != undef)) {
                # Manage only the enabled services' caches; old caches remain on disk until explicit project removal.
                $cache_names = concat(['hf-cache'], $enabled_services.map |$service| { "${service}-cache" })
                $cache_directories = Hash($cache_names.map |$directory| {
                  [$directory, { 'owner' => 'root', 'group' => 'root', 'mode' => '0700' }]
                })

                # Convert the timeout to the string form used by generated systemd directives.
                $startup_timeout_string = String($startup_timeout)

                # Both deployment paths share Compose content, monitoring, caches and systemd settings.
                $compose_parameters = {
                  'compose_content'            => template('docker/vllm.yaml'),
                  'env_content'                => Sensitive(template('docker/vllm.env')),
                  'monitoring_health_required' => $enabled_services,
                  'monitoring_starting_grace'  => $startup_timeout,
                  'project_directories'        => $cache_directories,
                  'pull'                       => $pull,
                  'systemd_service'            => stdlib::merge({ 'TimeoutStartSec' => $startup_timeout_string }, $systemd_service),
                  'systemd_unit'               => $systemd_unit,
                }

                # Use the shared Compose proxy for remote access, with only the selected API routes.
                if ($server_name != undef) {
                  # Keep public route names stable; the proxy owns upstream URL and directive rendering.
                  $service_ports = { 'llm' => $llm_port, 'stt' => $stt_port }
                  $api_routes = Hash($enabled_services.map |$service| {
                    ["/${service}/v1/", { 'port' => $service_ports[$service], 'uri' => '/v1/' }]
                  })

                  # Apply the consumer allowlist before the final deny rule, including non-API locations.
                  $access_directives = $whitelist_ips.map |$address| { "allow ${address};" }

                  # Forward authentication and streamed requests through the common proxy implementation.
                  docker::compose_proxy { $name:
                    *                      => $compose_parameters,
                    server_name            => $server_name,
                    http_enable            => false,
                    http3_enable           => false,
                    ssl_certificate        => $ssl_certificate,
                    ssl_certificate_key    => $ssl_certificate_key,
                    client_max_body_size   => $client_max_body_size,
                    directives             => concat($access_directives, ['deny all;']),
                    proxy_routes           => $api_routes,
                    proxy_scheme           => 'http',
                    proxy_read_timeout     => "${proxy_timeout}s",
                    proxy_websocket        => false,
                    proxy_extra_directives => [
                      'proxy_http_version 1.1;',
                      "proxy_send_timeout ${proxy_timeout}s;",
                      'proxy_buffering off;',
                      'proxy_request_buffering off;',
                      'proxy_set_header Connection "";',
                      'proxy_set_header Authorization $http_authorization;',
                    ],
                    require                => Class['docker'],
                  }
                } else {
                  # Local-only deployments use the same Compose settings without requiring Nginx.
                  docker::compose { $name:
                    *       => $compose_parameters,
                    require => Class['docker'],
                  }
                }
              } else {
                fail('docker::vllm server_name requires the nginx class, ssl_certificate and ssl_certificate_key.')
              }
            } else {
              fail('docker::vllm arguments and stt_environment must not override managed listener, model or authentication settings.')
            }
          } else {
            fail('docker::vllm requires distinct ports for simultaneous services and startup_timeout greater than engine_ready_timeout.')
          }
        } else {
          fail('docker::vllm api_key must contain exactly 64 hexadecimal characters.')
        }
      } else {
        fail('docker::vllm requires at least one image and both model and served_model_name for each enabled service.')
      }
    } elsif ($ensure == 'absent') {
      docker::compose { $name:
        ensure  => absent,
        require => Class['docker'],
      }
    } else {
      fail('docker::vllm requires basic_settings::systemd before declaring a present stack.')
    }
  } else {
    fail('docker::vllm requires the docker class before its declaration.')
  }
}
