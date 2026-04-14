class basic_settings::package_sury (
  Enum['list','822']  $deb_version,
  Boolean             $enable,
  String              $os_parent,
  String              $os_name
) {
  # Check if we need newer format for APT
  if ($deb_version == '822') {
    $file = '/etc/apt/sources.list.d/sury_php.sources'
  } else {
    $file = '/etc/apt/sources.list.d/sury_php.list'
  }

  # Set keyrings file
  $key = '/usr/share/keyrings/sury.gpg'

  # Check if enabled
  if ($enable) {
    # Get variables
    case $os_parent {
      'ubuntu': {
        $url = 'https://ppa.launchpadcontent.net/ondrej/php/ubuntu'
      }
      default: {
        $url = 'https://packages.sury.org/php'
      }
    }

    # Get source
    if ($deb_version == '822') {
      $source  = "Types: deb\nURIs: ${url}\nSuites: ${os_name}\nComponents: main\nSigned-By:${key}\n"
    } else {
      $source = "deb [signed-by=${key}] ${url} ${os_name} main\n"
    }

    # Add sury PHP repo
    case $os_parent {
      'ubuntu': {
        # Write the repo definition and import the signing key directly for Ubuntu systems.
        exec { 'package_sury_source':
          command => "/usr/bin/printf \"# Managed by puppet\n${source}\" > ${file}; /usr/bin/curl -fsSL 'https://keyserver.ubuntu.com/pks/lookup?op=get&search=0xB8DC7E53946656EFBCE4C1DD71DAEAAB4AD4CAB6' | gpg --dearmor | tee ${key} >/dev/null; chmod 644 ${key}; /usr/bin/apt-get update",
          unless  => "[ -e ${file} ]",
          require => Package['apt', 'apt-transport-https', 'curl', 'gnupg'],
        }
      }
      default: {
        # Install the archive keyring through a root-only tempfile and always clean it up on exit.
        exec { 'package_sury_source':
          command => "/usr/bin/bash -c 'set -e; umask 077; tmpfile=\$(/usr/bin/mktemp /root/debsuryorg-archive-keyring.XXXXXX.deb) || exit 1; trap \"rm -f \\\"\$tmpfile\\\"\" EXIT; /usr/bin/curl -fsSL https://packages.sury.org/debsuryorg-archive-keyring.deb -o \"\$tmpfile\"; dpkg -i \"\$tmpfile\"; printf \"%b\" \"${source}\" > ${file}; /usr/bin/apt-get update'", #lint:ignore:140chars
          unless  => "[ -e ${file} ]",
          require => Package['apt', 'apt-transport-https', 'curl', 'gnupg'],
        }
      }
    }
  } else {
    # Remove sury php repo
    exec { 'package_sury_source':
      command => "/usr/bin/bash -c '/usr/bin/rm ${file} && /usr/bin/apt-get update'",
      onlyif  => "[ -e ${file} ]",
      require => Package['apt'],
    }

    # Remove sury key
    if ($os_parent == 'ubuntu') {
      file { 'package_sury_key':
        ensure => absent,
        path   => $key,
      }
    }
  }
}
