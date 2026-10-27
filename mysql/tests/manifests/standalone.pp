class { 'mysql':
  automysqlbackup_password => Sensitive($facts['compile_test_password']),
}

# Create the database referenced by the grant below.
mysql::database { 'app':
  ensure => present,
}

# Create the account referenced by the grant below.
mysql::user { 'app':
  ensure   => present,
  username => 'app',
  password => Sensitive($facts['compile_test_password']),
}

# Grant the synthetic account access to its database.
mysql::grant { 'app':
  ensure   => present,
  username => 'app',
  database => 'app',
}
