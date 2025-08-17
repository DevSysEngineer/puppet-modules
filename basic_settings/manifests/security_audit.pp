define basic_settings::security_audit (
  Enum['present','absent']  $ensure                     = present,
  Integer                   $order                      = 25,
  Array                     $rule_options               = [],
  Array                     $rule_suspicious_packages   = [],
  Array                     $rules                      = []
) {
  # Check if auditd package is not defined
  if (!defined(Package['auditd'])) {
    package { 'auditd':
      ensure          => installed,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
    }
  }

  # Enable auditd service
  if (!defined(Service['auditd'])) {
    service { 'auditd':
      ensure  => true,
      enable  => true,
      require => Package['auditd'],
    }
  }

  # Create audit rule dir */
  if (!defined(File['/etc/audit/rules.d'])) {
    file { '/etc/audit/rules.d':
      ensure  => directory,
      recurse => true,
      force   => true,
      purge   => true,
      mode    => '0700',
      require => Package['auditd'],
    }
  }

  # Create rule file
  file { "/etc/audit/rules.d/${order}-${title}.rules":
    ensure  => $ensure,
    content => template('basic_settings/security/custom.rules'),
    owner   => 'root',
    group   => 'root',
    mode    => '0600',
    notify  => Service['auditd'],
    require => File['/etc/audit/rules.d'],
  }
}
