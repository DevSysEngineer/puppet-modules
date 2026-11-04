# Compile vendor boot activation without the shared systemd classes, preserving caller APT options.
class { 'nvidia':
  pinning         => 580,
  install_options => ['--assume-yes'],
}
