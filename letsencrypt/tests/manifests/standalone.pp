include letsencrypt

# The standalone authenticator ships with Certbot and needs no webserver class.
letsencrypt::certificate { 'app.example.test':
  domains => ['app.example.test'],
  plugin  => 'standalone',
}
