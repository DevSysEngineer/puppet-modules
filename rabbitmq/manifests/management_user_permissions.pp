define rabbitmq::management_user_permissions (
  String $user,
  String $configure   = '.*',
  String $read        = '.*',
  String $vhost       = '/',
  String $write       = '.*'
) {
  if (defined(Class['rabbitmq::management'])) {
    # Get vhost name
    if ($vhost == '/') {
      $vhost_name = 'default'
    } else {
      $vhost_name = $vhost
    }

    # Escape permission arguments before passing them to rabbitmqctl and grep.
    $vhost_shell = stdlib::shell_escape($vhost)
    $user_shell = stdlib::shell_escape($user)
    $configure_shell = stdlib::shell_escape($configure)
    $write_shell = stdlib::shell_escape($write)
    $read_shell = stdlib::shell_escape($read)
    $permissions_pattern_shell = stdlib::shell_escape("${vhost}${configure}${write}${read}")

    # Set permissions
    exec { "rabbitmq_management_user_${user}_permissions_${vhost_name}":
      command => "/usr/sbin/rabbitmqctl --quiet set_permissions -p ${vhost_shell} ${user_shell} ${configure_shell} ${write_shell} ${read_shell}",
      unless  => "/usr/sbin/rabbitmqctl --quiet list_user_permissions --no-table-headers ${user_shell} | /usr/bin/tr -d '\t' | /usr/bin/grep ${permissions_pattern_shell}", #lint:ignore:140chars
      require => [
        Package['coreutils'],
        Package['grep'],
        Exec["rabbitmq_management_vhost_${vhost_name}"],
        Exec["rabbitmq_management_user_${user}"]
      ],
    }
  } else {
    fail('The rabbitmq::management class must be included before using the rabbitmq::management_user_permissions defined type.')
  }
}
