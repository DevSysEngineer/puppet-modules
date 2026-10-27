class sample(String $password = 'synthetic-default') {
  $api_key = 'synthetic-key'
  $config = { 'token' => 'synthetic-token' }
  sample::user { 'example': password => 'synthetic-resource' }
  $data = Sensitive('synthetic-wrapped')
  $more = Sensitive.new('synthetic-constructor')
  $encryption_key = 'synthetic-encryption'
  sample::user { 'signing': signing_key => 'synthetic-signing' }
}
