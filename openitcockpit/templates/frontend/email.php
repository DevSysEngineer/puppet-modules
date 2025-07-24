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
        ],
    ],
];
