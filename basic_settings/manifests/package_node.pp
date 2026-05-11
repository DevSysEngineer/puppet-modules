# @summary Manages the NodeSource APT repository and Node.js package.
#
# This private helper writes or removes the NodeSource APT source and signing
# key, installs or purges `nodejs`, refreshes APT on repository changes, and adds
# audit coverage for npm-related tooling when auditd is present.
#
# @example Internal use from basic_settings
#   class { 'basic_settings::package_node':
#     enable  => true,
#     version => 20,
#   }
#
# @param enable
#   Creates the repository, imports its key, and installs Node.js when `true`;
#   removes them when `false`.
#
# @param version
#   Node.js major version used in the NodeSource repository URL. The default is
#   20.
#
# @api private
class basic_settings::package_node (
  Boolean $enable,
  Integer $version = 20
) {
  # Set default value
  $file = '/etc/apt/sources.list.d/nodesource.list'
  $key = '/usr/share/keyrings/nodesource.gpg'
  $source = "deb [signed-by=${key}] https://deb.nodesource.com/node_${version}.x nodistro main\n"

  # Escape the keyring path before tee, chmod, and guard commands use it.
  $key_shell = stdlib::shell_escape($key)

  # Refresh the APT cache only after the managed repo state changes.
  exec { 'package_node_source_reload':
    command     => '/usr/bin/apt-get update',
    refreshonly => true,
    require     => Package['apt'],
  }

  if ($enable) {
    # Manage the NodeSource APT source explicitly instead of executing an upstream shell bootstrap.
    file { 'package_node_source':
      ensure  => file,
      path    => $file,
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      content => "# Managed by puppet\n${source}",
      notify  => Exec['package_node_source_reload'],
      require => Package['apt'],
    }

    # Download and install the repository signing key in a dedicated keyring file.
    exec { 'package_node_key':
      command => "/usr/bin/curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor | tee ${key_shell} >/dev/null; chmod 644 ${key_shell}", #lint:ignore:140chars
      unless  => "/usr/bin/test -e ${key_shell}",
      notify  => Exec['package_node_source_reload'],
      require => [Package['apt'], Package['apt-transport-https'], Package['curl'], Package['gnupg']],
    }

    # Install Node.js only after the managed source and key have been applied.
    package { 'nodejs':
      ensure          => installed,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
      require         => [File['package_node_source'], Exec['package_node_key'], Exec['package_node_source_reload']],
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

    # Remove the managed NodeSource repo file when the feature is disabled.
    file { 'package_node_source':
      ensure  => absent,
      path    => $file,
      notify  => Exec['package_node_source_reload'],
      require => [Package['apt'], Package['nodejs']],
    }

    # Remove the matching keyring so the disabled repo leaves no trusted signing material behind.
    file { 'package_node_key':
      ensure  => absent,
      path    => $key,
      notify  => Exec['package_node_source_reload'],
      require => [Package['apt'], Package['nodejs']],
    }
  }
}
