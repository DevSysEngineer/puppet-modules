class openitcockpit (
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

  # Install package
  package { 'openitcockpit':
    ensure          => installed,
    install_options => ['--no-install-recommends', '--no-install-suggests'],
  }
}
