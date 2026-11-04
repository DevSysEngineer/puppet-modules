# @summary Provides the shared systemd daemon reload for unit and drop-in changes.
#
# Unit wrappers and direct file owners include this class without containment, including on standalone installations.
# The caller owns Package['systemd']. File changes notify Exec['systemd_daemon_reload']; service ordering and refresh
# subscriptions remain with the service owner so unrelated unit changes do not restart its workload.
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
