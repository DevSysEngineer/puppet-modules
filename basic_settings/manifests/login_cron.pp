define basic_settings::login_cron (
  String $user,
  String $order = '10'
) {
  if (!defined(Concat['/etc/cron.allow'])) {
    concat { '/etc/cron.allow':
      owner => 'root',
      group => 'root',
      mode  => '0600',
    }
  }

  # Create fragment for each user
  concat::fragment { "cron_allow_${name}":
    target  => '/etc/cron.allow',
    content => "${name}\n",
    order   => $order,
  }
}
