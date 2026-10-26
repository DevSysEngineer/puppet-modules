$values = [
  'first',
  'second', # Keep this explanation with its element.
  -1,
  (2 + 3),
  {
    'key' => 'value',
  },
  call(
    'argument',
  ),
  'literal [
        string content
]',
  "${name} [
      interpolated string content
]",
  /[
        pattern content
]/,
  @(TEXT),
        heredoc content [
]
TEXT
  # Keep this comment with the last element.
  'last',
]
