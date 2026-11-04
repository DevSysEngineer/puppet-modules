# @summary Provides the shared systemd daemon reload for unit and drop-in changes.
#
# Included without containment by basic_settings::systemd so notifications from modules ordered after that class do
# not create dependency cycles. The caller owns Package['systemd']; consumers keep using Exec['systemd_daemon_reload'].
#
# @example Load the shared reload through its owning class
#   include basic_settings::systemd
#
# @api private
class basic_settings::systemd::reload {
  # Coalesce unit changes into the existing refresh-only reload after systemd has been installed.
  exec { 'systemd_daemon_reload':
    command     => '/usr/bin/systemctl daemon-reload',
    refreshonly => true,
    require     => Package['systemd'],
  }
}
