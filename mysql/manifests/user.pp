# @summary Creates, updates, or removes a MySQL user account using private credential input.
#
# Declare mysql before this defined type. The helper uses the parent's administrative defaults file and service.
# Desired credentials and SQL exist only during each shell invocation in a private mktemp directory under /root.
# Both the guard and mutation install an EXIT trap before writing inputs; neither leaves managed secret files.
# No account confirmation files persist between runs. SIGKILL cannot run cleanup traps.
# Sensitive hides command text in Puppet reports; the root shell command still contains the rendered credentials.
# Root rotation selects working desired credentials before inspecting accounts, then falls back to existing management
# credentials. Other accounts wait for the managed root configuration. Missing management access stops all mutations.
# Local checks exclude login-path overrides and verify the selected authentication plugin. Socket authentication is
# supported for the class-managed root account only and does not require a password. Every present account must
# authenticate over the local socket and return the managed User@Host identity. Accounts restricted to an external
# client cannot pass this local verification; a different account or failed post-change login stops the operation.
#
# @example Create a MySQL application user after declaring mysql
#   mysql::user { 'app':
#     ensure   => present,
#     password => Sensitive('replace-with-app-password'),
#     username => 'app',
#   }
#
# @param ensure
#   Creates or updates the user when `present`; drops it when `absent`.
#
# @param username
#   MySQL username to manage. The username and hostname together identify the account.
#
# @param hostname
#   MySQL host part for the account. The default is `localhost`; this is an account selector, not a connection endpoint.
#
# @param password
#   Sensitive string required for a present account using password authentication; omit for class-managed socket root
#   or absent accounts.
#   Empty passwords retain their existing meaning.
#   NUL is rejected before applying a catalog because the MySQL client cannot pass it intact. Other characters are
#   encoded separately for SQL and MySQL option files. Plain strings are rejected; convert Hiera lookups at their keys.
#
# @param password_latency
#   Selects the MySQL 8 password storage path. Use `authentication_string` for legacy `mysql_native_password`; the
#   default uses MySQL's default method. MySQL 5.7 uses mysql_native_password; older versions retain SET PASSWORD.
#   The requested plugin must already be available; MySQL 8.4 does not enable mysql_native_password automatically.
#
# @api public
define mysql::user (
  Enum['present', 'absent']   $ensure,
  String                      $username,
  String                      $hostname         = 'localhost',
  Optional[Sensitive[String]] $password         = undef,
  String                      $password_latency = 'password',
) {
  # The parent supplies the service, client packages and shared helper before account management.
  if (defined(Class['mysql'])) {
    # The class-owned root account must run before the new management configuration is published.
    $root_account = $username == 'root' and $hostname == 'localhost' and $mysql::root_managed
    if ($mysql::root_managed and !$root_account) {
      # Ordinary accounts use the completed root rotation, including recovery from an interrupted run.
      $config_require = [File['mysql_debian_cnf']]
    } else {
      # Root itself and unmanaged-root installations retain their existing administrative input.
      $config_require = []
    }

    # The class owns root authentication; ordinary users retain their version and password_latency selection.
    if (!$root_account or $mysql::root_authentication == undef) {
      # Select SQL syntax and plugin requirements once for the helper and SQL rendering.
      case $mysql::version {
        5.7: {
          # MySQL 5.7 retains native authentication while using log-redactable account statements.
          $authentication = 'mysql_native_password'
        }
        8.0, 8.4: {
          # Only the explicit compatibility selection requests the native authentication plugin.
          $authentication = $password_latency ? {
            'authentication_string' => 'mysql_native_password',
            default                 => 'default',
          }
        }
        default: {
          # Preserve the password column and SET PASSWORD statement for older servers.
          $authentication = 'legacy'
        }
      }
    } else {
      # Apply the explicit policy only to the root account owned by the parent class.
      $authentication = $mysql::root_authentication
    }

    # Render native client input only when the desired account uses it.
    if ($ensure == 'present') {
      # Reuse the option-file encoder used by the administrative configuration.
      $client_username = $username
      $client_password = $authentication ? {
        'auth_socket' => undef,
        default       => assert_type(Sensitive[String], $password),
      }
      $client_input = { 'cnf' => template('mysql/client.cnf') }
      $statements = ['inspect', 'drop', 'create', 'alter']
    } else {
      # Retirement needs account selectors only, without rendering a password.
      $client_input = {}
      $statements = ['inspect', 'drop']
    }

    # Keep the existing SQL encoder for both the credential check and mutation.
    $account_input = $statements.reduce($client_input) |$input, $statement| {
      $input + { "${statement}.sql" => template('mysql/user.sql') }
    }
    $temporary_files = $account_input.map |$extension, $content| {
      # Quote rendered input before embedding it in the shell command.
      $content_shell = stdlib::shell_escape($content)
      $filename_shell = stdlib::shell_escape("account.${extension}")
      "printf '%s' ${content_shell} > \"\${tmpdir}\"/${filename_shell} || exit 2"
    }
    $setup_script = join(concat([
      'umask 077',
      'tmpdir=$(/usr/bin/mktemp -d /root/mysql-user-check.XXXXXX) || exit 2',
      'trap \'rm -rf -- "$tmpdir"\' EXIT',
      'trap \'exit 129\' HUP',
      'trap \'exit 130\' INT',
      'trap \'exit 143\' TERM',
    ], $temporary_files), "\n")

    # Quote helper arguments independently; the temporary input prefix is resolved by the shell.
    $script_shell = stdlib::shell_escape($mysql::user_script_path)
    $defaults_shell = stdlib::shell_escape($mysql::defaults_file)
    $authentication_shell = stdlib::shell_escape($authentication)
    $root_shell = stdlib::shell_escape(String($root_account))
    $account_shell = stdlib::shell_escape("${username}@${hostname}")
    $ensure_shell = stdlib::shell_escape($ensure)
    $helper_arguments = join([
      $defaults_shell, '"$tmpdir/account"', $authentication_shell, $root_shell,
      $account_shell,
    ], ' ')

    # Each check and mutation owns its temporary files, even when no change is necessary.
    exec { "mysql_user_${username}@${hostname}":
      provider  => shell,
      unless    => Sensitive.new("${setup_script}\n${script_shell} check-${ensure_shell} ${helper_arguments}"),
      command   => Sensitive.new("${setup_script}\n${script_shell} ${ensure_shell} ${helper_arguments}"),
      logoutput => false,
      require   => concat([Service[$mysql::package_name], File[$mysql::user_script_path]], $config_require),
    }
  } else {
    fail('Class mysql is not defined, but is required for mysql::user')
  }
}
