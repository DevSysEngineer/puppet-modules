define basic_settings::security_audit (
  Enum['present','absent']  $ensure                     = present,
  Integer                   $order                      = 25,
  Array                     $rule_options               = [],
  Array                     $rule_suspicious_packages   = [],
  Array                     $rules                      = []
) {
  # Enable auditd service
  if (!defined(Service['auditd'])) {
    service { 'auditd':
      ensure  => true,
      enable  => true,
      require => Package['auditd'],
    }

    # Create service check
    if (defined(Class['basic_settings::monitoring']) and $basic_settings::monitoring::package != 'none') {
      basic_settings::monitoring_service { 'auditd': }
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
