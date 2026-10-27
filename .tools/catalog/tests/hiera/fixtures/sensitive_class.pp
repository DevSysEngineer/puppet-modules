class catalog_fixture(Sensitive[String] $password) {
  if $password.unwrap != 'synthetic-catalog-test-only' { fail('wrong automatic lookup') }
}
