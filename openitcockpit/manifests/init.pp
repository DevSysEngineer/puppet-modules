class openitcockpit (
  Optional[String] $install_dir    = undef,
  Optional[String] $webserver_uid  = undef,
  Optional[String] $webserver_gid  = undef
) {
  # Try to get uid and gid
  $nginx_enable = defined(Class['nginx'])
  $php_fpm_enable = defined(Class['php8::fpm'])
  if ($webserver_uid == undef or $webserver_gid == undef) {
    if ($nginx_enable) {
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

  # Check if sudo package is not defined
  if (!defined(Package['sudo'])) {
    package { 'sudo':
      ensure          => installed,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
    }
  }

  # Create sudoers file
  file { '/etc/sudoers.d/openitc_cake':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0440',
    content => "# Managed by puppet\nCmnd_Alias OPENITC_CAKE_CMD = /opt/openitc/frontend/bin/cake *\nDefaults!OPENITC_CAKE_CMD root_sudo\nroot ALL = (ALL) SETENV: OPENITC_CAKE_CMD\n",
    require => Package['sudo'],
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
    if ($php_fpm_enable) {
      $requirements = [File['/opt/openitc'], Class['php8::fpm']]
    } else {
      $requirements = File['/opt/openitc']
    }
  } else {
    # Set requirements
    $install_dir_correct = '/opt/openitc'
    if ($php_fpm_enable) {
      $requirements = Class['php8::fpm']
    } else {
      $requirements = undef
    }
  }

  # Setup openitcockpit
  exec { 'openitcockpit_setup':
    command     => '/opt/openitc/frontend/SETUP.sh',
    refreshonly => true,
  }

  # Install package
  package { ['openitcockpit', 'openitcockpit-monitoring-plugins']:
    ensure          => installed,
    install_options => ['--no-install-recommends', '--no-install-suggests'],
    #notify          => Exec['openitcockpit_setup'],
    require         => $requirements,
  }

  # Check if nginx is enabled
  if ($nginx_enable) {
    $nginx_config = '/etc/nginx/sites-available/openitc'
    file { $nginx_config:
      ensure  => file,
      replace => false,
      owner   => 'root',
      group   => 'root',
      mode    => '0600',
    }

    # Create symlink
    file { '/etc/nginx/conf.d/openitc':
      ensure  => 'link',
      target  => $nginx_config,
      force   => true,
      require => File[$nginx_config],
    }
  }

  # Check if php FPM is enabled
  if ($php_fpm_enable) {
    php8::fpm_pool { 'oitc':
      listen => '/run/php/php-fpm-oitc.sock',
    }
  }
}
