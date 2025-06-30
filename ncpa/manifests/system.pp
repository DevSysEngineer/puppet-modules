class ncpa::system (
  Integer $cpu_warning      = 60,
  Integer $cpu_critical     = 80,
  Integer $memory_warning   = 80,
  Integer $memory_critical  = 90,
  Integer $process_warning  = 300,
  Integer $process_critical = 400,
  Integer $swap_warning     = 80,
  Integer $swap_critical    = 90,
) {
# Create settings file
  file { '/usr/local/ncpa/etc/ncpa.cfg.d/system.cfg':
    ensure  => file,
    content => Sensitive.new(template('ncpa/system.cfg')),
    owner   => 'root',
    group   => 'nagios',
    mode    => '0600',
    notify  => Service['ncpa'],
    require => Package['ncpa'],
  }
}
