# @summary Manages RabbitMQ AMQP listeners and optional MQTT over TLS.
#
# This class requires `rabbitmq` and writes `/etc/rabbitmq/conf.d/tcp.conf`.
# When all certificate paths are provided, TLS is enabled and plain TCP follows `tcp_enable`; otherwise TLS is disabled
# and plain TCP is forced on so the broker remains reachable.
# Declare `rabbitmq::plugin { 'rabbitmq_mqtt': }` before this class to include MQTT settings; this class does not enable
# the plugin itself. MQTT uses TLS only and requires the same complete certificate set. The check uses the Puppet
# declaration, not the running broker's plugin state. Omitting the declaration does not disable an already enabled
# plugin.
#
# @example Enable TLS and disable plain TCP
#   class { 'rabbitmq::tcp':
#     ssl_ca_certificate  => '/etc/rabbitmq/ssl/ca.pem',
#     ssl_certificate     => '/etc/rabbitmq/ssl/cert.pem',
#     ssl_certificate_key => '/etc/rabbitmq/ssl/key.pem',
#     tcp_enable          => false,
#   }
#
# @example Configure MQTT over TLS with an explicitly enabled plugin
#   include rabbitmq
#   rabbitmq::plugin { 'rabbitmq_mqtt': }
#
#   # Configure both protocols after declaring the MQTT plugin.
#   class { 'rabbitmq::tcp':
#     ssl_ca_certificate  => '/etc/rabbitmq/ssl/ca.pem',
#     ssl_certificate     => '/etc/rabbitmq/ssl/cert.pem',
#     ssl_certificate_key => '/etc/rabbitmq/ssl/key.pem',
#   }
#
# @param mqtt_ssl_port
#   MQTT TLS listener port, used only when the MQTT plugin is declared before this class and all certificate paths are
#   supplied. Without that declaration, no MQTT settings are written. Plain MQTT and anonymous access are disabled when
#   the plugin is declared.
#
# @param ssl_ca_certificate
#   Optional CA certificate path for TLS listeners.
#
# @param ssl_certificate
#   Optional certificate path for TLS listeners.
#
# @param ssl_certificate_key
#   Optional private key path for TLS listeners.
#
# @param ssl_ciphers
#   TLS cipher list rendered into RabbitMQ configuration.
#
# @param ssl_port
#   TLS AMQP listener port.
#
# @param ssl_protocols
#   TLS protocol list rendered into RabbitMQ configuration.
#
# @param tcp_enable
#   Enables the plain TCP listener when TLS is available. Plain TCP is forced on when TLS certificate inputs are
#   incomplete.
#
# @param tcp_port
#   Plain AMQP listener port.
#
# @api public
class rabbitmq::tcp (
  Integer          $mqtt_ssl_port       = 8883,
  Optional[String] $ssl_ca_certificate  = undef,
  Optional[String] $ssl_certificate     = undef,
  Optional[String] $ssl_certificate_key = undef,
  Array            $ssl_ciphers         = [
    'TLS_AES_256_GCM_SHA384',
    'TLS_AES_128_GCM_SHA256',
    'TLS_CHACHA20_POLY1305_SHA256',
    'TLS_AES_128_CCM_SHA256',
    'TLS_AES_128_CCM_8_SHA256',
    'ECDHE-ECDSA-AES128-CCM',
    'ECDHE-ECDSA-AES128-CCM8',
    'ECDHE-ECDSA-AES256-CCM',
    'ECDHE-ECDSA-AES256-CCM8',
    'ECDHE-RSA-AES128-GCM-SHA256',
    'ECDHE-RSA-AES256-GCM-SHA384',
    'ECDHE-RSA-CHACHA20-POLY1305',
  ],
  Integer          $ssl_port            = 5671,
  Array            $ssl_protocols       = ['tlsv1.3', 'tlsv1.2'],
  Boolean          $tcp_enable          = false,
  Integer          $tcp_port            = 5672,
) {
  # Require the RabbitMQ parent before configuring AMQP listeners and TLS.
  if (defined(Class['rabbitmq'])) {
    # Emit MQTT settings only for a plugin explicitly declared before this class is evaluated.
    $mqtt_enable = defined(Rabbitmq::Plugin['rabbitmq_mqtt'])

    # Check if all cert variables are given
    if ($ssl_ca_certificate != undef and $ssl_certificate != undef and $ssl_certificate_key != undef) {
      # Enable TLS and honor the TCP toggle when a complete certificate set is supplied.
      $tls_allow = true
      $tcp_enable_correct = $tcp_enable
    } else {
      # Keep plaintext TCP available when no complete TLS certificate set is supplied.
      $tls_allow = false
      $tcp_enable_correct = true
    }

    # Manage the AMQP listeners and any explicitly requested MQTT configuration.
    file { '/etc/rabbitmq/conf.d/tcp.conf':
      ensure  => file,
      content => template('rabbitmq/tcp.conf'),
      owner   => 'rabbitmq',
      group   => 'rabbitmq',
      mode    => '0600',
      notify  => Service['rabbitmq-server'],
      require => File['rabbitmq_config_dir'],
    }
  } else {
    fail('The rabbitmq class must be included before using the rabbitmq::tcp class type.')
  }
}
