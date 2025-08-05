<?php
return [
    'Email' => [
        'default' => [
            'transport' => 'default',
            'from'      => 'openitcockpit@<%= @server_fdqn_correct %>'
        ],
    ],
    'EmailTransport' => [
        'default' => [
            'className' => \Cake\Mailer\Transport\MailTransport::class,
            'host'      => '<%= @smtp_server %>',
            'port'      => 25,
            'timeout'   => 30,
            'username'  => null,
            'password'  => null,
            'client'    => null,
            'tls'       => null,
            'url'       => env('EMAIL_TRANSPORT_DEFAULT_URL', null),
        ],
    ]
];
