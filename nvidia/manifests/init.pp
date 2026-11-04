# @summary Installs a pinned open headless NVIDIA driver and Persistence Mode on Ubuntu 24.04 ARM64.
#
# Prepare the NVIDIA CUDA/SBSA repository, refresh APT, and install the selected kernel and its headers first.
# When basic_settings::kernel is declared, pin installation waits for that class. The caller must order any
# separately managed repositories and headers. This class does not install Docker, CUDA or platform metapackages.
# Declare basic_settings, then nvidia, then docker: Docker detects only an already declared nvidia class.
# Existing pinning packages, including residual configuration, are purged before installing the requested pin.
# Driver packages use ensure => installed: updates within a branch are not applied automatically.
# Changing pinning selects another branch's driver package. Driver upgrades and reboots are managed separately.
# Secure Boot and DKMS must work for the selected boot kernel.
# nv-persistence-mode supplies the vendor configuration; the headless driver dependencies supply nvidia-persistenced.
# Declare basic_settings::systemd first to activate the daemon through its <cluster_id>-system.target with Wants/After.
# Otherwise the vendor service is enabled for normal boots. No additional public parameters are required.
# Puppet manages boot activation only: ensure => undef avoids starting a daemon against a mismatched loaded driver.
# The first activation of the new driver and Persistence Mode takes effect after a manually planned reboot.
#
# @example Install the Spark driver after preparing the platform
#   class { 'basic_settings':
#     kernel_flavor     => 'nvidia',
#     nvidia_dgx_enable => true,
#   }
#
#   # Install the driver after preparing its package source and kernel headers.
#   class { 'nvidia':
#     pinning => 580,
#     require => [
#       Class['basic_settings::package_nvidia_dgx'],
#       Exec['basic_settings_source_reload'],
#     ],
#   }
#
# @param pinning
#   Required positive integer driver branch, for example 580.
#   Selects nvidia-driver-pinning-<branch> and nvidia-headless-<branch>-server-open from the configured repository.
#   Both packages must exist; missing packages fail installation without a fallback.
#   A guarded cleanup removes other installed pins and residual configuration before installing the requested pin.
#
# @param install_options
#   Additional APT installation options, default []. Mandatory no-recommends and no-suggests options are appended.
#
# @api public
class nvidia (
  Integer[1] $pinning,
  Array      $install_options = [],
) {
  # Keep the driver installation restricted to the Spark platform.
  $platform_supported = $facts['os']['name'] == 'Ubuntu' and $facts['os']['release']['major'] == '24.04'
    and $facts['os']['architecture'] in ['aarch64', 'arm64']
  if ($platform_supported) {
    # Provide the commands used by the guarded cleanup, also when this class is used independently.
    $cleanup_packages = ['apt', 'dpkg', 'dash', 'mawk', 'findutils']
    stdlib::ensure_packages($cleanup_packages, {
      'ensure'          => 'installed',
      'install_options' => concat($install_options, ['--no-install-recommends', '--no-install-suggests']),
    })

    # Inspect current dpkg state during application; retain the requested pin and ignore fully purged packages.
    $pin_package = "nvidia-driver-pinning-${pinning}"
    $pin_package_shell = stdlib::shell_escape($pin_package)

    # The format placeholders belong to dpkg-query, while mawk selects only obsolete pin packages.
    $pinning_query = "/usr/bin/dpkg-query -W -f='\${Package}\\t\${db:Status-Abbrev}\\n'"
    $pinning_filter = '$1 ~ /^nvidia-driver-pinning-[0-9]+([.][0-9]+)*$/ && $1 != keep && substr($2, 2, 1) != "n" { print $1 }'
    $old_pin_query = "${pinning_query} | /usr/bin/mawk -v keep=${pin_package_shell} '${pinning_filter}'"

    # The desired kernel may already be installed without being the running kernel.
    if (defined(Class['basic_settings::kernel'])) {
      # Wait for the selected kernel and headers.
      $kernel_require = Class['basic_settings::kernel']
    } else {
      # Standalone callers provide the kernel and headers before applying this class.
      $kernel_require = undef
    }

    # Purge only replaced pin packages, including residual configuration, before selecting the requested pin.
    exec { 'nvidia_pinning_cleanup':
      command  => "${old_pin_query} | /usr/bin/xargs --no-run-if-empty /usr/bin/apt-get --yes purge --",
      onlyif   => "${old_pin_query} | /usr/bin/mawk 'END { exit (NR == 0) }'",
      provider => shell,
      require  => [
        Package[$cleanup_packages],
        $kernel_require,
      ],
    }

    # --purge also covers a conflicting pin installed after the cleanup.
    package { $pin_package:
      ensure          => installed,
      provider        => apt,
      install_options => concat($install_options, [
        '--purge',
        '--no-install-recommends',
        '--no-install-suggests',
      ]),
      require         => Exec['nvidia_pinning_cleanup'],
    }

    # Select the open headless driver from the same branch as the pinning package.
    package { [
        "nvidia-headless-${pinning}-server-open",
        'nvidia-modprobe',
        "nvidia-utils-${pinning}-server",
      ]:
        ensure          => installed,
        provider        => apt,
        install_options => concat($install_options, ['--no-install-recommends', '--no-install-suggests']),
        require         => Package[$pin_package],
    }

    # Install NVIDIA's Persistence Mode configuration after the selected headless driver and utilities.
    package { 'nv-persistence-mode':
      ensure          => installed,
      provider        => apt,
      install_options => concat($install_options, ['--no-install-recommends', '--no-install-suggests']),
      require         => Package["nvidia-headless-${pinning}-server-open", "nvidia-utils-${pinning}-server"],
    }

    # Use the shared system target when it has already been declared.
    if (defined(Class['basic_settings::systemd'])) {
      # The shared target owns boot activation instead of the vendor enablement links.
      $persistence_enable = false

      # Wait for the start attempt without making later system phases depend on a successful GPU initialization.
      basic_settings::systemd_drop_in { 'nvidia_persistenced_dependency':
        target_unit => "${basic_settings::systemd::cluster_id}-system.target",
        unit        => {
          'After' => 'nvidia-persistenced.service',
          'Wants' => 'nvidia-persistenced.service',
        },
        require     => [
          Package['nv-persistence-mode'],
          Basic_settings::Systemd_target["${basic_settings::systemd::cluster_id}-system"],
        ],
      }
    } else {
      # Standalone hosts use the boot integration supplied by NVIDIA.
      $persistence_enable = true
    }

    # Leave the running state unchanged because the new driver takes effect after the first planned reboot.
    service { 'nvidia-persistenced':
      ensure  => undef,
      enable  => $persistence_enable,
      require => Package['nv-persistence-mode'],
    }
  } else {
    fail('The NVIDIA headless driver mapping requires Ubuntu 24.04 ARM64.')
  }
}
