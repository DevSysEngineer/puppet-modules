# @summary Manages the user_oidc app and its login behavior through the shared Nextcloud app resource.
#
# Declare docker first and provide the existing AIO deployment named compose_name. This class owns exactly one
# Docker::Nextcloud_app['user_oidc']; do not declare that resource separately. The fixed local AIO container supports
# one installation per Docker daemon. Configure providers separately and keep working administrative access through
# /login?direct=1 while available. This setting controls login behavior, not every alternative authentication route.
#
# @example Install OIDC and redirect login to an independently configured provider
#   class { 'docker::nextcloud_user_oidc':
#     compose_name                 => 'nextcloud-aio',
#     allow_multiple_user_backends => false,
#   }
#
# @param compose_name
#   Title of the existing Compose, Compose proxy or Nextcloud owner, visible before OCC evaluates its prerequisites.
#
# @param allow_multiple_user_backends
#   True allows multiple login methods; false redirects login to a single configured, working OIDC provider.
#   Undef leaves the stored setting untouched, including after a previously managed value is omitted.
#   Stored as app type string with value 1 or 0. Does not configure providers, users or credentials.
#
# @param disable
#   False keeps the installed app globally enabled, replacing a group restriction. True keeps it disabled, including
#   during first installation, and disables before applying settings. Ignored when ensure is false.
#
# @param ensure
#   True installs the app when missing and manages activation and supplied settings without automatic app updates.
#   False only removes an app whose files are present through OCC, which may remove appdata; settings are ignored.
#   An incomplete Nextcloud installation or unavailable container skips execution without starting containers.
#
# @api public
class docker::nextcloud_user_oidc (
  Pattern[/\A[A-Za-z0-9_.-]+\z/] $compose_name,
  Optional[Boolean]              $allow_multiple_user_backends = undef,
  Boolean                        $disable                      = false,
  Boolean                        $ensure                       = true,
) {
  # Explicit false must be managed; only undef leaves the existing login setting untouched.
  if ($allow_multiple_user_backends != undef) {
    # user_oidc uses getValueString and compares with '1'; a boolean storage type can fall back to allowing backends.
    # https://github.com/nextcloud/user_oidc/blob/main/lib/Service/SettingsService.php
    $backends_value = $allow_multiple_user_backends ? { true => '1', false => '0' }
    $settings = {
      'allow_multiple_user_backends' => { 'type' => 'string', 'value' => $backends_value },
    }
  } else {
    # Omitting the option preserves previously stored app configuration.
    $settings = {}
  }

  # Delegate lifecycle, registration and configuration ordering to the shared app owner.
  docker::nextcloud_app { 'user_oidc':
    ensure       => $ensure,
    compose_name => $compose_name,
    disable      => $disable,
    settings     => $settings,
  }
}
