# Naemon requires the OpenITCOCKPIT package supplied by its host profile.
package { 'openitcockpit':
  ensure          => installed,
  install_options => ['--no-install-recommends', '--no-install-suggests'],
}

include naemon

# This wrapper also instantiates naemon::host.
naemon::basic_settings { 'node':
  address => '192.0.2.10',
}

# Group the host created by the wrapper above.
naemon::hostgroup { 'servers': }
