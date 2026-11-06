# @summary Installs Proxmox VE packages and kernel cleanup on Debian 12.
#
# This class expects `basic_settings` platform detection to be available. It installs the selected Proxmox kernel for
# supported releases, installs `proxmox-ve` and `open-iscsi`, removes generic Linux kernel packages, and refreshes
# GRUB after kernel cleanup. Reboot the host manually during a maintenance window to activate the installed kernel.
# Missing platform context or a platform other than Debian 12 fails before creating kernel-dependent resources.
#
# @example Install Proxmox after the basic server baseline
#   include basic_settings
#   include proxmox
#
# @api public
class proxmox () {
  # Platform detection is owned by basic_settings; dependent resources must not escape that contract.
  if (defined(Class['basic_settings'])) {
    case $basic_settings::os_name {
      'bookworm': {
        # Select the mapped Proxmox kernel for the Bookworm installation path.
        $kernel = '6.2'
      }
      default:  {
        # Leave the kernel selection unset when no platform mapping is available.
        $kernel = undef
      }
    }

    # Keep kernel-dependent resources within the supported platform path.
    if ($kernel) {
      # GRUB refreshes require this package even when basic_settings does not manage the bootloader.
      stdlib::ensure_packages(['grub2-common'], {
        'ensure'          => 'installed',
        'install_options' => ['--no-install-recommends', '--no-install-suggests'],
      })

      # Install the selected kernel before the platform packages.
      package { "pve-kernel-${kernel}":
        ensure          => installed,
        install_options => ['--no-install-recommends', '--no-install-suggests'],
      }

      # Kernel activation is a manual maintenance action; installation continues without scheduling a reboot.
      package { ['proxmox-ve', 'open-iscsi']:
        ensure          => installed,
        install_options => ['--no-install-recommends', '--no-install-suggests'],
        require         => Package["pve-kernel-${kernel}"],
      }

      # Regenerate GRUB when conflicting kernel packages are removed.
      exec { 'proxmox_update_grub':
        command     => '/usr/sbin/update-grub',
        refreshonly => true,
        require     => Package['grub2-common', 'proxmox-ve'],
      }

      # Notify GRUB only after removing packages that conflict with the selected PVE kernel.
      package { ['linux-image*', 'os-prober']:
        ensure  => absent,
        require => Package['proxmox-ve'],
        notify  => Exec['proxmox_update_grub'],
      }
    } else {
      fail('proxmox supports only Debian 12 (bookworm) with a selected PVE kernel.')
    }
  } else {
    fail('proxmox requires the basic_settings class before selecting a kernel.')
  }
}
