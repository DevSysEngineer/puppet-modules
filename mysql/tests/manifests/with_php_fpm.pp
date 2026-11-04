# Compile the database dependency on PHP-FPM alongside Nginx and the server baseline.
class { 'basic_settings':
  mysql_enable  => true,
  mysql_version => 8.4,
}

include nginx
include php8
include php8::fpm

class { 'mysql':
  automysqlbackup_password => Sensitive($facts['compile_test_password']),
}
