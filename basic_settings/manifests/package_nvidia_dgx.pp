# @summary Manages the NVIDIA DGX and CUDA APT repositories for Ubuntu Noble ARM64.
#
# This private helper requires Exec['basic_settings_source_reload'] from basic_settings. It manages only the two
# repository definitions and their public signing keys. Both keys are bootstrapped again when either is missing or
# empty; changed non-empty keys and upstream key rotation are not detected. Source content and permissions converge
# on every run. No NVIDIA software, APT preferences, upgrades or reboot settings are managed here.
#
# @example Enable through the existing basic_settings declaration on Ubuntu 24.04 ARM64
#   class { 'basic_settings':
#     nvidia_dgx_enable => true,
#   }
#
# @param deb_version
#   APT source format to manage: `list` or `822`. The other format is removed.
#
# @param enable
#   Creates both repositories and bootstraps their keys when `true`; removes all four source filenames and both keys
#   when `false`, including on unsupported platforms. Check other sources for shared use of these keys before rollout.
#
# @param os_name
#   Platform codename from basic_settings. Enabling requires `noble` and Ubuntu release `24.04`.
#
# @param os_parent
#   Platform family from basic_settings. Enabling requires `ubuntu` and ARM64; Facter may report `aarch64` or `arm64`.
#
# @api private
class basic_settings::package_nvidia_dgx (
  Enum['list', '822'] $deb_version,
  Boolean             $enable,
  String              $os_name,
  String              $os_parent,
) {
  # Keep the support decision here so direct helper calls cannot activate repositories for another platform.
  $nvidia_dgx_allow = $os_parent == 'ubuntu' and $os_name == 'noble' and $facts['os']['name'] == 'Ubuntu'
    and $facts['os']['release']['major'] == '24.04' and $facts['os']['architecture'] in ['aarch64', 'arm64']

  # Reject unsupported activation while allowing cleanup independently of platform support.
  if (!$enable or $nvidia_dgx_allow) {
    # APT owns the source directory and supplies the existing refresh command on either lifecycle path.
    ensure_packages('apt', {
      'ensure'          => 'installed',
      'install_options' => ['--no-install-recommends', '--no-install-suggests'],
    })

    # Limit ownership to these repository definitions and signing keys.
    $keys = ['/usr/share/keyrings/cuda_debian_prod.gpg', '/usr/share/keyrings/dgx_debian_prod.gpg']
    $source_files = [
      '/etc/apt/sources.list.d/cuda-compute-repo.list',
      '/etc/apt/sources.list.d/cuda-compute-repo.sources',
      '/etc/apt/sources.list.d/dgx.list',
      '/etc/apt/sources.list.d/dgx.sources',
    ]

    # Enable only the mapped platform; false always removes this helper's files.
    if ($enable and $nvidia_dgx_allow) {
      # Supply every external command used by the bootstrap, including tar's gzip subprocess and the POSIX shell.
      $repository_packages = ['apt', 'ca-certificates', 'coreutils', 'curl', 'dash', 'gzip', 'tar']
      ensure_packages($repository_packages, {
        'ensure'          => 'installed',
        'install_options' => ['--no-install-recommends', '--no-install-suggests'],
      })

      # Public APT keyrings must be reachable by APT's unprivileged signature-verification process.
      file { '/usr/share/keyrings':
        ensure  => directory,
        owner   => 'root',
        group   => 'root',
        mode    => '0755',
        require => Package['apt'],
      }

      # Keep shell expansion literal until execution; stage both complete keys before replacing either destination.
      $bootstrap = @(BOOTSTRAP)
        set -eu
        die() {
            printf '%s\n' "$1" >&2
            exit 1
        }
        CURL=$(command -v curl) || die 'curl is required'
        TAR=$(command -v tar) || die 'tar is required'
        MKTEMP=$(command -v mktemp) || die 'mktemp is required'
        RM=$(command -v rm) || die 'rm is required'
        CHMOD=$(command -v chmod) || die 'chmod is required'
        CHOWN=$(command -v chown) || die 'chown is required'
        MV=$(command -v mv) || die 'mv is required'

        # Stage on the keyring filesystem so each final rename is atomic.
        umask 077
        TEMP_DIR=$($MKTEMP -d /usr/share/keyrings/.nvidia-dgx.XXXXXX)
        trap '$RM -rf -- "$TEMP_DIR"' 0
        trap 'exit 1' HUP INT TERM

        # HTTPS trust and exact archive members are required; no source files or preferences are extracted.
        $CURL -fsSL --proto '=https' --proto-redir '=https' \
            https://repo.download.nvidia.com/baseos/ubuntu/noble/arm64/dgx-repo-files.tgz \
            -o "$TEMP_DIR/repositories.tgz"
        $TAR -xOzf "$TEMP_DIR/repositories.tgz" ./usr/share/keyrings/cuda_debian_prod.gpg > "$TEMP_DIR/cuda.gpg"
        $TAR -xOzf "$TEMP_DIR/repositories.tgz" ./usr/share/keyrings/dgx_debian_prod.gpg > "$TEMP_DIR/dgx.gpg"
        test -s "$TEMP_DIR/cuda.gpg" && test -s "$TEMP_DIR/dgx.gpg" || die 'NVIDIA signing keys must both be non-empty'

        # Preserve the binary key bytes; these public signing keys must remain readable by APT.
        $CHOWN root:root "$TEMP_DIR/cuda.gpg" "$TEMP_DIR/dgx.gpg"
        $CHMOD 0644 "$TEMP_DIR/cuda.gpg" "$TEMP_DIR/dgx.gpg"
        $MV -f -- "$TEMP_DIR/cuda.gpg" /usr/share/keyrings/cuda_debian_prod.gpg
        $MV -f -- "$TEMP_DIR/dgx.gpg" /usr/share/keyrings/dgx_debian_prod.gpg
        | BOOTSTRAP
      $bootstrap_shell = stdlib::shell_escape($bootstrap)
      exec { 'package_nvidia_dgx_keys':
        provider => shell,
        command  => "/bin/dash -c ${bootstrap_shell}",
        unless   => '/bin/dash -c "test -s /usr/share/keyrings/cuda_debian_prod.gpg && test -s /usr/share/keyrings/dgx_debian_prod.gpg"',
        path     => ['/usr/bin', '/bin'],
        require  => [Package[$repository_packages], File['/usr/share/keyrings']],
        notify   => Exec['basic_settings_source_reload'],
      }

      # Public signing keys need mode 0644 for APT; a management header would corrupt their binary format.
      file { $keys:
        ensure  => file,
        replace => false,
        owner   => 'root',
        group   => 'root',
        mode    => '0644',
        require => Exec['package_nvidia_dgx_keys'],
        notify  => Exec['basic_settings_source_reload'],
      }

      # Use only the explicit Noble ARM64 mapping; CUDA names that architecture sbsa.
      $dgx_url = 'https://repo.download.nvidia.com/baseos/ubuntu/noble/arm64/'
      $cuda_url = 'https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/sbsa/'

      # Generate both source formats directly and remove only this helper's alternative filenames.
      if ($deb_version == '822') {
        # deb822 keeps CUDA's flat suite and omits Components.
        $extension = 'sources'
        $alternative = 'list'
        $dgx_content = "# Managed by puppet\nTypes: deb\nURIs: ${dgx_url}\nSuites: noble noble-updates\nComponents: common dgx\nSigned-By: /usr/share/keyrings/dgx_debian_prod.gpg\n" # lint:ignore:140chars
        $cuda_content = "# Managed by puppet\nTypes: deb\nURIs: ${cuda_url}\nSuites: /\nSigned-By: /usr/share/keyrings/cuda_debian_prod.gpg\n" # lint:ignore:140chars
      } else {
        # Classic sources need a separate entry for each DGX suite and the flat CUDA suite.
        $extension = 'list'
        $alternative = 'sources'
        $dgx_content = "# Managed by puppet\ndeb [signed-by=/usr/share/keyrings/dgx_debian_prod.gpg] ${dgx_url} noble common dgx\ndeb [signed-by=/usr/share/keyrings/dgx_debian_prod.gpg] ${dgx_url} noble-updates common dgx\n" # lint:ignore:140chars
        $cuda_content = "# Managed by puppet\ndeb [signed-by=/usr/share/keyrings/cuda_debian_prod.gpg] ${cuda_url} /\n"
      }

      # Every source change waits for both keys; every source resource precedes the shared refresh.
      file { ["/etc/apt/sources.list.d/cuda-compute-repo.${alternative}", "/etc/apt/sources.list.d/dgx.${alternative}"]:
        ensure  => absent,
        require => File[$keys],
        notify  => Exec['basic_settings_source_reload'],
      }

      # Enforce source content on every run using the same root-only permissions as the base APT sources.
      $sources = {
        "/etc/apt/sources.list.d/cuda-compute-repo.${extension}" => $cuda_content,
        "/etc/apt/sources.list.d/dgx.${extension}"               => $dgx_content,
      }
      $sources.each |String $source_path, String $source_content| {
        file { $source_path:
          ensure  => file,
          content => $source_content,
          owner   => 'root',
          group   => 'root',
          mode    => '0600',
          require => File[$keys],
          notify  => Exec['basic_settings_source_reload'],
        }
      }
    } else {
      # Remove all owned source variants before their keys and the existing APT refresh.
      file { $source_files:
        ensure  => absent,
        require => Package['apt'],
        notify  => Exec['basic_settings_source_reload'],
      }

      # Other repositories must stop referencing these keys before this helper is disabled.
      file { $keys:
        ensure  => absent,
        require => File[$source_files],
        notify  => Exec['basic_settings_source_reload'],
      }
    }
  } else {
    fail('NVIDIA DGX repositories require Ubuntu 24.04 (noble) with ARM64 architecture; disable nvidia_dgx_enable to clean up.')
  }
}
