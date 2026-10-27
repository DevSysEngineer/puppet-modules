include basic_settings

include php8
include php8::cli
include php8::fpm

php8::fpm_pool { 'app': }
