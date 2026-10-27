# Compile every Nginx interface without declaring the server baseline.
include nginx

# Supply a vhost for the explicit certificate-check registration below.
nginx::server { 'app.example.test':
  docroot             => '/var/www/app',
  https_enable        => true,
  monitoring_cert     => false,
  php_fpm_enable      => false,
  server_name         => 'app.example.test',
  ssl_certificate     => '/etc/ssl/certs/app.pem',
  ssl_certificate_key => '/etc/ssl/private/app.key',
}

# Instantiate the helper even when the monitoring backend is inactive.
nginx::monitoring_cert { 'app':
  config_file => '/etc/nginx/conf.d/app.example.test.conf',
  server_name => 'app.example.test',
}
