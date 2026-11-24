# @summary Builds the default Nginx server for one address, port and transport.
#
# The Nginx class creates the port 80 listeners. Primary and redirect vhosts share these resources and contribute
# protocol and socket options to their own listeners. TLS participants add handshake rejection before the HTTP handler.
#
# @example Configure the standard listeners through the owning class
#   include nginx
#
# @param address
#   Nginx listen address including the port and any IPv6 brackets. The title is the SHA256 of the transport and address.
#
# @api private
define nginx::default_listener (
  String[1] $address,
) {
  # The Nginx class owns the include directory and the landing page.
  if defined(Class['nginx']) {
    # Vhosts share one listen directive with one set of socket options.
    $listen_file = "${nginx::config}/listen-${name}.inc"
    concat { $name:
      path    => $listen_file,
      owner   => 'root',
      group   => 'root',
      mode    => '0600',
      require => File[$nginx::config],
    }

    # Socket options contributed by vhosts belong on this single default listen directive.
    concat::fragment { "nginx_listen_${name}_header":
      target  => $name,
      content => template('nginx/listen.conf'),
      order   => '01',
    }

    # Close the listen directive after all protocol and socket options.
    concat::fragment { "nginx_listen_${name}_default":
      target  => $name,
      content => " default_server;\n",
      order   => '70',
    }

    # Keep the server file independent of socket option changes so its notification can follow the owning class or vhost.
    file { "nginx_default_${name}":
      ensure  => file,
      path    => "/etc/nginx/sites-enabled/default-${name}",
      owner   => 'root',
      group   => 'root',
      mode    => '0600',
      content => template('nginx/default_server.conf'),
      require => [
        Concat[$name],
        File['/etc/nginx/landing.html', '/etc/nginx/sites-enabled'],
      ],
      before  => Service['nginx'],
    }
  } else {
    fail('Declare nginx before configuring a default listener.')
  }
}
