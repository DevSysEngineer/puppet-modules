class basic_settings::package_node (
  Boolean $enable,
  Integer $version = 20
) {
  # Set default value
  $file = '/etc/apt/sources.list.d/nodesource.list'

  if ($enable) {
    # Install source list
    exec { 'source_nodejs':
      command => "/usr/bin/bash -c 'umask 22; /usr/bin/curl -fsSL https://deb.nodesource.com/setup_${version}.x | bash -'",
      unless  => "[ -e ${file} ]",
      notify  => Exec['package_node_source_reload'],
      require => [Package['apt'], Package['curl']],
    }

    # Install nodejs package
    package { 'nodejs':
      ensure          => installed,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
      require         => Exec['source_nodejs'],
    }

    # Create list of packages that is suspicious
    $suspicious_packages = ['/usr/local/npm']

    # Setup audit rules
    if (defined(Package['auditd'])) {
      basic_settings::security_audit { 'node':
        rule_suspicious_packages => $suspicious_packages,
      }
    }
  } else {
    # Remove nodejs package
    package { 'nodejs':
      ensure  => purged,
    }

    # Remove nodejs repo
    exec { 'source_nodejs':
      command => "/usr/bin/bash -c '/usr/bin/rm ${file} && /usr/bin/apt-get update'",
      onlyif  => "[ -e ${file} ]",
      require => [Package['apt'], Package['nodejs']],
    }
  }
}
