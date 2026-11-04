# Monitoring also instantiates the backend helpers; hosts enables the optional hosts class.
class { 'basic_settings':
  hosts_enable       => true,
  monitoring_package => 'openitcockpit',
}

# Add the optional hosts entry.
basic_settings::hosts::entry { 'app':
  hostname => 'app.example.test',
  ip       => '192.0.2.20',
}

# A locked synthetic account needs no credential fixture.
basic_settings::login::user { 'compile-example':
  gid      => 2000,
  home     => '/home/compile-example',
  password => Sensitive('!'),
  uid      => 2000,
}

# Attach a cron entry to the synthetic account.
basic_settings::login::cron { 'compile-example':
  user => 'compile-example',
}

# Allow one harmless command for the synthetic account.
basic_settings::login::sudo { 'compile-example':
  rule => 'compile-example ALL=(root) /usr/bin/true',
}

# Register the optional npm audit check.
basic_settings::monitoring::npm_audit { 'app':
  dir => '/opt/app',
}
