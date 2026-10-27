class { 'basic_settings':
  nvidia_dgx_enable => true,
}

# Compile the driver class with one representative version pin.
class { 'nvidia':
  pinning => 580,
}
