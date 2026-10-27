include catalog_fixture
$value = lookup('catalog_fixture::password', Sensitive[String])
inline_template('<% raise "global Hiera is not empty" unless YAML.safe_load_file(Puppet[:hiera_config]) == {"version" => 5, "hierarchy" => []}; raise "environment fixture missing" unless File.file?(File.join(scope.compiler.environment.configuration.path_to_env, "hiera.yaml")) %>')
if $value.unwrap != 'synthetic-catalog-test-only' { fail('wrong explicit lookup') }
