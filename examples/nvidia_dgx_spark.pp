# Docker scenarios require Engine >= 29.0.0 without Swarm and a consumer-managed forward filter loaded before forwarding.
# Arrange firewall activation and boot ordering as described in README; ip_version selects the forwarding families.
# Example: headless NVIDIA DGX Spark / ASUS Ascent GX10 with Ubuntu 24.04 ARM64.
# Declare each class once, in this evaluation order; require relationships alone do not enable Docker's class detection.
# Installs the open headless driver and Container Toolkit; CUDA applications belong in containers.
# Review the package plan and daemon start options before use; no desktop or DGX platform metapackages are requested.
# Review APT changes and boot configuration, retain the generic kernel, and schedule a manual reboot.

node 'dgx-spark.example.org' {
  class { 'basic_settings':
    docker_enable     => true,
    ip_forwarding     => true,
    nginx_enable      => true,
    kernel_flavor     => 'nvidia',
    nvidia_dgx_enable => true,
  }

  # Pin selection precedes driver installation and waits for the NVIDIA sources, APT refresh and selected kernel headers.
  class { 'nvidia':
    pinning => lookup('profile::nextcloud_ai::driver_branch', Integer[1]),
    require => [
      Class['basic_settings::kernel', 'basic_settings::package_nvidia_dgx'],
      Exec['basic_settings_source_reload'],
    ],
  }

  # The declared driver class activates toolkit installation and runtime configuration without another switch.
  class { 'docker':
    require => Class['basic_settings'],
  }

  # Terminate TLS on the host; these vLLM listeners expose HTTP only on loopback.
  class { 'nginx':
    securitytxt_contacts => ['mailto:security@example.org'],
    require              => Class['basic_settings'],
  }

  # Supply official vllm/vllm-openai release tags and model commits after verifying them with this host and driver.
  # Replace the allowed documentation address with the Nextcloud source address observed by Nginx.
  # Verify the image entrypoint is vllm serve and its manifest supports ARM64; tags are passed without suffix changes.
  # Test WAV, MP3 and Talk MP4 directly and via HTTPS; the memory and audio settings below are GPU examples, not CPU defaults.
  docker::vllm { 'nextcloud-ai':
    api_key               => lookup('profile::nextcloud_ai::api_key', Sensitive[String]),
    llm_image_tag         => lookup('profile::nextcloud_ai::llm_image_tag', String[1]),
    llm_model             => 'Qwen/Qwen3-14B',
    llm_served_model_name => 'nextcloud-verslag',
    stt_image_tag         => lookup('profile::nextcloud_ai::stt_image_tag', String[1]),
    stt_model             => 'openai/whisper-large-v3-turbo',
    stt_served_model_name => 'whisper-1',
    server_name           => 'ai.example.org',
    ssl_certificate       => '/etc/letsencrypt/live/ai.example.org/fullchain.pem',
    ssl_certificate_key   => '/etc/letsencrypt/live/ai.example.org/privkey.pem',
    whitelist_ips         => ['192.0.2.10'],
    llm_arguments         => [
      '--revision',
      lookup('profile::nextcloud_ai::llm_revision', String[1]),
      '--dtype',
      'bfloat16',
      '--max-model-len',
      '32768',
      '--max-num-seqs',
      '1',
      '--gpu-memory-utilization',
      '0.45',
      '--reasoning-parser',
      'qwen3',
    ],
    stt_arguments         => [
      '--revision',
      lookup('profile::nextcloud_ai::stt_revision', String[1]),
      '--dtype',
      'float16',
      '--max-model-len',
      '448',
      '--max-num-seqs',
      '1',
      '--gpu-memory-utilization',
      '0.10',
    ],
    stt_environment       => {
      'VLLM_MAX_AUDIO_CLIP_FILESIZE_MB'   => '1024',
      'VLLM_MAX_AUDIO_DECODE_DURATION_S'  => '7200',
      'VLLM_MAX_AUDIO_DECODE_BYTES'       => '2147483648',
      'VLLM_MAX_AUDIO_PREPROCESS_WORKERS' => '1',
    },
  }

}
