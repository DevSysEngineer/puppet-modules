class naemon (

) {
  package { 'naemon':
    ensure          => installed,
    install_options => ['--no-install-recommends', '--no-install-suggests'],
  }
}
