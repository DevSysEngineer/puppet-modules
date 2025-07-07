class nrdp (
  Sensitive[Array]  $tokens,
  Boolean           $https_force    = true,
  Optional[String]  $webserver_uid  = undef,
  Optional[String]  $webserver_gid  = undef
) {
  # Try to get uuid and gid
  if ($webserver_uid == undef or $webserver_gid == undef) {
    if (defined(Class['naemon'])) {
      $webserver_uid_correct = $naemon::webserver_uid_correct
      $webserver_gid_correct = $naemon::webserver_gid_correct
    } else {
      $webserver_uid_correct = undef
      $webserver_gid_correct = undef
    }
  } else {
    $webserver_uid_correct = $webserver_uid
    $webserver_gid_correct = $webserver_gid
  }

  # Check if webserver uid and gid are defined
  if ($webserver_uid_correct != undef and $webserver_gid_correct != undef) {
    # Set variables
    $install_dir = '/var/www/nrdp'
    $download_url = 'https://api.github.com/repos/NagiosEnterprises/nrdp/releases/latest'
    $tokens_correct = join($tokens, "','")

    # Install coreutils package
    if (!defined(Package['coreutils'])) {
      package { 'coreutils':
        ensure          => installed,
        install_options => ['--no-install-recommends', '--no-install-suggests'],
      }
    }

    # Install curl package
    if (!defined(Package['curl'])) {
      package { 'curl':
        ensure          => installed,
        install_options => ['--no-install-recommends', '--no-install-suggests'],
      }
    }

    # Install rsync package
    if (!defined(Package['rsync'])) {
      package { 'rsync':
        ensure          => installed,
        install_options => ['--no-install-recommends', '--no-install-suggests'],
      }
    }

    # Install system package
    if (!defined(Package['findutils'])) {
      package { 'findutils':
        ensure          => installed,
        install_options => ['--no-install-recommends', '--no-install-suggests'],
      }
    }

    # Install sed package
    if (!defined(Package['sed'])) {
      package { 'sed':
        ensure          => installed,
        install_options => ['--no-install-recommends', '--no-install-suggests'],
      }
    }

    # Install unzip package
    if (!defined(Package['unzip'])) {
      package { 'unzip':
        ensure          => installed,
        install_options => ['--no-install-recommends', '--no-install-suggests'],
      }
    }

    # Download latest NRDP release
    exec { 'nrdp_download_latest':
      command => "/usr/bin/curl -s ${download_url} | /bin/sed -n 's/.*\"browser_download_url\": \"\\(.*nrdp.*zip\\)\".*/\\1/p' | /usr/bin/head -n1 | /usr/bin/xargs -I{} /usr/bin/curl -L -o /tmp/nrdp.zip {}",
      onlyif  => "test ! -d ${install_dir}/server",
      require => Package['coreutils', 'curl', 'findutils', 'sed'],
    }

    # Extract zip dir
    exec { 'nrdp_extract':
      command => "/usr/bin/unzip -q /tmp/nrdp.zip -d /tmp && /bin/rsync -a --delete /tmp/nrdp*/ ${install_dir}/ && /bin/rm -rf /tmp/nrdp*",
      creates => "${install_dir}/server/index.php",
      require => [Exec['nrdp_download_latest'], Package['rsync', 'unzip']],
    }

    # Permissions
    file { 'nrdp_permissions':
      ensure  => directory,
      path    => $install_dir,
      owner   => $webserver_uid_correct,
      group   => $webserver_gid_correct,
      recurse => true,
      require => Exec['nrdp_extract'],
    }

    # Create config file
    file { 'nrdp_config':
      ensure  => file,
      path    => "${install_dir}/server/config.inc.php",
      owner   => $webserver_uid_correct,
      group   => $webserver_gid_correct,
      mode    => '0640',
      content => Sensitive.new(template('nrdp/config.inc.php')),
      require => File['nrdp_permissions'],
    }
  } else {
    fail('webserver_uid and webserver_gid must be defined')
  }
}
