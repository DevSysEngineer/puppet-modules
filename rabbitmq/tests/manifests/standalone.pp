include rabbitmq

# Exercise MQTT and AMQP with the same synthetic certificate paths.
class { 'rabbitmq::tcp':
  ssl_ca_certificate  => '/etc/rabbitmq/ssl/ca.pem',
  ssl_certificate     => '/etc/rabbitmq/ssl/cert.pem',
  ssl_certificate_key => '/etc/rabbitmq/ssl/key.pem',
}

# Management also declares its plugin, default vhost, user and permissions.
class { 'rabbitmq::management':
  admin_password => $facts['compile_test_password'],
}

# MQTT reuses the TLS options and creates its vhost through management, so it follows both.
include rabbitmq::mqtt

# Create the exchange used by the binding below.
rabbitmq::management::exchange { 'app': }

# Create the queue used by the binding below.
rabbitmq::management::queue { 'app': }

# Bind the synthetic exchange to its queue.
rabbitmq::management::binding { 'app':
  destination => 'app',
  source      => 'app',
}
