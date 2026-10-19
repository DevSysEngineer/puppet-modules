# @summary Manages integration_openai text and transcription settings through the shared Nextcloud app resource.
#
# Declare docker first and provide the existing AIO deployment named compose_name. This class owns exactly one
# Docker::Nextcloud_app['integration_openai']; do not declare that resource separately. The fixed local AIO container
# supports one installation per Docker daemon. Settings follow integration_openai 5.0.0: ordinary values use string
# storage, including boolean flags and numeric limits. API keys additionally retain native sensitive and lazy flags.
# Undef leaves each app setting untouched, including when a formerly managed parameter is omitted. Empty strings
# explicitly clear string values. Configure Talk recording options separately through docker::nextcloud; this class
# neither selects task providers nor manages AIO's worker. No container restart or app update is performed.
#
# @example Configure a text provider for an existing AIO deployment
#   class { 'docker::nextcloud_integration_openai':
#     compose_name                => 'nextcloud-aio',
#     api_key                     => lookup('profile::nextcloud_ai::api_key', Sensitive[String]),
#     default_completion_model_id => 'nextcloud-verslag',
#     llm_provider_enabled        => true,
#     url                         => 'https://ai.example.org/llm/v1',
#   }
#
# @param compose_name
#   Title of the existing Compose, Compose proxy or Nextcloud owner, visible before OCC evaluates its prerequisites.
#
# @param api_key
#   Administrator API key for text requests, supplied from protected configuration. Undef leaves it untouched;
#   an empty Sensitive string clears it. Personal integration keys can override this administrator key.
#   OCC arguments and comparisons remain Sensitive; administrators can still inspect process arguments.
#
# @param chat_endpoint_enabled
#   True selects the chat-completions endpoint; false selects legacy completions. Undef preserves the stored choice.
#
# @param default_completion_model_id
#   Text model ID exposed by the provider. An empty string restores the app's fallback model; undef leaves it unmanaged.
#
# @param default_stt_model_id
#   Transcription model ID exposed by the provider. An empty string restores the app's fallback; undef leaves it
#   unmanaged.
#
# @param disable
#   False keeps the installed app globally enabled; true keeps it disabled while still managing supplied settings.
#   Ignored when ensure is false. Delegates activation and configuration ordering to docker::nextcloud_app.
#
# @param ensure
#   True installs a missing app and manages activation and supplied settings without automatic updates.
#   False only removes the app through OCC and ignores all settings and keys; removal may delete appdata.
#   An unavailable container or incomplete Nextcloud installation skips execution without starting containers.
#
# @param llm_extra_params
#   Extra text request parameters as a hash, serialized to a JSON object. An empty hash clears the extra parameters;
#   undef leaves them unmanaged. Supply ordinary request options only, without credentials.
#
# @param llm_provider_enabled
#   True enables the app's text provider; false disables it. Undef preserves the stored setting.
#
# @param max_tokens
#   Positive maximum number of generated tokens, stored as a decimal string. Undef preserves the stored limit.
#   The provider and model must support this limit; use_max_completion_tokens_param chooses its request field.
#
# @param request_timeout
#   Positive text request timeout in seconds. Undef preserves the stored timeout.
#
# @param service_name
#   Display name for the text service. An empty string clears the name; undef leaves it unmanaged.
#
# @param stt_api_key
#   Separate administrator API key for transcription, with the same protection and empty/undef behavior as api_key.
#   No key is copied implicitly from api_key; pass the same Sensitive value explicitly when both services share a key.
#
# @param stt_provider_enabled
#   True enables the app's transcription provider; false disables it. Undef preserves the stored setting.
#
# @param stt_request_timeout
#   Positive transcription request timeout in seconds. Undef preserves the stored timeout.
#
# @param stt_service_name
#   Display name for the transcription service. An empty string clears the name; undef leaves it unmanaged.
#
# @param stt_url
#   Transcription API base URL, including its version path. Prefer HTTPS; use HTTP only for a backend without TLS.
#   An empty string restores the app's endpoint fallback; undef leaves it unmanaged.
#
# @param stt_use_basic_auth
#   True uses separately configured transcription Basic Auth credentials; false selects API-key authentication.
#   This parameter does not configure a Basic Auth username or password. Undef preserves the stored choice.
#
# @param url
#   Text API base URL, including its version path. Prefer HTTPS; use HTTP only for a backend without TLS.
#   An empty string restores the app's endpoint fallback; undef leaves it unmanaged.
#
# @param use_basic_auth
#   True uses separately configured text Basic Auth credentials; false selects API-key authentication.
#   This parameter does not configure a Basic Auth username or password. Undef preserves the stored choice.
#
# @param use_max_completion_tokens_param
#   True sends the token limit as max_completion_tokens; false sends max_tokens. Undef preserves the stored choice.
#
# @api public
class docker::nextcloud_integration_openai (
  Pattern[/\A[A-Za-z0-9_.-]+\z/]  $compose_name,
  Optional[Sensitive[String]]     $api_key                         = undef,
  Optional[Boolean]               $chat_endpoint_enabled           = undef,
  Optional[String]                $default_completion_model_id     = undef,
  Optional[String]                $default_stt_model_id            = undef,
  Boolean                         $disable                         = false,
  Boolean                         $ensure                          = true,
  Optional[Hash[String[1], Data]] $llm_extra_params                = undef,
  Optional[Boolean]               $llm_provider_enabled            = undef,
  Optional[Integer[1]]            $max_tokens                      = undef,
  Optional[Integer[1]]            $request_timeout                 = undef,
  Optional[String]                $service_name                    = undef,
  Optional[Sensitive[String]]     $stt_api_key                     = undef,
  Optional[Boolean]               $stt_provider_enabled            = undef,
  Optional[Integer[1]]            $stt_request_timeout             = undef,
  Optional[String]                $stt_service_name                = undef,
  Optional[String]                $stt_url                         = undef,
  Optional[Boolean]               $stt_use_basic_auth              = undef,
  Optional[String]                $url                             = undef,
  Optional[Boolean]               $use_basic_auth                  = undef,
  Optional[Boolean]               $use_max_completion_tokens_param = undef,
) {
  # Omitted values remain unmanaged; false and empty strings must still reach the app configuration.
  $settings = {
    'chat_endpoint_enabled'           => $chat_endpoint_enabled,
    'default_completion_model_id'     => $default_completion_model_id,
    'default_stt_model_id'            => $default_stt_model_id,
    'llm_extra_params'                => $llm_extra_params,
    'llm_provider_enabled'            => $llm_provider_enabled,
    'max_tokens'                      => $max_tokens,
    'request_timeout'                 => $request_timeout,
    'service_name'                    => $service_name,
    'stt_provider_enabled'            => $stt_provider_enabled,
    'stt_request_timeout'             => $stt_request_timeout,
    'stt_service_name'                => $stt_service_name,
    'stt_url'                         => $stt_url,
    'stt_use_basic_auth'              => $stt_use_basic_auth,
    'url'                            => $url,
    'use_basic_auth'                  => $use_basic_auth,
    'use_max_completion_tokens_param' => $use_max_completion_tokens_param,
  }.filter |$key, $value| { $ensure and $value != undef }
  $setting_descriptors = $settings.reduce({}) |$result, $entry| {
    # The app's getters require string storage even for flags and numbers; hashes are request JSON objects.
    # https://github.com/nextcloud/integration_openai/blob/v5.0.0/lib/Service/OpenAiSettingsService.php
    $value = $entry[1]
    $value_string = $value ? {
      Boolean => $value ? { true => '1', false => '0' },
      Hash    => stdlib::to_json($value),
      default => String($value),
    }
    $result + { $entry[0] => { 'type' => 'string', 'value' => $value_string } }
  }

  # Delegate lifecycle, registration and ordinary configuration to the shared app owner.
  docker::nextcloud_app { 'integration_openai':
    ensure       => $ensure,
    compose_name => $compose_name,
    disable      => $disable,
    settings     => $setting_descriptors,
  }

  # Removal must not re-create configuration; only supplied keys are written for an installed app.
  if ($ensure) {
    # Keep the two credentials independent and preserve existing values when either parameter is omitted.
    $api_keys = {
      'api_key'     => $api_key,
      'stt_api_key' => $stt_api_key,
    }.filter |$key, $value| { $value != undef }
    $api_keys.each |$config_key, $config_value| {
      # Protect both the setter argument and the decrypted details comparison without exposing values in diagnostics.
      $value = $config_value.unwrap
      $value_argument = "--value=${value}"
      $argument = Sensitive($value_argument)
      $details_json = stdlib::to_json({
        'app'       => 'integration_openai',
        'key'       => $config_key,
        'value'     => $value,
        'type'      => 'string',
        'lazy'      => true,
        'sensitive' => true,
      })
      $expected_details = Sensitive($details_json)

      # Equal key values still require correction when native storage type, sensitivity or lazy loading differs.
      docker::nextcloud_occ { "integration_openai_${config_key}":
        command      => [
          'config:app:set', 'integration_openai', $config_key,
          '--type=string', '--sensitive', '--lazy', $argument,
        ],
        compose_name => $compose_name,
        unless       => ['config:app:get', 'integration_openai', $config_key, '--details'],
        unless_json  => $expected_details,
        require      => Docker::Nextcloud_app['integration_openai'],
      }
    }
  }
}
