class openitcockpit (
  Optional[String] $install_dir    = undef,
  Optional[String] $ssl_certificate        = undef,
  Optional[String] $ssl_certificate_key    = undef,
  Optional[String] $webserver_uid  = undef,
  Optional[String] $webserver_gid  = undef,
) {
  # Set some values
  $log_dir = '/var/log/openitc'
  $lib_dir = '/var/lib/openitc'
  $nginx_enable = defined(Class['nginx'])
  $php_fpm_enable = defined(Class['php8::fpm'])

  # Try to get uid and gid
  if ($webserver_uid == undef or $webserver_gid == undef) {
    if ($nginx_enable) {
      $webserver_uid_correct = $nginx::run_user
      $webserver_gid_correct = $nginx::run_group
    } else {
      $webserver_uid_correct = 'www-data'
      $webserver_gid_correct = 'www-data'
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
  } else {
    # Create directory
    $install_dir_correct = '/opt/openitc'
    file { $install_dir_correct:
      ensure => directory,
      owner  => 'root',
      group  => 'root',
      mode   => '0755', # Important for internal scripts
    }
  }

  # Set requirements
  if ($php_fpm_enable) {
    $requirements = [File['/opt/openitc'], Class['php8::fpm']]
  } else {
    $requirements = File['/opt/openitc']
  }

  # Create dirs
  file { [
      '/opt/openitc/etc',
      '/opt/openitc/etc/mod_gearman',
      '/opt/openitc/etc/mysql',
      '/opt/openitc/etc/nagios',
      '/opt/openitc/etc/statusengine',
      '/opt/openitc/frontend',
      '/opt/openitc/nagios',
      $lib_dir,
      "${lib_dir}/frontend",
      "${lib_dir}/frontend/tmp",
      "${lib_dir}/nagios",
      "${lib_dir}/nagios/var",
      "${lib_dir}/var",
      $log_dir,
    ]:
      ensure  => directory,
      owner   => 'root',
      group   => 'root',
      mode    => '0755', # Important for internal scripts
      require => $requirements,
  }

  # Create symlink
  file { '/opt/openitc/frontend/tmp':
    ensure  => 'link',
    target  => "${lib_dir}/frontend/tmp",
    force   => true,
    require => File["${lib_dir}/frontend/tmp"],
  }

  # Create symlink
  file { '/opt/openitc/nagios/var':
    ensure  => 'link',
    target  => "${lib_dir}/nagios/var",
    force   => true,
    require => File["${lib_dir}/nagios/var"],
  }

  # Create symlink
  file { '/opt/openitc/var':
    ensure  => 'link',
    target  => "${lib_dir}/var",
    force   => true,
    require => File["${lib_dir}/var"],
  }

  # Create symlink
  file { '/opt/openitc/logs':
    ensure  => 'link',
    target  => $log_dir,
    force   => true,
    require => File[$log_dir],
  }

  # Install package
  package { ['openitcockpit', 'openitcockpit-frontend-angular', 'openitcockpit-module-grafana', 'openitcockpit-monitoring-plugins']:
    ensure          => installed,
    install_options => ['--no-install-recommends', '--no-install-suggests'],
    require         => File['/opt/openitc/logs'],
  }

  # Create mod_gearman_neb config file
  file { '/opt/openitc/etc/mod_gearman/mod_gearman_neb.conf':
    ensure  => file,
    replace => false,
    owner   => 'root',
    group   => $webserver_gid_correct,
    mode    => '0644',
    require => File['/opt/openitc/etc/mod_gearman'],
  }

  # Create nagios config file
  file { '/opt/openitc/etc/nagios/nagios.cfg':
    ensure  => file,
    replace => false,
    owner   => 'root',
    group   => $webserver_gid_correct,
    mode    => '0644',
    require => File['/opt/openitc/etc/nagios'],
  }

  # Create statusengine config file
  file { '/opt/openitc/etc/statusengine/statusengine.toml':
    ensure  => file,
    replace => false,
    owner   => 'root',
    group   => $webserver_gid_correct,
    mode    => '0644',
    require => File['/opt/openitc/etc/statusengine'],
  }

  # Create openitc directory
  file { '/etc/nginx/openitc':
    ensure  => directory,
    owner   => 'root',
    group   => 'root',
    mode    => '0700',
    require => Package['openitcockpit'],
  }

  # Get SSL content
  if ($ssl_certificate != undef and $ssl_certificate_key != undef) {
    $ssl_content = template('openitcockpit/nginx/ssl_cert.conf')
  } else {
    $ssl_content = ''
  }

  # Create SSL config file
  file { '/etc/nginx/openitc/ssl_cert.conf':
    ensure  => file,
    content => $ssl_content,
    owner   => 'root',
    group   => 'root',
    mode    => '0600',
    require => File['/etc/nginx/openitc'],
  }

  # Check if php FPM is enabled
  if ($php_fpm_enable) {
    php8::fpm_pool { 'oitc':
      listen => '/run/php/php-fpm-oitc.sock',
    }
  }
}
