class { 'basic_settings':
  mysql_enable  => true,
  mysql_version => 9.7,
}

# The active repository overrides the unchanged package_version default.
class { 'mysql':
  automysqlbackup_password => Sensitive($facts['compile_test_password']),
  root_authentication      => 'caching_sha2_password',
  root_password            => Sensitive($facts['compile_test_password']),
}

# Include all public defined types in the combined series scenario.
mysql::database { 'app':
  ensure => present,
}

# Create an ordinary user after selecting the explicit root policy.
mysql::user { 'app':
  ensure   => present,
  username => 'app',
  password => Sensitive($facts['compile_test_password']),
}

# Use the repository-selected series for database-scoped grants.
mysql::grant { 'app':
  ensure   => present,
  username => 'app',
  database => 'app',
}
