class { 'mysql':
  automysqlbackup_password => Sensitive($facts['compile_test_password']),
  package_version          => 9.7,
  root_password            => Sensitive($facts['compile_test_password']),
}

# Exercise modern account SQL without a managed package source.
mysql::user { 'app':
  ensure   => present,
  username => 'app',
  password => Sensitive($facts['compile_test_password']),
}

# Retire native accounts without requiring a password or the removed plugin.
mysql::user { 'retired':
  ensure           => absent,
  username         => 'retired',
  password_latency => 'authentication_string',
}

# Include the database interface in the standalone series scenario.
mysql::database { 'app':
  ensure => present,
}

# Compile both directions of privilege management on separate object scopes.
mysql::grant { 'app':
  ensure   => present,
  username => 'app',
  database => 'app',
}

# Keep revocation on a separate scope from the present grant.
mysql::grant { 'retired_scope':
  ensure     => absent,
  username   => 'app',
  database   => 'retired',
  privileges => ['SELECT'],
}
