include rabbitmq
include rabbitmq::tcp

# Management also declares its plugin, default vhost, user and permissions.
class { 'rabbitmq::management':
  admin_password => $facts['compile_test_password'],
}

# Create the exchange used by the binding below.
rabbitmq::management_exchange { 'app': }

# Create the queue used by the binding below.
rabbitmq::management_queue { 'app': }

# Bind the synthetic exchange to its queue.
rabbitmq::management_binding { 'app':
  destination => 'app',
  source      => 'app',
}
