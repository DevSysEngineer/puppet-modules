class openitcockpit (
  Optional[String] $install_dir    = undef,
  Optional[String] $webserver_uid  = undef,
  Optional[String] $webserver_gid  = undef
) {
  # Try to get uid and gid
  if ($webserver_uid == undef or $webserver_gid == undef) {
    if (defined(Class['nginx'])) {
      $webserver_uid_correct = $nginx::run_user
      $webserver_gid_correct = $nginx::run_group
    } else {
      $webserver_uid_correct = undef
      $webserver_gid_correct = undef
    }
  } else {
    $webserver_uid_correct = $webserver_uid
    $webserver_gid_correct = $webserver_gid
  }

  # Check if installation dir is given
  if ($install_dir != undef) {
    # Create directory
    $install_dir_correct = $install_dir
    file { 'openitcockpit_install_dir':
      ensure => directory,
      path   => $install_dir,
      owner  => 'root',
      group  => 'root',
      mode   => '0755', # Important for internal scripts
    }

    # Create symlink
    file { '/opt/openitc':
      ensure  => 'link',
      target  => $install_dir,
      force   => true,
      require => File['openitcockpit_install_dir'],
    }

    # Set requirements
    $requirements = File['/opt/openitc']
  } else {
    # Set requirements
    $install_dir_correct = '/opt/openitc'
    $requirements = undef
  }

  # Install package
  package { 'openitcockpit':
    ensure          => installed,
    install_options => ['--no-install-recommends', '--no-install-suggests'],
    require         => $requirements,
  }
}
