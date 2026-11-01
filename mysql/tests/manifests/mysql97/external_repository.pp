include basic_settings

# A disabled repository helper must not override the externally selected series.
class { 'mysql':
  automysqlbackup_password => Sensitive($facts['compile_test_password']),
  package_version          => 9.7,
  root_authentication      => 'auth_socket',
}

# Include all public defined types while root uses the explicit socket policy.
mysql::database { 'app':
  ensure => present,
}

# Exercise ordinary password users alongside the socket-authenticated root account.
mysql::user { 'app':
  ensure   => present,
  username => 'app',
  password => Sensitive($facts['compile_test_password']),
}

# Use modern privilege comparison with an externally managed package source.
mysql::grant { 'app':
  ensure   => present,
  username => 'app',
  database => 'app',
}
