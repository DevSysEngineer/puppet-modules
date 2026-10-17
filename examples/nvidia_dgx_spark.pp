# Docker scenarios require Engine >= 29.0.0 without Swarm and a consumer-managed forward filter loaded before forwarding.
# Arrange firewall activation and boot ordering as described in README; ip_version selects the forwarding families.
# Example: headless NVIDIA DGX Spark / ASUS Ascent GX10 with Ubuntu 24.04 ARM64.
# Declare each class once, in this evaluation order; require relationships alone do not enable Docker's class detection.
# Installs the open headless driver and Container Toolkit; CUDA applications belong in containers.
# Review the package plan and daemon start options before use; no desktop or DGX platform metapackages are requested.
# Review APT changes and boot configuration, retain the generic kernel, and schedule a manual reboot.

node 'dgx-spark.example.org' {
  class { 'basic_settings':
    docker_enable     => true,
    ip_forwarding     => true,
    kernel_flavor     => 'nvidia',
    nvidia_dgx_enable => true,
  }

  # Pin selection precedes driver installation and waits for the NVIDIA sources, APT refresh and selected kernel headers.
  class { 'nvidia':
    pinning => 580,
    require => [
      Class['basic_settings::kernel', 'basic_settings::package_nvidia_dgx'],
      Exec['basic_settings_source_reload'],
    ],
  }

  # The declared driver class activates toolkit installation and runtime configuration without another switch.
  class { 'docker':
    require => Class['basic_settings'],
  }
}
