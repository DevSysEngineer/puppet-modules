# @summary Manages a generated systemd timer unit and optional timer monitoring.
#
# This defined type writes `/etc/systemd/system/<title>.timer`, manages timer enablement and optional runtime state, and
# registers monitoring through `basic_settings::monitoring::timer` when requested.
#
# @example Create a daily timer
#   basic_settings::systemd::timer { 'example':
#     description => 'Example timer',
#     timer       => { 'OnCalendar' => '*-*-* 03:00' },
#   }
#
# @param description
#   Human-readable timer description rendered into the unit.
#
# @param daemon_reload
#   Exec resource title notified after the timer file changes. The shared default is declared automatically;
#   a custom exec must be declared by the caller.
#
# @param enable
#   Controls whether the timer is enabled when `ensure` is `present`.
#
# @param ensure
#   Controls whether the generated timer unit is present or absent.
#
# @param install
#   Key/value settings rendered into the `[Install]` section.
#
# @param monitoring_enable
#   Enables generated timer monitoring when set to `true`.
#
# @param monitoring_log_window
#   Trailing journal interval in seconds for generated timer monitoring, ending at the check time without clipping to
#   the latest trigger. `undef` keeps the check's last-trigger interval. Historical entries are diagnostic context;
#   current target service properties determine status. Output limits, check interval and agent timeout stay unchanged.
#
# @param monitoring_package
#   Monitoring backend package passed to `basic_settings::monitoring::timer`.
#
# @param monitoring_timeout
#   OpenITCOCKPIT execution timeout in seconds for the generated timer check. Set this separately from
#   `monitoring_log_window`; it does not change the check interval, timer schedule or target service's runtime limits.
#
# @param state
#   Optional Puppet service state for the timer, usually `running` or `stopped`.
#
# @param timer
#   Key/value settings rendered into the `[Timer]` section.
#
# @param unit
#   Key/value settings rendered into the `[Unit]` section.
#
# @api public
define basic_settings::systemd::timer (
  String                               $description,
  String                               $daemon_reload         = 'systemd_daemon_reload',
  Boolean                              $enable                = true,
  Enum['present', 'absent']            $ensure                = present,
  Hash                                 $install               = {
    'WantedBy'  => 'timers.target',
  },
  Optional[Boolean]                    $monitoring_enable     = undef,
  Optional[Integer[1]]                 $monitoring_log_window = undef,
  Optional[String]                     $monitoring_package    = undef,
  Integer[1]                           $monitoring_timeout    = 10,
  Optional[Enum['running', 'stopped']] $state                 = undef,
  Hash                                 $timer                 = {},
  Hash                                 $unit                  = {},
) {
  # Check if systemd package is not defined
  if (!defined(Package['systemd'])) {
    package { 'systemd':
      ensure          => installed,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
    }
  }

  # Provide the shared reload without pulling in the systemd target ladder.
  include basic_settings::systemd::reload

  # Create timer file
  file { "/etc/systemd/system/${title}.timer":
    ensure  => $ensure,
    content => template('basic_settings/systemd/timer'),
    owner   => 'root',
    group   => 'root',
    mode    => '0644', # See issue https://github.com/systemd/systemd/issues/770
    notify  => Exec[$daemon_reload],
    require => Package['systemd'],
  }

  # Set service
  if ($ensure == present) {
    service { "${title}.timer":
      ensure  => $state,
      enable  => $enable,
      require => File["/etc/systemd/system/${title}.timer"],
    }

    # Check if we need to monitoring this timer
    if ($monitoring_enable != undef and $monitoring_package != 'none') {
      # Translate the explicit monitoring toggle into check presence or removal.
      $monitoring_ensure = $monitoring_enable ? { true => 'present', default => absent }

      # Register or retire the timer check using the caller's monitoring choice.
      basic_settings::monitoring::timer { $title:
        ensure     => $monitoring_ensure,
        log_window => $monitoring_log_window,
        package    => $monitoring_package,
        timeout    => $monitoring_timeout,
      }
    }
  } elsif ($monitoring_package != 'none') {
    basic_settings::monitoring::timer { $title:
      ensure     => $ensure,
      log_window => $monitoring_log_window,
      package    => $monitoring_package,
      timeout    => $monitoring_timeout,
    }
  }
}
