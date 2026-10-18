# @summary Manages one additional Nextcloud app and its declared app configuration through OCC.
#
# The resource name is the exact app ID. Declare docker first and provide a visible Docker::Compose,
# Docker::Compose_proxy or Docker::Nextcloud owner named compose_name, with Docker::Compose in the final catalog.
# The existing OCC route uses www-data in the fixed local nextcloud-aio-nextcloud container: one AIO per Docker daemon.
# Missing/stopped containers or an incomplete Nextcloud installation skip all operations without starting anything.
# App files without an installed_version registration fail the read-only registration check and block configuration.
# Commands and guards retain OCC's Sensitive protection and disabled output logging; administrators can still inspect
# process arguments. No container restart, app update, provider registration or system configuration is performed.
#
# @example Keep an additional app installed and globally enabled
#   docker::nextcloud_app { 'user_oidc':
#     compose_name => 'nextcloud-aio',
#     settings     => {
#       'allow_multiple_user_backends' => { 'type' => 'string', 'value' => '0' },
#     },
#   }
#
# @param compose_name
#   Title of the existing AIO deployment owner. The owner supplies the managed Compose resource and runtime
#   dependencies.
#
# @param disable
#   With ensure true, false keeps the app globally enabled, replacing any group restriction; true keeps it disabled.
#   New apps are installed disabled. Disabling precedes settings, so a failed setting cannot prevent deactivation.
#   Enabling waits for registration and every managed setting. Ignored when ensure is false.
#
# @param ensure
#   True installs missing apps and manages their activation and settings without updating installed versions.
#   False only removes an app when its files are present, ignoring disable and settings. OCC removal can delete appdata
#   and run app uninstall steps; it does not guarantee removal of every table or configuration entry. Bundled apps may
#   refuse removal. There is no forced file removal or database purge. Omitting this resource leaves the app unmanaged.
#
# @param settings
#   App configuration keyed by nonempty setting names. Each descriptor requires type and value: string accepts String
#   or Sensitive[String], boolean accepts Boolean, integer accepts Integer. Booleans store 1/0; integers store decimal
#   strings. Empty strings, false and zero are explicit values; undef is invalid. Both storage type and value converge.
#   Empty settings manages no keys; omitted keys, including formerly managed keys, remain untouched. The lifecycle keys
#   enabled and installed_version are reserved. Use the appropriate app wrapper for config.php or provider commands.
#   Sensitive strings remain protected in derived arguments and JSON comparisons; errors identify only app and key.
#
# @api public
define docker::nextcloud_app (
  Pattern[/\A[A-Za-z0-9_.-]+\z/] $compose_name,
  Boolean                        $disable      = false,
  Boolean                        $ensure       = true,
  Hash[String[1], Struct[{
    'type'  => Enum['string', 'boolean', 'integer'],
    'value' => Variant[String, Sensitive[String], Boolean, Integer],
  }]]                            $settings     = {},
) {
  # OCC owns deployment checks and execution; this wrapper only coordinates the app's desired state.
  if (defined(Class['docker'])) {
    # Removal ignores settings; validate combinations only while those values are managed.
    $invalid_settings = $settings.filter |$key, $setting| {
      # Match the declared storage type without interpolating the setting's value into diagnostics.
      $value_type = $setting['type'] ? {
        'string'  => Variant[String, Sensitive[String]],
        'boolean' => Boolean,
        'integer' => Integer,
      }
      $key in ['enabled', 'installed_version'] or !($setting['value'] =~ $value_type)
    }.keys
    if (!$ensure or $invalid_settings.empty) {
      # Present apps must register successfully before settings or activation are touched.
      if ($ensure) {
        docker::nextcloud_occ { "app_${name}_install":
          command      => ['app:install', $name, '--keep-disabled'],
          compose_name => $compose_name,
          unless       => ['app:getpath', $name],
        }

        # Files alone can survive an incomplete installation; missing registration must visibly fail.
        $registration_read = ['config:app:get', $name, 'installed_version']
        docker::nextcloud_occ { "app_${name}_registered":
          command      => $registration_read,
          compose_name => $compose_name,
          unless       => $registration_read,
          require      => Docker::Nextcloud_occ["app_${name}_install"],
        }

        # Global activation differs from a group list; only native app commands change lifecycle state.
        $activation_command = $disable ? { true => 'app:disable', false => 'app:enable' }
        $activation_value = $disable ? { true => 'no', false => 'yes' }

        # Registration is required even when no settings are managed.
        docker::nextcloud_occ { "app_${name}_activation":
          command      => [$activation_command, $name],
          compose_name => $compose_name,
          unless       => ['config:app:get', $name, 'enabled', '--default-value=no'],
          unless_json  => stdlib::to_json($activation_value),
          require      => Docker::Nextcloud_occ["app_${name}_registered"],
        }

        # Disable first, but enable only after every type/value pair; an empty hash still waits for registration.
        $settings_require = $disable ? {
          true  => Docker::Nextcloud_occ["app_${name}_activation"],
          false => Docker::Nextcloud_occ["app_${name}_registered"],
        }
        $settings_before = $disable ? {
          true  => undef,
          false => Docker::Nextcloud_occ["app_${name}_activation"],
        }
        $settings.each |$key, $setting| {
          # Nextcloud exposes ordinary app reads as storage strings, including for typed booleans and integers.
          $setting_type = $setting['type']
          $value = $setting['value']
          $value_unwrapped = $value ? {
            Sensitive => $value.unwrap,
            default   => $value,
          }
          $value_string = $setting_type ? {
            'boolean' => $value ? { true => '1', false => '0' },
            'integer' => String($value),
            'string'  => $value_unwrapped,
          }
          $value_argument = "--value=${value_string}"
          $value_json = stdlib::to_json($value_string)
          $value_argument_correct = $value ? {
            Sensitive => Sensitive($value_argument),
            default   => $value_argument,
          }
          $value_json_correct = $value ? {
            Sensitive => Sensitive($value_json),
            default   => $value_json,
          }
          $setter = ['config:app:set', $name, $key, "--type=${setting_type}", $value_argument_correct]

          # Both guards read the same key, with details added only for the type comparison.
          $getter = ['config:app:get', $name, $key]

          # Equal storage strings can hide different types; check details before comparing the value.
          # https://github.com/nextcloud/server/blob/master/core/Command/Config/App/GetConfig.php
          docker::nextcloud_occ { "app_${name}_setting_type_${key}":
            command      => $setter,
            compose_name => $compose_name,
            json_path    => ['type'],
            unless       => concat($getter, ['--details']),
            unless_json  => stdlib::to_json($setting_type),
            require      => $settings_require,
          }

          # A failed type correction blocks this write; a successful correction already supplies the desired value.
          docker::nextcloud_occ { "app_${name}_setting_value_${key}":
            command      => $setter,
            compose_name => $compose_name,
            unless       => $getter,
            unless_json  => $value_json_correct,
            before       => $settings_before,
            require      => Docker::Nextcloud_occ["app_${name}_setting_type_${key}"],
          }
        }
      } else {
        docker::nextcloud_occ { "app_${name}_remove":
          command      => ['app:remove', $name],
          compose_name => $compose_name,
          onlyif       => ['app:getpath', $name],
        }
      }
    } else {
      fail("docker::nextcloud_app ${name}: invalid type/value combination or reserved setting: ${join($invalid_settings, ', ')}.")
    }
  } else {
    fail('docker::nextcloud_app requires the docker class before its declaration.')
  }
}
