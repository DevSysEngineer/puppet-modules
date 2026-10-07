# @summary Registers a Mirth Connect check with the OpenITCOCKPIT agent.
#
# This class adds a custom OpenITCOCKPIT check for Mirth Connect through the shared monitoring helper. It requires
# `openitcockpit::agent` so the agent directory and custom-check configuration exist.
#
# @example Enable the Mirth Connect check
#   include openitcockpit::agent
#   include openitcockpit::agent_mirth_connect
#
# @param ensure
#   Controls whether the custom monitoring check is present or absent.
#
# @param package
#   Optional monitoring package override passed to `basic_settings::monitoring_custom`.
#
# @api public
class openitcockpit::agent_mirth_connect (
  Enum['present', 'absent'] $ensure  = present,
  Optional[String]          $package = undef,
) {
  # Require the agent parent before registering the Mirth Connect check.
  if (defined(Class['openitcockpit::agent'])) {
    # Preserve the parent's expected init environment in the monitoring template.
    $systemd_enable = $openitcockpit::agent::systemd_enable

    # Install runtime packages only while this registration deploys the check.
    $monitoring_package = pick($package, $openitcockpit::agent::monitoring_package)
    $monitoring_active = $ensure == present and $openitcockpit::agent::monitoring_enable and $monitoring_package != 'none'
    if ($monitoring_active) {
      # Select the tools used alongside mccommand and the systemd or process inspection interface.
      $monitoring_packages = concat(['coreutils', 'dash', 'mawk', 'sed'], $systemd_enable ? {
        true    => ['systemd'],
        default => ['procps'],
      })
      ensure_packages($monitoring_packages, {
        'ensure'          => 'installed',
        'install_options' => ['--no-install-recommends', '--no-install-suggests'],
      })
      $monitoring_require = Package[$monitoring_packages]
    } else {
      # Retirement does not install packages for the removed executable.
      $monitoring_require = undef
    }

    # Register the check after its runtime packages.
    basic_settings::monitoring_custom { 'mirth_connect':
      ensure   => $ensure,
      package  => $package,
      friendly => 'Mirth Connect',
      content  => template('openitcockpit/agent/check_mirth_connect'),
      timeout  => 60,
      require  => $monitoring_require,
    }
  } else {
    fail('The openitcockpit::agent class must be included before using the openitcockpit::agent_mirth_connect defined type.')
  }
}
