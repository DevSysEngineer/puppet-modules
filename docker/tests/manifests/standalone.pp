# Backups require shared systemd; monitoring exposes the Compose monitoring helper.
include basic_settings::systemd
include basic_settings::monitoring

include docker
include nginx

# The application wrappers instantiate Compose, proxy, backup and command helpers.
docker::authentik { 'authentik':
  database_password => Sensitive($facts['compile_test_password']),
  secret_key        => Sensitive($facts['compile_test_password']),
  server_name       => 'auth.example.test',
}

# Compile the CRM wrapper and its database backup.
docker::twenty { 'twenty':
  database_password => Sensitive($facts['compile_test_password']),
  secret_key        => Sensitive($facts['compile_test_password']),
}

# Compile the runner with its default container settings.
docker::gitlab_runner { 'runner': }

# Provide the application used by the integration classes below.
docker::nextcloud { 'nextcloud': }

# Enable the OIDC integration for the existing application.
class { 'docker::nextcloud_user_oidc':
  compose_name => 'nextcloud',
}

# Enable the AI integration for the existing application.
class { 'docker::nextcloud_integration_openai':
  compose_name => 'nextcloud',
}

# Attach synthetic object storage to the existing application.
docker::nextcloud_s3 { 'archive':
  compose_name => 'nextcloud',
  bucket       => 'compile-example',
  key          => $facts['compile_test_password'],
  secret       => Sensitive($facts['compile_test_password']),
}

# Compile an inference service with synthetic model identifiers.
docker::vllm { 'text-ai':
  api_key               => Sensitive($facts['compile_test_api_key']),
  llm_image_tag         => 'v0.11.0',
  llm_model             => 'example/model',
  llm_served_model_name => 'example',
}
