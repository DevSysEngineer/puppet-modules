# Hosts examples for managing `/etc/hosts` through concat.
# Replace hostnames and addresses with environment data.

node 'hosts-basic.example.org' {
  class { 'basic_settings':
    hosts_enable            => true,
    hosts_localhost_aliases => ['puppet', 'test'],
    server_fdqn             => 'hosts-basic.example.org',
  }

  basic_settings::hosts_entry { 'puppet':
    hostname => 'puppet',
    ip       => '10.200.3.69',
  }

  basic_settings::hosts_entry { 'checkmk':
    comment  => 'checkmk',
    hostname => 'bhr808619-prd.tools.vancis.io',
    ip       => '10.200.14.10',
  }
}

node 'network-only.example.org' {
  class { 'basic_settings::network':
    firewall_package => 'nftables',
    hosts_enable     => true,
    server_fdqn      => 'network-only.example.org',
  }

  basic_settings::hosts_entry { 'internal-api':
    comment  => 'internal api endpoint',
    hostname => 'api.internal.example.org',
    ip       => '10.200.20.15',
  }
}

node 'hosts-direct.example.org' {
  class { 'basic_settings::hosts':
    server_fdqn => 'hosts-direct.example.org',
  }

  basic_settings::hosts_entry { 'mail-relay':
    hostname => 'mail-relay.internal.example.org',
    ip       => '10.200.30.25',
  }
}
