define mysql::database (
  Enum['present','absent']    $ensure,
  String                      $charset  = 'utf8',
  String                      $collate  = 'utf8_general_ci',
  Boolean                     $destroy  = false,
  Optional[String]            $import   = undef,
) {
  if (defined(Class['mysql'])) {
    # Set requirements
    Exec {
      require => [Service[$mysql::package_name], File[$mysql::script_path]],
    }

    # Escape MySQL command arguments before using them in exec commands and guards.
    $defaults_file_shell = stdlib::shell_escape($mysql::defaults_file)
    $database_shell = stdlib::shell_escape($title)
    $show_databases_query_shell = stdlib::shell_escape('SHOW DATABASES;')

    # Run query
    case $ensure {
      'present': {
        # Check if we need import SQL to database
        if ($import != undef) {
          # Escape the import path before using it as a shell redirection source.
          $import_shell = stdlib::shell_escape($import)

          # Import database from file
          exec { "mysql_database_import_${title}":
            command     => "/usr/bin/mysql --defaults-file=${defaults_file_shell} -D ${database_shell} < ${import_shell}",
            refreshonly => true,
          }
          $notify = Exec["mysql_database_import_${title}"]
        } else {
          $notify = undef
        }

        # Escape the CREATE DATABASE query before passing it to mysql -e.
        $create_database_query_shell = stdlib::shell_escape("CREATE DATABASE `${title}` DEFAULT CHARACTER SET = '${charset}' DEFAULT COLLATE = '${collate}';")

        # Create database through the shell provider so escaped SQL semicolons and guard pipelines stay intact.
        exec { "mysql_create_database_${title}":
          provider => shell,
          unless   => "/usr/bin/mysql --defaults-file=${defaults_file_shell} -NBe ${show_databases_query_shell} | /usr/bin/grep -qx ${database_shell}",
          command  => "/usr/bin/mysql --defaults-file=${defaults_file_shell} -e ${create_database_query_shell}", #lint:ignore:140chars
          notify   => $notify,
        }
      }
      'absent': {
        if ($destroy) {
          # Escape the DROP DATABASE query before passing it to mysql -e.
          $drop_database_query_shell = stdlib::shell_escape("DROP DATABASE `${title}`;")

          # Drop database through the shell provider so escaped SQL semicolons and guard pipelines stay intact.
          exec { "mysql_drop_database_${title}":
            provider => shell,
            onlyif   => "/usr/bin/mysql --defaults-file=${defaults_file_shell} -NBe ${show_databases_query_shell} | /usr/bin/grep -qx ${database_shell}",
            command  => "/usr/bin/mysql --defaults-file=${defaults_file_shell} -e ${drop_database_query_shell}",
          }
        } else {
          notify { "mysql_drop_database_${title}":
            message => 'Database is set to absent, but will not be deleted unless $destroy is set to true.',
          }
        }
      }
      default: {
        fail('Unknown ensure: $ensure, must be present or absent')
      }
    }
  } else {
    fail('Class mysql is not defined, but is required for mysql::database')
  }
}
