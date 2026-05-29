# @summary Deploys and monitors one Docker Compose project as a systemd service.
#
# This defined type creates a root-only project directory under `/opt/docker`,
# manages optional `.env` content, syncs and validates a Compose file from an
# HTTPS, local file, or Puppet file-server source, and creates a
# `docker-compose-<title>.service` when the shared systemd wrapper is available.
# It also registers a stack-level monitoring check so container health can be
# evaluated separately from the orchestration unit.
#
# @example Deploy a Compose stack from a Puppet file source
#   docker::compose { 'example':
#     compose_source => 'puppet:///modules/profile/example/docker-compose.yml',
#   }
#
# @example Deploy a stack with sensitive environment content
#   docker::compose { 'example':
#     compose_source => 'file:///srv/puppet/example/docker-compose.yml',
#     env_content    => Sensitive("COMPOSE_PROJECT_NAME=example\n"),
#   }
#
# @param compose_checksum
#   Optional SHA256 checksum for the Compose file. This is most useful for HTTPS
#   sources where unexpected upstream changes should fail the Puppet run.
#
# @param compose_source
#   Compose file source. Must start with `https://`, `file:///`, or
#   `puppet:///` when `ensure` is `present`.
#
# @param ensure
#   Controls whether the Compose project directory and service are present or
#   absent.
#
# @param env_content
#   Optional `.env` file content. Strings are wrapped in `Sensitive`; explicit
#   `Sensitive[String]` values are passed through.
#
# @param env_source
#   Optional Puppet-compatible source for the `.env` file. When set, it takes
#   precedence over `env_content` and must start with `https://`, `file:///`, or
#   `puppet:///`.
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
# @param target
#   `basic_settings::systemd` target suffix that should bind to the generated
#   Compose service. The default is `services`.
#
# @api public
define docker::compose (
  Optional[Pattern[/\A[0-9a-fA-F]{64}\z/]]      $compose_checksum            = undef,
  Optional[String]                              $compose_source              = undef,
  Enum['present','absent']                      $ensure                      = present,
  Optional[Variant[String, Sensitive[String]]]  $env_content                 = undef,
  Optional[String]                              $env_source                  = undef,
  Integer                                       $monitoring_detail_limit     = 6000,
  Array[Pattern[/\A[A-Za-z0-9_.-]+\z/]]         $monitoring_expected_exited  = [],
  Array[Pattern[/\A[A-Za-z0-9_.-]+\z/]]         $monitoring_health_required  = [],
  Integer                                       $monitoring_interval         = 300,
  Boolean                                       $monitoring_orphan_critical  = false,
  Array[Pattern[/\A[A-Za-z0-9_.-]+\z/]]         $monitoring_profiles         = [],
  Integer                                       $monitoring_starting_grace   = 300,
  Integer                                       $monitoring_timeout          = 60,
  String                                        $target                      = 'services'
) {
  # Validate the compose name to avoid issues with file paths and systemd unit names.
  if ($name =~ /\A[a-zA-Z0-9_.-]+\z/) {
    # Set up variables for file paths and service names based on the title of the defined resource.
    $app_dir = "/opt/docker/${name}"
    $compose_file = "${app_dir}/docker-compose.yml"
    $env_file = "${app_dir}/.env"
    $service_name = "docker-compose-${name}"
    $daemon_reload = "docker_compose_systemd_daemon_reload_${name}"

    # Check if ensure is present to determine if the compose stack should be deployed or removed.
    if ($ensure == present) {
      if ($compose_source != undef) {
        # Only support https, local file, and Puppet file-server sources so Compose content is not fetched over plain HTTP.
        if ($compose_source =~ /(?i:\A(?:https:\/\/|file:\/\/\/|puppet:\/\/\/))/) {
          # Determine the content of the environment file based on the provided parameters.
          if ($env_source == undef) {
            case $env_content {
              String: {
                $env_file_content = Sensitive.new($env_content)
              }
              default: {
                $env_file_content = $env_content
              }
            }
          } else {
            if ($env_source =~ /(?i:\A(?:https:\/\/|file:\/\/\/|puppet:\/\/\/))/) {
              $env_file_content = undef
            } else {
              fail('docker::compose env_source must start with https://, file:///, or puppet:///')
            }
          }

          # Normalize the compose checksum to lowercase if provided, otherwise leave it as undef.
          $compose_checksum_value = $compose_checksum ? {
            undef   => undef,
            default => $compose_checksum.downcase(),
          }

          # Check if monitoring is enabled to determine if the compose service should be configured with failure monitoring for integration with the monitoring stack.
          $monitoring_enable = defined(Class['basic_settings::monitoring'])
          if ($monitoring_enable) {
            $monitoring_package = $basic_settings::monitoring::package
            $unit_failure = {
              'OnFailure' => 'notify-failed@%i.service',
            }
          } else {
            $monitoring_package = 'none'
            $unit_failure = {}
          }

          # Check if docker-compose-plugin package is not defined
          if (!defined(Package['docker-compose-plugin'])) {
            package { 'docker-compose-plugin':
              ensure          => installed,
              install_options => ['--no-install-recommends', '--no-install-suggests'],
              require         => Package['docker'],
            }
          }

          # Check if docker directory is not defined
          if (!defined(File['/opt/docker'])) {
            file { '/opt/docker':
              ensure => directory,
              owner  => 'root',
              group  => 'root',
              mode   => '0700',
            }
          }

          # Create a directory for docker-compose
          file { $app_dir:
            ensure => directory,
            owner  => 'root',
            group  => 'root',
            mode   => '0700',
          }

          # Manage the environment file for the compose stack if either a source or content is provided.
          if ($env_source != undef or $env_content != undef) {
            file { $env_file:
              ensure  => file,
              source  => $env_source,
              content => $env_file_content,
              owner   => 'root',
              group   => 'root',
              mode    => '0600',
              require => File[$app_dir],
            }
            $env_cmd = " --env-file ${env_file}"
            $compose_require = File[$env_file]
            $env_monitoring = $env_file
          } else {
            $env_cmd = ''
            $compose_require = File[$app_dir]
            $env_monitoring = undef
          }

          # Sync and validate the compose file before it is promoted into the project directory.
          file { $compose_file:
            ensure         => file,
            source         => $compose_source,
            checksum       => 'sha256',
            checksum_value => $compose_checksum_value,
            validate_cmd   => "/usr/bin/docker compose --project-directory ${app_dir}${env_cmd} --file % config --quiet",
            owner          => 'root',
            group          => 'root',
            mode           => '0600',
            require        => [$compose_require, Package['docker-compose-plugin']],
          }

          if (defined(Class['basic_settings::systemd'])) {
            # Determine the service subscription based
            if ($env_source != undef or $env_content != undef) {
              $service_require = [Package['docker', 'docker-compose-plugin'], File[$compose_file], File[$env_file]]
              $service_subscribe = File[$compose_file, $env_file]
            } else {
              $service_require = [Package['docker', 'docker-compose-plugin'], File[$compose_file]]
              $service_subscribe = File[$compose_file]
            }

            # Reload systemd after the generated compose service unit changes.
            exec { $daemon_reload:
              command     => '/usr/bin/systemctl daemon-reload',
              refreshonly => true,
              require     => Package['systemd'],
            }

            # Manage the compose stack as a root-run orchestration service for the Docker daemon.
            basic_settings::systemd_service { $service_name:
              description        => "Docker Compose stack ${name}",
              monitoring_enable  => $monitoring_enable,
              monitoring_package => $monitoring_package,
              service_subscribe  => $service_subscribe,
              service            => {
                'ExecStart'               => "/usr/bin/docker compose --project-name ${name} --project-directory ${app_dir}${env_cmd} --file ${compose_file} up --detach --remove-orphans",
                'ExecStop'                => "/usr/bin/docker compose --project-name ${name} --project-directory ${app_dir}${env_cmd} --file ${compose_file} down --remove-orphans",
                'LockPersonality'         => 'true',
                'MemoryDenyWriteExecute'  => 'true',
                'NoNewPrivileges'         => 'true',
                'PrivateDevices'          => 'true',
                'PrivateTmp'              => 'true',
                'ProtectClock'            => 'true',
                'ProtectHostname'         => 'true',
                'ProtectControlGroups'    => 'true',
                'ProtectKernelLogs'       => 'true',
                'ProtectKernelModules'    => 'true',
                'ProtectKernelTunables'   => 'true',
                'ProtectSystem'           => 'full',
                'RemainAfterExit'         => 'yes',
                'RestrictSUIDSGID'        => 'true',
                'SystemCallArchitectures' => 'native',
                'TimeoutStartSec'         => '300',
                'TimeoutStopSec'          => '300',
                'Type'                    => 'oneshot',
                'UMask'                   => '0077',
                'User'                    => 'root',
                'WorkingDirectory'        => $app_dir,
              },
              unit               => stdlib::merge($unit_failure, {
                  'After'    => ['docker.service', 'network-online.target'],
                  'Requires' => 'docker.service',
                  'Wants'    => 'network-online.target',
              }),
              daemon_reload      => $daemon_reload,
              enable             => false,
              require            => $service_require,
            }

            # If the target is not 'services', create a dependency on the specified target to allow for flexible ordering of the compose stack in relation to other systemd services and targets.
            basic_settings::systemd_drop_in { "${service_name}_dependency":
              target_unit   => "${basic_settings::systemd::cluster_id}-${target}.target",
              unit          => {
                'BindsTo' => "${service_name}.service",
              },
              daemon_reload => $daemon_reload,
              require       => Basic_settings::Systemd_target["${basic_settings::systemd::cluster_id}-${target}"],
            }
          }

          # Monitor the rendered Compose stack separately from the orchestration service unit.
          docker::compose_monitoring { $name:
            project_directory => $app_dir,
            compose_files     => [$compose_file],
            detail_limit      => $monitoring_detail_limit,
            env_file          => $env_monitoring,
            expected_exited   => $monitoring_expected_exited,
            health_required   => $monitoring_health_required,
            interval          => $monitoring_interval,
            orphan_critical   => $monitoring_orphan_critical,
            package           => $monitoring_package,
            profiles          => $monitoring_profiles,
            project_name      => $name,
            starting_grace    => $monitoring_starting_grace,
            timeout           => $monitoring_timeout,
            require           => File[$compose_file],
          }
        } else {
          fail('docker::compose compose_source must start with https://, file:///, or puppet:///')
        }
      } else {
        fail('docker::compose requires compose_source when ensure is present.')
      }
    } else {
      # Remove the directory for docker-compose
      file { $app_dir:
        ensure => absent,
        force  => true,
      }
    }
  } else {
    fail('docker::compose titles may only contain letters, numbers, dots, underscores, and hyphens.')
  }
}
