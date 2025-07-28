class basic_settings::package_openitcockpit (
  Enum['list','822']  $deb_version,
  Boolean             $enable,
  String              $os_parent,
  String              $os_name,
  String              $package,
  Optional[String]    $license = undef
  Boolean             $nightly = false,
) {
  # Check if we need newer format for APT
  if ($deb_version == '822') {
    $file = '/etc/apt/sources.list.d/openitcockpit.sources'
  } else {
    $file = '/etc/apt/sources.list.d/openitcockpit.list'
  }

  # Set keyrings file
  $key = '/usr/share/keyrings/openitcockpit.gpg'

  if ($enable) {
    # Check if package is server or agent
    if ($package == 'server') {
      # Set url
      if ($nightly) {
        $url = "https://packages5.openitcockpit.io/openitcockpit/${os_name}/nightly"
      } else {
        $url = "https://packages5.openitcockpit.io/openitcockpit/${os_name}/stable"
      }

      # Get source
      if ($deb_version == '822') {
        $source  = "Types: deb\nURIs: ${url}\nSuites: ${os_name}\nComponents: main\nSigned-By:${key}\n"
      } else {
        $source = "deb [signed-by=${key}] ${url} ${os_name} main\n"
      }
    } else {
      # Set url
      if ($nightly) {
        $url = 'https://packages5.openitcockpit.io/openitcockpit-agent/deb/nightly'
      } else {
        $url = 'https://packages5.openitcockpit.io/openitcockpit-agent/deb/stable'
      }

      # Get source
      if ($deb_version == '822') {
        $source  = "Types: deb\nURIs: ${url}\nSuites: deb\nComponents: main\nSigned-By:${key}\n"
      } else {
        $source = "deb [signed-by=${key}] ${url} deb main\n"
      }
    }

    # Get license
    if ($license == undef) {
      $license_correct = 'e5aef99e-817b-0ff5-3f0e-140c1f342792' #Community
    } else {
      $license_correct = $license
    }

    # Install openitcockpit license
    file { 'package_openitcockpit_license':
      ensure  => file,
      path    => '/etc/apt/auth.conf.d/openitcockpit.conf',
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      content => "machine packages5.openitcockpit.io login secret password ${license_correct}\n",
      require => Package['apt', 'apt-transport-https'],
    }

    # Install openitcockpit repo
    exec { 'package_openitcockpit_source':
      command => "/usr/bin/printf \"# Managed by puppet\n${source}\" > ${file}; /usr/bin/curl -fsSL https://packages5.openitcockpit.io/repokey.txt | gpg --dearmor | tee ${key} >/dev/null; chmod 644 ${key}; /usr/bin/apt-get update",
      unless  => "[ -e ${file} ]",
      require => [File['package_openitcockpit_license'], Package['curl']],
    }
  } else {
    # Remove openitcockpit license
    file { 'package_openitcockpit_license':
      ensure => absent,
      path   => '/etc/apt/auth.conf.d/openitcockpit.conf',
    }

    # Remove openitcockpit repo
    exec { 'package_openitcockpit_source':
      command => "/usr/bin/bash -c '/usr/bin/rm ${file} && /usr/bin/apt-get update'",
      onlyif  => "[ -e ${file} ]",
      require => Package['apt'],
    }

    # Remove openitcockpit key
    file { 'package_openitcockpit_key':
      ensure => absent,
      path   => $key,
    }
  }
}
