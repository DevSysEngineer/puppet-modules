# @summary Orchestrates the shared baseline for hardened Debian and Ubuntu servers.
#
# The main `basic_settings` class is the repository foundation. It manages base APT sources, systemd target composition,
# monitoring, security tooling, package hygiene, kernel and network defaults, timezone, locale, login policy, Puppet
# integration, and optional upstream package repositories for local service modules. Many service modules read state
# from this class when it is present, so changes here can affect service ordering, monitoring, package sources, and host
# hardening across the catalog.
#
# @example Build a web host baseline
#   class { 'basic_settings':
#     nginx_enable               => true,
#     mysql_enable               => true,
#     monitoring_package         => 'openitcockpit',
#     monitoring_package_install => true,
#     systemd_ntp_extra_pools    => ['ntp.example.org'],
#   }
#
# @param antivirus_package
#   Optional antivirus integration name used by kernel, network, package, and security components for compatibility
#   exceptions.
#
# @param backports
#   Enables the OS backports repository when the detected platform allows it.
#
# @param cluster_id
#   Prefix for generated systemd target names. The default is `core`.
#
# @param communication_name
#   Optional LLDP communication hostname passed to `basic_settings::network`.
#
# @param description
#   Optional host description reserved for profile data and future templates.
#
# @param dns_dnssec
#   DNSSEC mode passed to systemd-resolved configuration.
#
# @param docker_enable
#   Enables the Docker APT repository on supported platforms. The unused source format is removed. With false
#   (including omission), or when the platform disallows it, removes docker.list and docker.sources from
#   /etc/apt/sources.list.d and /usr/share/keyrings/docker.gpg; this is active cleanup, not leaving existing
#   configuration alone. Source removal refreshes APT. Keep independently managed sources on other paths and check
#   shared key use before disabling.
#
# @param docs_enable
#   Enables local documentation packages through `basic_settings::locale`.
#
# @param environment
#   Server environment passed to login policy and network templates, and to `[agent] environment` when
#   puppet_conf_enable is true and puppetserver_enable is false. Defaults to `production`; this is explicit
#   configuration, not the current Puppet code environment or a fact.
#   See `basic_settings::login` for the environment-dependent shell idle timeout.
#
# @param firewall_package
#   Firewall implementation passed to `basic_settings::network`.
#
# @param firewall_remove
#   Allows the network class to purge competing firewall packages when `true`.
#
# @param getty_enable
#   Keeps discovered, non-reserved text and serial consoles running when true and stops them on each Puppet run when
#   false. Kiosk mode forces them on; getty_reserved_units takes precedence. Boot links remain unchanged and systemd
#   or boot may activate consoles between runs. Requires the console_gettys agent fact; discovery failures stop
#   compilation. Verify console recovery access before rollout.
#
# @param getty_reserved_units
#   Concrete getty@<instance>.service or serial-getty@<instance>.service names excluded from console management, for
#   example getty@tty2.service or serial-getty@ttyAMA0.service. Wildcards and templates are invalid. An empty array
#   reserves none. Reservations override getty_enable and kiosk mode; Puppet does not start, stop, enable, disable
#   or mask reserved consoles. Arrange their ownership and activation separately. A reserved instance need not be
#   discovered; discovery errors still fail compilation.
#
# @param gitlab_enable
#   Enables the GitLab APT repository on supported platforms. The unused source format is removed. With false
#   (including omission), or when the platform disallows it, removes gitlab.list and gitlab.sources from
#   /etc/apt/sources.list.d and /usr/share/keyrings/gitlab.gpg; this is active cleanup, not leaving existing
#   configuration alone. Source removal refreshes APT. Keep independently managed sources on other paths and check
#   shared key use before disabling.
#
# @param guest_agent_enable
#   Enables detected VM guest-agent packages through `basic_settings::kernel`.
#
# @param gui_mode
#   Selects GUI-related package behavior. `none` keeps the host minimal.
#
# @param hosts_enable
#   Enables management of `/etc/hosts` through `basic_settings::network`.
#
# @param hosts_localhost_aliases
#   Additional host aliases appended to the `127.0.0.1 localhost` record.
#
# @param ip_configurator_package
#   Optional network configuration frontend, currently `none` or `netplan.io`.
#
# @param ip_dhcp_enable
#   Enables DHCP client configuration through the network class.
#
# @param ip_forwarding
#   Enables host unicast forwarding through basic_settings::kernel; false (default) keeps it disabled.
#   With true, ip_version => 'all' forwards both families and ip_version => '4' forwards only IPv4, with IPv6 disabled.
#   The consumer owns firewall rules and activation ordering. docker_enable does not select forwarding.
#
# @param ip_ra_enable
#   Enables IPv6 router advertisement handling when DHCP and IP version settings allow it.
#
# @param ip_ra_learn_prefix
#   Controls whether router-advertised prefixes are learned by kernel/network configuration.
#
# @param ip_version
#   Selects IPv4-only (`4`) or dual-stack (`all`) behavior.
#
# @param kernel_connection_max
#   Connection backlog limit passed to kernel templates and consumers.
#
# @param kernel_flavor
#   Selects the kernel package profile. Auto uses the running kernel suffix: -generic selects generic, -raspi
#   selects raspi, and every other suffix (including -nvidia) selects no kernel packages. Other kernel hardening
#   remains active. Explicit profiles ignore the running suffix.
#   Generic installs linux-generic, removes the raspi metapackages and, on Ubuntu releases other than 26.04,
#   installs the release-specific generic HWE image and headers. Raspi installs linux-raspi and removes generic
#   kernel metapackages.
#   Nvidia requires Ubuntu 24.04 ARM64 (arm64 or aarch64), otherwise compilation fails. It installs
#   linux-nvidia-hwe-24.04 and linux-tools-nvidia-hwe-24.04 from Ubuntu sources, retaining existing generic kernels
#   and linux-tools-common. It does not select the -nvidia-64k line or pin a build, require nvidia_dgx_enable,
#   install GPU drivers or CUDA, choose a boot entry or trigger a reboot. Verify the package plan and boot
#   configuration before a manual reboot; the README contains the complete Spark procedure.
#
# @param kernel_hugepages
#   Hugepage count passed to the kernel class.
#
# @param kernel_memory_available_profiles
#   Optional MemAvailable threshold profiles passed to `basic_settings::kernel`.
#   `undef` lets the kernel class use its built-in RAM profile list.
#
# @param kernel_mglru_enable
#   Controls Multi-Gen LRU. `true` uses the default, `false` disables it, and an integer sets a custom `min_ttl_ms`.
#
# @param kernel_network_mode
#   Kernel network hardening mode passed to sysctl templates.
#
# @param kernel_ram_disk_package
#   Initramfs implementation selected for the kernel class.
#
# @param kernel_security_lockdown
#   Requests kernel lockdown: true selects integrity, false selects none and a string supplies an explicit mode.
#   With Secure Boot, none becomes integrity. Without Secure Boot, ESET or an enabled detected VM guest agent
#   overrides the request to none. This affects kernel boot configuration; verify compatibility before changing it.
#
# @param kernel_swap_free_profiles
#   Optional SwapFree threshold profiles passed to `basic_settings::kernel`.
#   `undef` lets the kernel class use its built-in swap profile list.
#
# @param kernel_tcp_congestion_control
#   TCP congestion-control mode passed to `basic_settings::kernel`.
#
# @param kernel_tcp_fastopen
#   TCP Fast Open sysctl value passed to `basic_settings::kernel`.
#
# @param keyboard_enable
#   Optional override for console keyboard management in `basic_settings::assistent`.
#
# @param locale_enable
#   Enables full locale package management through `basic_settings::locale`.
#
# @param lvm_enable
#   Enables LVM package and audit management through `basic_settings::io`.
#
# @param mail_package
#   Mail transport installed for monitoring and systemd failure notifications.
#
# @param mongodb_enable
#   Enables the MongoDB APT repository on supported platforms. The unused source format is removed. With false
#   (including omission), or when the platform disallows it, removes mongodb.list and mongodb.sources from
#   /etc/apt/sources.list.d and /usr/share/keyrings/mongodb.gpg; this is active cleanup, not leaving existing
#   configuration alone. Source removal refreshes APT. Keep independently managed sources on other paths and check
#   shared key use before disabling. Also purges mongodb-org-server when disabled or unsupported; plan database
#   backup and retirement first.
#
# @param mongodb_version
#   MongoDB version used when the MongoDB repository is enabled.
#
# @param monitoring_package
#   Monitoring backend to configure. `none` disables generated monitoring integration and `openitcockpit` enables
#   OpenITCOCKPIT custom checks.
#
# @param monitoring_package_install
#   Installs the monitoring agent package when the selected backend supports it.
#
# @param mozilla_enable
#   Enables the Mozilla APT repository on supported platforms. The unused source format is removed. With false
#   (including omission), or when the platform disallows it, removes mozilla.list and mozilla.sources from
#   /etc/apt/sources.list.d and /usr/share/keyrings/mozilla.gpg; this is active cleanup, not leaving existing
#   configuration alone. Source removal refreshes APT. Keep independently managed sources on other paths and check
#   shared key use before disabling.
#
# @param mysql_enable
#   Enables the MySQL APT repository on supported platforms. The unused source format is removed. With false
#   (including omission), or when the platform disallows it, removes mysql.list and mysql.sources from
#   /etc/apt/sources.list.d and /usr/share/keyrings/mysql.gpg; this is active cleanup, not leaving existing
#   configuration alone. Source removal refreshes APT. Keep independently managed sources on other paths and check
#   shared key use before disabling. Cleanup also removes /etc/apt/preferences.d/90-mysql and
#   /usr/share/keyrings/mysql.key.
#
# @param mysql_version
#   MySQL version used when the MySQL repository is enabled.
#
# @param network_interfaces
#   Interface patterns passed to network and systemd-networkd helpers.
#
# @param nginx_enable
#   Enables the Nginx APT repository on supported platforms. The unused source format is removed. With false
#   (including omission), or when the platform disallows it, removes nginx.list and nginx.sources from
#   /etc/apt/sources.list.d and /usr/share/keyrings/nginx-archive-keyring.gpg; this is active cleanup, not leaving
#   existing configuration alone. Source removal refreshes APT. Keep independently managed sources on other paths
#   and check shared key use before disabling.
#
# @param nodejs_enable
#   Enables the NodeSource APT repository on supported platforms. The unused source format is removed. With false
#   (including omission), or when the platform disallows it, removes nodesource.list and nodesource.sources from
#   /etc/apt/sources.list.d and /usr/share/keyrings/nodesource.gpg; this is active cleanup, not leaving existing
#   configuration alone. Source removal refreshes APT. Keep independently managed sources on other paths and check
#   shared key use before disabling. Also purges nodejs and removes the module-owned npm permission helper when
#   disabled or unsupported.
#
# @param nodejs_version
#   Node.js major version used by the NodeSource repository helper.
#
# @param non_free
#   Optional repository flag reserved for platform source templates.
#
# @param nvidia_dgx_enable
#   Manages only the NVIDIA DGX and CUDA APT sources and public signing keys, not NVIDIA packages. True requires
#   Ubuntu 24.04 (noble), with Facter architecture arm64 or aarch64; unsupported activation fails compilation. The
#   selected source format replaces the alternative format.
#   False, including omission, removes dgx.list, dgx.sources, cuda-compute-repo.list and cuda-compute-repo.sources
#   from /etc/apt/sources.list.d and cuda_debian_prod.gpg and dgx_debian_prod.gpg from /usr/share/keyrings, even on
#   unsupported platforms. Set true before rollout if these sources must remain, and check other sources for shared
#   key paths. Installed software and other NVIDIA configuration remain untouched.
#   When either key is missing or empty, both keys are bootstrapped again. Non-empty key contents are not compared
#   or rotated automatically; plan key rotation separately. Source contents, owner and permissions converge on every
#   run, and source/key changes refresh APT.
#
# @param openitcockpit_enable
#   Enables the OpenITCOCKPIT APT repository on supported platforms. The unused source format is removed. With false
#   (including omission), or when the platform disallows it, removes openitcockpit.list and openitcockpit.sources
#   from /etc/apt/sources.list.d and /usr/share/keyrings/openitcockpit.gpg; this is active cleanup, not leaving
#   existing configuration alone. Source removal refreshes APT. Keep independently managed sources on other paths
#   and check shared key use before disabling. Cleanup also removes /etc/apt/auth.conf.d/openitcockpit.conf.
#   Selecting a monitoring backend does not force this repository on.
#
# @param openitcockpit_license
#   Optional OpenITCOCKPIT repository license token written to root-only APT auth.
#
# @param openitcockpit_nightly
#   Uses the OpenITCOCKPIT nightly repository channel when `true`.
#
# @param openitcockpit_package
#   OpenITCOCKPIT repository family to configure, either `agent` or `server`.
#
# @param openjdk_enable
#   Installs OpenJDK packages independently of Puppet Server requirements when supported.
#
# @param openjdk_version
#   OpenJDK major version for independent Java consumers, or `default` for the OS default JDK.
#   An enabled JVM Puppet server selects its required Java version and /usr/bin/java alternative instead.
#
# @param pro_enable
#   Enables Ubuntu Pro client handling through `basic_settings::pro`.
#
# @param pro_monitoring_enable
#   Enables Ubuntu Pro monitoring packages when Pro support is active.
#
# @param proxmox_enable
#   Requests the Proxmox APT repository. The current platform mapping disallows it on every platform, so both true
#   and false remove proxmox.list and proxmox.sources from /etc/apt/sources.list.d and
#   /usr/share/keyrings/proxmox.gpg. Removal refreshes APT. A Proxmox deployment must supply its own repository
#   under different paths; this option does not install Proxmox.
#
# @param proxy_http
#   Optional HTTP proxy rendered into APT configuration.
#
# @param proxy_https
#   Optional HTTPS proxy rendered into APT configuration.
#
# @param puppet_conf_enable
#   Manages the complete puppet.conf from a template when true (the default) and puppetserver_enable is false.
#   The template contains `[main] certname` and server_list, and `[agent] environment`; other settings are replaced.
#   False leaves puppet.conf and its metadata untouched, including previously managed settings; it does not stop
#   the agent service. The Boolean is passed explicitly to basic_settings::puppet, including false.
#
# @param puppet_version
#   Selects the OpenVox APT component: `8` or `9`. Undef uses major 8 in the repository helper.
#   Does not enable the repository, pin packages, or request an installed agent upgrade or downgrade.
#
# @param puppetserver_enable
#   Enables Puppet Server/OpenVox Server package and service integration. True excludes all agent puppet.conf
#   management, regardless of puppet_conf_enable, and preserves previously written settings.
#   The effective Vox Pupuli source selects upstream packages; otherwise the child uses an explicit distro route.
#   Server package availability is not checked during compilation; source changes do not migrate CA or server data.
#
# @param puppetserver_jvm_memory
#   JVM heap size passed to `basic_settings::puppet`.
#
# @param puppetserver_names
#   Non-empty server names for agent configuration. All names are written as a comma-separated server_list,
#   preserving their order and optional ports. Use puppet_conf_enable to disable management, not undef.
#   Names remain subject to the parameter type when management is disabled.
#
# @param rabbitmq_enable
#   Enables the Erlang and RabbitMQ APT repositories on supported platforms. Removes the unused source format. With
#   false (including omission), or on unsupported platforms, removes rabbitmq-erlang.list/.sources and
#   rabbitmq-server.list/.sources from /etc/apt/sources.list.d, plus rabbitmq-erlang.gpg and rabbitmq-server.gpg
#   from /usr/share/keyrings. Source cleanup refreshes APT; it does not purge the broker package. Keep independent
#   sources on other paths and check shared key use before disabling.
#
# @param server_fdqn
#   Fully qualified host name passed to monitoring, security, package, and network templates, and to the managed
#   agent configuration as `[main] certname`. Defaults to Facter; must match the enrolled agent certificate.
#
# @param server_timezone
#   Timezone passed to `basic_settings::timezone`. The default is `UTC`.
#
# @param smtp_server
#   SMTP relay hostname used by modules that render application mail settings.
#
# @param snap_enable
#   Enables snapd in package management. Ubuntu Pro may force this on when Pro is enabled.
#
# @param sudoers_dir_enable
#   Allows `basic_settings::login` to own and purge `/etc/sudoers.d`. Set to `false` on hosts with existing unmanaged
#   sudoers snippets.
#
# @param sury_enable
#   Enables https://packages.sury.org/php/ on supported Debian and Ubuntu platforms using the
#   debsuryorg-archive-keyring package. Updates existing source content and removes its unused source format. With
#   false (including omission), or when unsupported, removes sury_php.list and sury_php.sources from
#   /etc/apt/sources.list.d and refreshes APT. On Ubuntu it also removes the legacy /usr/share/keyrings/sury.gpg; the
#   archive keyring package is not removed by this branch. Keep independent sources on other paths and check shared
#   key use before disabling.
#
# @param systemd_default_target
#   Target suffix selected as the default target in `basic_settings::systemd`.
#
# @param systemd_notify_mail
#   Mail recipient used by generated systemd failure notifications.
#
# @param systemd_ntp_extra_pools
#   Extra NTP pools passed to `basic_settings::timezone`.
#
# @param unattended_upgrades_block_packages
#   Optional replacement list of packages blocked from unattended upgrades.
#
# @param unattended_upgrades_block_packages_extra
#   Additional package patterns appended to the unattended-upgrades block list.
#
# @param unattended_upgrades_reboot
#   Controls whether unattended-upgrades may reboot the host automatically.
#
# @param usb_any_requirements
#   USB monitoring entries where any one matching device satisfies the requirement.
#
# @param usb_expected
#   USB monitoring entries expected to be present.
#
# @param usb_whitelist
#   USB monitoring entries allowed without raising an unauthorized-device alert.
#
# @param voxpupuli_enable
#   Enables the Vox Pupuli/OpenVox APT repository on supported platforms. The unused source format is removed. With
#   false (including omission), or when the platform disallows it, removes voxpupuli.list and voxpupuli.sources from
#   /etc/apt/sources.list.d and /usr/share/keyrings/openvox-keyring.gpg; this is active cleanup, not leaving
#   existing configuration alone. Source removal refreshes APT. Keep independently managed sources on other paths
#   and check shared key use before disabling.
#
# @param vulnerabilities_package
#   Optional vulnerability scanner integration passed to login policy.
#
# @param vulnerabilities_user
#   User account for the vulnerability scanner integration.
#
# @param wireless_enable
#   Enables wireless package support through `basic_settings::network`.
#
# @api public
class basic_settings (
  Optional[String]                           $antivirus_package                        = undef,
  Boolean                                    $backports                                = false,
  String                                     $cluster_id                               = 'core',
  Optional[String]                           $communication_name                       = undef,
  Optional[String]                           $description                              = undef,
  Enum['allow-downgrade', 'no']              $dns_dnssec                               = 'allow-downgrade',
  Boolean                                    $docker_enable                            = false,
  Boolean                                    $docs_enable                              = false,
  String                                     $environment                              = 'production',
  String                                     $firewall_package                         = 'nftables',
  Boolean                                    $firewall_remove                          = true,
  Boolean                                    $getty_enable                             = false,
  Array[Basic_settings::Getty_unit]          $getty_reserved_units                     = [],
  Boolean                                    $gitlab_enable                            = false,
  Boolean                                    $guest_agent_enable                       = false,
  Enum['none', 'kiosk', 'adwaita-icon']      $gui_mode                                 = 'none',
  Boolean                                    $hosts_enable                             = false,
  Array[String[1]]                           $hosts_localhost_aliases                  = [],
  Enum['none', 'netplan.io']                 $ip_configurator_package                  = 'none',
  Boolean                                    $ip_dhcp_enable                           = true,
  Boolean                                    $ip_forwarding                            = false,
  Boolean                                    $ip_ra_enable                             = true,
  Boolean                                    $ip_ra_learn_prefix                       = true,
  Enum['all', '4']                           $ip_version                               = 'all',
  Integer                                    $kernel_connection_max                    = 4096,
  Enum['auto', 'generic', 'raspi', 'nvidia'] $kernel_flavor                            = 'auto',
  Integer                                    $kernel_hugepages                         = 0,
  Optional[Array[Hash]]                      $kernel_memory_available_profiles         = undef,
  Variant[Boolean, Integer[0]]               $kernel_mglru_enable                      = true,
  String                                     $kernel_network_mode                      = 'strict',
  Enum['initramfs', 'dracut']                $kernel_ram_disk_package                  = 'initramfs',
  Variant[Boolean, String]                   $kernel_security_lockdown                 = true,
  Optional[Array[Hash]]                      $kernel_swap_free_profiles                = undef,
  String                                     $kernel_tcp_congestion_control            = 'brr',
  Integer                                    $kernel_tcp_fastopen                      = 3,
  Optional[Boolean]                          $keyboard_enable                          = undef,
  Boolean                                    $locale_enable                            = false,
  Boolean                                    $lvm_enable                               = false,
  String                                     $mail_package                             = 'postfix',
  Boolean                                    $mongodb_enable                           = false,
  Float                                      $mongodb_version                          = 8.0,
  Enum['none', 'openitcockpit']              $monitoring_package                       = 'none',
  Boolean                                    $monitoring_package_install               = false,
  Boolean                                    $mozilla_enable                           = false,
  Boolean                                    $mysql_enable                             = false,
  Float                                      $mysql_version                            = 8.0,
  Array                                      $network_interfaces                       = ['eth*', 'ens*', 'wlan*'],
  Boolean                                    $nginx_enable                             = false,
  Boolean                                    $nodejs_enable                            = false,
  Integer                                    $nodejs_version                           = 20,
  Boolean                                    $non_free                                 = false,
  Boolean                                    $nvidia_dgx_enable                        = false,
  Boolean                                    $openitcockpit_enable                     = false,
  Optional[String]                           $openitcockpit_license                    = undef,
  Boolean                                    $openitcockpit_nightly                    = false,
  Enum['agent', 'server']                    $openitcockpit_package                    = 'agent',
  Boolean                                    $openjdk_enable                           = false,
  String                                     $openjdk_version                          = 'default',
  Boolean                                    $pro_enable                               = false,
  Boolean                                    $pro_monitoring_enable                    = false,
  Boolean                                    $proxmox_enable                           = false,
  Optional[String]                           $proxy_http                               = undef,
  Optional[String]                           $proxy_https                              = undef,
  Boolean                                    $puppet_conf_enable                       = true,
  Optional[Enum['8', '9']]                   $puppet_version                           = undef,
  Boolean                                    $puppetserver_enable                      = false,
  Enum['512mb', '1gb', '2gb']                $puppetserver_jvm_memory                  = '2gb',
  Array[String[1], 1]                        $puppetserver_names                       = ['puppet'],
  Boolean                                    $rabbitmq_enable                          = false,
  String                                     $server_fdqn                              = $facts['networking']['fqdn'],
  String                                     $server_timezone                          = 'UTC',
  String                                     $smtp_server                              = 'localhost',
  Boolean                                    $snap_enable                              = false,
  Boolean                                    $sudoers_dir_enable                       = true,
  Boolean                                    $sury_enable                              = false,
  String                                     $systemd_default_target                   = 'helpers',
  String                                     $systemd_notify_mail                      = 'root',
  Array                                      $systemd_ntp_extra_pools                  = [],
  Optional[Array]                            $unattended_upgrades_block_packages       = undef,
  Array                                      $unattended_upgrades_block_packages_extra = [],
  Boolean                                    $unattended_upgrades_reboot               = false,
  Array                                      $usb_any_requirements                     = [],
  Array                                      $usb_expected                             = [],
  Array                                      $usb_whitelist                            = [],
  Boolean                                    $voxpupuli_enable                         = false,
  Optional[String]                           $vulnerabilities_package                  = undef,
  Optional[String]                           $vulnerabilities_user                     = undef,
  Boolean                                    $wireless_enable                          = false,
) {
  # Get OS name
  case $facts['os']['name'] {
    'Ubuntu': {
      # Set some variables
      $os_parent = 'ubuntu'
      $os_repo = 'main universe restricted'

      # Select the Ubuntu archive that publishes packages for this architecture.
      if ($facts['os']['architecture'] == 'amd64') {
        # Use the main Ubuntu mirrors for amd64 packages.
        $os_url = 'http://archive.ubuntu.com/ubuntu/'
        $os_url_security = 'http://security.ubuntu.com/ubuntu'
      } else {
        # Use the Ubuntu ports mirrors for other architectures.
        $os_url = 'http://ports.ubuntu.com/ubuntu-ports/'
        $os_url_security = 'http://ports.ubuntu.com/ubuntu-ports/'
      }

      # Do thing based on version
      if ($facts['os']['release']['major'] == '26.04') { # LTS
        # Select the repository formats and package capabilities for Ubuntu 26.04.
        $backports_allow = false
        $deb_version = '822'
        $docker_allow = true
        $gcc_version = 16
        $gitlab_allow = true
        $mongodb_allow = true
        $mozilla_allow = true

        # Restrict these third-party database repositories to their supported architecture.
        if ($facts['os']['architecture'] == 'amd64') {
          # Enable the MySQL and RabbitMQ repository paths selected for amd64.
          $mysql_allow = true
          $rabbitmq_allow = true
        } else {
          # Disable the MySQL and RabbitMQ repository paths on other architectures.
          $mysql_allow = false
          $rabbitmq_allow = false
        }
        $nginx_allow = true
        $nodejs_allow = true
        $openitcockpit_allow = true
        $openjdk_allow = true
        $os_name = 'resolute'
        $ram_disk_package = 'initramfs'
        $proxmox_allow = false
        $puppetserver_jdk = true
        $sury_allow = true
        $voxpupuli_allow = true
      } elsif ($facts['os']['release']['major'] == '24.04') { # LTS
        # Select the repository formats and package capabilities for Ubuntu 24.04.
        $backports_allow = false
        $deb_version = '822'
        $docker_allow = true
        $gcc_version = 14
        $gitlab_allow = true
        $mongodb_allow = true
        $mozilla_allow = true

        # Restrict these third-party database repositories to their supported architecture.
        if ($facts['os']['architecture'] == 'amd64') {
          # Enable the MySQL and RabbitMQ repository paths selected for amd64.
          $mysql_allow = true
          $rabbitmq_allow = true
        } else {
          # Disable the MySQL and RabbitMQ repository paths on other architectures.
          $mysql_allow = false
          $rabbitmq_allow = false
        }
        $nginx_allow = true
        $nodejs_allow = true
        $openitcockpit_allow = true
        $openjdk_allow = true
        $os_name = 'noble'
        $ram_disk_package = 'initramfs'
        $proxmox_allow = false
        $puppetserver_jdk = true
        $sury_allow = true
        $voxpupuli_allow = true
      } elsif ($facts['os']['release']['major'] == '23.04') { # Stable
        # Select the repository formats and package capabilities for Ubuntu 23.04.
        $backports_allow = false
        $deb_version = 'list'
        $docker_allow = true
        $gcc_version = 12
        $gitlab_allow = true
        $mongodb_allow = true
        $mozilla_allow = true

        # Limit MySQL to amd64 while retaining RabbitMQ availability on the other architecture path.
        if ($facts['os']['architecture'] == 'amd64') {
          # Enable the MySQL and RabbitMQ repository paths selected for amd64.
          $mysql_allow = true
          $rabbitmq_allow = true
        } else {
          # Keep RabbitMQ available while disabling the MySQL repository on other architectures.
          $mysql_allow = false
          $rabbitmq_allow = true
        }
        $nginx_allow = true
        $nodejs_allow = true
        $openitcockpit_allow = true
        $openjdk_allow = true
        $os_name = 'lunar'
        $ram_disk_package = 'initramfs'
        $proxmox_allow = false
        $puppetserver_jdk = true
        $sury_allow = false
        $voxpupuli_allow = true
      } elsif ($facts['os']['release']['major'] == '22.04') { # LTS
        # Select the repository formats and package capabilities for Ubuntu 22.04.
        $backports_allow = false
        $deb_version = 'list'
        $docker_allow = true
        $gcc_version = 12
        $gitlab_allow = true
        $mongodb_allow = true
        $mozilla_allow = true

        # Restrict these third-party database repositories to their supported architecture.
        if ($facts['os']['architecture'] == 'amd64') {
          # Enable the MySQL and RabbitMQ repository paths selected for amd64.
          $mysql_allow = true
          $rabbitmq_allow = true
        } else {
          # Disable the MySQL and RabbitMQ repository paths on other architectures.
          $mysql_allow = false
          $rabbitmq_allow = false
        }
        $nginx_allow = true
        $nodejs_allow = true
        $openitcockpit_allow = true
        $openjdk_allow = true
        $os_name = 'jammy'
        $ram_disk_package = 'initramfs'
        $proxmox_allow = false
        $puppetserver_jdk = false
        $sury_allow = true
        $voxpupuli_allow = true
      } else {
        # Disable optional repositories and integrations when no platform mapping is available.
        $backports_allow = false
        $deb_version = 'list'
        $docker_allow = false
        $gcc_version = undef
        $gitlab_allow = false
        $mongodb_allow = false
        $mozilla_allow = false
        $mysql_allow = false
        $nginx_allow = false
        $nodejs_allow = false
        $openitcockpit_allow = false
        $openjdk_allow = false
        $os_name = 'unknown'
        $ram_disk_package = 'initramfs'
        $rabbitmq_allow = false
        $proxmox_allow = false
        $puppetserver_jdk = false
        $sury_allow = false
        $voxpupuli_allow = false
      }
    }
    'Debian': {
      # Set some variables
      $os_parent = 'debian'
      $os_repo = 'main contrib non-free-firmware'
      $os_url = 'http://deb.debian.org/debian/'
      $os_url_security = 'http://deb.debian.org/debian-security/'

      # Do thing based on version
      if ($facts['os']['release']['major'] == '13') {
        # Select the repository formats and package capabilities for Debian 13.
        $backports_allow = false
        $deb_version = 'list'
        $docker_allow = true
        $gcc_version = undef
        $gitlab_allow = true
        $mongodb_allow = true
        $mozilla_allow = true

        # Enable the upstream MySQL repository only for amd64.
        if ($facts['os']['architecture'] == 'amd64') {
          # Enable the MySQL repository path selected for amd64.
          $mysql_allow = true
        } else {
          # Disable the MySQL repository path on other architectures.
          $mysql_allow = false
        }
        $nginx_allow = true
        $nodejs_allow = true
        $openitcockpit_allow = true
        $openjdk_allow = true
        $os_name = 'trixie'
        $ram_disk_package = 'initramfs'
        $rabbitmq_allow = true
        $proxmox_allow = false
        $puppetserver_jdk = true
        $sury_allow = true
        $voxpupuli_allow = true
      } elsif ($facts['os']['release']['major'] == '12') {
        # Select the repository formats and package capabilities for Debian 12.
        $backports_allow = false
        $deb_version = 'list'
        $docker_allow = true
        $gcc_version = undef
        $gitlab_allow = true
        $mongodb_allow = true
        $mozilla_allow = true

        # Enable the upstream MySQL repository only for amd64.
        if ($facts['os']['architecture'] == 'amd64') {
          # Enable the MySQL repository path selected for amd64.
          $mysql_allow = true
        } else {
          # Disable the MySQL repository path on other architectures.
          $mysql_allow = false
        }
        $nginx_allow = true
        $nodejs_allow = true
        $openitcockpit_allow = true
        $openjdk_allow = true
        $os_name = 'bookworm'
        $ram_disk_package = 'initramfs'
        $rabbitmq_allow = true
        $proxmox_allow = false
        $puppetserver_jdk = true
        $sury_allow = true
        $voxpupuli_allow = true
      } else {
        # Disable optional repositories and integrations when no platform mapping is available.
        $backports_allow = false
        $deb_version = 'list'
        $docker_allow = false
        $gcc_version = undef
        $gitlab_allow = false
        $mongodb_allow = false
        $mozilla_allow = false
        $mysql_allow = false
        $nginx_allow = false
        $nodejs_allow = false
        $openitcockpit_allow = false
        $openjdk_allow = false
        $os_name = 'unknown'
        $ram_disk_package = 'initramfs'
        $rabbitmq_allow = false
        $proxmox_allow = false
        $puppetserver_jdk = false
        $sury_allow = false
        $voxpupuli_allow = false
      }
    }
    default: {
      # Disable optional repositories and integrations when no platform mapping is available.
      $backports_allow = false
      $deb_version = 'list'
      $docker_allow = false
      $gcc_version = undef
      $gitlab_allow = false
      $mongodb_allow = false
      $mozilla_allow = false
      $mysql_allow = false
      $nginx_allow = false
      $nodejs_allow = false
      $openitcockpit_allow = false
      $openjdk_allow = false
      $os_name = 'unknown'
      $ram_disk_package = 'initramfs'
      $rabbitmq_allow = false
      $proxmox_allow = false
      $puppetserver_jdk = false
      $sury_allow = false
    }
  }

  # Get ramdisk package
  if ($kernel_ram_disk_package == undef) {
    # Use the platform's default initramfs implementation.
    $kernel_ram_disk_package_correct = $ram_disk_package
  } else {
    # Preserve the requested initramfs implementation.
    $kernel_ram_disk_package_correct = $kernel_ram_disk_package
  }

  # Get snap state
  if ($pro_enable and !$snap_enable) {
    # Keep Snap available for the enabled Ubuntu Pro integration.
    $snap_correct = true
  } else {
    # Honor the caller's Snap setting when Pro does not require it.
    $snap_correct = $snap_enable
  }

  # Get IP RA state
  if ($ip_dhcp_enable and $ip_ra_enable) {
    case $ip_version {
      '4': {
        # Disable IPv6 router advertisements on an IPv4-only host.
        $ip_ra_enable_correct = false
      }
      default: {
        # Preserve the requested router-advertisement setting when IPv6 is available.
        $ip_ra_enable_correct = $ip_ra_enable
      }
    }
  } else {
    # Disable router advertisements when DHCP or router-advertisement handling is turned off.
    $ip_ra_enable_correct = false
  }

  # Get audio state
  case $gui_mode {
    'kiosk': {
      # Enable audio support for the selected kiosk configuration.
      $audio_enable = true
    }
    default: {
      # Leave audio support disabled outside the kiosk configuration.
      $audio_enable = false
    }
  }

  # Reuse packages already supplied by standalone features and keep APT policy consistent.
  ensure_packages(
    [
      'apt',
      'apt-transport-https',
      'bc',
      'coreutils',
      'curl',
      'dash',
      'dpkg',
      'findutils',
      'grep',
      'gnupg',
      'lsb-release',
      'kmod',
      'sed',
      'util-linux',
    ],
    {
      'ensure'          => 'installed',
      'install_options' => ['--no-install-recommends', '--no-install-suggests'],
    },
  )

  # Basic system packages
  package { 'sysstat':
    ensure          => installed,
    install_options => ['--no-install-recommends', '--no-install-suggests'],
  }

  # Reload source list
  exec { 'basic_settings_source_reload':
    command     => '/usr/bin/apt-get update',
    refreshonly => true,
    require     => Package['apt'],
  }

  # Use the source-list format selected for this platform.
  if ($deb_version != '822') {
    # Check if we need backports
    $backports_file = "/etc/apt/sources.list.d/${os_name}-backports.list"
    $backports_packages = ['apt', 'coreutils', 'dash']

    # Escape the backports path before using it in exec commands and guards.
    $backports_file_shell = stdlib::shell_escape($backports_file)

    # Manage the backports source according to both the request and platform availability.
    if ($backports and $backports_allow) {
      # Prepare the backports package options and repository content together.
      $backports_install_options = ['-t', "${os_name}-backports"]

      # Escape generated backports source content before the shell writes it.
      $backports_source_shell = stdlib::shell_escape("deb ${os_url} ${os_name}-backports ${os_repo}\n")
      exec { 'basic_settings_source_backports':
        command => "/usr/bin/printf %s ${backports_source_shell} > ${backports_file_shell}",
        unless  => "/usr/bin/test -e ${backports_file_shell}",
        notify  => Exec['basic_settings_source_reload'],
        require => Package[$backports_packages],
      }
    } else {
      # Use normal package selection when backports are not enabled.
      $backports_install_options = []
      exec { 'basic_settings_source_backports':
        command => "/usr/bin/rm ${backports_file_shell}",
        onlyif  => "/usr/bin/test -e ${backports_file_shell}",
        notify  => Exec['basic_settings_source_reload'],
        require => Package[$backports_packages],
      }
    }

    # Based on OS parent use correct source list
    file { 'basic_settings_source':
      ensure  => file,
      path    => '/etc/apt/sources.list',
      mode    => '0600',
      owner   => 'root',
      group   => 'root',
      content => template("basic_settings/source/${os_parent}.list"),
      notify  => Exec['basic_settings_source_reload'],
      require => Exec['basic_settings_source_backports'],
    }
  } else {
    # Based on OS parent use correct source list
    file { '/etc/apt/sources.list':
      ensure  => file,
      mode    => '0600',
      owner   => 'root',
      group   => 'root',
      content => "# Managed by puppet\n# ${facts['os']['name']} sourcess have to moved to /etc/apt/sources.list.d/${os_parent}.sources\n",
      notify  => Exec['basic_settings_source_reload'],
      require => Package['apt'],
    }

    # Based on OS parent use correct source list
    file { 'basic_settings_source':
      ensure  => file,
      path    => "/etc/apt/sources.list.d/${os_parent}.sources",
      mode    => '0600',
      owner   => 'root',
      group   => 'root',
      content => template("basic_settings/source/${os_parent}.sources"),
      notify  => Exec['basic_settings_source_reload'],
      require => [
        Package['apt'],
        File['/etc/apt/sources.list'],
      ],
    }

    # Check if we need backports
    if ($backports and $backports_allow) {
      # Select packages from the distribution's backports suite.
      $backports_install_options = ['-t', "${os_name}-backports"]
    } else {
      # Use normal package selection when backports are not enabled.
      $backports_install_options = []
    }
  }

  # Set systemd
  class { 'basic_settings::systemd':
    cluster_id      => $cluster_id,
    default_target  => $systemd_default_target,
    install_options => $backports_install_options,
    require         => File['basic_settings_source']
  }

  # Special case when monitoring_package is not none
  if ($monitoring_package != 'none') {
    # Check if variable openitcockpit is true; if true, install new source list and key
    if ($openitcockpit_enable and $openitcockpit_allow) {
      class { 'basic_settings::package_openitcockpit':
        deb_version => $deb_version,
        enable      => true,
        license     => $openitcockpit_license,
        nightly     => $openitcockpit_nightly,
        package     => $openitcockpit_package,
        os_parent   => $os_parent,
        os_name     => $os_name,
      }
    } else {
      class { 'basic_settings::package_openitcockpit':
        deb_version => $deb_version,
        enable      => false,
        license     => $openitcockpit_license,
        nightly     => $openitcockpit_nightly,
        package     => $openitcockpit_package,
        os_parent   => $os_parent,
        os_name     => $os_name,
      }
    }
    $monitoring_requirements = Class['basic_settings::package_openitcockpit', 'basic_settings::systemd']
  } else {
    # Retain systemd ordering without requiring an OpenITCockpit repository.
    $monitoring_requirements = Class['basic_settings::systemd']
  }

  # Setup message
  class { 'basic_settings::monitoring':
    mail_to            => $systemd_notify_mail,
    mail_package       => $mail_package,
    package            => $monitoring_package,
    package_install    => $monitoring_package_install,
    server_fdqn        => $server_fdqn,
    sudoers_dir_enable => $sudoers_dir_enable,
    require            => $monitoring_requirements,
  }

  # Setup security
  class { 'basic_settings::security':
    antivirus_package => $antivirus_package,
    mail_to           => $systemd_notify_mail,
    server_fdqn       => $server_fdqn,
    require           => Class['basic_settings::monitoring'],
  }

  # Set IO
  class { 'basic_settings::io':
    lvm_enable => $lvm_enable,
    require    => Class['basic_settings::monitoring'],
  }

  # Setup APT
  class { 'basic_settings::packages':
    antivirus_package                        => $antivirus_package,
    ip_version                               => $ip_version,
    mail_to                                  => $systemd_notify_mail,
    server_fdqn                              => $server_fdqn,
    snap_enable                              => $snap_correct,
    proxy_http                               => $proxy_http,
    proxy_https                              => $proxy_https,
    unattended_upgrades_block_packages       => $unattended_upgrades_block_packages,
    unattended_upgrades_block_packages_extra => $unattended_upgrades_block_packages_extra,
    unattended_upgrades_reboot               => $unattended_upgrades_reboot,
    require                                  => [
      File['/etc/apt/sources.list'],
      Class['basic_settings::monitoring'],
    ],
  }

  # Set Pro
  class { 'basic_settings::pro':
    enable            => $pro_enable,
    monitoring_enable => $pro_monitoring_enable,
    require           => Class['basic_settings::monitoring']
  }

  # Set timezone
  class { 'basic_settings::timezone':
    timezone        => $server_timezone,
    ntp_extra_pools => $systemd_ntp_extra_pools,
    install_options => $backports_install_options,
    require         => [
      File['basic_settings_source'],
      Class['basic_settings::monitoring'],
    ],
  }

  # Setup kernel
  class { 'basic_settings::kernel':
    antivirus_package         => $antivirus_package,
    connection_max            => $kernel_connection_max,
    guest_agent_enable        => $guest_agent_enable,
    hugepages                 => $kernel_hugepages,
    install_options           => $backports_install_options,
    ip_forwarding             => $ip_forwarding,
    ip_version                => $ip_version,
    ip_ra_enable              => $ip_ra_enable_correct,
    ip_ra_learn_prefix        => $ip_ra_learn_prefix,
    kernel_flavor             => $kernel_flavor,
    memory_available_profiles => $kernel_memory_available_profiles,
    mglru_enable              => $kernel_mglru_enable,
    network_mode              => $kernel_network_mode,
    ram_disk_package          => $kernel_ram_disk_package_correct,
    security_lockdown         => $kernel_security_lockdown,
    swap_free_profiles        => $kernel_swap_free_profiles,
    tcp_congestion_control    => $kernel_tcp_congestion_control,
    tcp_fastopen              => $kernel_tcp_fastopen,
    usb_whitelist             => $usb_whitelist,
    usb_expected              => $usb_expected,
    usb_any_requirements      => $usb_any_requirements
  }

  # Install NVIDIA kernel packages only after Ubuntu sources and the central APT refresh are ready.
  if ($kernel_flavor == 'nvidia') {
    Exec['basic_settings_source_reload'] -> Package['linux-nvidia-hwe-24.04', 'linux-tools-nvidia-hwe-24.04']
  }

  # Set network
  class { 'basic_settings::network':
    antivirus_package       => $antivirus_package,
    communication_name      => $communication_name,
    configurator_package    => $ip_configurator_package,
    dhcp_enable             => $ip_dhcp_enable,
    dns_dnssec              => $dns_dnssec,
    environment             => $environment,
    firewall_package        => $firewall_package,
    firewall_remove         => $firewall_remove,
    hosts_enable            => $hosts_enable,
    hosts_localhost_aliases => $hosts_localhost_aliases,
    install_options         => $backports_install_options,
    interfaces              => $network_interfaces,
    server_fdqn             => $server_fdqn,
    wireless_enable         => $wireless_enable,
    require                 => [
      File['basic_settings_source'],
      Class['basic_settings::monitoring'],
    ],
  }

  # Set timezone
  class { 'basic_settings::locale':
    enable              => $locale_enable,
    docs_enable         => $docs_enable
  }

  # Set assistent
  class { 'basic_settings::assistent':
    audio_enable    => $audio_enable,
    keyboard_enable => $keyboard_enable,
  }

  # Check if variable docket is true; if true, install new source list and key
  if ($docker_enable and $docker_allow) {
    class { 'basic_settings::package_docker':
      deb_version => $deb_version,
      enable      => true,
      os_parent   => $os_parent,
      os_name     => $os_name,
    }
  } else {
    class { 'basic_settings::package_docker':
      deb_version => $deb_version,
      enable      => false,
      os_parent   => $os_parent,
      os_name     => $os_name,
    }
  }

  # Check if variable gitlab is true; if true, install new source list and key
  if ($gitlab_enable and $gitlab_allow) {
    class { 'basic_settings::package_gitlab':
      deb_version => $deb_version,
      enable      => true,
      os_parent   => $os_parent,
      os_name     => $os_name,
    }
  } else {
    class { 'basic_settings::package_gitlab':
      deb_version => $deb_version,
      enable      => false,
      os_parent   => $os_parent,
      os_name     => $os_name,
    }
  }

  # Special case when monitoring_package is none
  if ($monitoring_package == 'none') {
    # Check if variable openitcockpit is true; if true, install new source list and key
    if ($openitcockpit_enable and $openitcockpit_allow) {
      class { 'basic_settings::package_openitcockpit':
        deb_version => $deb_version,
        enable      => true,
        license     => $openitcockpit_license,
        nightly     => $openitcockpit_nightly,
        package     => $openitcockpit_package,
        os_parent   => $os_parent,
        os_name     => $os_name,
      }
    } else {
      class { 'basic_settings::package_openitcockpit':
        deb_version => $deb_version,
        enable      => false,
        license     => $openitcockpit_license,
        nightly     => $openitcockpit_nightly,
        package     => $openitcockpit_package,
        os_parent   => $os_parent,
        os_name     => $os_name,
      }
    }
  }

  # Check if variable mysql is true; if true, install new source list and key
  if ($mongodb_enable and $mongodb_allow) {
    class { 'basic_settings::package_mongodb':
      deb_version => $deb_version,
      enable      => true,
      os_parent   => $os_parent,
      os_name     => $os_name,
      version     => $mongodb_version,
    }
  } else {
    class { 'basic_settings::package_mongodb':
      deb_version => $deb_version,
      enable      => false,
      os_parent   => $os_parent,
      os_name     => $os_name,
    }
  }

  # Check if variable mozilla is true; if true, install new source list and key
  if ($mozilla_enable and $mozilla_allow) {
    class { 'basic_settings::package_mozilla':
      deb_version => $deb_version,
      enable      => true,
      os_parent   => $os_parent,
      os_name     => $os_name,
    }
  } else {
    class { 'basic_settings::package_mozilla':
      deb_version => $deb_version,
      enable      => false,
      os_parent   => $os_parent,
      os_name     => $os_name,
    }
  }

  # Check if variable mysql is true; if true, install new source list and key
  if ($mysql_enable and $mysql_allow) {
    class { 'basic_settings::package_mysql':
      deb_version => $deb_version,
      enable      => true,
      os_parent   => $os_parent,
      os_name     => $os_name,
      version     => $mysql_version,
    }
  } else {
    class { 'basic_settings::package_mysql':
      deb_version => $deb_version,
      enable      => false,
      os_parent   => $os_parent,
      os_name     => $os_name,
    }
  }

  # Check if variable nginx is true; if true, install new source list and key
  if ($nginx_enable and $nginx_allow) {
    class { 'basic_settings::package_nginx':
      deb_version => $deb_version,
      enable      => true,
      os_parent   => $os_parent,
      os_name     => $os_name,
    }
  } else {
    class { 'basic_settings::package_nginx':
      deb_version => $deb_version,
      enable      => false,
      os_parent   => $os_parent,
      os_name     => $os_name,
    }
  }

  # Check if variable nodejs is true; if true, install new source list and key
  if ($nodejs_enable and $nodejs_allow) {
    class { 'basic_settings::package_node':
      deb_version => $deb_version,
      enable      => true,
      version     => $nodejs_version,
    }
  } else {
    class { 'basic_settings::package_node':
      deb_version => $deb_version,
      enable      => false,
    }
  }

  # Let the helper enforce its enable/allow decision so unsupported explicit requests fail instead of silently disabling.
  class { 'basic_settings::package_nvidia_dgx':
    deb_version => $deb_version,
    enable      => $nvidia_dgx_enable,
    os_parent   => $os_parent,
    os_name     => $os_name,
  }

  # Check if variable proxmox is true; if true, install new source list and key
  if ($proxmox_enable and $proxmox_allow) {
    class { 'basic_settings::package_proxmox':
      deb_version => $deb_version,
      enable      => true,
      os_parent   => $os_parent,
      os_name     => $os_name,
    }
  } else {
    class { 'basic_settings::package_proxmox':
      deb_version => $deb_version,
      enable      => false,
      os_parent   => $os_parent,
      os_name     => $os_name,
    }
  }

  # Check if variable rabbitmq is true; if true, install new source list and key
  if ($rabbitmq_enable and $rabbitmq_allow) {
    class { 'basic_settings::package_rabbitmq':
      deb_version => $deb_version,
      enable      => true,
      os_parent   => $os_parent,
      os_name     => $os_name,
    }
  } else {
    class { 'basic_settings::package_rabbitmq':
      deb_version => $deb_version,
      enable      => false,
      os_parent   => $os_parent,
      os_name     => $os_name,
    }
  }

  # Check if variable rabbitmq is true; if true, install new source list and key
  if ($sury_enable and $sury_allow) {
    class { 'basic_settings::package_sury':
      deb_version => $deb_version,
      enable      => true,
      os_parent   => $os_parent,
      os_name     => $os_name,
    }
  } else {
    class { 'basic_settings::package_sury':
      deb_version => $deb_version,
      enable      => false,
      os_parent   => $os_parent,
      os_name     => $os_name,
    }
  }

  # Configure the selected OpenVox source only when enabled and supported by the platform.
  if ($voxpupuli_enable and $voxpupuli_allow) {
    class { 'basic_settings::package_voxpupuli':
      deb_version    => $deb_version,
      enable         => true,
      os_parent      => $os_parent,
      os_version     => $facts['os']['release']['major'],
      puppet_version => $puppet_version,
    }
  } else {
    class { 'basic_settings::package_voxpupuli':
      deb_version    => $deb_version,
      enable         => false,
      os_parent      => $os_parent,
      os_version     => $facts['os']['release']['major'],
      puppet_version => $puppet_version,
    }
  }

  # Remove Java when no enabled feature needs it, retaining GUI dependencies according to the selected mode.
  $puppetserver_java_enable = $puppetserver_enable and ($basic_settings::package_voxpupuli::enable or $puppetserver_jdk)
  if (!($puppetserver_java_enable or ($openjdk_enable and $openjdk_allow))) {
    # Remove openjdk package
    package { 'openjdk':
      ensure => purged,
      name   => 'openjdk*',
    }

    # Setup GUI mode
    case $gui_mode {
      'kiosk': {
        # Enable the icon theme and configuration service needed by the kiosk desktop.
        $adwaita_icon_theme_enable = true
        $dconf_service_enable = true
      }
      'adwaita-icon': {
        # Keep the icon theme without enabling the desktop configuration service.
        $adwaita_icon_theme_enable = true
        $dconf_service_enable = false
      }
      default: {
        # Omit desktop dependencies when no selected component needs them.
        $adwaita_icon_theme_enable = false
        $dconf_service_enable = false
      }
    }

    # Retain icon themes required by the selected GUI mode when Java is removed.
    if ($adwaita_icon_theme_enable) {
      # Install adwaita icon package
      package { 'adwaita-icon-theme':
        ensure          => installed,
        install_options => ['--no-install-recommends', '--no-install-suggests'],
        require         => Package['openjdk'],
      }
    } else {
      # Remove adwaita icon package
      package { 'adwaita-icon-theme':
        ensure  => purged,
        require => Package['openjdk'],
      }
    }

    # Retain dconf only when the selected GUI mode still needs it.
    if ($dconf_service_enable) {
      # Install dconf service package
      package { 'dconf-service':
        ensure          => installed,
        install_options => ['--no-install-recommends', '--no-install-suggests'],
        require         => Package['openjdk'],
      }
    } else {
      # Remove dconf service package
      package { 'dconf-service':
        ensure  => purged,
        require => Package['openjdk'],
      }
    }

    # Remove java extensions
    package { ['ca-certificates-java']:
      ensure  => purged,
      require => Package['openjdk'],
    }
  } else {
    # Get package name
    if ($puppetserver_enable or $openjdk_version == 'default') {
      # Let the distribution choose its default JDK package.
      $openjdk_package = 'default-jdk'
    } else {
      # Select the explicitly requested JDK version.
      $openjdk_package = "openjdk-${openjdk_version}-jdk"
    }

    # Install openjdk package
    package { 'openjdk':
      ensure          => installed,
      name            => $openjdk_package,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
    }

    # Install java extensions
    package { [
        'adwaita-icon-theme',
        'ca-certificates-java',
        'dconf-service',
      ]:
      ensure          => installed,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
      require         => Package['openjdk'],
    }
  }

  # Setup development
  class { 'basic_settings::development':
    gcc_version     => $gcc_version,
    install_options => $backports_install_options,
    require         => File['basic_settings_source']
  }

  # Setup Puppet
  class { 'basic_settings::puppet':
    environment        => $environment,
    jvm_memory         => $puppetserver_jvm_memory,
    puppet_conf_enable => $puppet_conf_enable,
    puppetserver_names => $puppetserver_names,
    server_enable      => $puppetserver_enable,
    server_fdqn        => $server_fdqn,
  }

  # Setup login
  class { 'basic_settings::login':
    environment             => $environment,
    getty_enable            => $getty_enable,
    getty_reserved_units    => $getty_reserved_units,
    gui_mode                => $gui_mode,
    mail_to                 => $systemd_notify_mail,
    server_fdqn             => $server_fdqn,
    sudoers_dir_enable      => $sudoers_dir_enable,
    vulnerabilities_package => $vulnerabilities_package,
    vulnerabilities_user    => $vulnerabilities_user,
  }
}
