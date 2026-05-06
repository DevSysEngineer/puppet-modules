define nginx::server (
  Optional[String]    $access_log                       = undef,
  Boolean             $acme_enable                      = false,
  Boolean             $allow_directories                = false,
  Integer             $backlog                          = -1, # Global settings; -1: Disabled, 0: Kernel; >0: Custom value
  Optional[String]    $client_max_body_size             = undef,
  Boolean             $default_server                   = false,
  Optional[String]    $docroot                          = undef,
  Array               $directives                       = [],
  Optional[String]    $error_log                        = undef,
  Optional[Integer]   $fastcgi_read_timeout             = undef,
  Integer             $fastopen                         = 0, # Global settings
  Integer             $hsts_max_age                     = 31536000,
  Boolean             $http2_enable                     = false,
  Boolean             $http3_enable                     = false,
  Boolean             $http_enable                      = true,
  Boolean             $http_ipv6                        = true,
  Integer             $http_port                        = 80,
  Boolean             $https_enable                     = false,
  Boolean             $https_force                      = false,
  Boolean             $https_ipv6                       = true,
  Integer             $https_port                       = 443,
  Optional[String]    $ip                               = undef,
  Optional[String]    $ipv6                             = undef,
  Optional[String]    $keepalive_request_file           = undef,
  Array               $location_directives              = [],
  Boolean             $location_internal                = false,
  Array               $locations                        = [],
  Array               $php_fpm_directives               = [],
  Boolean             $php_fpm_enable                   = true,
  String              $php_fpm_location                 = '~* \.php$',
  String              $php_fpm_location_inc             = '~* \.php.inc$',
  String              $php_fpm_uri                      = 'unix:/run/php/php-fpm.sock',
  Optional[String]    $redirect_certificate             = undef,
  Optional[String]    $redirect_certificate_key         = undef,
  Optional[String]    $redirect_certificate_trusted     = undef,
  Optional[String]    $redirect_from                    = undef,
  Optional[String]    $redirect_http_port               = undef,
  Optional[String]    $redirect_https_port              = undef,
  Optional[String]    $redirect_ip                      = undef,
  Optional[String]    $redirect_ipv6                    = undef,
  Optional[Array]     $redirect_ssl_ciphers             = undef,
  Optional[String]    $redirect_ssl_protocols           = undef,
  Boolean             $restart_service                  = true,
  Boolean             $reuseport                        = false, # Global settings
  Optional[String]    $server_name                      = undef,
  Optional[Boolean]   $securitytxt_enable               = undef,
  Optional[Array]     $securitytxt_contacts             = undef,
  Optional[String]    $securitytxt_policy               = undef,
  Optional[String]    $securitytxt_encryption           = undef,
  Optional[Array]     $securitytxt_preferred_languages  = undef,
  Optional[Integer]   $securitytxt_expires_days         = undef,
  Optional[Integer]   $ssl_buffer_size                  = undef,
  Optional[String]    $ssl_certificate                  = undef,
  Optional[String]    $ssl_certificate_key              = undef,
  Optional[String]    $ssl_certificate_trusted          = undef,
  Array               $ssl_ciphers                      = [
    'TLS_AES_128_GCM_SHA256',
    'TLS_AES_256_GCM_SHA384',
    'TLS_CHACHA20_POLY1305_SHA256',
    'ECDHE-ECDSA-AES128-GCM-SHA256',
    'ECDHE-RSA-AES128-GCM-SHA256',
    'ECDHE-ECDSA-AES256-GCM-SHA384',
    'ECDHE-RSA-AES256-GCM-SHA384',
    'ECDHE-ECDSA-CHACHA20-POLY1305',
    'ECDHE-RSA-CHACHA20-POLY1305',
    'DHE-RSA-AES128-GCM-SHA256',
    'DHE-RSA-AES256-GCM-SHA384','DHE-RSA-CHACHA20-POLY1305',
  ],
  Optional[String]    $ssl_protocols                    = undef,
  Optional[String]    $ssl_session_cache                = undef,
  Optional[String]    $ssl_session_timeout              = undef,
  Boolean             $ssl_stapling                     = false,
  String              $try_files_custom                 = '$uri/ =404',
  Boolean             $try_files_enable                 = true
) {
  if (defined(Class['nginx'])) {
    # Use the first server_name as the public host for Canonical and fallback contacts.
    if ($server_name != undef and $server_name != '') {
      $securitytxt_server_name = split($server_name, ' ')[0]
    } else {
      $securitytxt_server_name = $name
    }

    # Prefer explicit vhost contacts, then nginx-wide contacts, then monitoring mail.
    if ($securitytxt_contacts != undef) {
      $securitytxt_contacts_real = $securitytxt_contacts
    } elsif ($nginx::securitytxt_contacts != undef) {
      $securitytxt_contacts_real = $nginx::securitytxt_contacts
    } elsif (defined(Class['basic_settings::monitoring'])) {
      # basic_settings::monitoring::mail_to is an address, so add mailto: when needed.
      $securitytxt_contacts_real = $basic_settings::monitoring::mail_to ? {
        /^(mailto:|https:\/\/|tel:)/ => [$basic_settings::monitoring::mail_to],
        default                     => ["mailto:${basic_settings::monitoring::mail_to}"],
      }
    } else {
      # Last resort: use the primary vhost name so the generated Contact is domain-local.
      $securitytxt_contacts_real = ["mailto:info@${securitytxt_server_name}"]
    }

    # Let each vhost opt out, otherwise follow the nginx-wide default.
    if ($securitytxt_enable != undef) {
      $securitytxt_enable_real = $securitytxt_enable
    } else {
      $securitytxt_enable_real = $nginx::securitytxt_enable
    }

    # Optional fields can be set per vhost or inherited from nginx.
    if ($securitytxt_policy != undef) {
      $securitytxt_policy_real = $securitytxt_policy
    } else {
      $securitytxt_policy_real = $nginx::securitytxt_policy
    }

    # Prefer a vhost-specific Encryption URL; otherwise inherit the nginx-wide default.
    if ($securitytxt_encryption != undef) {
      $securitytxt_encryption_real = $securitytxt_encryption
    } else {
      $securitytxt_encryption_real = $nginx::securitytxt_encryption
    }

    # Prefer vhost-specific languages; otherwise use the nginx-wide language list.
    if ($securitytxt_preferred_languages != undef) {
      $securitytxt_preferred_languages_real = $securitytxt_preferred_languages
    } else {
      $securitytxt_preferred_languages_real = $nginx::securitytxt_preferred_languages
    }

    # Prefer a vhost-specific expiry window; otherwise use the nginx-wide value.
    if ($securitytxt_expires_days != undef) {
      $securitytxt_expires_days_real = $securitytxt_expires_days
    } else {
      $securitytxt_expires_days_real = $nginx::securitytxt_expires_days
    }

    # A proxied vhost is detected from the same location_directives used by location /.
    $securitytxt_proxy_pass_directives = filter($location_directives) |$directive| {
      String($directive) =~ /^\s*proxy_pass\s+/
    }
    $securitytxt_proxy_header_directives = filter($location_directives) |$directive| {
      String($directive) =~ /^\s*proxy_set_header\s+/
    }

    # Reuse only the first proxy_pass target and ask the backend for security.txt explicitly.
    if (!empty($securitytxt_proxy_pass_directives)) {
      $securitytxt_proxy_pass_target      = regsubst(
        String($securitytxt_proxy_pass_directives[0]),
        '^\s*proxy_pass\s+([^;\s#]+).*$',
        '\1'
      )
      $securitytxt_proxy_pass_base        = regsubst($securitytxt_proxy_pass_target, '/+$', '')
      $securitytxt_proxy_pass_securitytxt = "${securitytxt_proxy_pass_base}/.well-known/security.txt"
      $securitytxt_proxy_enable           = true
    } else {
      $securitytxt_proxy_pass_target      = undef
      $securitytxt_proxy_pass_base        = undef
      $securitytxt_proxy_pass_securitytxt = undef
      $securitytxt_proxy_enable           = false
    }

    # Preferred-Languages is optional; an empty array simply omits the field.
    if ($securitytxt_preferred_languages_real != undef and !empty($securitytxt_preferred_languages_real)) {
      $securitytxt_languages = join($securitytxt_preferred_languages_real, ',')
    } else {
      $securitytxt_languages = ''
    }

    # Invalid Contact values suppress the managed file instead of failing the catalog.
    $securitytxt_invalid_contacts = filter($securitytxt_contacts_real) |$securitytxt_contact_value| {
      String($securitytxt_contact_value) !~ /^(mailto:|https:\/\/|tel:)/
    }

    # Invalid security.txt input disables the managed fallback instead of failing the catalog.
    $securitytxt_active = (
      $securitytxt_enable_real
      and ($securitytxt_expires_days_real > 0)
      and !empty($securitytxt_contacts_real)
      and empty($securitytxt_invalid_contacts)
    )

    # security.txt canonical always points at the standard well-known URL for this vhost.
    $securitytxt_canonical_real = "https://${securitytxt_server_name}/.well-known/security.txt"

    # Only calculate Expires after validating the configured day count.
    if ($securitytxt_expires_days_real > 0) {
      $securitytxt_expires = (Timestamp() + Timespan("${securitytxt_expires_days_real}-00:00:00")).strftime('%Y-%m-%dT00:00:00Z')
    } else {
      $securitytxt_expires = undef
    }

    # Keep the fallback file namespaced by the Puppet resource title in one flat directory.
    $securitytxt_file = "/etc/nginx/security/${name}-security.txt"

    # Escape the generated path once before using it in the cleanup command.
    $securitytxt_file_shell = stdlib::shell_escape($securitytxt_file)

    # Nginx named locations only get safe identifier characters.
    $securitytxt_location_name = regsubst($name, '[^A-Za-z0-9_]', '_', 'G')

    # Check if TCP fast open is enabled
    if (defined(Class['basic_settings::kernel'])) {
      # Check if valid backlog value is given
      if ($backlog == 0) {
        $backlog_active = true
        $backlog_value = $basic_settings::kernel::connection_max
      } elsif ($backlog > 0) {
        $backlog_active = true
        $backlog_value = $backlog
      } else {
        $backlog_active = false
        $backlog_value = undef
      }

      # Check TCP fast open
      if ($basic_settings::kernel::tcp_fastopen == 3 and $fastopen > 0) {
        $tcp_fastopen = true
      } else {
        $tcp_fastopen = false
      }

      # Check if IPv6 is active
      if ($basic_settings::kernel::ip_version_v6) {
        $http_ipv6_correct = $http_ipv6
        $https_ipv6_correct = $https_ipv6
      } else {
        $http_ipv6_correct = false
        $https_ipv6_correct = false
      }
    } else {
      # Check if valid backlog value is given
      if ($backlog > 0) {
        $backlog_active = true
        $backlog_value = $backlog
      } else {
        $backlog_active = false
        $backlog_value = undef
      }
      $tcp_fastopen = false
      $http_ipv6_correct = $http_ipv6
      $https_ipv6_correct = $https_ipv6
    }

    # Check if HTTP/2 or HTTP/3 is allowed
    if ($https_enable and $ssl_certificate != undef and $ssl_certificate_key != undef) {
      $http2_active = $http2_enable
      if ($ssl_protocols != undef and $ssl_protocols =~ 'TLSv1.3') {
        $http3_active = $http3_enable
      } elsif ($nginx::ssl_protocols =~ 'TLSv1.3') {
        $http3_active = $http3_enable
      } else {
        $http3_active = false
      }

      # Check if redirect_certificate is not given
      if ($redirect_certificate != undef and $redirect_certificate_key != undef) {
        $redirect_certificate_correct = $redirect_certificate
        $redirect_certificate_key_correct = $redirect_certificate_key
      } else {
        $redirect_certificate_correct = $ssl_certificate
        $redirect_certificate_key_correct = $ssl_certificate_key
      }
    } else {
      $http2_active = false
      $http3_active = false
      $redirect_certificate_correct = undef
      $redirect_certificate_key_correct = undef
    }

    # Split server_name from by space, we need only the first in template to use as a redirect
    if ($redirect_from and $redirect_from != '') {
      $redirect_to = split($server_name, ' ')[0]
    }

    # Set IPv4
    if ($redirect_ip == undef) {
      $redirect_ip_correct = $ip
    } else {
      $redirect_ip_correct = $redirect_ip
    }

    # Set IPv6
    if ($redirect_ipv6 == undef) {
      $redirect_ipv6_correct = $ipv6
    } else {
      $redirect_ipv6_correct = $redirect_ipv6
    }

    # Set HTTP port
    if ($redirect_http_port == undef) {
      $redirect_http_port_correct = $http_port
    } else {
      $redirect_http_port_correct = $redirect_http_port
    }

    # Check if the HTTP port are the same
    if ($redirect_http_port_correct == $http_port) {
      $redirect_http_options = false
    } else {
      $redirect_http_options = true
    }

    # Set HTTP port
    if ($redirect_https_port == undef) {
      $redirect_https_port_correct = $https_port
    } else {
      $redirect_https_port_correct = $redirect_https_port
    }

    # Check if the HTTP port are the same
    if ($redirect_https_port_correct == $https_port) {
      $redirect_https_options = false
    } else {
      $redirect_https_options = true
    }

    # Set SSL protocols
    if ($redirect_ssl_protocols == undef) {
      $redirect_ssl_protocols_correct = $ssl_protocols
    } else {
      $redirect_ssl_protocols_correct = $redirect_ssl_protocols
    }

    # Set SSL ciphers
    $ssl_ciphers_correct = join($ssl_ciphers, ':')
    if ($redirect_ssl_ciphers == undef) {
      $redirect_ssl_ciphers_correct = $ssl_ciphers_correct
    } else {
      $redirect_ssl_ciphers_correct = join($redirect_ssl_ciphers, ':')
    }

    # Inform nginx when file is changed or created
    if ($restart_service) {
      file { "/etc/nginx/conf.d/${name}.conf":
        ensure  => file,
        content => template('nginx/server.conf'),
        owner   => 'root',
        group   => 'root',
        mode    => '0600',
        notify  => Service['nginx'],
      }
    } else {
      file { "/etc/nginx/conf.d/${name}.conf":
        ensure  => file,
        content => template('nginx/server.conf'),
        owner   => 'root',
        group   => 'root',
        mode    => '0600',
      }
    }

    # Rebuild security.txt after the vhost config changes by removing the stale fallback first.
    if ($securitytxt_active) {
      exec { "nginx_securitytxt_remove_${name}":
        command     => "/bin/rm -f ${securitytxt_file_shell}",
        refreshonly => true,
        subscribe   => File["/etc/nginx/conf.d/${name}.conf"],
      }

      # The file resource creates missing files; replace false prevents daily Expires churn.
      file { $securitytxt_file:
        ensure  => file,
        owner   => 'root',
        group   => 'root',
        mode    => '0644',
        content => template('nginx/security.txt'),
        replace => false,
        require => [File['nginx_security'], Exec["nginx_securitytxt_remove_${name}"]],
      }
    } else {
      # Remove stale fallback files when security.txt is disabled or input is invalid.
      file { $securitytxt_file:
        ensure  => absent,
        require => File['nginx_security'],
      }
    }
  } else {
    fail('The nginx class must be included before using the nginx::server defined type.')
  }
}
