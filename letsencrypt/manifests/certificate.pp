define letsencrypt::certificate (
  Array                       $domains,
  Enum['present','absent']    $ensure     = present,
  String                      $plugin     = 'nginx',
) {
  if (defined(Class['letsencrypt'])) {
    # Try to get require
    case $plugin {
      'nginx': {
        $require = [Package['certbot'], Package['grep'], Package['python3-certbot-nginx']]
      }
      default: {
        $require = [Package['certbot'], Package['grep']]
      }
    }

    # Set binary
    $cerbot_bin = '/usr/bin/certbot'

    # Escape certbot command arguments before using them in exec commands and guards.
    $cerbot_bin_shell = stdlib::shell_escape($cerbot_bin)
    $plugin_shell = stdlib::shell_escape($plugin)
    $name_shell = stdlib::shell_escape($name)

    # Run command based on ensure
    case $ensure {
      'present': {
        # Convert array to string
        $domain_sort = $domains.sort();
        $domain_list_find = join($domain_sort, ' ')

        # Escape domain arguments and grep pattern before certbot commands use them.
        $domain_args_shell = join($domain_sort.map |$domain| { "-d ${stdlib::shell_escape($domain)}" }, ' ')
        $domain_find_shell = stdlib::shell_escape("Domains: ${domain_list_find}")

        # Check if fullchain.pem and privkey.pem exists
        exec { "letsencrypt_certificate_${name}":
          command => "${cerbot_bin_shell} run --${plugin_shell} -n --cert-name ${name_shell} ${domain_args_shell}",
          unless  => "${cerbot_bin_shell} certificates -n --cert-name ${name_shell} | /usr/bin/grep ${domain_find_shell}",
          require => $require,
        }
      }
      'absent': {
        # Escape the certificate name grep pattern before checking certbot output.
        $certificate_name_find_shell = stdlib::shell_escape("Certificate Name: ${name}")

        # Delete fullchain.pem and privkey.pem
        exec { "letsencrypt_certificate_${name}":
          command => "${cerbot_bin_shell} delete --${plugin_shell} --cert-name ${name_shell}",
          onlyif  => "${cerbot_bin_shell} certificates -n --cert-name ${name_shell} | /usr/bin/grep ${certificate_name_find_shell}",
          require => $require,
        }
      }
      default: {
        fail('Unknown ensure: $ensure, must be present or absent')
      }
    }
  } else {
    fail('Class lletsencryptet is not defined, but is required for letsencrypt::certificate')
  }
}
