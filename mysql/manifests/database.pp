define mysql::database (
  Enum['present','absent']    $ensure,
  String                      $charset  = 'utf8',
  String                      $collate  = 'utf8_general_ci',
  Boolean                     $destroy  = false,
  Optional[String]            $import   = undef,
) {
  # Set requirements
  Exec {
    require => [Service[$mysql::package_name], File[$mysql::script_path]],
  }

  # Run query
  case $ensure {
    'present': {
      # Check if we need import SQL to database
      if ($import != undef) {
        # Import database from file
        exec { "mysql_database_import_${title}":
          command     => "/usr/bin/bash -c \"mysql --defaults-file=${mysql::defaults_file} -D ${title} ' < ${import}",
          refreshonly => true,
        }
        $notify = Excec["mysql_database_import_${title}"]
      } else {
        $notify = undef
      }

      # Create database
      exec { "mysql_create_database_${title}":
        unless  => "/usr/bin/bash -c \"mysql --defaults-file=${mysql::defaults_file} -NBe 'SHOW DATABASES;' | grep -qx '${title}'\"",
        command => "mysql --defaults-file=${mysql::defaults_file} -e \"CREATE DATABASE \\`${title}\\` DEFAULT CHARACTER SET = '${charset}' DEFAULT COLLATE = '${collate}';\"", #lint:ignore:140chars
        notify  => $notify,
      }
    }
    'absent': {
      if ($destroy) {
        exec { "mysql_drop_database_${title}":
          onlyif  => "/usr/bin/bash -c \"mysql --defaults-file=${mysql::defaults_file} -NBe 'SHOW DATABASES;' | grep -qx '${title}'\"",
          command => "mysql --defaults-file=${mysql::defaults_file} -e \"DROP DATABASE \\`${title}\\`;\"",
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
}
