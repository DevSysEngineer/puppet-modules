class basic_settings::package_docker (
  Enum['list','822']  $deb_version,
  Boolean             $enable,
  String              $os_name,
  String              $os_parent
) {
  # Check if we need newer format for APT
  if ($deb_version == '822') {
    $file = '/etc/apt/sources.list.d/docker.sources'
  } else {
    $file = '/etc/apt/sources.list.d/docker.list'
  }

  # Set keyrings file
  $key = '/usr/share/keyrings/docker.gpg'

  # Escape repository paths before using them in exec commands and guards.
  $file_shell = stdlib::shell_escape($file)
  $key_shell = stdlib::shell_escape($key)

  if ($enable) {
    # Set url
    $url = "https://download.docker.com/linux/${os_parent}"

    # Get source
    if ($deb_version == '822') {
      $source  = "Types: deb\nURIs: ${url}\nSuites: ${os_name}\nComponents: stable\nSigned-By:${key}\n"
    } else {
      $source = "deb [signed-by=${key}] ${url} ${os_name} stable\n"
    }

    # Escape generated repo content and key URL before the shell writes or fetches them.
    $source_shell = stdlib::shell_escape("# Managed by puppet\n${source}")
    $key_url_shell = stdlib::shell_escape("${url}/gpg")

    # Install docker repo
    exec { 'package_docker_source':
      command => "/usr/bin/printf %s ${source_shell} > ${file_shell}; /usr/bin/curl -fsSL ${key_url_shell} | gpg --dearmor | tee ${key_shell} >/dev/null; chmod 644 ${key_shell}; /usr/bin/apt-get update", #lint:ignore:140chars
      unless  => "/usr/bin/test -e ${file_shell}",
      require => Package['apt', 'apt-transport-https', 'curl', 'gnupg'],
    }
  } else {
    # Remove docker repo
    exec { 'package_docker_source':
      command => "/usr/bin/rm ${file_shell} && /usr/bin/apt-get update",
      onlyif  => "/usr/bin/test -e ${file_shell}",
      require => Package['apt'],
    }

    # Remove docker key
    file { 'package_docker_key':
      ensure => absent,
      path   => $key,
    }
  }
}
