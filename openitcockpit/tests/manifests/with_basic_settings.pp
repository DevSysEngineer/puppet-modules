include basic_settings

include openitcockpit

# Use a complete synthetic push configuration.
class { 'openitcockpit::agent':
  push_apikey => Sensitive($facts['compile_test_password']),
  push_enable => true,
  push_url    => 'https://monitoring.example.test',
}
include openitcockpit::agent_mirth_connect

class { 'openitcockpit::server':
  grafana_password => Sensitive($facts['compile_test_password']),
}
