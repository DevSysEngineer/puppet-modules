define basic_settings::login_sudo (
  String $rule,
) {
  # Check if sudo package is not defined
  if (!defined(Package['sudo'])) {
    package { 'sudo':
      ensure          => installed,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
    }
  }

  # Creeate condif file
  file { "/etc/sudoers.d/${name}":
    ensure  => file,
    mode    => '0440',
    owner   => 'root',
    group   => 'root',
    content => "${rule}\n",
    require => Package['sudo'],
  }
}
