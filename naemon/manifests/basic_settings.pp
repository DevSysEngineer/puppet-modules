define naemon::basic_settings (
  Optional[String]          $address      = undef,
  Enum['present','absent']  $ensure       = present,
  Optional[String]          $friendly     = undef,
) {
  # Create host
  naemon::host { $name:
    ensure   => $ensure,
    address  => $address,
    friendly => $friendly,
    checks   => {
      'firewall' => {
        active_checks          => {
          enable => false,
        },
        passive_checks_enabled => true,
        process_perf_data      => true,
      },
    },
  }
}
