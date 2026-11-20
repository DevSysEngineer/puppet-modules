# @summary Enables RabbitMQ MQTT over TLS.
#
# This class requires `rabbitmq::management` and `rabbitmq::tcp` with a complete certificate set. It enables the
# `rabbitmq_mqtt` plugin, creates the MQTT vhost and writes `/etc/rabbitmq/conf.d/mqtt.conf`. The TLS listener reuses
# the TLS options from `rabbitmq::tcp`, so declare both classes first. Anonymous access is disabled and the plain
# listener stays off unless `tcp_enable` is set. Grant MQTT users permissions on the vhost with
# `rabbitmq::management::user`. Removing this class does not disable an already enabled plugin.
#
# @example Enable MQTT over TLS
#   include rabbitmq
#
#   # Provide the TLS options that the MQTT listener reuses.
#   class { 'rabbitmq::tcp':
#     ssl_ca_certificate  => '/etc/rabbitmq/ssl/ca.pem',
#     ssl_certificate     => '/etc/rabbitmq/ssl/cert.pem',
#     ssl_certificate_key => '/etc/rabbitmq/ssl/key.pem',
#   }
#
#   # Management creates the MQTT vhost.
#   class { 'rabbitmq::management':
#     admin_password => lookup('rabbitmq::admin_password'),
#   }
#
#   include rabbitmq::mqtt
#
# @param exchange
#   Topic exchange that MQTT messages are published to.
#
# @param prefetch
#   Maximum number of unacknowledged messages delivered to an MQTT subscriber.
#
# @param ssl_port
#   MQTT TLS listener port.
#
# @param tcp_enable
#   Enables the unencrypted MQTT listener on `tcp_port` next to TLS. Clients then send credentials in plain text, so
#   only enable it on trusted networks. `false` writes `mqtt.listeners.tcp = none`.
#
# @param tcp_port
#   Plain MQTT listener port, used only when `tcp_enable` is `true`.
#
# @param vhost
#   Vhost that MQTT connections use. The class creates it with `rabbitmq::management::vhost` unless that vhost is
#   already declared earlier in the catalog.
#
# @api public
class rabbitmq::mqtt (
  String  $exchange   = 'amq.topic',
  Integer $prefetch   = 10,
  Integer $ssl_port   = 8883,
  Boolean $tcp_enable = false,
  Integer $tcp_port   = 1883,
  String  $vhost      = 'mqtt',
) {
  # Require the AMQP TLS setup whose options MQTT reuses and the management interface that creates the vhost.
  if (defined(Class['rabbitmq::management']) and defined(Class['rabbitmq::tcp'])) {
    # MQTT always serves TLS, so it needs the complete AMQP certificate set.
    if ($rabbitmq::tcp::tls_allow) {
      # Enable the MQTT plugin before writing its listener configuration.
      rabbitmq::plugin { 'rabbitmq_mqtt': }

      # Create the MQTT vhost unless the deployment already manages it.
      if (!defined(Rabbitmq::Management::Vhost[$vhost])) {
        rabbitmq::management::vhost { $vhost: }
      }

      # Manage the MQTT listeners without anonymous access.
      file { '/etc/rabbitmq/conf.d/mqtt.conf':
        ensure  => file,
        content => template('rabbitmq/mqtt.conf'),
        owner   => 'rabbitmq',
        group   => 'rabbitmq',
        mode    => '0600',
        notify  => Service['rabbitmq-server'],
        require => [
          File['rabbitmq_config_dir'],
          Rabbitmq::Plugin['rabbitmq_mqtt'],
        ],
      }
    } else {
      fail('The rabbitmq::mqtt class requires rabbitmq::tcp with ssl_ca_certificate, ssl_certificate and ssl_certificate_key.')
    }
  } else {
    fail('The rabbitmq::management and rabbitmq::tcp classes must be included before using the rabbitmq::mqtt class.')
  }
}
