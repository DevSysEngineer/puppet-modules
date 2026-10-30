class { 'basic_settings':
  kernel_flavor     => 'nvidia',
  kernel_version    => '7.0.0-1019-nvidia',
  nvidia_dgx_enable => true,
}

# Compile the driver class with one representative version pin.
class { 'nvidia':
  pinning => 580,
}
