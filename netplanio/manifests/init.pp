class netplanio (
) {
  # Check if we have systemd
  if (defined(Package['netplan.io'])) {
    # Install netplan.io package
    package { 'netplan.io':
      ensure          => installed,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
    }
  }
}
