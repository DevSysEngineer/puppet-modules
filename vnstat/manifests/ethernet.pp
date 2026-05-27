# @summary Adds vnStat configuration for one ethernet interface.
#
# This defined type appends optional concat fragments to `/etc/vnstat.conf` and
# `/etc/vnstat-monitoring.conf`. Use it for interface-specific configuration
# that should stay outside the global vnStat defaults, such as a known
# technical speed cap for `MaxBW<interface>` or 95th percentile monitoring
# thresholds.
#
# @example Configure a known maximum bandwidth for one interface
#   vnstat::ethernet { 'ens192':
#     bandwidth_max => 1000,
#   }
#
# @param bandwidth_max
#   Optional value for `MaxBW<interface>` in Mbit/s. Set this to the real
#   technical interface speed, not a purchased traffic bundle or alert limit.
#
# @param ensure
#   Controls whether the concat fragment is emitted. `absent` omits the
#   fragment from the compiled configuration.
#
# @param interface
#   Interface name used in generated vnStat directives. `undef` uses the
#   resource title.
#
# @param order
#   Concat fragment order. The default `50` places interface fragments after the
#   base vnStat configuration.
#
# @param p95_critical
#   Optional 95th percentile critical threshold in Mbit/s for this interface.
#   `undef` inherits the class-level threshold when one is configured.
#
# @param p95_warning
#   Optional 95th percentile warning threshold in Mbit/s for this interface.
#   `undef` inherits the class-level threshold when one is configured.
#
# @api public
define vnstat::ethernet (
  Optional[Integer[0, 50000]] $bandwidth_max = undef,
  Enum['present','absent']    $ensure        = 'present',
  Optional[String[1]]         $interface     = undef,
  String[1]                   $order         = '50',
  Optional[Integer[1]]        $p95_critical  = undef,
  Optional[Integer[1]]        $p95_warning   = undef,
) {
  if (defined(Class['vnstat'])) {
    if ($interface == undef) {
      $interface_correct = $name
    } else {
      $interface_correct = $interface
    }

    # The monitoring config is whitespace-delimited, so interface names must stay single-token.
    if ($interface_correct !~ /\s/) {
      if ($p95_warning == undef) {
        $p95_warning_correct = $vnstat::p95_warning
      } else {
        $p95_warning_correct = $p95_warning
      }

      if ($p95_critical == undef) {
        $p95_critical_correct = $vnstat::p95_critical
      } else {
        $p95_critical_correct = $p95_critical
      }

      # Validate the effective thresholds that the monitoring check will apply.
      if ($p95_warning_correct == undef or $p95_critical_correct == undef or $p95_critical_correct >= $p95_warning_correct) {
        if ($ensure == present and $bandwidth_max != undef) {
          concat::fragment { "vnstat_ethernet_${name}":
            target  => '/etc/vnstat.conf',
            content => template('vnstat/ethernet.conf'),
            order   => $order,
            require => Concat['/etc/vnstat.conf'],
          }
        }

        if ($ensure == present and ($p95_warning != undef or $p95_critical != undef)) {
          concat::fragment { "vnstat_monitoring_ethernet_${name}":
            target  => '/etc/vnstat-monitoring.conf',
            content => template('vnstat/monitoring.conf'),
            order   => $order,
            require => Concat['/etc/vnstat-monitoring.conf'],
          }
        }
      } else {
        fail("vnstat::ethernet[${name}] effective p95_critical must be greater than or equal to p95_warning.")
      }
    } else {
      fail("vnstat::ethernet[${name}] interface names must not contain whitespace.")
    }
  } else {
    fail('The vnstat class must be included before using the vnstat::ethernet defined type.')
  }
}
