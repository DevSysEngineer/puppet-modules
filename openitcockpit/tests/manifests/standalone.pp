# Supply the shared sudo prerequisite without the full server baseline.
include basic_settings::login

# The server helper requires these real command packages.
stdlib::ensure_packages(['coreutils', 'grep'], {
  'ensure'          => 'installed',
  'install_options' => ['--no-install-recommends', '--no-install-suggests'],
})

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
