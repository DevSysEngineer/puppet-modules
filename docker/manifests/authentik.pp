# @summary Deploys the bundled Authentik Docker Compose stack.
#
# This class deploys the module-shipped `docker/files/authentik.yaml` Compose
# file. Declare `docker` before using it. When `server_name` is set, declare
# `nginx` as well so `docker::compose_proxy` can add the reverse proxy;
# otherwise the class declares `docker::compose` directly.
#
# @example Deploy Authentik with generated `.env` content
#   class { 'docker': }
#
#   class { 'docker::authentik':
#     pg_pass     => Sensitive('change-me'),
#     secret_key  => Sensitive('change-me'),
#   }
#
# @example Deploy Authentik behind Nginx
#   class { 'docker': }
#   class { 'nginx': }
#
#   class { 'docker::authentik':
#     pg_pass             => Sensitive('change-me'),
#     secret_key          => Sensitive('change-me'),
#     server_name         => 'auth.example.org',
#     ssl_certificate     => '/etc/letsencrypt/live/auth.example.org/fullchain.pem',
#     ssl_certificate_key => '/etc/letsencrypt/live/auth.example.org/privkey.pem',
#   }
#
# @param pg_pass
#   PostgreSQL password written as `PG_PASS` in the generated `.env` file.
#
# @param secret_key
#   Secret key written as `AUTHENTIK_SECRET_KEY` in the generated `.env` file.
#
# @param ensure
#   Controls whether the Authentik Compose project directory and service are
#   present or absent.
#
# @param monitoring_detail_limit
#   Maximum number of diagnostic characters emitted before the Compose monitoring `Interpretation:` section.
#
# @param monitoring_expected_exited
#   Container names that are allowed to be exited without making the stack
#   critical, such as one-shot migration containers.
#
# @param monitoring_health_required
#   Container names that must have a healthy Docker health state.
#
# @param monitoring_interval
#   Monitoring interval in seconds for the Compose stack check.
#
# @param monitoring_orphan_critical
#   Treats orphaned Compose containers as critical when `true`.
#
# @param monitoring_profiles
#   Compose profiles passed to the monitoring check.
#
# @param monitoring_starting_grace
#   Grace period in seconds before starting containers are considered a problem.
#
# @param monitoring_timeout
#   Timeout in seconds for the Compose stack monitoring check.
#
# @param port
#   Local Authentik upstream port used by Nginx when `server_name` is set. The
#   default `9443` matches the bundled Compose HTTPS listener and is also written
#   as `COMPOSE_PORT_HTTPS`.
#
# @param scheme
#   Upstream scheme used by Nginx when `server_name` is set. The default is
#   `https`, so local proxy traffic is encrypted.
#
# @param server_name
#   Optional public Nginx `server_name`. When unset, only `docker::compose` is
#   declared.
#
# @param ssl_certificate
#   Public TLS certificate path for the generated Nginx vhost.
#
# @param ssl_certificate_key
#   Public TLS private key path for the generated Nginx vhost.
#
# @param ssl_certificate_trusted
#   Optional trusted certificate path for public OCSP configuration.
#
# @param ssl_verify
#   Verifies the Authentik upstream certificate when proxying over HTTPS. The
#   default is `false` because the bundled stack exposes local HTTPS on `9443`
#   with an application-managed certificate.
#
# @param tag
#   Docker image tag written as `AUTHENTIK_TAG`.
#
# @param target
#   `basic_settings::systemd` target suffix that should bind to the generated
#   Compose service. The default is `services`.
#
# @api public
class docker::authentik (
  Sensitive[String]                             $pg_pass,
  Sensitive[String]                             $secret_key,
  Enum['present','absent']                      $ensure                      = present,
  Integer                                       $monitoring_detail_limit     = 6000,
  Array[Pattern[/\A[A-Za-z0-9_.-]+\z/]]         $monitoring_expected_exited  = [],
  Array[Pattern[/\A[A-Za-z0-9_.-]+\z/]]         $monitoring_health_required  = [],
  Integer                                       $monitoring_interval         = 300,
  Boolean                                       $monitoring_orphan_critical  = false,
  Array[Pattern[/\A[A-Za-z0-9_.-]+\z/]]         $monitoring_profiles         = [],
  Integer                                       $monitoring_starting_grace   = 300,
  Integer                                       $monitoring_timeout          = 60,
  Integer[1, 65535]                             $port                        = 9443,
  Enum['http','https']                          $scheme                      = 'https',
  Optional[String]                              $server_name                 = undef,
  Optional[String]                              $ssl_certificate             = undef,
  Optional[String]                              $ssl_certificate_key         = undef,
  Optional[String]                              $ssl_certificate_trusted     = undef,
  Boolean                                       $ssl_verify                  = false,
  String                                        $tag                         = '2026.2.2',
  String                                        $target                      = 'services'
) {
  # Generate .env content for the Compose stack based on the provided parameters.
  $env_content = Sensitive.new(template('docker/authentik.env'))

  # Use the proxy wrapper only when a public Nginx vhost is requested.
  if ($server_name != undef) {
    docker::compose_proxy { 'authentik':
      ensure                     => $ensure,
      env_content                => $env_content,
      compose_source             => 'puppet:///modules/docker/authentik.yaml',
      monitoring_detail_limit    => $monitoring_detail_limit,
      monitoring_expected_exited => $monitoring_expected_exited,
      monitoring_health_required => $monitoring_health_required,
      monitoring_interval        => $monitoring_interval,
      monitoring_orphan_critical => $monitoring_orphan_critical,
      monitoring_profiles        => $monitoring_profiles,
      monitoring_starting_grace  => $monitoring_starting_grace,
      monitoring_timeout         => $monitoring_timeout,
      proxy_port                 => $port,
      proxy_scheme               => $scheme,
      proxy_ssl_verify           => $ssl_verify,
      server_name                => $server_name,
      ssl_certificate            => $ssl_certificate,
      ssl_certificate_key        => $ssl_certificate_key,
      ssl_certificate_trusted    => $ssl_certificate_trusted,
      target                     => $target,
    }
  } else {
    docker::compose { 'authentik':
      ensure                     => $ensure,
      compose_source             => 'puppet:///modules/docker/authentik.yaml',
      env_content                => $env_content,
      monitoring_detail_limit    => $monitoring_detail_limit,
      monitoring_expected_exited => $monitoring_expected_exited,
      monitoring_health_required => $monitoring_health_required,
      monitoring_interval        => $monitoring_interval,
      monitoring_orphan_critical => $monitoring_orphan_critical,
      monitoring_profiles        => $monitoring_profiles,
      monitoring_starting_grace  => $monitoring_starting_grace,
      monitoring_timeout         => $monitoring_timeout,
      target                     => $target,
      require                    => Class['docker'],
    }
  }
}
