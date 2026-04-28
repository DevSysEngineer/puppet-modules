define docker::compose_monitoring (
  Pattern[/\A\/[A-Za-z0-9._\/-]+\z/]            $project_directory,
  Array[String]                                 $compose_files     = [],
  Integer                                       $detail_limit      = 30,
  Optional[String]                              $env_file          = undef,
  Enum['present','absent']                      $ensure            = present,
  Array[Pattern[/\A[A-Za-z0-9_.-]+\z/]]         $expected_exited   = [],
  Array[Pattern[/\A[A-Za-z0-9_.-]+\z/]]         $health_required   = [],
  Integer                                       $interval          = 300,
  Boolean                                       $orphan_critical   = false,
  Optional[String]                              $package           = undef,
  Array[Pattern[/\A[A-Za-z0-9_.-]+\z/]]         $profiles          = [],
  Optional[Pattern[/\A[A-Za-z0-9_.-]+\z/]]      $project_name      = undef,
  Integer                                       $starting_grace    = 300,
  Integer                                       $timeout           = 60,
) {
  if ($name =~ /\A[a-zA-Z0-9_.-]+\z/) {
    # Set command arguments for the stack-specific service check.
    $project_name_arg = $project_name ? {
      undef   => '',
      default => " -p ${project_name}",
    }
    $env_file_arg = $env_file ? {
      undef   => '',
      default => " -e ${env_file}",
    }
    $compose_files_arg = length($compose_files) ? {
      0       => '',
      default => " -f ${join($compose_files, ' -f ')}",
    }
    $expected_exited_arg = length($expected_exited) ? {
      0       => '',
      default => " -x ${join($expected_exited, ',')}",
    }
    $health_required_arg = length($health_required) ? {
      0       => '',
      default => " -H ${join($health_required, ',')}",
    }
    $profiles_arg = length($profiles) ? {
      0       => '',
      default => " -P ${join($profiles, ',')}",
    }
    $orphan_critical_arg = $orphan_critical ? {
      true    => ' -O',
      default => '',
    }

    # Join the command arguments together.
    $cmd = join([
        "-d ${project_directory}",
        $project_name_arg,
        $compose_files_arg,
        $env_file_arg,
        " -n ${name} -g ${starting_grace} -l ${detail_limit}",
        $expected_exited_arg,
        $health_required_arg,
        $profiles_arg,
        $orphan_critical_arg,
    ], '')

    # The stack check parses Docker's JSON output with jq.
    if (!defined(Package['jq'])) {
      package { 'jq':
        ensure          => installed,
        install_options => ['--no-install-recommends', '--no-install-suggests'],
      }
    }

    # Create the monitoring resource for this stack.
    basic_settings::monitoring_custom { "docker_compose_${name}":
      ensure   => $ensure,
      source   => 'puppet:///modules/docker/check_compose',
      cmd      => $cmd,
      friendly => "Docker Compose ${name}",
      interval => $interval,
      package  => $package,
      timeout  => $timeout,
      require  => Package['jq'],
    }
  } else {
    fail('docker::compose_monitoring titles may only contain letters, numbers, dots, underscores, and hyphens.')
  }
}
