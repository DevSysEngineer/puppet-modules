# @summary Creates, updates, or removes a MySQL user account using private credential input.
#
# Declare mysql before this defined type. The helper uses the parent's administrative defaults file and service.
# Desired credentials and SQL stay in root-only files under /usr/local/lib/puppet/mysql-users, without Puppet file
# backups or diffs. Removing an account deletes its secret inputs and confirmation record, but keeps the shared helper.
# Root rotation selects working desired credentials before inspecting accounts, then falls back to existing management
# credentials. Other accounts wait for the managed root configuration. Missing management access stops all mutations.
# Local checks exclude login-path overrides and verify the selected authentication plugin. Socket authentication is
# supported for the class-managed root account only and does not require a password. Remote accounts
# cannot be authenticated from the local socket: their first application sets the password and records the input digest
# and server authentication state. Subsequent runs compare both; an external password change invalidates that record.
#
# @example Create a MySQL application user after declaring mysql
#   mysql::user { 'app':
#     ensure   => present,
#     password => Sensitive('replace-with-app-password'),
#     username => 'app',
#   }
#
# @param ensure
#   Creates or updates the user when `present`; drops it and removes private credential inputs when `absent`.
#
# @param username
#   MySQL username to manage. The username and hostname together identify the account and its private input files.
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
    # Hash the serialized identity so neither path separators nor ambiguous account joins can alias input files.
    $account_id = sha256(to_json([$username, $hostname]))
    $input_base = "${mysql::user_input_dir}/${account_id}"
    $input_files = ["${input_base}.cnf", "${input_base}.create.sql", "${input_base}.alter.sql"]

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

    # Encode all non-secret helper arguments at the shell boundary.
    $script_shell = stdlib::shell_escape($mysql::user_script_path)
    $defaults_shell = stdlib::shell_escape($mysql::defaults_file)
    $input_shell = stdlib::shell_escape($input_base)
    $authentication_shell = stdlib::shell_escape($authentication)
    $root_shell = stdlib::shell_escape(String($root_account))
    $hostname_shell = stdlib::shell_escape($hostname)
    $account_shell = stdlib::shell_escape("${username}@${hostname}")
    $helper_arguments = "${defaults_shell} ${input_shell} ${authentication_shell} ${root_shell} ${hostname_shell} ${account_shell}" # lint:ignore:140chars

    # Inspections and removal statements contain account identifiers only, including during retirement.
    ['inspect', 'drop'].each |$statement| {
      file { "${input_base}.${statement}.sql":
        ensure    => file,
        content   => Sensitive.new(template('mysql/user.sql')),
        backup    => false,
        show_diff => false,
        owner     => 'root',
        group     => 'root',
        mode      => '0600',
        require   => File[$mysql::user_input_dir],
      }
    }

    # Secret input is only rendered for present accounts; Puppet owns its persistent lifecycle.
    if ($ensure == 'present') {
      # Share the client option-file encoder with the class-owned management configuration.
      $client_username = $username
      $client_password = $authentication ? {
        'auth_socket' => undef,
        default       => assert_type(Sensitive[String], $password),
      }

      # Publish only the connection options required by the selected authentication method.
      file { "${input_base}.cnf":
        ensure    => file,
        content   => Sensitive.new(template('mysql/client.cnf')),
        backup    => false,
        show_diff => false,
        owner     => 'root',
        group     => 'root',
        mode      => '0600',
        require   => File[$mysql::user_input_dir],
      }

      # Separate create and alter statements prevent passwordless intermediate accounts.
      ['create', 'alter'].each |$statement| {
        file { "${input_base}.${statement}.sql":
          ensure    => file,
          content   => Sensitive.new(template('mysql/user.sql')),
          backup    => false,
          show_diff => false,
          owner     => 'root',
          group     => 'root',
          mode      => '0600',
          require   => File[$mysql::user_input_dir],
        }
      }
    } else {
      # Remove only this account's secret inputs and helper-owned confirmation record.
      $retired_files = concat($input_files, ["${input_base}.applied"])
      file { $retired_files:
        ensure    => absent,
        backup    => false,
        show_diff => false,
      }
    }

    # Repeat preflight in the mutation path because Puppet treats any failed unless as permission to run command.
    $required_files = concat($input_files, ["${input_base}.inspect.sql", "${input_base}.drop.sql", $mysql::user_script_path])
    $ensure_shell = stdlib::shell_escape($ensure)
    exec { "mysql_user_${username}@${hostname}":
      provider  => shell,
      unless    => Sensitive.new("${script_shell} check-${ensure_shell} ${helper_arguments}"),
      command   => Sensitive.new("${script_shell} ${ensure_shell} ${helper_arguments}"),
      logoutput => false,
      require   => concat([Service[$mysql::package_name], File[$required_files]], $config_require),
    }
  } else {
    fail('Class mysql is not defined, but is required for mysql::user')
  }
}
