class { 'basic_settings':
  cluster_id        => 'gpu',
  kernel_flavor     => 'nvidia',
  kernel_version    => '7.0.0-1019-nvidia',
  nvidia_dgx_enable => true,
}

# Compile Persistence Mode against a custom system target after the platform prerequisites.
class { 'nvidia':
  pinning => 580,
  require => [
    Class['basic_settings::kernel', 'basic_settings::packages::nvidia_dgx'],
    Exec['basic_settings_source_reload'],
  ],
}
