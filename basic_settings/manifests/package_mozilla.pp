class basic_settings::package_mozilla (
  Enum['list','822']  $deb_version,
  Boolean             $enable,
  String              $os_parent,
  String              $os_name
) {
  # Check if we need newer format for APT
  if ($deb_version == '822') {
    $file = '/etc/apt/sources.list.d/mozilla.sources'
  } else {
    $file = '/etc/apt/sources.list.d/mozilla.list'
  }

  # Set keyrings file
  $key = '/usr/share/keyrings/mozilla.gpg'

  # Check if enabled
  if ($enable) {
    # Get variables
    case $os_parent {
      'ubuntu': {
        $url = 'https://ppa.launchpadcontent.net/mozillateam/ppa/ubuntu'
      }
      default: {
        $url = 'https://packages.mozilla.org/apt'
      }
    }

    # Get source
    if ($deb_version == '822') {
      $source  = "Types: deb\nURIs: ${url}\nSuites: ${os_name}\nComponents: main\nSigned-By:${key}\n"
    } else {
      $source = "deb [signed-by=${key}] ${url} ${os_name} main\n"
    }

    # Add mozilla repo
    case $os_parent {
      'ubuntu': {
        exec { 'package_mozilla_source':
          command => "/usr/bin/printf \"# Managed by puppet\n${source}\" > ${file}; /usr/bin/curl -fsSL 'https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x738BEB9321D1AAEC13EA9391AEBDF4819BE21867' | gpg --dearmor | tee ${key} >/dev/null; chmod 644 ${key}; /usr/bin/apt-get update",
          unless  => "[ -e ${file} ]",
          notify  => Exec['package_mozilla_source_reload'],
          require => Package['apt', 'apt-transport-https', 'curl', 'gnupg'],
        }
      }
      default: {
        exec { 'package_mozilla_source':
          command => "/usr/bin/printf \"# Managed by puppet\n${source}\" > ${file}; /usr/bin/curl -fsSL https://packages.mozilla.org/apt/repo-signing-key.gpg | gpg --dearmor | tee ${key} >/dev/null; chmod 644 ${key}; /usr/bin/apt-get update",
          unless  => "[ -e ${file} ]",
          require => Package['apt', 'apt-transport-https', 'curl', 'gnupg'],
        }
      }
    }
  } else {
    # Remove sury php repo
    exec { 'package_mozilla_source':
      command => "/usr/bin/bash -c '/usr/bin/rm ${file} && /usr/bin/apt-get update'",
      onlyif  => "[ -e ${file} ]",
      require => Package['apt'],
    }

    # Remove sury key
    file { 'package_mozilla_key':
      ensure => absent,
      path   => $key,
    }
  }
}
