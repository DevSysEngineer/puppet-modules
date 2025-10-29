define basic_settings::login_sudo (
  String  $rule,
  Integer $order = 25,
) {
  # Check if login class is not defined
  if (!defined(Class['basic_settings::login'])) {
    # Set values
    $prefix = $basic_settings::login::sudoers_prefix

    # Install sudo package
    package { 'sudo':
      ensure          => installed,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
    }
  } else {
    $prefix = 'z'
  }

  # Create config file
  file { "/etc/sudoers.d/${prefix}${order}-${name}":
    ensure  => file,
    mode    => '0440',
    owner   => 'root',
    group   => 'root',
    content => "# Managed by puppet\n${rule}\n",
    require => Package['sudo'],
  }
}
