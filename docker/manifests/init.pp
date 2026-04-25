class docker (
  Enum['ce'] $edition = 'ce',
) {
  # Determine the correct package name based on the edition
  case $edition {
    'ce': {
      $package_name = 'docker-ce'
    }
    default: {
      fail("Unsupported docker edition: ${edition}")
    }
  }

  # Install docker
  package { 'docker':
    ensure          => installed,
    name            => $package_name,
    install_options => ['--no-install-recommends', '--no-install-suggests'],
  }
}
