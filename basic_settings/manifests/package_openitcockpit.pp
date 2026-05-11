class basic_settings::package_openitcockpit (
  Enum['list','822']  $deb_version,
  Boolean             $enable,
  String              $os_name,
  String              $os_parent,
  String              $package,
  Optional[String]    $license = undef,
  Boolean             $nightly = false
) {
  # Check if we need newer format for APT
  if ($deb_version == '822') {
    $file = '/etc/apt/sources.list.d/openitcockpit.sources'
  } else {
    $file = '/etc/apt/sources.list.d/openitcockpit.list'
  }

  # Set keyrings file
  $key = '/usr/share/keyrings/openitcockpit.gpg'

  # Escape repository paths before using them in exec commands and guards.
  $file_shell = stdlib::shell_escape($file)
  $key_shell = stdlib::shell_escape($key)

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

    # Escape generated repo content before the shell writes it.
    $source_shell = stdlib::shell_escape("# Managed by puppet\n${source}")

    # Install openitcockpit license
    file { 'package_openitcockpit_license':
      ensure  => file,
      path    => '/etc/apt/auth.conf.d/openitcockpit.conf',
      owner   => 'root',
      group   => 'root',
      mode    => '0600',
      content => Sensitive.new("machine packages5.openitcockpit.io login secret password ${license_correct}\n"),
      require => Package['apt', 'apt-transport-https'],
    }

    # Install openitcockpit repo
    exec { 'package_openitcockpit_source':
      command => "/usr/bin/printf %s ${source_shell} > ${file_shell}; /usr/bin/curl -fsSL https://packages5.openitcockpit.io/repokey.txt | gpg --dearmor | tee ${key_shell} >/dev/null; chmod 644 ${key_shell}; /usr/bin/apt-get update", #lint:ignore:140chars
      unless  => "/usr/bin/test -e ${file_shell}",
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
      command => "/usr/bin/rm ${file_shell} && /usr/bin/apt-get update",
      onlyif  => "/usr/bin/test -e ${file_shell}",
      require => Package['apt'],
    }

    # Remove openitcockpit key
    file { 'package_openitcockpit_key':
      ensure => absent,
      path   => $key,
    }
  }
}
