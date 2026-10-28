node 'example.test' {
  if !$supported {
    fail('Unsupported platform.')
  }

  notice('Continuing outside the valid branch')
}
