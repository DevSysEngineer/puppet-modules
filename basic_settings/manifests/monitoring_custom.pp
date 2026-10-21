# @summary Registers a custom monitoring script with the configured monitoring backend.
#
# This defined type writes or removes a root-owned plugin script and registers it in OpenITCOCKPIT `customchecks.ini`
# when that backend is active. It centralizes plugin file permissions, scheduling metadata, and optional sudoers support
# for checks that need elevated privileges. Optional private state is managed before registration. ERB templates use
# the derived state_dir; inline content, file sources and shared-script references receive STATE_DIR at runtime.
#
# @example Register a custom OpenITCOCKPIT check
#   basic_settings::monitoring_custom { 'example':
#     template => 'profile/check_example',
#     friendly => 'Example service',
#     interval => 300,
#   }
#
# @param check
#   Plugin executable as inline text, rendered template output, or an https://, file:///, or puppet:/// source.
#   URI schemes are case-insensitive; other URI schemes are rejected. Local files use an absolute file:/// URL.
#   Source files and inline scripts include their own shebang and management comment. Mutually exclusive with
#   template and shared-script references. Undef leaves content unspecified, including during removal.
#
# @param cmd
#   Optional arguments appended after the managed script path in the generated command.
#
# @param ensure
#   Controls whether the plugin script and registration are present or absent. `absent` also removes an old script with
#   backend `none`.
#
# @param friendly
#   Human-readable check name. `undef` uses a capitalized resource title.
#
# @param interval
#   Check interval in seconds. The default is 300.
#
# @param package
#   Monitoring package override. `undef` inherits `basic_settings::monitoring` when that class is declared.
#
# @param register
#   Registers a runnable check when true. Set false to manage one shared script without creating a check for the script
#   itself.
#
# @param root_required
#   Indicates whether the check requires root privileges. When a non-root plugin owner is used by a backend, this
#   controls sudoers generation.
#
# @param script
#   Title of another monitoring_custom resource that owns the shared script; only letters, digits, underscores, dots and
#   hyphens are accepted. `undef` manages this check own script. With a title, this resource only registers arguments
#   and never creates or removes the shared file; check and template must remain undef. The owner supplies
#   its backend path and file dependency through this type.
#
# @param state
#   Manages a root-owned 0700 directory per registration under the agent state directory when true. The resource title
#   must contain only letters, digits, dots, underscores or hyphens, excluding `.` and `..`. The derived state_dir is
#   available in templates; commands without template receive it as STATE_DIR. False manages no state. Retirement
#   retains state.
#
# @param template
#   Optional module-relative ERB template name, rendered in this type's scope. Mutually exclusive with check
#   and unavailable for shared-script references. Use @state_dir for the managed directory and @template_data for
#   caller-owned inputs. Rendering occurs only while deploying an active backend's executable.
#
# @param template_data
#   Explicit caller-owned inputs for template as a hash. It is available as @template_data and defaults to an empty
#   hash. It does not replace derived values such as state_dir or become executable shell code.
#
# @param timeout
#   Check timeout in seconds. The default is 30.
#
# @api public
define basic_settings::monitoring_custom (
  Optional[String]          $check         = undef,
  Optional[String]          $cmd           = undef,
  Enum['present', 'absent'] $ensure        = present,
  Optional[String]          $friendly      = undef,
  Integer                   $interval      = 300,
  Optional[String]          $package       = undef,
  Boolean                   $register      = true,
  Boolean                   $root_required = true,
  Optional[String[1]]       $script        = undef,
  Boolean                   $state         = false,
  Optional[String[1]]       $template      = undef,
  Hash[String, Any]         $template_data = {},
  Integer                   $timeout       = 30,
) {
  # Resolve a source URL without interpreting the contents of ordinary or caller-rendered scripts.
  if ($check != undef and $check =~ /(?i:\A[a-z][a-z0-9+.-]*:\/\/)/) {
    # Sources are fetched by the agent when applying the catalog.
    $source = $check
    $content = undef
  } else {
    # Caller-rendered and literal scripts are already available during compilation.
    $source = undef
    $content = $check
  }

  # Keep valid input on the main path so validation failures stay exceptional.
  if (($check == undef or $template == undef)
    and ($script == undef or ($check == undef and $template == undef))) {
    # Validate the executable source and shared-script identifier before registering the check.
    if (($source == undef or $source =~ /(?i:\A(?:puppet:\/\/\/|file:\/\/\/|https:\/\/))/)
      and ($script == undef or $script =~ /\A[A-Za-z0-9_.-]+\z/)
      and (!$state or ($name =~ /\A[A-Za-z0-9_.-]+\z/ and $name !~ /\A\.{1,2}\z/))) {
      # Get friendly name
      if ($friendly == undef) {
        # Derive a readable monitoring label from the resource title.
        $friendly_correct = capitalize($name)
      } else {
        # Use the caller's monitoring label.
        $friendly_correct = $friendly
      }

      # Try to get package
      if (defined(Class['basic_settings::monitoring'])) {
        # Inherit the central monitoring backend unless this registration selects one.
        if ($package == undef) {
          # Inherit the monitoring backend selected by the central monitoring class.
          $package_correct = $basic_settings::monitoring::package
        } else {
          # Use the explicitly selected monitoring backend.
          $package_correct = $package
        }
        $sudoers_dir_enable = $basic_settings::monitoring::sudoers_dir_enable
      } else {
        # Disable backend registration and sudoers integration without monitoring configuration.
        $package_correct = 'none'
        $sudoers_dir_enable = false
      }

      # Get sudoers prefix
      if ($sudoers_dir_enable) {
        # Use unprefixed fragments in the managed sudoers directory.
        $sudoers_prefix = ''
      } else {
        # Use the fallback sudoers prefix when no managed sudoers directory is available.
        $sudoers_prefix = 'z'
      }

      # Do thing based on package
      $file_ensure = $ensure ? { 'present' => 'file', default => $ensure }
      case $package_correct {
        'openitcockpit': {
          # Resolve this registration's name and the path of its own or shared executable.
          $script_name = "check_${name}"
          $script_owner = $script ? { undef => $name, default => $script }
          $script_path = "/etc/openitcockpit-agent/plugins/check_${script_owner}"

          # Keep the monitoring executable outside the control of unprivileged users.
          $uid = 'root'
          $gid = 'root'

          # Derive private storage from the backend and registration identity, independently of the shared executable.
          $state_dir = $state ? {
            true    => "${basic_settings::monitoring::state_dir}/${name}",
            default => undef,
          }

          # Provision state only while this backend installs the check, retaining history during retirement.
          if ($ensure == present and $state) {
            # Keep the registration's own state private and order it after the shared parent.
            file { $state_dir:
              ensure  => directory,
              owner   => $uid,
              group   => $gid,
              mode    => '0700',
              require => File['monitoring_location_state'],
            }
            $registration_require = $template ? {
              undef   => [File[$script_path, $state_dir], Package['coreutils']],
              default => File[$script_path, $state_dir],
            }
          } else {
            # Disabled state or retirement must not remove previously collected history.
            $registration_require = File[$script_path]
          }

          # Append caller arguments only when this registration supplies them.
          if ($cmd == undef or $cmd == '') {
            # Invoke the check directly when no extra arguments are supplied.
            $command_args = $script_path
          } else {
            # Append the supplied arguments to the check executable.
            $command_args = "${script_path} ${cmd}"
          }

          # Static scripts and shared-script references need runtime state; own templates already receive state_dir.
          if ($state and $template == undef) {
            # env also works with executors that launch commands without a shell.
            $state_dir_shell = stdlib::shell_escape($state_dir)
            $command = "/usr/bin/env STATE_DIR=${state_dir_shell} ${command_args}"
          } else {
            # Use the rendered default for templates and preserve commands for checks without storage.
            $command = $command_args
          }

          # Create fragment for plugin
          if ($ensure == present and $register) {
            concat::fragment { "monitoring_plugin_${name}":
              target  => '/etc/openitcockpit-agent/customchecks.ini',
              content => "\n[${script_name}] # ${friendly_correct}\ncommand = ${command}\ninterval = ${interval}\ntimeout = ${timeout}\nenabled = true\n", # lint:ignore:140chars
              order   => '10',
              require => $registration_require,
            }
          }
        }
        default: {
          # Cleanup must retain the backend-owned path even after monitoring has been disabled.
          $script_path = $ensure ? {
            absent  => "/etc/openitcockpit-agent/plugins/check_${name}",
            default => undef,
          }
          $uid = 'root'
          $gid = 'root'
          $state_dir = undef
        }
      }

      # Check if script path is not defined
      if ($script_path != undef and $script == undef) {
        # Render with this resource's derived state_dir and explicit caller data only for an active installation.
        if ($source != undef) {
          # A file source never also supplies inline content.
          $script_content = undef
        } elsif ($ensure == present and $template != undef) {
          # Render only after the backend-derived template variables are known.
          $script_content = template($template)
        } else {
          # Use inline check content and avoid template reads during retirement.
          $script_content = $content
        }

        # Keep sourced and rendered executables mutually exclusive.
        file { $script_path:
          ensure  => $file_ensure,
          content => $script_content,
          source  => $source,
          owner   => $uid,
          group   => $gid,
          mode    => '0700',
        }

        # Create sudo
        if ($root_required and $uid != 'root') {
          # Provide sudo once when an active privileged check needs it.
          if ($ensure == present and !defined(Package['sudo'])) {
            package { 'sudo':
              ensure          => installed,
              install_options => ['--no-install-recommends', '--no-install-suggests'],
            }
          }
          $sudo_cmnd = regsubst("monitoring_plugin_${name}", '[^A-Za-z0-9]', '_', 'G').upcase
          file { "/etc/sudoers.d/${sudoers_prefix}25-monitoring_plugin_${name}":
            ensure  => $file_ensure,
            owner   => 'root',
            group   => 'root',
            mode    => '0440',
            content => "# Managed by puppet\nCmnd_Alias ${sudo_cmnd} = ${script_path} * \nDefaults!${sudo_cmnd} !mail_always \n${uid} ALL=(root) NOPASSWD: ${sudo_cmnd}\n", # lint:ignore:140chars
            require => Package['sudo'],
          }
        }
      }
    } else {
      fail('basic_settings::monitoring_custom requires an approved source URL and safe shared-script/state titles containing only letters, digits, dots, underscores or hyphens.') # lint:ignore:140chars
    }
  } else {
    fail('basic_settings::monitoring_custom accepts only one of check or template; shared scripts accept neither.')
  }
}
