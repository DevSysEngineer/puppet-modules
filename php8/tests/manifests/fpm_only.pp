# Compile FPM and one pool without CLI, Nginx or the server baseline.
include php8
include php8::fpm

php8::fpm_pool { 'app': }
