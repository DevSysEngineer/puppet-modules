# @summary Installs a pinned open headless NVIDIA driver on Ubuntu 24.04 ARM64.
#
# Prepare the NVIDIA CUDA/SBSA repository, refresh APT, and install the selected kernel and its headers first.
# When basic_settings::kernel is declared, pin installation waits for that class. The caller must order any
# separately managed repositories and headers. This class does not install Docker, CUDA or platform metapackages.
# Declare basic_settings, then nvidia, then docker: Docker detects only an already declared nvidia class.
# Existing pinning packages, including residual configuration, are purged before installing the requested pin.
# Driver packages use ensure => installed: updates within a branch are not applied automatically.
# Changing pinning selects another branch's driver package; review the resulting APT changes before applying.
# Plan driver upgrades and any reboot separately; Secure Boot and DKMS must work for the selected boot kernel.
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
#     require => [Class['basic_settings::package_nvidia_dgx'], Exec['basic_settings_source_reload']],
#   }
#
# @param pinning
#   Required positive integer driver branch, for example 580.
#   Selects nvidia-driver-pinning-<branch> and nvidia-headless-<branch>-open from the configured repository.
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
    ensure_packages($cleanup_packages, {
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
      # Wait for the selected kernel and its transitive header dependency.
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
      require  => [Package[$cleanup_packages], $kernel_require],
    }

    # --purge also covers a conflicting pin installed after the cleanup.
    package { $pin_package:
      ensure          => installed,
      provider        => apt,
      install_options => concat($install_options, ['--purge', '--no-install-recommends', '--no-install-suggests']),
      require         => Exec['nvidia_pinning_cleanup'],
    }

    # Select the open headless driver from the same branch as the pinning package.
    package { ["nvidia-headless-${pinning}-open", 'nvidia-modprobe']:
      ensure          => installed,
      provider        => apt,
      install_options => concat($install_options, ['--no-install-recommends', '--no-install-suggests']),
      require         => Package[$pin_package],
    }
  } else {
    fail('The NVIDIA headless driver mapping requires Ubuntu 24.04 ARM64.')
  }
}
