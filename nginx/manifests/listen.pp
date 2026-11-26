# @summary Registers one shared socket option for the default Nginx configuration.
#
# @example Configure an option through a vhost
#   include nginx
#   nginx::server { 'example.test':
#     reuseport => true,
#   }
#
# @param setting
#   Nginx listen option name.
#
# @param socket
#   Transport and Nginx address, including the port.
#
# @param value
#   Effective option value. A true boolean renders the option without an argument.
#
# @api private
define nginx::listen (
  String[1]                         $setting,
  String[1]                         $socket,
  Variant[Boolean, Integer, String] $value,
) {
  # The parent owns the output file shared by primary and redirect vhosts.
  if defined(Class['nginx']) {
    # Keep the unique setting and its socket together in the completed catalog.
    $option = { 'socket' => $socket, 'setting' => $setting, 'value' => $value }
    Nginx_default_config <| title == $nginx::default_config |> {
      options +> [$option],
    }
  } else {
    fail('Declare nginx before configuring a listener option.')
  }
}
