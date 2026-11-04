# @summary Manages a generated systemd service unit and optional monitoring.
#
# This defined type writes `/etc/systemd/system/<title>.service` from the shared template, controls the service
# enablement state, registers service monitoring when requested, and automatically adds an npm audit check for Node.js
# services with a known working directory. Service hardening is supplied explicitly by the caller through the `service`
# hash.
#
# @example Create a hardened oneshot service
#   basic_settings::systemd_service { 'example':
#     description => 'Example task',
#     service     => {
#       'ExecStart' => '/usr/local/sbin/example',
#       'Type'      => 'oneshot',
#     },
#   }
#
# @param description
#   Human-readable service description rendered into the unit.
#
# @param daemon_reload
#   Exec resource title notified after the service file changes.
#
# @param enable
#   Controls whether the service is enabled when `ensure` is `present`.
#
# @param ensure
#   Controls whether the generated service unit is present or absent.
#
# @param install
#   Key/value settings rendered into the `[Install]` section.
#
# @param monitoring_active_days
#   Optional active-day expression passed to generated service monitoring.
#
# @param monitoring_active_windows
#   Optional active-window expression passed to generated service monitoring.
#
# @param monitoring_additional_check_timeout
#   OpenITCOCKPIT execution timeout in seconds for additional checks registered for this service.
#   The automatic npm audit check for Node.js services with a working directory currently uses this setting.
#   Allow time for execution and output. This is independent of `monitoring_timeout` and does not change the check
#   interval or service runtime limits.
#
# @param monitoring_enable
#   Enables generated monitoring when set to `true`. `undef` leaves monitoring absent.
#
# @param monitoring_log_window
#   Journal lookback in seconds for generated service monitoring. `undef` keeps the check script default. Running
#   services remain limited to their latest activation; other states use the latest state change when more recent.
#   The window affects journal context and failure/warning matching, not the output line limit. Larger windows can
#   retain alarms longer and require more journal processing within the unchanged agent timeout.
#
# @param monitoring_package
#   Monitoring backend package passed to `basic_settings::monitoring_service`.
#
# @param monitoring_timeout
#   OpenITCOCKPIT execution timeout in seconds for the generated systemd service check. This is independent of
#   `monitoring_additional_check_timeout` and `monitoring_log_window`; it does not change service runtime limits
#   or check intervals.
#
# @param service
#   Key/value settings rendered into the `[Service]` section.
#
# @param service_subscribe
#   Optional resources subscribed by the Puppet `service` resource.
#
# @param unit
#   Key/value settings rendered into the `[Unit]` section.
#
# @api public
define basic_settings::systemd_service (
  String                    $description,
  String                    $daemon_reload                       = 'systemd_daemon_reload',
  Boolean                   $enable                              = true,
  Enum['present', 'absent'] $ensure                              = present,
  Hash                      $install                             = {
    'WantedBy'  => 'multi-user.target',
  },
  Optional[String]          $monitoring_active_days              = undef,
  Optional[String]          $monitoring_active_windows           = undef,
  Integer[1]                $monitoring_additional_check_timeout = 30,
  Optional[Boolean]         $monitoring_enable                   = undef,
  Optional[Integer[1]]      $monitoring_log_window               = undef,
  Optional[String]          $monitoring_package                  = undef,
  Integer[1]                $monitoring_timeout                  = 10,
  Hash                      $service                             = {},
  Optional[Array]           $service_subscribe                   = undef,
  Hash                      $unit                                = {},
) {
  # Check if systemd package is not defined
  if (!defined(Package['systemd'])) {
    package { 'systemd':
      ensure          => installed,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
    }
  }

  # Create systemd service file
  file { "/etc/systemd/system/${name}.service":
    ensure  => $ensure,
    content => template('basic_settings/systemd/service'),
    owner   => 'root',
    group   => 'root',
    mode    => '0644', # See issue https://github.com/systemd/systemd/issues/770
    notify  => Exec[$daemon_reload],
    require => Package['systemd'],
  }

  # Set service
  if ($ensure == present) {
    # Enable service
    service { $name:
      enable    => $enable,
      require   => File["/etc/systemd/system/${name}.service"],
      subscribe => $service_subscribe,
    }

    # Check if we need to monitoring this service
    if ($monitoring_enable != undef and $monitoring_package != 'none') {
      # Translate the explicit monitoring toggle into check presence or removal.
      $monitoring_ensure = $monitoring_enable ? { true => 'present', default => absent }
    } else {
      # Remove the service check when monitoring is not selected for this backend.
      $monitoring_ensure = absent
    }
  } elsif ($monitoring_package != 'none') {
    # Remove the service check when monitoring is not selected for this backend.
    $monitoring_ensure = absent
  }

  # Setup monitoring for this service
  basic_settings::monitoring_service { $name:
    ensure         => $monitoring_ensure,
    package        => $monitoring_package,
    log_window     => $monitoring_log_window,
    timeout        => $monitoring_timeout,
    active_windows => $monitoring_active_windows,
    active_days    => $monitoring_active_days,
  }

  # Check if service is using node executable in ExecStart
  if ('ExecStart' in $service and $service['ExecStart'] =~ String and $service['ExecStart'] =~ /^(?:node|\.{1,2}\/node|\/(?:[^\/\s]+\/)+node)\s+/) { # lint:ignore:140chars
    # Require a working directory before registering the Node.js dependency audit.
    if ('WorkingDirectory' in $service and $service['WorkingDirectory'] =~ String) {
      basic_settings::monitoring_npm_audit { $name:
        ensure  => $monitoring_ensure,
        dir     => $service['WorkingDirectory'],
        package => $monitoring_package,
        timeout => $monitoring_additional_check_timeout,
      }
    } else {
      basic_settings::monitoring_npm_audit { $name:
        ensure  => absent,
        dir     => '',
        package => $monitoring_package,
        timeout => $monitoring_additional_check_timeout,
      }
    }
  }
}
