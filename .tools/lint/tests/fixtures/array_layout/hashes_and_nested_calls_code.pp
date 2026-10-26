class example (
  Array[String] $defaults = [
    'default_with_a_name_long_enough_to_require_multiline_array_layout',
  ],
) {
  $nested = wrap(join([
    [
      'nested_with_a_name_long_enough_to_require_multiline_array_layout',
    ],
    { 'key' => [
      'value_with_a_name_long_enough_to_require_multiline_array_layout',
    ] },
  ], ' '))
  notify { 'example':
    message => join(
      [
        'message_with_a_name_long_enough_to_require_multiline_array_layout',
      ],
      ' ',
    ),
  }
}
