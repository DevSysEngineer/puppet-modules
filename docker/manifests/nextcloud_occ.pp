# @summary Runs OCC commands and guards in Nextcloud AIO.
#
# Declare docker first and provide Docker::Compose[$compose_name], Docker::Compose_proxy[$compose_name], or
# Docker::Nextcloud[$compose_name]. The owner must be visible when this resource is evaluated; wrappers must provide
# Docker::Compose[$compose_name] in the final catalog. Missing owners fail compilation before declaring OCC commands.
# OCC waits for the visible owner; docker::compose_exec selects the exact nextcloud-aio-nextcloud container name,
# matching https://github.com/nextcloud/all-in-one#how-to-run-occ-commands. AIO creates this sibling itself without
# Compose service or oneoff labels. The fixed name means only one AIO instance can run on this Docker daemon.
# Commands run as www-data with php occ, resolved inside the selected container.
# JSON comparisons add --output=json automatically to the command being compared. An existing --output=json is kept.
# Providing unless_json without unless reuses command as the read-only guard, including during noop.
# A read-only onlyif guard requires successful OCC status JSON with installed set to boolean true. A missing/stopped
# container, incomplete installation or unreadable status skips the mutation; each Puppet run checks again.
# Installation and unless guards also run during noop, without executing the mutation.
# No OCC helper scripts or request files are installed.
# Commands and guards are Sensitive and output logging is disabled. Arguments remain visible through host/container
# process inspection. OCC config:system:set has no --sensitive option.
# Protect process access and Nextcloud logs/profiler.
#
# @example Leave maintenance mode when Nextcloud reports it active
#   docker::nextcloud_occ { 'maintenance-off':
#     command      => ['maintenance:mode', '--off'],
#     compose_name => 'nextcloud-aio',
#     unless       => ['status', '--exit-code'],
#   }
#
# @example Report a change while the read-only status shows maintenance mode
#   docker::nextcloud_occ { 'maintenance-detected':
#     command      => ['status'],
#     compose_name => 'nextcloud-aio',
#     command_json => 'true',
#     json_path    => ['maintenance'],
#     unless_json  => 'false',
#   }
#
# @param command
#   OCC command and arguments without PHP or the OCC path. Use Sensitive[String] for arguments containing credentials.
#   Must be read-only when reused as the guard by unless_json without an explicit unless.
#
# @param compose_name
#   Shared title of the deployment owner and its managed docker::compose resource, used for ordering only.
#   AIO owns the independently named nextcloud-aio-nextcloud container on the same local Docker daemon.
#
# @param command_json
#   Optional expected JSON from command, optionally Sensitive. Undef retains native exit-code behavior. Otherwise
#   execution succeeds only when the selected JSON value matches; invalid JSON, missing keys or a mismatch fail.
#   A read-only command can thereby report a change only for an actionable value, notifying its normal Puppet targets.
#   Values are JSON documents: 'true' is a boolean and '"warning"' is a string. Output formatting is automatic.
#
# @param json_path
#   Optional object-key path selected before comparing command_json or unless_json. Undef compares the entire JSON
#   value. Requires at least one expected JSON value; native commands and guards do not use this path.
#
# @param json_returns
#   Accepted OCC exit codes before JSON comparison, default [0]. A matching JSON value is also required; accepting
#   a nonzero exit code alone never reports a change. Does not alter the installation or native OCC guards.
#
# @param refreshonly
#   Defaults to false. True executes only on a refresh event, still subject to the installation and unless guards.
#   Multiple notifications in one transaction are combined by Puppet.
#
# @param timeout
#   Maximum seconds for each command or guard, default 120. A Docker client timeout can leave PHP running.
#
# @param unless
#   Optional read-only OCC command. Exit 0 skips the mutation; other exit codes allow it only after installation.
#   Default undef reuses command when unless_json is set, otherwise adds no application guard. Guards run during noop.
#
# @param unless_json
#   Optional expected JSON from unless, optionally Sensitive. Undef compares only exit status; otherwise parsed JSON
#   values are compared with object key ordering ignored and array order preserved. Uses command when unless is unset.
#   Has the same JSON representation, automatic output formatting and optional json_path as command_json.
#
# @api public
define docker::nextcloud_occ (
  Array[Variant[String, Sensitive[String]], 1]           $command,
  Pattern[/\A[A-Za-z0-9_.-]+\z/]                         $compose_name,
  Optional[Variant[String, Sensitive[String]]]           $command_json = undef,
  Optional[Array[String[1], 1]]                          $json_path    = undef,
  Array[Integer[0, 255], 1]                              $json_returns = [0],
  Boolean                                                $refreshonly  = false,
  Integer[1]                                             $timeout      = 120,
  Optional[Array[Variant[String, Sensitive[String]], 1]] $unless       = undef,
  Optional[Variant[String, Sensitive[String]]]           $unless_json  = undef,
) {
  # Resolve the visible stack owner without assuming its wrapper body has already been evaluated.
  $compose_defined = defined(Docker::Compose[$compose_name])
  $compose_proxy_defined = defined(Docker::Compose_proxy[$compose_name])

  # The Nextcloud wrapper is optional; direct Compose deployments also work while that type is unavailable.
  $nextcloud_defined = defined('docker::nextcloud') and defined(Docker::Nextcloud[$compose_name])
  if ($compose_defined) {
    # Order OCC operations after the existing Compose stack.
    $compose_require = Docker::Compose[$compose_name]
    $compose_contract_fail_text = undef
  } elsif ($compose_proxy_defined) {
    # Order OCC operations after the existing Compose proxy wrapper.
    $compose_require = Docker::Compose_proxy[$compose_name]
    $compose_contract_fail_text = undef
  } elsif ($nextcloud_defined) {
    # Order OCC operations after the existing Nextcloud wrapper.
    $compose_require = Docker::Nextcloud[$compose_name]
    $compose_contract_fail_text = undef
  } else {
    # Report the missing stack owner before declaring OCC execution resources.
    $compose_contract_fail_text = "docker::nextcloud_occ requires Docker::Compose[${compose_name}], Docker::Compose_proxy[${compose_name}], or Docker::Nextcloud[${compose_name}] in the catalog." # lint:ignore:140chars
  }

  # Resolve prerequisites centrally before declaring either mutations or read-only JSON checks.
  if ($compose_contract_fail_text == undef and defined(Class['docker'])) {
    # A path selects a value for comparison; it has no meaning without an expected value.
    if ($json_path == undef or $command_json != undef or $unless_json != undef) {
      # An omitted guard command reuses the declared read when the caller supplies an unchanged JSON value.
      $unless_correct = $unless_json ? {
        undef   => $unless,
        default => pick($unless, $command),
      }

      # Model installation, execution and the application guard identically, with independent comparison settings.
      $operations = {
        'onlyif'  => { 'arguments' => ['status'], 'json' => 'true', 'path' => ['installed'], 'returns' => [0] },
        'command' => { 'arguments' => $command, 'json' => $command_json, 'path' => $json_path, 'returns' => $json_returns },
        'unless'  => { 'arguments' => $unless_correct, 'json' => $unless_json, 'path' => $json_path, 'returns' => $json_returns },
      }
      $occ_prefix = ['php', 'occ', '--no-interaction', '--no-ansi']

      # Canonicalize object keys recursively while retaining JSON scalar types and array ordering.
      $compare_php = join([
        '$sort = function ($value) use (&$sort) {',
        '    if (is_object($value)) {',
        '        $fields = get_object_vars($value); ksort($fields);',
        '        return (object) array_map($sort, $fields);',
        '    }',
        '    return is_array($value) ? array_map($sort, $value) : $value;',
        '};',
        '$actual = json_decode(stream_get_contents(STDIN), false, 512, JSON_THROW_ON_ERROR);',
        '$expected = json_decode($argv[1], false, 512, JSON_THROW_ON_ERROR);',
        'foreach (json_decode($argv[2], true, 512, JSON_THROW_ON_ERROR) as $key) {',
        '    if (!is_object($actual) || !property_exists($actual, $key)) { exit(2); }',
        '    $actual = $actual->{$key};',
        '}',
        'exit(json_encode($sort($actual)) === json_encode($sort($expected)) ? 0 : 1);',
      ], "\n")

      # Build every invocation once; expected JSON determines output formatting and result handling.
      $commands_correct = $operations.reduce({}) |$result, $entry| {
        # Keep native commands separate from JSON comparisons without changing their arguments or exit semantics.
        $kind = $entry[0]
        $operation = $entry[1]
        $arguments = $operation['arguments']

        # Only an expected JSON value enables output formatting and comparison for this operation.
        $expected = $operation['json']
        if ($expected != undef) {
          # Existing callers may already request JSON; new callers only declare the value to compare.
          $arguments_correct = '--output=json' in $arguments ? {
            true    => $arguments,
            default => concat($arguments, ['--output=json']),
          }

          # Preserve Sensitive values and argument boundaries while capturing the OCC result.
          $expected_correct = $expected ? {
            Sensitive => $expected.unwrap,
            default   => $expected,
          }
          $path_json = stdlib::to_json(pick($operation['path'], []))
          $compare_shell = ['php', '-r', $compare_php, $expected_correct, $path_json].map |$argument| {
            stdlib::shell_escape($argument)
          }.join(' ')

          # Capture OCC output before comparing it so a failed command cannot be hidden by the JSON parser.
          $read_shell = concat($occ_prefix, $arguments_correct).map |$argument| {
            # Unwrap only while preparing a Sensitive command.
            $argument_correct = $argument ? {
              Sensitive => $argument.unwrap,
              default   => $argument,
            }
            stdlib::shell_escape($argument_correct)
          }.join(' ')

          # Capture and validate OCC's exit code before evaluating JSON, including the strict installation status.
          $status_tests_shell = $operation['returns'].map |$status| {
            # Statuses are typed integers; escape them at the shell boundary like other dynamic arguments.
            $status_shell = stdlib::shell_escape(String($status))
            "[ \"\$STATUS\" -eq ${status_shell} ]"
          }.join(' || ')
          $invocation = ['/bin/sh', '-c', Sensitive(join([
            "CURRENT=\$(${read_shell})",
            'STATUS=$?',
            "${status_tests_shell} || exit 1",
            "printf '%s' \"\$CURRENT\" | ${compare_shell}",
          ], "\n"))]
        } else {
          # Default callers keep the same OCC prefix and native exit-code semantics.
          $invocation = $arguments ? {
            undef   => undef,
            default => concat($occ_prefix, $arguments),
          }
        }
        $result + { $kind => $invocation }
      }

      # All OCC execution, including refresh events and read-only detectors, retains the installation guard.
      docker::compose_exec { "docker_nextcloud_occ_${title}":
        command        => $commands_correct['command'],
        compose_name   => $compose_name,
        container_name => 'nextcloud-aio-nextcloud',
        onlyif         => $commands_correct['onlyif'],
        refreshonly    => $refreshonly,
        timeout        => $timeout,
        unless         => $commands_correct['unless'],
        user           => 'www-data',
        require        => $compose_require,
      }
    } else {
      fail('docker::nextcloud_occ json_path requires command_json or unless_json.')
    }
  } else {
    # Report the missing deployment first, or the required runtime class when the deployment is visible.
    $fail_text = pick($compose_contract_fail_text, 'docker::nextcloud_occ requires the docker class before its declaration.')
    fail($fail_text)
  }
}
