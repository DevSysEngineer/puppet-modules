# @summary Manages timezone and systemd-timesyncd NTP configuration.
#
# Installs tzdata and the validation tools, checks the selected zone on the agent, and manages /etc/localtime as a
# symlink plus /etc/timezone as a compatibility file. Invalid zone data fails an apply before either file is changed.
# The read-only guard also runs during noop; noop cannot prove validation after a pending package installation.
# Timezone management runs independently of NTP and does not manage the hardware clock or debconf answers.
# When Package[systemd] is declared before this class, it also installs and enables systemd-timesyncd, renders
# /etc/systemd/timesyncd.conf, removes competing NTP packages, and adds a check when monitoring is active.
#
# @example Set the server timezone
#   class { 'basic_settings::timezone':
#     timezone => 'Europe/Amsterdam',
#   }
#
# @param timezone
#   Required timezone name relative to /usr/share/zoneinfo; basic_settings supplies server_timezone, default UTC.
#   Non-empty segments accept letters, digits, underscores, dots, hyphens and plus signs; standalone dot or double-dot
#   segments, whitespace and shell metacharacters are rejected. The agent must provide a readable regular file with
#   a TZif header after tzdata installation. Names such as UTC, Etc/UTC, Etc/GMT+1 and
#   America/Argentina/Buenos_Aires are preserved literally.
#
# @param install_options
#   Additional APT options for systemd-timesyncd; an empty array adds no caller options. Mandatory no-recommends and
#   no-suggests flags are appended without deduplication so they remain effective.
#
# @param ntp_extra_pools
#   Additional NTP pools prepended to the OS default pool list.
#
# @api public
class basic_settings::timezone (
  Pattern[/\A(?!(?:.*\/)?\.{1,2}(?:\/|\z))[A-Za-z0-9_.+-]+(?:\/[A-Za-z0-9_.+-]+)*\z/] $timezone,
  Array                                                                               $install_options = [],
  Array                                                                               $ntp_extra_pools = [],
) {
  # Share runtime packages with callers while retaining the APT installation policy.
  $timezone_packages = ['coreutils', 'dash', 'tzdata']

  ensure_packages($timezone_packages, {
    'ensure'          => 'installed',
    'install_options' => ['--no-install-recommends', '--no-install-suggests'],
  })

  # Escape the agent-side zone path once for the shell command and its read-only guard.
  $zone_shell = stdlib::shell_escape("/usr/share/zoneinfo/${timezone}")

  # A failed validation blocks both file resources; valid data never runs the failing command.
  exec { 'timezone_validate_zoneinfo':
    command  => "/usr/bin/printf 'Invalid timezone data: %s\n' ${zone_shell} >&2; exit 1",
    provider => shell,
    unless   => "test -f ${zone_shell} && test -r ${zone_shell} && test \"\$(/usr/bin/head -c 4 ${zone_shell})\" = TZif",
    require  => Package[$timezone_packages],
  }

  # Keep timezone identification in the symlink without modifying package-owned zoneinfo files.
  file { '/etc/localtime':
    ensure  => link,
    target  => "/usr/share/zoneinfo/${timezone}",
    owner   => 'root',
    group   => 'root',
    require => Exec['timezone_validate_zoneinfo'],
  }

  # This compatibility format accepts only a timezone name, so a Managed by puppet header is invalid.
  # The timezone name is public system configuration and must be readable by unprivileged applications.
  file { '/etc/timezone':
    ensure  => file,
    content => "${timezone}\n",
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    require => File['/etc/localtime'],
  }

  # Check if systemd is installed
  if (defined(Package['systemd'])) {
    # Reload systemd deamon
    exec { 'systemd_timezone_daemon_reload':
      command     => '/usr/bin/systemctl daemon-reload',
      refreshonly => true,
      require     => Package['systemd'],
    }

    # Install package
    # Keep policy flags last even when caller options contain duplicate or conflicting flags.
    package { 'systemd-timesyncd':
      ensure          => installed,
      install_options => concat($install_options, ['--no-install-recommends', '--no-install-suggests']),
    }

    # Get OS name
    case $facts['os']['name'] {
      'Ubuntu': {
        # Combine extra NTP pools with the Ubuntu defaults.
        $ntp_all_pools = flatten($ntp_extra_pools, [
          '0.ubuntu.pool.ntp.org',
          '1.ubuntu.pool.ntp.org',
          '2.ubuntu.pool.ntp.org',
          '3.ubuntu.pool.ntp.org',
        ])
      }
      'Debian': {
        # Combine extra NTP pools with the Debian defaults.
        $ntp_all_pools = flatten($ntp_extra_pools, [
          '0.debian.pool.ntp.org',
          '1.debian.pool.ntp.org',
          '2.debian.pool.ntp.org',
          '3.debian.pool.ntp.org',
        ])
      }
      default: {
        # Leave the pool list empty when no distribution default is defined.
        $ntp_all_pools = []
      }
    }

    # Systemd NTP settings
    $ntp_list = join($ntp_all_pools, ' ')

    # Create systemd timesyncd config
    file { '/etc/systemd/timesyncd.conf':
      ensure  => file,
      content => template('basic_settings/systemd/timesyncd.conf'),
      owner   => 'root',
      group   => 'root',
      mode    => '0644', # Important
      notify  => Exec['systemd_timezone_daemon_reload'],
      require => Package['systemd-timesyncd'],
    }

    # Ensure that systemd-timesyncd is always running
    service { 'systemd-timesyncd':
      ensure    => running,
      enable    => true,
      require   => File['/etc/systemd/timesyncd.conf'],
      subscribe => File['/etc/systemd/timesyncd.conf'],
    }

    # Create service check
    if (defined(Class['basic_settings::monitoring']) and $basic_settings::monitoring::package != 'none') {
      # Install the external commands used by this check.
      $monitoring_packages = ['dash', 'grep', 'mawk', 'sed']

      ensure_packages($monitoring_packages, {
        'ensure'          => 'installed',
        'install_options' => ['--no-install-recommends', '--no-install-suggests'],
      })

      # Prepare package names before constructing resource dependencies.
      $monitoring_required_packages = concat(
        $monitoring_packages,
        ['systemd'],
      )

      # Register the check after its runtime packages.
      basic_settings::monitoring_custom { 'systemd_timesyncd':
        source  => 'puppet:///modules/basic_settings/monitoring/check_systemd_timesyncd',
        require => Package[$monitoring_required_packages],
      }
    }

    # Remove unnecessary packages
    package { ['chrony', 'ntp', 'ntpdate', 'ntpsec']:
      ensure  => purged,
      require => Package['systemd-timesyncd'],
    }
  }
}
