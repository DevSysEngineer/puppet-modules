include basic_settings

class { 'gitlab':
  root_password => $facts['compile_test_password'],
}

include gitlab::config
