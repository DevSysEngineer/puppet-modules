define basic_settings::systemd_timer(
        $ensure         = present,
        $description,
        $unit           = {},
        $timer          = {},
        $install        = {
            'WantedBy'  => 'timers.target'
        },
        $daemon_reload  = 'systemd_daemon_reload'
    ) {

    /* Create timer file */
    file { "/etc/systemd/system/${title}.timer":
        ensure  => $ensure,
        content => template('basic_settings/systemd/timer'),
        mode    => '0644',
        notify  => Exec["${daemon_reload}"],
        require => Package['systemd']
    }

    /* Enable timer */
    service {  "${title}.timer":
        ensure  => true,
        enable  => true,
        require => File["/etc/systemd/system/${title}.timer"]
    }
}
