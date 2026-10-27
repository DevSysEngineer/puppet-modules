# @summary Installs and configures PHP-FPM for the selected PHP 8 version.
#
# Declare `php8` first to select the version and extensions, and add at least one `php8::fpm_pool` after this class.
# FPM runs without Nginx or the `basic_settings` class. Without shared startup integration, Puppet enables and starts
# the service directly. With a declared systemd package, the shared drop-in helper applies the existing hardening.
# A previously declared Nginx class binds FPM to Nginx; otherwise `basic_settings::systemd`, when declared, binds FPM
# to its services target. These integrated routes disable vendor enablement and leave stopped services stopped.
# The module owns the FPM global config and pool directory, purges unmanaged pools, and writes custom INI settings.
# Previously declared monitoring and logrotate facilities remain optional integrations.
#
# @example Configure PHP-FPM
#   include php8
#
#   class { 'php8::fpm':
#     ini_settings => { 'memory_limit' => '256M' },
#   }
#
#   # Provide the pool required by the managed FPM service.
#   php8::fpm_pool { 'app': }
#
# @param errorlog
#   Optional FPM error log path. `undef` uses the versioned default under `/var/log`.
#
# @param ini_settings
#   Hash of INI settings rendered into the FPM custom settings file. Must not include module-managed PHP INI settings
#   such as `expose_php`. A previously declared `basic_settings::timezone` supplies `date.timezone` unless overridden
#   here. Changes restart FPM; with shared startup integration, a stopped service stays stopped.
#
# @param pidfile
#   Optional FPM PID file path. `undef` uses the versioned default under `/run`.
#
# @api public
class php8::fpm (
  Optional[String] $errorlog     = undef,
  Hash             $ini_settings = {},
  Optional[String] $pidfile      = undef,
) {
  # Require the PHP parent before configuring its FPM service.
  if (defined(Class['php8'])) {
    # Merge given init settings with default settings
    if (defined(Class['basic_settings::timezone'])) {
      # Use the central timezone as a PHP default while retaining explicit INI overrides.
      $correct_ini_settings = stdlib::merge({
          'date.timezone' => $basic_settings::timezone::timezone,
      }, $ini_settings)
    } else {
      # Keep the supplied INI settings without adding a central timezone default.
      $correct_ini_settings = $ini_settings
    }

    # Reject module-managed PHP INI settings before the custom settings template is rendered.
    $reserved_ini_setting_names = ['expose_php']
    $reserved_ini_settings = $correct_ini_settings.keys.filter |$setting_key| { $setting_key in $reserved_ini_setting_names }
    if (empty($reserved_ini_settings)) {
      # Get minor version from PHP init
      $minor_version = $php8::minor_version

      # Get correct pid file
      if ($pidfile == undef) {
        # Keep the FPM PID file distinct for the selected PHP minor version.
        $correct_pidfile = "/run/php/php8.${minor_version}-fpm.pid"
      } else {
        # Preserve the caller's FPM PID-file path.
        $correct_pidfile = $pidfile
      }

      # Get correct error file
      if ($errorlog == undef) {
        # Keep the FPM error log distinct for the selected PHP minor version.
        $correct_errorlog = "/var/log/php8.${minor_version}-fpm.log"
      } else {
        # Preserve the caller's FPM error-log path.
        $correct_errorlog = $errorlog
      }

      # Install package
      package { "php8.${minor_version}-fpm":
        ensure          => installed,
        install_options => ['--no-install-recommends', '--no-install-suggests'],
        require         => Class['php8'],
      }

      # Follow Nginx's optional systemd integration, but disable startup only when another unit actually owns it.
      $systemd_enable = defined(Package['systemd'])
      $nginx_enable = defined(Class['nginx'])
      $systemd_target_enable = defined(Class['basic_settings::systemd'])
      $monitoring_enable = defined(Class['basic_settings::monitoring'])
      $service_integrated = $systemd_enable and ($nginx_enable or $systemd_target_enable)
      $service_ensure = $service_integrated ? { true => undef, default => true }
      $service_enable = $service_integrated ? { true => false, default => true }

      # Manage FPM after its package is installed, preserving the existing integrated lifecycle.
      service { "php8.${minor_version}-fpm":
        ensure  => $service_ensure,
        enable  => $service_enable,
        require => Package["php8.${minor_version}-fpm"],
      }

      # Keep Apache module removal independent of optional systemd configuration.
      if ($nginx_enable) {
        package { "libapache2-mod-php8.${minor_version}":
          ensure => purged,
        }
      }

      # Add drop-ins only when systemd has already been selected by the caller.
      if ($systemd_enable) {
        # Reload unit changes before Puppet manages the FPM service.
        exec { "php8_${minor_version}_systemd_daemon_reload":
          command     => '/usr/bin/systemctl daemon-reload',
          refreshonly => true,
          require     => Package['systemd'],
          before      => Service["php8.${minor_version}-fpm"],
        }

        # Set PHP-FPM service hardening explicitly, even when newer distro units already ship these settings.
        $default_service = {
          'PrivateDevices'          => 'true',
          'PrivateTmp'              => 'true',
          'ProtectClock'            => 'true',
          'ProtectHome'             => 'true',
          'ProtectHostname'         => 'true',
          'ProtectControlGroups'    => 'true',
          'ProtectKernelLogs'       => 'true',
          'ProtectKernelModules'    => 'true',
          'ProtectKernelTunables'   => 'true',
          'ProtectSystem'           => 'full',
          'RestrictAddressFamilies' => 'AF_INET AF_INET6 AF_NETLINK AF_UNIX',
          'RestrictNamespaces'      => 'true',
          'RestrictRealtime'        => 'true',
          'SystemCallArchitectures' => 'native',
          'UMask'                   => '0077',
        }

        # Check if nginx class exists
        if ($nginx_enable) {
          # Create drop in for nginx service
          basic_settings::systemd_drop_in { 'nginx_php_dependency':
            target_unit   => 'nginx.service',
            unit          => {
              'After'   => "php8.${minor_version}-fpm.service",
              'BindsTo' => "php8.${minor_version}-fpm.service",
            },
            daemon_reload => "php8_${minor_version}_systemd_daemon_reload",
            require       => Package['nginx'],
          }

          # Set service
          $service = stdlib::merge({
              'Nice' => "-${nginx::nice_level}",
          }, $default_service)
        } else {
          # Use the default FPM service settings without an Nginx service dependency.
          $service = $default_service
        }

        # Preserve the shared failure-notification hook when monitoring is declared.
        if ($monitoring_enable) {
          # Route unit failures through the configured monitoring notification service.
          $unit = {
            'OnFailure' => 'notify-failed@%i.service',
          }
        } else {
          # Leave unit failure hooks empty when monitoring is unavailable.
          $unit = {}
        }

        # Create drop in for PHP FPM service
        basic_settings::systemd_drop_in { "php8_${minor_version}_settings":
          target_unit   => "php8.${minor_version}-fpm.service",
          unit          => $unit,
          service       => $service,
          daemon_reload => "php8_${minor_version}_systemd_daemon_reload",
          require       => Package["php8.${minor_version}-fpm"],
          before        => Exec["php8_${minor_version}_systemd_daemon_reload"],
        }

        # Supply a startup path on baseline hosts without changing the existing Nginx dependency chain.
        if (!$nginx_enable and $systemd_target_enable) {
          basic_settings::systemd_drop_in { "php8_${minor_version}_dependency":
            target_unit   => "${basic_settings::systemd::cluster_id}-services.target",
            unit          => {
              'BindsTo' => "php8.${minor_version}-fpm.service",
            },
            daemon_reload => "php8_${minor_version}_systemd_daemon_reload",
            require       => Basic_settings::Systemd_target["${basic_settings::systemd::cluster_id}-services"],
          }
        }
      }

      # Create PHP FPM config
      file { "/etc/php/8.${minor_version}/fpm/php-fpm.conf":
        ensure  => file,
        content => template('php8/fpm-global.conf'),
        owner   => 'root',
        group   => 'root',
        mode    => '0600',
        notify  => Service["php8.${minor_version}-fpm"],
        require => Package["php8.${minor_version}-fpm"],
      }

      # Create PHP FPM pool
      file { "/etc/php/8.${minor_version}/fpm/pool.d":
        ensure  => directory,
        owner   => 'root',
        group   => 'root',
        mode    => '0600',
        purge   => true,
        force   => true,
        recurse => true,
        notify  => Service["php8.${minor_version}-fpm"],
        require => Package["php8.${minor_version}-fpm"],
      }

      # Apply custom INI settings after package installation and refresh the running FPM service when they change.
      file { "/etc/php/8.${minor_version}/fpm/conf.d/99-custom-settings.ini":
        ensure  => file,
        content => template('php8/settings-template.ini'),
        owner   => 'root',
        group   => 'root',
        mode    => '0600',
        notify  => Service["php8.${minor_version}-fpm"],
        require => Package["php8.${minor_version}-fpm"],
      }

      # Register the existing FPM service check only when a monitoring backend is active.
      if ($monitoring_enable and $basic_settings::monitoring::package != 'none') {
        basic_settings::monitoring_service { 'php8':
          friendly => 'PHP8',
          services => ["php8.${minor_version}-fpm"],
        }
      }

      # Check if logrotate package exists
      if (defined(Package['logrotate'])) {
        basic_settings::io_logrotate { "php8.${minor_version}-fpm":
          path           => "/var/log/php8.${minor_version}-fpm.log",
          frequency      => 'weekly',
          compress_delay => true,
          rotate_post    => "if [ -x /usr/lib/php/php8.${minor_version}-fpm-reopenlogs ]; then\n\t\t/usr/lib/php/php8.${minor_version}-fpm-reopenlogs;\n\tfi", # lint:ignore:140chars
        }
      }
    } else {
      # List reserved INI keys in the validation error before rejecting the configuration.
      $reserved_ini_settings_text = join($reserved_ini_settings, ', ')
      fail("php8::fpm ini_settings must not include module-managed PHP INI settings: ${reserved_ini_settings_text}.")
    }
  } else {
    fail('The php8 class must be included before using the php8::fpm class type.')
  }
}
