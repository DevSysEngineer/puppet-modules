# @summary Registers or removes one named S3 objectstore through Nextcloud OCC.
#
# Declare docker first and provide the initialized Nextcloud AIO deployment required by docker::nextcloud_occ.
# The resource name is the key below objectstore; only that complete subtree is managed.
# Other stores and the default/root selections are preserved. Registration does not activate primary storage.
# Names start with a letter or digit and use letters, digits, dots, underscores and hyphens.
# The names default, root, class and arguments are reserved.
# Unspecified optional arguments are omitted, including on updates that remove a previously configured override.
# Nextcloud owns their defaults. PHP-style option names are mapped from the snake_case Puppet parameters below.
# Changes to active primary storage require a separate migration plan; removing a store still in use loses access.
# Optional monitoring reads only this subtree using OCC as www-data in nextcloud-aio-nextcloud on the local daemon.
# It requires the existing central monitoring backend, native curl SigV4, and GNU timeout in the AIO container.
# HTTPS also requires host curl >= 7.88 with OpenSSL certificate output. Runtime incompatibilities report UNKNOWN;
# no container packages or permissions are changed.
# One signed HeadBucket (s3:ListBucket permission on AWS), or explicitly selected HeadObject (object read permission),
# assesses metadata access and request duration. HTTPS also checks host CA verification and server certificate expiry.
# This uses the monitoring host network and trust store, not PHP's CA bundle or the container network.
# Uploads, object contents, decryption, deletion and the complete Nextcloud workflow are outside its scope.
# Stored use_ssl=false selects unencrypted HTTP and skips TLS, certificate checks and certificate performance data.
# Otherwise HTTPS is required; there is no automatic downgrade when TLS fails. Legacy authentication,
# credential-provider chains, session credentials, perBucket overrides, special AWS endpoints and literal IPv6
# endpoints are unsupported by this check. It maps the stored Nextcloud 32-34 S3 contract; see the executable usage.
# Disabling or removing a check leaves the shared executable and other targets intact; removing the Puppet declaration
# retires the check through the central concat registration but preserves the stored Nextcloud configuration.
#
# @example Register an S3-compatible store without selecting it as default
#   docker::nextcloud_s3 { 'server1':
#     compose_name   => 'nextcloud-aio',
#     bucket         => 'nextcloud-01',
#     hostname       => 's3.example.org',
#     key            => 'replace-with-access-key',
#     secret         => Sensitive('replace-with-secret'),
#     use_path_style => true,
#   }
#
# @param compose_name
#   Title of the managed docker::compose resource and project label passed to docker::nextcloud_occ.
#   The standard AIO deployment uses nextcloud-aio.
#
# @param bucket
#   S3 bucket name, required when present. Defaults to undef. Use a unique, AWS-compatible bucket per store.
#
# @param concurrency
#   Maximum concurrent multipart uploads. Positive integer; undef leaves the Nextcloud default.
#
# @param connect_timeout
#   S3 connection timeout in seconds, including fractional seconds. Zero disables it; undef leaves the Nextcloud
#   default.
#
# @param copy_size_limit
#   Single-copy size limit in bytes (copySizeLimit). Undef leaves the Nextcloud default.
#
# @param ensure
#   Present manages the named store; absent deletes only that store and needs no credentials. Defaults to present.
#   Before removal, migrate its data and separately change any default/root selection or user mappings referring to it.
#
# @param hostname
#   S3 endpoint hostname without scheme or bucket prefix. Undef leaves Nextcloud's Amazon endpoint selection.
#
# @param key
#   Access key ID, required when present. Accepts String or Sensitive[String]; defaults to undef.
#
# @param legacy_auth
#   True requests legacy signature v2; false keeps the normal signature provider. Undef omits the option.
#
# @param monitoring_detail_limit
#   Optional positive diagnostic character budget (-l, DETAIL_LIMIT), excluding the final Interpretation section.
#   Undef omits the option and uses the environment or executable default.
#
# @param monitoring_enable
#   Defaults to false. True registers this present store when Docker's existing monitoring backend is active.
#   False removes only its monitoring registration and does not alter the store.
#
# @param monitoring_interval
#   Positive agent scheduling interval in seconds, default 300; independent of runtime environment settings.
#
# @param monitoring_object
#   Optional existing object key (-o, S3_OBJECT). Undef omits the option; the executable otherwise uses HeadBucket.
#   An empty string explicitly resets an environment object selection. Nonempty selects exactly one HeadObject;
#   deletion of that object causes an alarm. SSE-C headers come only from the existing store configuration.
#   Control characters cannot be serialized in the agent INI command. No object is created or downloaded.
#   Keys with a path segment consisting of only . or .. report UNKNOWN: native curl SigV4 rewrites those paths.
#
# @param monitoring_response_critical
#   Optional positive response threshold in seconds (-C, RESPONSE_CRITICAL), including fractional seconds.
#   Undef omits the option. Must exceed the effective warning threshold; the executable checks partial overrides.
#
# @param monitoring_response_warning
#   Optional positive response threshold in seconds (-W, RESPONSE_WARNING), including fractional seconds.
#   Undef omits the option. Must be below the effective critical threshold. Only successful HEAD requests use it.
#
# @param monitoring_timeout
#   Optional whole seconds, at least five (-t, TIMEOUT), for the entire check and its agent timeout.
#   Undef omits -t and retains the wrapper's agent default; environment changes do not change the agent budget.
#   The executable reserves three seconds for termination, cleanup and output, and bounds OCC inside the container.
#
# @param monitoring_validity_critical
#   Optional nonnegative days (-c, VALIDITY_CRITICAL). Undef omits the option and uses environment or script default.
#   Remaining validity strictly below this threshold is critical; it must be below the effective warning threshold.
#   Applies only to HTTPS; HTTP ignores this setting. Invalid or mismatched HTTPS certificates are always critical.
#
# @param monitoring_validity_warning
#   Optional positive days (-w, VALIDITY_WARNING). Undef omits the option and uses environment or script default.
#   Remaining validity strictly below this threshold warns; the executable checks partial overrides against defaults.
#   Applies only to HTTPS; HTTP ignores this setting.
#
# @param occ_timeout
#   Maximum seconds per OCC operation, default 120. Independent of S3 connection and request timeouts.
#
# @param port
#   S3 endpoint TCP port, 1 through 65535. Undef leaves Nextcloud's scheme-dependent default.
#
# @param proxy
#   Proxy URL, optionally Sensitive when it contains credentials; false disables the proxy. Undef omits the option.
#
# @param put_size_limit
#   Single-PUT size limit in bytes (putSizeLimit). Undef leaves the Nextcloud default.
#
# @param region
#   S3 region. Undef leaves Nextcloud's region selection; neither region nor hostname is required by this define.
#
# @param secret
#   Secret access key as Sensitive[String], required when present. Defaults to undef; ignored when absent.
#
# @param sse_c_key
#   Sensitive base64-encoded 32-byte SSE-C encryption key. Undef omits the option; retain keys needed to decrypt data.
#
# @param storage_class
#   Object storage class (storageClass), for example STANDARD_IA. Undef leaves the Nextcloud default.
#
# @param timeout
#   S3 timeout in whole seconds; zero disables it. Undef leaves the Nextcloud default.
#   Nextcloud stores this setting in an integer property; fractional values are supported only by connect_timeout.
#
# @param upload_part_size
#   Multipart upload part size in bytes (uploadPartSize). Must be at least 5 MiB; undef leaves the Nextcloud default.
#
# @param use_multipart_copy
#   True enables multipart copy and false disables it (useMultipartCopy). Undef leaves the Nextcloud default.
#
# @param use_path_style
#   True addresses buckets in the URL path; false uses virtual-host addressing. Undef leaves the Nextcloud default.
#
# @param use_ssl
#   True uses HTTPS; false explicitly permits unencrypted S3 traffic. Undef leaves the Nextcloud default.
#   Monitoring follows the stored value. False skips TLS and certificate checks while retaining metadata and latency
#   checks.
#
# @param verify_bucket_exists
#   True checks bucket existence; false skips that check. Undef leaves the Nextcloud default.
#   Disable only after provisioning the bucket; multibucket deployments may need the check.
#
# @param version
#   AWS S3 API version, such as latest or 2006-03-01. Undef leaves the Nextcloud default.
#
# @api public
define docker::nextcloud_s3 (
  Pattern[/\A[A-Za-z0-9_.-]+\z/]                              $compose_name,
  Optional[String[1]]                                         $bucket                       = undef,
  Optional[Integer[1]]                                        $concurrency                  = undef,
  Optional[Variant[Integer[0], Float[0]]]                     $connect_timeout              = undef,
  Optional[Integer[1]]                                        $copy_size_limit              = undef,
  Enum['present', 'absent']                                   $ensure                       = present,
  Optional[String[1]]                                         $hostname                     = undef,
  Optional[Variant[String[1], Sensitive[String[1]]]]          $key                          = undef,
  Optional[Boolean]                                           $legacy_auth                  = undef,
  Optional[Integer[1]]                                        $monitoring_detail_limit      = undef,
  Boolean                                                     $monitoring_enable            = false,
  Integer[1]                                                  $monitoring_interval          = 300,
  Optional[String]                                            $monitoring_object            = undef,
  Optional[Variant[Integer[1], Float[0]]]                     $monitoring_response_critical = undef,
  Optional[Variant[Integer[1], Float[0]]]                     $monitoring_response_warning  = undef,
  Optional[Integer[5]]                                        $monitoring_timeout           = undef,
  Optional[Integer[0]]                                        $monitoring_validity_critical = undef,
  Optional[Integer[1]]                                        $monitoring_validity_warning  = undef,
  Integer[1]                                                  $occ_timeout                  = 120,
  Optional[Integer[1, 65535]]                                 $port                         = undef,
  Optional[Variant[Boolean, String[1], Sensitive[String[1]]]] $proxy                        = undef,
  Optional[Integer[1]]                                        $put_size_limit               = undef,
  Optional[String[1]]                                         $region                       = undef,
  Optional[Sensitive[String[1]]]                              $secret                       = undef,
  Optional[Sensitive[String[1]]]                              $sse_c_key                    = undef,
  Optional[String[1]]                                         $storage_class                = undef,
  Optional[Integer[0]]                                        $timeout                      = undef,
  Optional[Integer[5242880]]                                  $upload_part_size             = undef,
  Optional[Boolean]                                           $use_multipart_copy           = undef,
  Optional[Boolean]                                           $use_path_style               = undef,
  Optional[Boolean]                                           $use_ssl                      = undef,
  Optional[Boolean]                                           $verify_bucket_exists         = undef,
  Optional[String[1]]                                         $version                      = undef,
) {
  # Docker supplies the host runtime; the OCC wrapper owns the AIO invocation.
  if (defined(Class['docker'])) {
    # Reject selection keys and the legacy single-store fields so this resource only owns a named store.
    if ($name =~ /\A[A-Za-z0-9][A-Za-z0-9_.-]*\z/ and !($name in ['default', 'root', 'class', 'arguments'])) {
      # Removal needs only a name; creation requires the three S3 credentials/settings.
      if ($ensure == absent or ($bucket != undef and $key != undef and $secret != undef and $proxy != true)) {
        # Serialize real Puppet data and preserve false, integer and fractional values without copying defaults.
        if ($ensure == present) {
          # Keep the public snake_case names independent of Nextcloud's mixed-case configuration keys.
          $arguments = {
            'bucket'               => $bucket,
            'key'                  => $key,
            'secret'               => $secret,
            'region'               => $region,
            'storageClass'         => $storage_class,
            'hostname'             => $hostname,
            'use_ssl'              => $use_ssl,
            'use_path_style'       => $use_path_style,
            'port'                 => $port,
            'sse_c_key'            => $sse_c_key,
            'concurrency'          => $concurrency,
            'proxy'                => $proxy,
            'connect_timeout'      => $connect_timeout,
            'timeout'              => $timeout,
            'uploadPartSize'       => $upload_part_size,
            'putSizeLimit'         => $put_size_limit,
            'useMultipartCopy'     => $use_multipart_copy,
            'copySizeLimit'        => $copy_size_limit,
            'legacy_auth'          => $legacy_auth,
            'version'              => $version,
            'verify_bucket_exists' => $verify_bucket_exists,
          }.filter |$option, $value| { $value != undef }.reduce({}) |$result, $entry| {
            # Only protected serialization needs the raw credential values.
            $value = $entry[1] ? {
              Sensitive => $entry[1].unwrap,
              default   => $entry[1],
            }
            $result + { $entry[0] => $value }
          }
          $objectstore_json = stdlib::to_json({
            'class'     => '\OC\Files\ObjectStore\S3',
            'arguments' => $arguments,
          })
          $command = ['config:system:set', '--type=json', Sensitive("--value=${objectstore_json}"), 'objectstore', $name]
          $expected_json = Sensitive($objectstore_json)
        } else {
          # OCC renders the explicit missing-value fallback as a JSON string, distinct from any objectstore object.
          $command = ['config:system:delete', 'objectstore', $name]
          $expected_json = '"null"'
        }

        # Read the named subtree as JSON; the explicit missing-value fallback distinguishes absence from an object.
        docker::nextcloud_occ { "s3_${name}":
          command      => $command,
          compose_name => $compose_name,
          timeout      => $occ_timeout,
          unless       => ['config:system:get', '--default-value=null', 'objectstore', $name],
          unless_json  => $expected_json,
        }

        # Retired targets consume neither monitoring overrides nor dependencies on active store configuration.
        $monitoring_active = $ensure == present and $monitoring_enable and $docker::monitoring_enable
          and $basic_settings::monitoring::package != 'none'
        $monitoring_settings_valid = !$monitoring_active or (
          ($use_ssl == false or $monitoring_validity_critical == undef or $monitoring_validity_warning == undef
            or $monitoring_validity_critical < $monitoring_validity_warning)
          and ($monitoring_response_critical == undef or $monitoring_response_critical > 0)
          and ($monitoring_response_warning == undef or $monitoring_response_warning > 0)
          and ($monitoring_response_critical == undef or $monitoring_response_warning == undef
            or $monitoring_response_warning < $monitoring_response_critical)
          and ($monitoring_object == undef or $monitoring_object !~ /[\x00-\x1f\x7f]/)
        )
        if ($monitoring_settings_valid) {
          # Assemble only explicit runtime overrides; the executable owns all measurement defaults.
          if ($monitoring_active) {
            # Shell escaping preserves object keys without permitting new INI lines.
            $monitoring_overrides = {
              '-o' => $monitoring_object,
              '-w' => $monitoring_validity_warning,
              '-c' => $monitoring_validity_critical,
              '-W' => $monitoring_response_warning,
              '-C' => $monitoring_response_critical,
              '-t' => $monitoring_timeout,
              '-l' => $monitoring_detail_limit,
            }.filter |$option, $value| { $value != undef }.map |$option, $value| {
              # Preserve shell arguments through OpenITCOCKPIT ConfigParser's percent interpolation as well.
              $value_shell = stdlib::shell_escape(String($value))
              $value_ini = regsubst($value_shell, '%', '%%', 'G')
              "${option} ${value_ini}"
            }
            $store_shell = stdlib::shell_escape($name)
            $monitoring_cmd = join(concat(["-s ${store_shell}"], $monitoring_overrides), ' ')

            # Registration waits for the shared executable and the named store configuration.
            $monitoring_require = [
              Basic_settings::Monitoring_custom['nextcloud_s3'], Docker::Nextcloud_occ["s3_${name}"],
            ]
          } else {
            # Retirement needs no credentials, executable owner or active OCC dependency.
            $monitoring_cmd = undef
            $monitoring_require = undef
          }

          # Keep each target's registration separate from the shared executable's lifetime.
          $monitoring_ensure = $monitoring_active ? { true => present, default => absent }

          # The central backend owns executable paths and registration cleanup.
          basic_settings::monitoring_custom { "nextcloud_s3_${name}":
            ensure   => $monitoring_ensure,
            cmd      => $monitoring_cmd,
            friendly => "Nextcloud S3 ${name}",
            interval => $monitoring_interval,
            script   => 'nextcloud_s3',
            timeout  => $monitoring_timeout,
            require  => $monitoring_require,
          }
        } else {
          fail('docker::nextcloud_s3 monitoring requires ordered thresholds, positive response times and an object key without control characters.') # lint:ignore:140chars
        }
      } else {
        fail('docker::nextcloud_s3 requires bucket, key and secret when present; proxy must be a URL or false.')
      }
    } else {
      fail('docker::nextcloud_s3 requires a valid objectstore name; default, root, class and arguments are reserved.')
    }
  } else {
    fail('docker::nextcloud_s3 requires the docker class before its declaration.')
  }
}
