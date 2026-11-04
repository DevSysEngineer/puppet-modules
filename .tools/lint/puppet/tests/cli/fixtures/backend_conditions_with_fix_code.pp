# Register the check when monitoring is active.
$active = $basic_settings::monitoring::package == 'synthetic_backend'
if $active {
  basic_settings::monitoring::custom { 'synthetic': }
}
