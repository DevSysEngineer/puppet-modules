# Compile every PHP interface without the server baseline or Nginx.
include php8
include php8::cli
include php8::fpm

php8::fpm_pool { 'app': }
