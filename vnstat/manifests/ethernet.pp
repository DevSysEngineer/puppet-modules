# @summary Adds vnStat configuration for one ethernet interface.
#
# This defined type appends one concat fragment to `/etc/vnstat.conf`. Use it
# for interface-specific configuration that should stay outside the global
# vnStat defaults, such as a known technical speed cap for
# `MaxBW<interface>`.
#
# @example Configure a known maximum bandwidth for one interface
#   vnstat::ethernet { 'ens192':
#     max_bandwidth => 1000,
#   }
#
# @param ensure
#   Controls whether the concat fragment is emitted. `absent` omits the
#   fragment from the compiled configuration.
#
# @param interface
#   Interface name used in generated vnStat directives. `undef` uses the
#   resource title.
#
# @param max_bandwidth
#   Optional value for `MaxBW<interface>` in Mbit/s. Set this to the real
#   technical interface speed, not a purchased traffic bundle or alert limit.
#
# @param order
#   Concat fragment order. The default `50` places interface fragments after the
#   base vnStat configuration.
#
# @api public
define vnstat::ethernet (
  Enum['present','absent'] $ensure        = 'present',
  Optional[String[1]]      $interface     = undef,
  Optional[Integer[0]]     $max_bandwidth = undef,
  String[1]                $order         = '50',
) {
  if (defined(Class['vnstat'])) {
    if ($interface == undef) {
      $interface_correct = $name
    } else {
      $interface_correct = $interface
    }

    if ($ensure == present) {
      concat::fragment { "vnstat_ethernet_${name}":
        target  => '/etc/vnstat.conf',
        content => template('vnstat/ethernet.conf'),
        order   => $order,
        require => Concat['/etc/vnstat.conf'],
      }
    }
  } else {
    fail('The vnstat class must be included before using the vnstat::ethernet defined type.')
  }
}
