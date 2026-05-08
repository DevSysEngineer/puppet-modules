define rabbitmq::plugin (
  Optional[Type] $notify_target = undef,
) {
  if (defined(Class['rabbitmq'])) {
    # Escape the plugin name before building the enable command and guard.
    $name_shell = stdlib::shell_escape($name)

    # Escape the complete enable script before passing it to bash -c.
    $enable_script_shell = stdlib::shell_escape("(umask 133 && /usr/sbin/rabbitmq-plugins --quiet enable ${name_shell})")

    # Setup the plugin
    exec { "rabbitmq_plugin_${name}":
      command => "/usr/bin/bash -c ${enable_script_shell}", # Important for rabbitmq to keep unmask 133
      unless  => "/usr/sbin/rabbitmq-plugins --quiet is_enabled ${name_shell}",
      notify  => $notify_target,
      require => Package['rabbitmq-server'],
    }

    # Create enabled plugins file
    if (!defined(File['rabbitmq_plugin_enable'])) {
      file { 'rabbitmq_plugin_enable':
        ensure  => file,
        path    => '/etc/rabbitmq/enabled_plugins',
        owner   => 'rabbitmq',
        group   => 'rabbitmq',
        mode    => '0600',
        replace => false,
        notify  => Service['rabbitmq-server'],
        require => Exec["rabbitmq_plugin_${name}"],
      }
    }
  } else {
    fail('The rabbitmq class must be included before using the rabbitmq::plugin defined type.')
  }
}
