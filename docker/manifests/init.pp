# @summary Installs Docker and the shared Compose runtime and monitoring tools.
#
# This class installs Docker CE, Compose, shared exec and backup scripts, and shared Compose and S3 monitoring checks.
# S3 monitoring requires native curl SigV4 and GNU coreutils; HTTPS also needs curl >= 7.88 with the OpenSSL backend.
# All docker::compose* definitions require this parent class, including when retiring a project.
# Repository setup is expected to be handled separately, commonly through `basic_settings` with `docker_enable => true`.
# Declare nvidia before docker to install the Container Toolkit and register its runtime automatically.
# Docker owns the complete /etc/docker/daemon.json; migrate existing settings into daemon_config before applying.
# The complete candidate is validated with dockerd before activation. An active daemon restarts on a change;
# a stopped daemon remains stopped. Do not also manage this file with nvidia-ctk or another configuration owner.
# Use the default rootful daemon configuration path and avoid duplicate options in the daemon start arguments.
# Removing the nvidia declaration removes its generated runtime entry but retains all GPU packages.
# NVIDIA integration does not set the default runtime; other configured runtimes and daemon options are retained.
#
# @example Install Docker CE
#   class { 'docker': }
#
# @param daemon_config
#   Docker daemon options recursively merged over the built-in defaults; default {} keeps those defaults.
#   Nested hashes retain unspecified defaults; other values replace them. Use Docker JSON option names and types.
#   The result replaces the complete daemon.json, including on hosts without nvidia; local edits are not imported.
#   ip6tables and ipv6 default to true for ip_version all and false for 4, independently of the firewall backend.
#   IP policy comes from an already declared basic_settings::network, otherwise basic_settings::kernel, otherwise all.
#   ipv6 enables the default bridge; user-defined networks still select IPv6 separately.
#   Both options remain overridable.
#   A declared nvidia class adds runtimes.nvidia with its managed path and arguments after applying these overrides.
#   Do not supply that entry yourself when using automatic integration.
#   Other runtimes and default-runtime are preserved.
#
# @param edition
#   Docker edition to install. The only supported value is `ce`, which installs the `docker-ce` package.
#
# @param firewall_package
#   Firewall selection: iptables, nftables or firewalld. The default undef inherits firewall_package from an already
#   declared basic_settings::network class; without that class it uses iptables. An explicit value takes precedence.
#   nftables defaults firewall-backend to nftables. iptables defaults to true for every firewall selection,
#   retaining Docker-managed IPv4 rules; ip6tables follows the inherited IP policy.
#   Other selections do not add firewall-backend. No firewall package or host forwarding is managed here.
#   The native nftables backend requires Engine >= 29.0.0, is experimental and is not supported in Swarm mode;
#   verify these conditions against the deployed Engine version. ip6tables does not enable IPv6 container networks.
#   The consumer must enable the required host forwarding and load its own forward filter before migration.
#   daemon_config overrides these defaults, including false for iptables/ip6tables with replacement firewall management.
#
# @api public
class docker (
  Hash[String, Data]                                  $daemon_config    = {},
  Enum['ce']                                          $edition          = 'ce',
  Optional[Enum['iptables', 'nftables', 'firewalld']] $firewall_package = undef,
) {
  # Install the package only for the supported Docker edition.
  if ($edition == 'ce') {
    # Resolve the Docker CE package name for the shared package resource.
    $package_name = 'docker-ce'

    # Set some values
    $monitoring_enable = defined(Class['basic_settings::monitoring'])

    # Only an already declared class activates GPU integration; module availability alone does not.
    $nvidia_available = defined(Class['nvidia'])

    # Reuse the network class availability for IP policy and firewall defaults.
    $network_available = defined(Class['basic_settings::network'])

    # Check if we have network class
    if (!$network_available) {
      # Inherit IP policy from the kernel class when no central network class owns it.
      if (defined(Class['basic_settings::kernel'])) {
        # Keep Docker networks aligned with the kernel's IP policy.
        $ip_version = $basic_settings::kernel::ip_version
      } else {
        # Enable both IP families when no central IP policy is available.
        $ip_version = 'all'
      }
    } else {
      # Prefer the central network class's IP policy for Docker networks.
      $ip_version = $basic_settings::network::ip_version
    }

    # Keep IPv6 networking and firewall management aligned with the inherited IP policy.
    $ipv6_enable = $ip_version == 'all'

    # An omitted firewall choice follows the declared network policy, or the standalone iptables default.
    if ($firewall_package == undef) {
      # Read central policy only when its class has already been declared.
      if ($network_available) {
        # Keep the daemon firewall choice aligned with the host network policy.
        $firewall_package_correct = $basic_settings::network::firewall_package
      } else {
        # Standalone Docker retains its existing iptables behavior.
        $firewall_package_correct = 'iptables'
      }
    } else {
      # An explicit Docker choice takes precedence over central network policy.
      $firewall_package_correct = $firewall_package
    }

    # Select the native nftables backend; firewall management defaults are shared below.
    $firewall_config = $firewall_package_correct ? {
      'nftables' => {
        'firewall-backend' => 'nftables',
      },
      default   => {},
    }

    # Keep the production daemon baseline under Docker's ownership on every host.
    $daemon_defaults = {
      'iptables'           => true,
      'ip6tables'          => $ipv6_enable,
      'ipv6'               => $ipv6_enable,
      'icc'                => true,
      'live-restore'       => true,
      'userland-proxy'     => false,
      'no-new-privileges'  => true,
      'log-driver'         => 'json-file',
      'log-opts'           => {
        'max-size' => '10m',
        'max-file' => '3',
      },
      'storage-driver'     => 'overlay2',
      'default-ulimits'    => {
        'nofile' => {
          'Name' => 'nofile',
          'Hard' => 65536,
          'Soft' => 65536,
        },
      },
    }
    $daemon_settings = deep_merge($daemon_defaults, $firewall_config, $daemon_config)

    # GPU hosts install Docker after the driver; ordinary hosts need no NVIDIA dependency.
    $package_require = $nvidia_available ? {
      true    => Class['nvidia'],
      default => undef,
    }

    # Install Docker from the separately managed repository.
    package { 'docker':
      ensure          => installed,
      name            => $package_name,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
      require         => $package_require,
    }

    # The toolkit's strict dependencies install its base runtime and both libnvidia-container packages together.
    if ($nvidia_available) {
      package { 'nvidia-container-toolkit':
        ensure          => installed,
        install_options => ['--no-install-recommends', '--no-install-suggests'],
        require         => [Class['nvidia'], Package['docker']],
      }

      # The runtime must exist before Docker can validate and activate its registration.
      $daemon_config_require = Package['nvidia-container-toolkit']
      $daemon_config_effective = deep_merge($daemon_settings, {
        'runtimes' => {
          'nvidia' => {
            'path'        => '/usr/bin/nvidia-container-runtime',
            'runtimeArgs' => [],
          },
        },
      })
    } else {
      # Ordinary Docker hosts use the same configuration owner without NVIDIA dependencies or generated settings.
      $daemon_config_require = Package['docker']
      $daemon_config_effective = $daemon_settings
    }

    # Docker CE does not guarantee this directory exists before the first managed daemon configuration.
    file { '/etc/docker':
      ensure  => directory,
      owner   => 'root',
      group   => 'root',
      mode    => '0700',
      require => Package['docker'],
    }

    # JSON cannot contain a Managed by puppet comment; validate the candidate before replacing the active file.
    file { '/etc/docker/daemon.json':
      ensure       => file,
      owner        => 'root',
      group        => 'root',
      mode         => '0600',
      content      => template('docker/daemon.json'),
      show_diff    => false,
      validate_cmd => '/usr/bin/dockerd --validate --config-file %',
      require      => [File['/etc/docker'], $daemon_config_require],
      notify       => Service['docker'],
    }

    # A refresh restarts only an active service; leave its running state and vendor enablement unmanaged.
    service { 'docker':
      hasrestart => true,
      hasstatus  => true,
      require    => Package['docker'],
    }

    # Compose deployment, host-side container mappings, backups and monitoring share these dependencies.
    ensure_packages(['coreutils', 'dash', 'docker-compose-plugin', 'gzip', 'mawk', 'util-linux'], {
      'ensure'          => 'installed',
      'install_options' => ['--no-install-recommends', '--no-install-suggests'],
    })

    # The parent class owns shared storage independently of individual projects.
    file { '/opt/docker':
      ensure => directory,
      owner  => 'root',
      group  => 'root',
      mode   => '0700',
    }

    # Share the management-helper directory with MySQL and the host's other management tools.
    if (!defined(File['/usr/local/lib/puppet'])) {
      file { '/usr/local/lib/puppet':
        ensure => directory,
        owner  => 'root',
        group  => 'root',
        mode   => '0755',
      }
    }

    # Puppet execs and scheduled backups share the same controlled Compose container selection.
    file { '/usr/local/lib/puppet/docker-compose-container':
      ensure  => file,
      owner   => 'root',
      group   => 'root',
      mode    => '0700',
      source  => 'puppet:///modules/docker/compose_container',
      require => [File['/usr/local/lib/puppet'], Package['dash', 'docker']],
    }

    # Keep the runner available when one project is retired while others still use it.
    file { '/usr/local/lib/puppet/docker-compose-backup':
      ensure  => file,
      owner   => 'root',
      group   => 'root',
      mode    => '0700',
      source  => 'puppet:///modules/docker/compose_backup',
      require => File['/usr/local/lib/puppet'],
    }

    # Create service check
    if ($monitoring_enable and $basic_settings::monitoring::package != 'none') {
      # Install the check's shell, text tools, JSON parser and Docker CLI.
      $monitoring_packages = ['ca-certificates', 'curl', 'docker-ce-cli', 'jq', 'openssl', 'sed']

      ensure_packages($monitoring_packages, {
        'ensure'          => 'installed',
        'install_options' => ['--no-install-recommends', '--no-install-suggests'],
      })

      # Prepare package names before constructing resource dependencies.
      $monitoring_required_packages = concat(
        $monitoring_packages,
        ['coreutils', 'dash', 'docker-compose-plugin', 'mawk'],
      )

      # The parent owns one shared check; project definitions only register their arguments.
      basic_settings::monitoring_custom { 'docker_compose':
        template => 'docker/check_compose',
        register => false,
        require  => Package[$monitoring_required_packages],
      }

      # Store registrations share the executable and never own its lifetime or credential files.
      basic_settings::monitoring_custom { 'nextcloud_s3':
        template => 'docker/check_nextcloud_s3',
        register => false,
        require  => Package[$monitoring_required_packages],
      }
    }
  } else {
    fail("Unsupported docker edition: ${edition}")
  }
}
