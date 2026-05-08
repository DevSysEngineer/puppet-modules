class basic_settings::package_gitlab (
  Enum['list','822']  $deb_version,
  Boolean             $enable,
  String              $os_parent,
  String              $os_name
) {
  # Check if we need newer format for APT
  if ($deb_version == '822') {
    $file = '/etc/apt/sources.list.d/gitlab.sources'
  } else {
    $file = '/etc/apt/sources.list.d/gitlab.list'
  }

  # Set keyrings file
  $key = '/usr/share/keyrings/gitlab.gpg'

  # Escape repository paths before using them in exec commands and guards.
  $file_shell = stdlib::shell_escape($file)
  $key_shell = stdlib::shell_escape($key)

  if ($enable) {
    # Get source
    if ($deb_version == '822') {
      $source  = "Types: deb\nURIs: https://packages.gitlab.com/gitlab/gitlab-ee/${os_parent}\nSuites: ${os_name}\nComponents: main\nSigned-By:${key}\n"
    } else {
      $source = "deb [signed-by=${key}] https://packages.gitlab.com/gitlab/gitlab-ee/${os_parent} ${os_name} main\n"
    }

    # Escape generated repo content before the shell writes it.
    $source_shell = stdlib::shell_escape("# Managed by puppet\n${source}")

    # Install Gitlab repo
    exec { 'package_gitlab_source':
      command => "/usr/bin/printf %s ${source_shell} > ${file_shell}; /usr/bin/curl -fsSL https://packages.gitlab.com/gitlab/gitlab-ee/gpgkey | gpg --dearmor | tee ${key_shell} >/dev/null; chmod 644 ${key_shell}; /usr/bin/apt-get update", #lint:ignore:140chars
      unless  => "/usr/bin/test -e ${file_shell}",
      require => Package['apt', 'apt-transport-https', 'curl', 'gnupg'],
    }
  } else {
    # Remove Nginx repo
    exec { 'package_gitlab_source':
      command => "/usr/bin/rm ${file_shell} && /usr/bin/apt-get update",
      onlyif  => "/usr/bin/test -e ${file_shell}",
      require => Package['apt'],
    }

    # Remove Gitlab key
    file { 'package_gitlab_key':
      ensure => absent,
      path   => $key,
    }
  }
}
