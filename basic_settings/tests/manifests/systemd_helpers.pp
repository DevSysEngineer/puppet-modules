# Use each systemd wrapper without the server baseline or its target ladder.
basic_settings::systemd::target { 'example':
  description    => 'Example target',
  parent_targets => ['multi-user'],
}

# Generate a unit without enabling or starting the workload.
basic_settings::systemd::service { 'example':
  description        => 'Example service',
  enable             => false,
  monitoring_package => 'none',
  service            => { 'ExecStart' => '/usr/bin/true' },
}

# Add a timer without a monitoring backend.
basic_settings::systemd::timer { 'example':
  description        => 'Example timer',
  enable             => false,
  monitoring_package => 'none',
  timer              => { 'OnCalendar' => 'daily' },
}

# Extend the standalone target through the shared reload.
basic_settings::systemd::drop_in { 'example_dependency':
  target_unit => 'example.target',
  unit        => { 'Wants' => 'example.service' },
}

# Configure a synthetic interface without the network class.
basic_settings::systemd::network { '90-example':
  interface => 'example0',
  network   => { 'DHCP' => 'no' },
}

# Remove an unused service without a monitoring backend.
basic_settings::systemd::service { 'retired-example':
  ensure             => absent,
  description        => 'Retired example service',
  monitoring_package => 'none',
}
