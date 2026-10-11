$api_key_name_counts = $api_keys.reduce({}) |$result, $api_key| {
  $api_key_name = $api_key['name']
  if ($result[$api_key_name] == undef) {
    $result + { $api_key_name => 1 }
  } else {
    $result + { $api_key_name => $result[$api_key_name] + 1 }
  }
}
$duplicate_api_key_name_counts = $api_key_name_counts.filter |$api_key_name, $count| { $count > 1 }
