class naemon () {
  if (defined(Package['openitcockpit'])) {
    package { 'openitcockpit-naemon':
      ensure          => installed,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
      require         => Package['openitcockpit'],
    }
  }
}
