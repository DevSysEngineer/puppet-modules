# FPM requires the real systemd package and shared unit management.
include basic_settings::systemd

include php8
include php8::fpm

php8::fpm_pool { 'app': }
