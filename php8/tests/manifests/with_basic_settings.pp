# Compile every PHP interface with the server baseline and without Nginx.
include basic_settings

include php8
include php8::cli
include php8::fpm

php8::fpm_pool { 'app': }
