# @summary Installs and configures vnStat traffic accounting.
#
# This class installs vnStat, builds `/etc/vnstat.conf` and
# `/etc/vnstat-monitoring.conf` through concat, and integrates the daemon with
# the local `basic_settings` systemd and logrotate helpers when those helpers
# are already present in the catalog. The default configuration lets vnstatd add
# newly discovered interfaces automatically so a host receives traffic
# accounting without a per-interface resource.
#
# @example Install vnStat with the default configuration
#   class { 'vnstat': }
#
# @param bandwidth_max
#   Optional global `MaxBandwidth` value in Mbit/s. `undef` omits the directive
#   so vnStat can use interface-specific values or its own detection without a
#   Puppet-rendered fallback.
#
# @param nice_level
#   Positive nice value rendered as a negative systemd `Nice` setting for
#   `vnstat.service`. The default `8` makes the daemon prefer responsiveness
#   without running at the highest priority.
#
# @param p95_critical
#   Optional global 95th percentile critical threshold in Mbit/s for the
#   monitoring check. Interface-specific `vnstat::ethernet` values override
#   this default.
#
# @param p95_warning
#   Optional global 95th percentile warning threshold in Mbit/s for the
#   monitoring check. Interface-specific `vnstat::ethernet` values override
#   this default.
#
# @param target
#   `basic_settings::systemd` target suffix that should bind to
#   `vnstat.service` when the shared systemd target ladder is present.
#
# @api public
class vnstat (
  Optional[Integer[0, 50000]] $bandwidth_max = undef,
  Integer                    $nice_level     = 8,
  Optional[Integer[1]]       $p95_critical   = undef,
  Optional[Integer[1]]       $p95_warning    = undef,
  String                     $target         = 'services',
) {
  # Keep generated monitoring configuration valid before the check consumes it.
  if ($p95_warning != undef and $p95_critical != undef and $p95_critical < $p95_warning) {
    fail('vnstat p95_critical must be greater than or equal to p95_warning.')
  }

  # Install vnstat
  package { 'vnstat':
    ensure          => installed,
    install_options => ['--no-install-recommends', '--no-install-suggests'],
  }

  # Check if we have systemd
  if (defined(Package['systemd'])) {
    # Disable service
    service { 'vnstat':
      ensure  => undef,
      enable  => false,
      require => Package['vnstat'],
    }

    # Reload systemd daemon
    exec { 'vnstat_systemd_daemon_reload':
      command     => '/usr/bin/systemctl daemon-reload',
      refreshonly => true,
      require     => Package['systemd'],
    }

    # Get unit
    if (defined(Class['basic_settings::monitoring'])) {
      $unit = {
        'OnFailure' => 'notify-failed@%i.service',
      }
    } else {
      $unit = {}
    }

    # Create drop in for vnstat service
    basic_settings::systemd_drop_in { 'vnstat_settings':
      target_unit   => 'vnstat.service',
      unit          => $unit,
      service       => {
        'Nice'         => "-${nice_level}",
      },
      daemon_reload => 'vnstat_systemd_daemon_reload',
      require       => Package['vnstat'],
    }

    # Create drop in for x target
    if (defined(Class['basic_settings::systemd'])) {
      basic_settings::systemd_drop_in { 'vnstat_dependency':
        target_unit   => "${basic_settings::systemd::cluster_id}-${target}.target",
        unit          => {
          'BindsTo'   => 'vnstat.service',
        },
        daemon_reload => 'vnstat_systemd_daemon_reload',
        require       => Basic_settings::Systemd_target["${basic_settings::systemd::cluster_id}-${target}"],
      }
    }
  } else {
    # Enable service
    service { 'vnstat':
      ensure  => true,
      enable  => true,
      require => Package['vnstat'],
    }
  }

  # Build vnStat configuration from the default template and optional fragments.
  concat { '/etc/vnstat.conf':
    owner   => 'root',
    group   => 'root',
    mode    => '0600', # Only root
    notify  => Service['vnstat'],
    require => Package['vnstat'],
  }
  concat::fragment { 'vnstat_config_default':
    target  => '/etc/vnstat.conf',
    content => template('vnstat/vnstat.conf'),
    order   => '10',
  }

  # Store monitoring-only defaults separately so vnStat receives only native directives.
  concat { '/etc/vnstat-monitoring.conf':
    owner   => 'root',
    group   => 'root',
    mode    => '0600',
    require => Package['vnstat'],
  }
  concat::fragment { 'vnstat_monitoring_config_default':
    target  => '/etc/vnstat-monitoring.conf',
    content => template('vnstat/monitoring.conf'),
    order   => '10',
  }

  # Check if logrotate package exists
  if (defined(Package['logrotate'])) {
    basic_settings::io_logrotate { 'vnstat':
      path           => '/var/log/vnstat/vnstat.log',
      frequency      => 'weekly',
      compress_delay => true,
      create_group   => 'vnstat',
      create_user    => 'vnstat',
      rotate_copy    => true,
    }
  }

  # Create service check
  if (defined(Class['basic_settings::monitoring']) and $basic_settings::monitoring::package != 'none') {
    basic_settings::monitoring_custom { 'vnstat_interfaces':
      ensure   => present,
      source   => 'puppet:///modules/vnstat/check_vnstat_interfaces',
      friendly => 'vnStat interfaces',
      timeout  => 60,
      require  => Concat['/etc/vnstat-monitoring.conf'],
    }
  }
}
