# Puppet-modules
Welkom bij mijn Puppet-modules project. Dit is een uitgebreide module voor je Puppet-omgeving, bestaande uit verschillende onderdelen: `Basic settings`, `Docker`, `GitLab`, `Let's Encrypt`, `Nginx`, `PHP`, `MySQL`, `SSH`, `RabbitMQ` en `vnStat`. Deze onderdelen kunnen afzonderlijk of in combinatie worden gebruikt om je infrastructuur te verbeteren. Om deze uitbreiding mogelijk te maken, vertrouw ik op andere Puppet-modules, die ik heb toegevoegd als git-submodules. Ik wil graag de makers van [concat](https://github.com/puppetlabs/puppetlabs-concat.git), [debconf](https://github.com/smoeding/puppet-debconf.git), [reboot](https://github.com/puppetlabs/puppetlabs-reboot.git), [stdlib](https://github.com/puppetlabs/puppetlabs-stdlib.git) en [timezone](https://github.com/saz/puppet-timezone.git) bedanken voor hun waardevolle bijdragen.

> [!IMPORTANT]
> **Perforce zet Puppet open-sourcecode achter betaalmuur**: In 2025 heeft Perforce, het bedrijf achter Puppet, besloten om de open-sourcecode van Puppet achter een gesloten omgeving te plaatsen. Deze omgeving blijft gratis tot 25 nodes. Heb je er meer, dan moet je gaan betalen. Vind jij – net als ik – dat open source toegankelijk en vrij beschikbaar moet blijven? Stap dan over naar [Vox Pupuli](https://voxpupuli.org/). Vox Pupuli biedt een drop-in replacement voor Puppet. Dat betekent dat je het Puppet-pakket kunt vervangen door openvox package van Vox Pupuli, zonder aanpassingen aan je bestaande configuratie.

> [!CAUTION]
> **Compatibiliteit**: Deze uitbreidingsmodule is ontworpen voor 64-bits besturingssystemen.

## Inhoudsopgave
- [Gebruik van voorbeelden](#gebruik-van-voorbeelden)
- [Beveiligingsaanpassingen](#beveiligingsaanpassingen)
- [Monitoring](#monitoring)
- [Installatie](#installatie)
- [Modules](#modules)
  - [Basic settings](#basic-settings)
  - [Docker](#docker)
  - [Let's Encrypt](#lets-encrypt)
  - [MySQL](#mysql)
  - [GitLab](#gitlab)
  - [Nginx](#nginx)
  - [PHP](#php)
  - [SSH](#ssh)
  - [RabbitMQ](#rabbitmq)
  - [VnStat](#vnstat)
- [Checks](#checks)
- [Voorbeelden](#voorbeelden)
- [Contributie](#contributie)

## Gebruik van voorbeelden
De voorbeelden in deze README gebruiken `example.org`, `xxxx.nl`, `replace-with-...` en vergelijkbare waarden als plaatsvervangers. Vervang die altijd door je eigen hostnamen, paden, gebruikersnamen en geheimen.

Gebruik `Sensitive('...')` of `Sensitive.new(...)` voor wachtwoorden, tokens en andere geheimen. Zet echte geheimen niet letterlijk in gedeelde voorbeelden of documentatie.

De README geeft per module de bedoeling, belangrijke defaults en een paar bruikbare voorbeelden. Uitgebreide varianten staan in de map `examples/`, terwijl je editor, linter en Puppet Strings-documentatie de volledige parameterlijst van classes en defined types tonen.

## Beveiligingsaanpassingen
Binnen de verschillende onderdelen heb ik diverse beveiligingsverbeteringen geïmplementeerd, ook wel bekend als [hardening](https://en.wikipedia.org/wiki/Hardening_(computing)). Dit kan leiden tot afwijkend gedrag van softwarepakketten ten opzichte van de oorspronkelijke verwachtingen. Voorbeelden hiervan zijn extra opties in systemd zoals `PrivateTmp: true`, `ProtectHome: true`, `ProtectSystem: full` en `UMask=0077`, en aanpassingen aan GRUB zodat de kernel bij het opstarten in een hardening modus draait. Ook zijn PAM-instellingen zo aangepast dat bestanden via umask 0077 worden aangemaakt. Systemd-services krijgen deze umask expliciet per service wanneer dit veilig is; services die bewust bestanden, logs of sockets delen vallen terug op de standaard umask of krijgen per service een minder strikte en gemotiveerde niet-standaard waarde. Ik wil madaidan en zijn pagina [linux-hardening](https://madaidans-insecurities.github.io/guides/linux-hardening.html) bedanken voor de waardevolle tips; een groot deel van deze informatie heb ik als inspiratie gebruikt.

Daarnaast worden gevoelige lokale hulpbestanden, zoals APT-authenticatie voor OpenITCOCKPIT, tijdelijke installer-downloads en het lokale Grafana-beheerwachtwoord, zoveel mogelijk root-only opgeslagen om onnodige blootstelling aan lokale gebruikers te beperken.

Voor kernel-lockdown gebruikt `basic_settings` dezelfde expliciete vorm als andere hardeningwaarden met een veilige default: `kernel_security_lockdown => true` gebruikt de standaard `integrity`, `false` vertaalt naar `none`, en een string zoals `'confidentiality'` wordt als expliciete lockdownwaarde gebruikt. Bij Secure Boot blijft `integrity` de minimale waarde. Voor MGLRU gebruikt `kernel_mglru_enable => true` de standaard `min_ttl_ms` van `1000`, `false` schakelt MGLRU uit, en een integer stelt een eigen `min_ttl_ms` in.

Hoewel vergelijkbare maatregelen door softwareleveranciers en Linux-distributies (zoals [Fedora](https://discussion.fedoraproject.org/t/f40-change-proposal-systemd-security-hardening-system-wide/96423/11)) worden toegepast, kies ik ervoor om deze aanpassingen ook in Puppet op te nemen. Dit is omdat niet alle distributies altijd de meest recente versie van de software gebruiken en er altijd een kans bestaat dat een specifieke beveiligingsaanpassing niet is doorgevoerd.

## Monitoring
Binnen de verschillende onderdelen zijn diverse monitoringtools en -scripts beschikbaar. Wanneer je in de `basic_settings`-class de optie `monitoring_package` instelt met een ondersteund monitoringpakket, worden automatisch configuratiebestanden voor dat pakket aangemaakt. Gebruik je basic_settings niet, dan kun je de ingebouwde monitoringtools en -scripts altijd handmatig activeren vanuit andere onderdelen.

Voor sommige processen, zoals firewall of SSH, is het niet voldoende om alleen te controleren of een proces draait. Vaak wil je ook verifiëren of het correct functioneert én performancegegevens kunnen uitlezen. Daarom zijn er voor bepaalde processen uitgebreide checks toegevoegd. De zichtbare statusregel van zo'n check hoort daarbij met het gecontroleerde onderdeel te beginnen en leesbare tekst te blijven; machinegerichte perfdata hoort in het perfdata-gedeelte en niet als `key=value`-tekst in de samenvatting.

Op dit moment wordt alleen de [OpenITCOCKPIT](https://openitcockpit.io/)-agent ondersteund. Hieronder vind je een voorbeeldconfiguratie:

Voor maatwerkchecks gebruikt de repository `basic_settings::monitoring_custom`. Deze helper plaatst het script in de OpenITCOCKPIT-pluginmap, registreert `customchecks.ini` en kan via de parameter `cmd` vaste argumenten achter het scriptpad zetten.

`basic_settings::monitoring` plaatst daarnaast de gedeelde mailhelper `/usr/local/lib/puppet/monitoring-notify`. Shellscripts kunnen de mailbody via stdin doorgeven en het onderwerp als argument meegeven. Met `-t` of `--to` kan een script een eigen ontvanger blijven gebruiken; zonder die optie gebruikt de helper de `mail_to`-waarde van de monitoringclass.

```sh
printf '%s\n' "$body" | /usr/local/lib/puppet/monitoring-notify -t beheer@example.nl "Onderwerp"
```

```puppet
node 'webserver.dev.xxxx.nl' {
    class { 'basic_settings':
        monitoring_package          => 'openitcockpit',
        monitoring_package_install  => true,
    }

    # Setup openitcockpit
    class { 'openitcockpit': }

    # Setup openitcockpit agent
    class { 'openitcockpit::agent':
        dockerstats_enable => false,
        libvirt_enable     => false,
        push_enable        => true,
        push_url           => 'https://monitoring.xxxx.nl',
        push_apikey        => Sensitive('XXXXXXX'), #lint:ignore:140chars
        require            => Class['basic_settings'],
    }
}
```

Standaard is de OpenITCOCKPIT-agent nu conservatiever geconfigureerd: de ingebouwde webserver bindt standaard op `127.0.0.1`, Prometheus-export staat standaard uit en in push-mode wordt het TLS-certificaat van de server standaard gecontroleerd. Gebruik je pull-based monitoring of wil je de exporter bewust publiceren, stel dit dan expliciet in.

### Voorbeeld

Hieronder een voorbeeld wanneer je de agent bewust op het netwerk wilt laten luisteren:

```puppet
node 'webserver.dev.xxxx.nl' {
    class { 'openitcockpit::agent':
        bind_address              => '0.0.0.0',
        prometheus_enable         => true,
        verify_server_certificate => true,
    }
}
```

## Installatie
Navigeer naar de hoofdmap van je Puppet-omgeving en voeg de submodule toe met het volgende commando:

```bash
git submodule add https://github.com/DevSysEngineer/puppet-modules.git global-modules
```

Voer vervolgens het volgende commando uit:

```bash
git submodule update --init --recursive
```

Als alles goed gaat, wordt de uitbreidingsmodule nu correct ingeladen in je Puppet Git-project. Nu moet alleen de Puppetserver nog weten dat deze map bestaat. Ga naar de `environments` map, kies de betreffende omgeving (bijvoorbeeld `development`). In deze omgeving bevindt zich een `manifests` map. Maak naast deze map een bestand met de naam `environment.conf` aan en plak de onderstaande configuratie:

```
modulepath=$codedir/global-modules:$codedir/modules:$basemodulepath
manifest=./manifests
```

De mapstructuur zou er nu zo uit moeten zien:
- Puppet
  - environments
    - development
      - manifests
      - environment.conf
    - production
      - manifests
      - environment.conf
  - global-modules
  - modules
  - .gitmodules

Controleer of de uitbreidingsmodule met submodules correct is ingeladen met de volgende opdracht:

```bash
puppet module list
```

## Modules

### Basic settings

Dit onderdeel bestaat uit subonderdelen die afzonderlijk kunnen worden toegepast zonder de hoofdklasse te gebruiken. Wanneer de hoofdklasse wordt aangeroepen, worden deze subonderdelen daarin geconfigureerd. Het doel van deze sectie is om een [headless server](https://en.wikipedia.org/wiki/Headless_computer) op te zetten met minimale GUI/UI-pakketten, om zo het verbruik van resources te minimaliseren. Daarnaast worden de serverinstellingen geoptimaliseerd voor High-performance computing ([HPC](https://en.wikipedia.org/wiki/High-performance_computing)).

Onnodige pakketten, zoals die voor energiebeheer op laptops, worden verwijderd omdat ze niet relevant zijn voor een serveromgeving. Pakketten zoals `mtr` en `rsync` worden daarentegen wel geïnstalleerd omdat ze vaak nodig zijn voor systeembeheerders. Ook worden beveiligingspakketten zoals `apparmor` en `auditd` geïnstalleerd om de server te beveiligen en te monitoren op verdachte activiteiten.

> [!CAUTION]
> **Sudo**: Wanneer `basic settings` gebruikt in een (bestaande) server waarin al sudo configuratie is toegepast, raad ik aan om de optie `sudoers_dir_enable` op `false` te zetten. Hierdoor blijft de bestaande configuratie behouden.

Basic settings omvatten de volgende subonderdelen:

- **Development:** Pakketten/configuraties gerelateerd aan ontwikkeling.
- **IO:** Pakketten/configuraties gerelateerd aan opslag, uitschakelen van floppy's, etc.
- **Kernel:** Pakketten/configuraties gerelateerd aan de kernel en optimalisatie ervan voor HPC-gebruik.
- **Locale:** Pakketten/configuraties gerelateerd aan taalinstellingen.
- **Login:** Pakketten/configuraties gerelateerd aan login en gebruikersbeheer.
- **Netwerk:** Pakketten/configuraties gerelateerd aan netwerken en optimalisatie ervan voor HPC-gebruik.
- **Packages:** Installeren van een pakketbeheerder en het verwijderen van andere pakketbeheerders indien mogelijk.
  - **Packages GitLab:** Configureren van APT-repo voor GitLab met bijbehorende sleutel.
  - **Packages MongoDB:** Configureren van APT-repo voor MongoDB met bijbehorende sleutel.
  - **Packages MySQL:** Configureren van APT-repo voor MySQL met bijbehorende sleutel.
  - **Packages Nginx:** Configureren van APT-repo voor Nginx met bijbehorende sleutel.
  - **Packages Node:** Configureren en installeren van APT-repo voor Node.
  - **Packages Proxmox:** Configureren van APT-repo voor Proxmox met bijbehorende sleutel.
  - **Packages RabbitMQ:** Configureren van APT-repo voor RabbitMQ met bijbehorende sleutel.
  - **Packages Sury:** Configureren van APT-repo voor Sury met bijbehorende sleutel.
- **Pro:** Voor Ubuntu is het mogelijk om een Pro-abonnement af te nemen.
- **Puppet:** Configureren van Puppet op de juiste manier.
- **Security:** Installeren van benodigde beveiligingspakketten om de server te monitoren.
- **Systemd:** Installeren van systemd en zorgen voor de juiste systeemdoelconfiguratie.
- **Timezone:** Configureren van tijd/datum.

#### Voorbeelden

In het onderstaande voorbeeld zie je hoe `basic settings` kan worden aangeroepen:

```puppet
node 'webserver.dev.xxxx.nl' {
    class { 'basic_settings':
        puppetserver_enable     => true,
        mysql_enable            => true,
        nginx_enable            => true,
        sury_enable             => true,
        systemd_ntp_extra_pools => ['ntp.time.nl']
    }
}
```

Zoals eerder vermeld, bevat `basic settings` ook een login subonderdeel. In het onderstaande voorbeeld wordt een gebruiker toegevoegd. Wanneer de gebruiker aan de groep `wheel` wordt toegevoegd, mag de gebruiker `su` gebruiken.

```puppet
node 'webserver.dev.xxxx.nl' {
    class { 'basic_settings': }

    basic_settings::login_user { 'beheer':
        gid             => 1001,
        home            => '/home/beheer',
        password        => Sensitive('replace-with-password-hash'),
        uid             => 1001,
        authorized_keys => ['ssh-ed25519 AAAA... beheer@example.org'],
        groups          => ['wheel'],
    }
}
```

`basic_settings::login_user` houdt home-, `.ssh`- en shell-startupbestanden privé. Wanneer je `home_source` of `private_key` gebruikt, moet de bron met `puppet:///`, `file:///` of `https://` beginnen; gewone HTTP-bronnen worden bewust geweigerd.

### Docker

Docker installeert Docker CE en beheert Compose-projecten op een voorspelbare manier. Gebruik `docker::compose` voor een eigen stack, `docker::compose_proxy` wanneer die stack via Nginx bereikbaar moet zijn, en de meegeleverde wrappers zoals `docker::authentik` en `docker::twenty` voor de standaard Compose-bestanden in deze module.

Een Compose-bron kan uit de Puppet file server, een lokaal `file:///`-pad of een HTTPS-URL komen. Gevoelige `.env`-inhoud hoort in `Sensitive(...)`. Declareer `docker` zelf; gebruik je een proxyroute, declareer dan ook `nginx`.

Belangrijk om te weten:

- `docker::compose` beheert per stack een eigen projectmap onder `/opt/docker/<naam>` en maakt de stack geschikt om via systemd mee te draaien in de doelstructuur van `basic_settings`.
- HTTP-bronnen voor Compose-bestanden worden bewust niet gebruikt. Gebruik `puppet:///`, `file:///` of `https://`; geef bij externe HTTPS-bronnen bij voorkeur een SHA256-checksum mee.
- Een `.env` kan uit `env_source` of `env_content` komen. Gebruik voor wachtwoorden en tokens altijd `Sensitive(...)`, omdat deze waarden anders te makkelijk in logs of diffs terechtkomen.
- Compose-monitoring kan controleren of containers healthy zijn, of bepaalde eenmalige containers normaal mogen eindigen en of er orphan containers achterblijven.
- `docker::compose_proxy` maakt naast de Compose-stack een Nginx-vhost aan. De upstream is standaard HTTPS; gebruik HTTP alleen als de containerapplicatie echt geen TLS ondersteunt.
- De wrappers `docker::authentik` en `docker::twenty` genereren hun `.env` zelf uit parameters. Zet je `server_name`, dan wordt de Nginx-proxyroute gebruikt; zonder `server_name` blijft het bij de Compose-stack.

#### Voorbeelden

Een eigen Compose-project uit de Puppet file server:

```puppet
node 'containerhost.dev.xxxx.nl' {
    class { 'docker': }

    docker::compose { 'example':
        compose_source => 'puppet:///modules/profile/example/docker-compose.yml',
    }
}
```

Een Compose-project met `.env`-inhoud en monitoringbeleid:

```puppet
node 'containerhost.dev.xxxx.nl' {
    class { 'docker': }

    docker::compose { 'example':
        compose_source             => 'file:///srv/puppet/files/example/docker-compose.yml',
        env_content                => Sensitive.new("COMPOSE_PROJECT_NAME=example\nMYSQL_PASSWORD=replace-with-password\n"),
        monitoring_health_required => ['web', 'db'],
        monitoring_expected_exited => ['migrate'],
    }
}
```

Een eigen Compose-project achter Nginx:

```puppet
node 'containerhost.dev.xxxx.nl' {
    class { 'docker': }
    class { 'nginx': }

    docker::compose_proxy { 'custom':
        compose_source       => 'puppet:///modules/profile/custom/docker-compose.yml',
        proxy_port           => 9443,
        server_name          => 'custom.example.org',
        ssl_certificate      => '/etc/letsencrypt/live/custom.example.org/fullchain.pem',
        ssl_certificate_key  => '/etc/letsencrypt/live/custom.example.org/privkey.pem',
    }
}
```

Een meegeleverde wrapper zonder eigen Compose-bestand:

```puppet
node 'containerhost.dev.xxxx.nl' {
    class { 'docker': }

    class { 'docker::authentik':
        pg_pass    => Sensitive('replace-with-postgresql-password'),
        secret_key => Sensitive('replace-with-secret-key'),
    }
}
```

Meer Docker-varianten staan in [`examples/docker.pp`](examples/docker.pp).

### Let's Encrypt

Let's Encrypt is een gratis, geautomatiseerde en open certificaatautoriteit die SSL/TLS-certificaten uitgeeft om veilige HTTPS-verbindingen mogelijk te maken. Dit onderdeel integreert Let's Encrypt in je Puppet-omgeving, zodat je eenvoudig certificaten kunt aanvragen en beheren. Het ondersteunt zowel automatische certificaatvernieuwing als configuratie van bijbehorende webservers, zoals Nginx.

#### Voorbeeld
Hieronder een voorbeeld hoe je Let's Encrypt gebruikt in je Puppet-omgeving:

```puppet
node 'webserver.dev.xxxx.nl' {
    letsencrypt::certificate { 'webserver.dev.xxxx.nl':
        domains => ['webserver.dev.xxxx.nl'],
    }
}
```

### MySQL

MySQL is een populair open-source relationeel databasebeheersysteem (RDBMS). Het wordt veel gebruikt voor het opslaan, ophalen en beheren van gegevens voor websites en applicaties. Dit onderdeel maakt het mogelijk om een MySQL-database server op te zetten en te configureren. Wanneer in `basic settings` de MySQL APT-repo is geactiveerd, probeert dit onderdeel de geselecteerde MySQL-versie te installeren in plaats van de standaardversie of databasevariant zoals MariaDB die vanuit het besturingssysteem wordt aangeboden. Indien `basic_settings` of het `security`-subonderdeel daarvan wordt gebruikt, worden verdachte commando's gemonitord door auditd.

Binnen het MySQL-onderdeel zit een ingebouwd back-upscript, dat is geforkt van [automysqlbackup](https://sourceforge.net/projects/automysqlbackup/). Dit back-upscript is op meerdere punten verbeterd. Standaard worden back-ups versleuteld met OpenSSL, waarbij PBKDF2 wordt gebruikt voor de sleutelafleiding. Back-ups kunnen handmatig worden ontsleuteld met het .enc-bestand en het bijbehorende wachtwoord. Het commando hiervoor is: `openssl enc -d -aes-256-cbc -pbkdf2 -in backup.sql.enc -out backup.sql -pass pass:..`.

#### Voorbeeld
Hieronder een voorbeeld hoe je MySQL database opzet in je Puppet omgeving:

```puppet
node 'webserver.dev.xxxx.nl' {
    /* Setup MySQL */
    class { 'mysql':
        automysqlbackup_password => Sensitive('replace-with-backup-password'),
        root_password            => 'replace-with-root-password',
    }

    /* Maak database www aan */
    mysql::database { 'www':
        ensure => present
    }

    /* Maak een databasegebruiker aan en verleen alle machtigingen aan de database */
    mysql::user { 'www':
        ensure    => present,
        password  => 'replace-with-user-password',
        username  => 'www',
    }
    ->
    mysql::grant { 'www':
        ensure  => present,
        username  => 'www',
        database  => 'www'
    }
}
```

### GitLab

GitLab is een populaire open-source DevOps-platform. Dit platform is voor softwareontwikkeling waar je en je team samen aan code kunnen werken. Het biedt functies zoals versiebeheer (het bijhouden van verschillende versies van je code), bugtracking (het bijhouden en oplossen van problemen in je software), en Continuous Integration/Continuous Deployment (CI/CD, wat helpt bij het automatisch testen en uitrollen van code).

#### Voorbeeld
Hieronder een voorbeeld hoe je een GitLab opzet in je Puppet omgeving:

```puppet
node 'gitlab.dev.xxxx.nl' {
    /* Setup gitlab */
    class { 'gitlab':
        root_password   => 'replace-with-root-password',
        server_fdqn     => 'gitlab.xxxx.nl'
    }

    /* Setup Gitlab config */
    class { 'gitlab::config':
        https                   => true,
        ssh_host                => 'source.xxxx.nl',
        ssh_port                => 2222,
        ssl_certificate         => '/etc/gitlab/ssl/fullchain.pem',
        ssl_certificate_key     => '/etc/gitlab/ssl/privkey.pem'
    }
}
```

### Nginx

Nginx installeert en beheert webservers en reverse proxies. Gebruik `nginx::server` voor een statische site, PHP-FPM-site of proxy-vhost. De module zet veilige defaults voor headers en `security.txt`, maar je kunt per vhost bewust afwijken wanneer een applicatie dat nodig heeft.

Belangrijk om te weten:

- De module gaat uit van Nginx als webserver en verwijdert Apache wanneer dat pakket aanwezig is. Gebruik dit dus niet op een host waar Apache bewust naast Nginx moet blijven draaien.
- Met `basic_settings` wordt Nginx in de systemd-doelstructuur opgenomen en krijgt de service extra hardening. Daardoor kan gedrag strenger zijn dan bij de distributie-defaults.
- Voor een statische vhost gebruik je een `docroot`. Voor een reverse proxy zet je `docroot => undef`, `try_files => false` en `php_fpm_enable => false`.
- HTTPS wordt per vhost aangezet met `https_enable`, certificaatpaden en eventueel `https_force`. HTTP/2 en HTTP/3 staan niet impliciet voor iedere vhost aan; zet ze alleen aan wanneer je ze wilt gebruiken.
- `security.txt` wordt standaard per vhost geregeld. Geef centrale of vhost-specifieke contacten mee, of zet `securitytxt_enable => false` wanneer een applicatie dit volledig zelf moet afhandelen.
- Security headers hebben veilige defaults, maar vooral CSP en HSTS kunnen applicaties breken. Gebruik een eigen string voor maatwerk of `false` wanneer Nginx een header voor die vhost niet moet beheren.
- Voor reverse proxies heeft versleutelde upstream-communicatie de voorkeur, ook lokaal. Bij self-signed upstreamcertificaten kun je certificaatcontrole uitzetten; plain HTTP is een bewuste uitzondering.

#### Voorbeeld
Een eenvoudige HTTPS-site:

```puppet
node 'webserver.dev.xxxx.nl' {
    class { 'nginx':
        securitytxt_contacts => ['mailto:security@example.org'],
    }

    nginx::server { 'app.example.org':
        docroot             => '/var/www/app.example.org',
        https_enable        => true,
        https_force         => true,
        server_name         => 'app.example.org',
        ssl_certificate     => '/etc/letsencrypt/live/app.example.org/fullchain.pem',
        ssl_certificate_key => '/etc/letsencrypt/live/app.example.org/privkey.pem',
    }
}
```

Een reverse proxy:

```puppet
node 'proxy.dev.xxxx.nl' {
    class { 'nginx': }

    nginx::server { 'app.example.org':
        docroot             => undef,
        https_enable        => true,
        https_force         => true,
        php_fpm_enable      => false,
        server_name         => 'app.example.org',
        ssl_certificate     => '/etc/letsencrypt/live/app.example.org/fullchain.pem',
        ssl_certificate_key => '/etc/letsencrypt/live/app.example.org/privkey.pem',
        try_files           => false,
        location_directives => [
            'proxy_pass https://127.0.0.1:8443;',
            'proxy_ssl_verify off;',
            'proxy_set_header Host $host;',
            'proxy_set_header X-Real-IP $remote_addr;',
            'proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;',
        ],
    }
}
```

Een vhost met eigen headerbeleid:

```puppet
nginx::server { 'app.example.nl':
    server_name               => 'app.example.nl',
    docroot                   => '/var/www/app.example.nl',
    x_frame_options           => 'DENY',
    x_content_type_options    => 'nosniff',
    referrer_policy           => 'same-origin',
    content_security_policy   => "default-src 'self'; object-src 'none'; base-uri 'self'; frame-ancestors 'none'; form-action 'self'",
    strict_transport_security => 'max-age=63072000; includeSubDomains; preload',
}
```

Meer webservervarianten staan in [`examples/web.pp`](examples/web.pp).

### PHP

PHP is een veelgebruikte open-source scriptingtaal die speciaal is ontworpen voor webontwikkeling. Het wordt vaak gebruikt in combinatie met een webserver zoals Apache of Nginx om dynamische inhoud op webpagina's te genereren. Dit onderdeel maakt het mogelijk om PHP te installeren en te configureren. Wanneer `basic settings` wordt gebruikt, zal PHP worden geconfigureerd volgens de aanbevelingen van harde beveiliging.

#### Voorbeeld
Hieronder een voorbeeld hoe je PHP configureert in je Puppet omgeving:

```puppet
node 'webserver.dev.xxxx.nl' {

    /* Standaard PHP instellingen */
    $php_settings = {
        'opcache.enable'                    => 1,
        'opcache.enable_cli'                => 0,
        'opcache.memory_consumption'        => 1024,
        'opcache.interned_strings_buffer'   => 64,
        'opcache.max_accelerated_files'     => 100000,
        'opcache.max_wasted_percentage'     => 30,
        'opcache.fast_shutdown'             => 1,
        'opcache.validate_timestamps'       => 1,
        'opcache.revalidate_freq'           => 60,
        'opcache.save_comments'             => 0,
        'max_execution_time'                => $fastcgi_read_timeout,
        'post_max_size'                     => '20M',
        'upload_max_filesize'               => '20M',
        'memory_limit'                      => '128M',
        'date.timezone'                     => $timezone
    }

    /* Standaard PHP-FPM instellingen */
    $php_fpm_settings = {
        'request_terminate_timeout' => $fastcgi_read_timeout
    }

    /* Setup PHP8 */
    class { 'php8':
        curl            => true,
        gd              => true,
        mbstring        => true,
        minor_version   => 3,
        mysql           => true,
        xml             => true,
        require         => Class['basic_settings']
    }

    /* PHP 8 cli */
    class {'php8::cli':
        ini_settings    => $php_settings,
        require         => Class['basic_settings']
    }

    /* PHP 8 fpm */
    class {'php8::fpm':
        ini_settings    => stdlib::merge($php_settings, $php_fpm_settings),
        require         => Class['nginx'] # Indien Nginx ook geïnstalleerd is op de server
    }
}
```

### SSH

SSH (Secure Shell) is een cryptografisch netwerkprotocol voor veilige gegevenscommunicatie, remote shell services of command execution, en andere beveiligde netwerkdiensten tussen twee netwerkcomputers. Dit onderdeel maakt het mogelijk om OpenSSH te configureren volgens de aanbevelingen van harde beveiliging. Dit omvat onder andere het uitschakelen van root login, het beperken van het aantal toegestane authenticatiepogingen en het configureren van key-based authenticatie.

`permit_root_login` gebruikt dezelfde expliciete hardeningvorm als andere veilige defaults: `false` schrijft `PermitRootLogin no`, `true` schrijft `yes`, en een string kan worden gebruikt voor OpenSSH-modi zoals `'prohibit-password'` of `'forced-commands-only'`.

#### Voorbeeld
Hieronder een voorbeeld hoe je SSH configureert in je Puppet omgeving:

```puppet
node 'webserver.dev.xxxx.nl' {

    class { 'ssh':
        password_authentication_users   => $users_external,
        allow_users                     => $allow_ssh,
    }
}
```

### RabbitMQ

RabbitMQ is een open-source berichtensysteem dat werkt volgens het Advanced Message Queuing Protocol (AMQP). Het wordt vaak gebruikt voor het beheren en afhandelen van berichten tussen verschillende applicaties of componenten binnen een gedistribueerd systeem. RabbitMQ zorgt ervoor dat berichten betrouwbaar en asynchroon kunnen worden uitgewisseld, wat essentieel is voor schaalbare en robuuste applicaties. Dit onderdeel maakt het mogelijk om RabbitMQ te installeren en te configureren.

#### Voorbeeld
Hieronder een voorbeeld hoe je RabbitMQ configureert in je Puppet omgeving:

```puppet
node 'webserver.dev.xxxx.nl' {

    /* Setup RabbitMQ */
    class { 'rabbitmq':
        target => 'production',
        require => Class['basic_settings']
    }

    /* Setup rabbitmq TLS */
    class { 'rabbitmq::tcp':
        ssl_ca_certificate      => '/etc/letsencrypt/live/rabbitmq.xxxx.nl/ca_cert.pem',
        ssl_certificate         => '/etc/letsencrypt/live/rabbitmq.xxxx.nl/cert.pem',
        ssl_certificate_key     => '/etc/letsencrypt/live/rabbitmq.xxxx.nl/privkey.pem'
    }

    /* Setup rabbitmq management */
    class { 'rabbitmq::management':
        admin_password      => 'wachtwoord',
        default_queue_type  => 'quorum',
        require             => Class['rabbitmq::tcp']
    }
    rabbitmq::management_exchange { 'failure_exchange':
        require => Class['rabbitmq::management']
    }
    rabbitmq::management_queue { 'failure_messages':
        type    => 'quorum',
        require => Rabbitmq::Management_exchange['failure_exchange']
    }
    rabbitmq::management_queue { 'result_messages':
        arguments => {
            'x-dead-letter-exchange'    => 'failure_exchange',
            'x-dead-letter-routing-key' => 'failure_messages'
        },
        type    => 'quorum',
        require => Rabbitmq::Management_exchange['failure_exchange']
    }
    rabbitmq::management_binding { 'failure_binding':
        source          => 'failure_exchange',
        destination     => 'failure_messages',
        routing_key     => 'failure_exchange',
        require         => Rabbitmq::Management_exchange['failure_exchange']
    }

    /* Setup user */
    rabbitmq::management_user { 'bookkeeper':
        password    => 'wachtwoord',
        tags        => undef,
        require     => Class['accounts']
    }
    rabbitmq::management_user_permissions { 'bookkeeper_default':
        user        => 'bookkeeper',
        configure   => '',
        write       => '.*',
        read        => '.*'
    }
}
```

### VnStat

vnStat houdt netwerkverbruik per interface bij. De `vnstat` class installeert het pakket en bouwt `/etc/vnstat.conf` op met `concat`. De basisconfiguratie laat `vnstatd` standaard alle nieuw gevonden interfaces toevoegen, zodat een server zonder extra resources al breed netwerkverkeer registreert. De globale `bandwidth_max` is standaard `0`; de module rendert daarmee `MaxBandwidth 0`, waardoor de globale vnStat-rejectlimiet uit blijft en de monitoringcheck deze waarde niet als positieve capaciteit gebruikt. Zet je `bandwidth_max` op een positieve waarde, dan wordt die globale `MaxBandwidth` een fallback voor interfaces zonder eigen limiet of bruikbare vnStat-detectie.

Gebruik `vnstat::ethernet` voor interface-specifieke aanvullingen die niet in de globale template thuishoren. De define schrijft alleen een `MaxBW<interface>`-fragment wanneer `bandwidth_max` op de define is gezet. Interface-specifieke `bandwidth_max`-waarden hebben voor vnStat en de monitoringcheck voorrang boven de globale `bandwidth_max`. De oude parameternaam `max_bandwidth` wordt niet meer gebruikt; gebruik voortaan `bandwidth_max`.

De 95th percentile-drempels voor de monitoringcheck heten `p95_warning` en `p95_critical`. Op classniveau zijn ze globale defaults voor alle interfaces; op `vnstat::ethernet` overschrijven ze de classwaarden per interface. Beide waarden zijn standaard `undef`. Als na het combineren van interface- en classniveau geen drempel bestaat, slaat de check de 95th-thresholdcontrole voor die interface over zonder foutstatus. Als één interfacewaarde is gezet en de andere classwaarde bestaat, schrijft de module de effectieve combinatie naar de monitoringconfiguratie.

De checkconfiguratie staat in `/etc/vnstat-monitoring.conf` en is root-only (`0600`). Het formaat is bewust eenvoudig: `p95_warning <Mbit/s>`, `p95_critical <Mbit/s>`, `interface <naam> p95_warning <Mbit/s>` en `interface <naam> p95_critical <Mbit/s>`. Globale regels komen uit de `vnstat` class; interface-regels komen uit `vnstat::ethernet` en winnen van de globale defaults.

Voor bandbreedte-afhankelijke berekeningen gebruikt `check_vnstat_interfaces` eerst `MaxBW<interface>` uit de effectieve vnStat-configuratie, daarna een strikt parsebare snelheid uit `vnstat --iflist`, en daarna een positieve globale `MaxBandwidth` uit `/etc/vnstat.conf`. De standaard `MaxBandwidth 0` betekent bewust geen globale capaciteit. Als geen betrouwbare positieve capaciteit beschikbaar is, wordt de capaciteitcontrole voor die interface overgeslagen en staat de reden in de long output. WARNING-, CRITICAL- en UNKNOWN-redenen staan ook direct in de korte output, zodat je niet eerst de long output hoeft te doorzoeken.

De check levert perfdata voor p95, capaciteitsgebruik, dag- en maandgroei, actuele dag- en maandtotalen en de leeftijd van de laatste vnStat-update. Ontbrekende vorige-dag- of vorige-maanddata wordt als normale startsituatie behandeld en slaat alleen de betreffende groeicontrole over. Met `--detail-limit <aantal>` kun je het aantal interfaceblokken in de long output begrenzen; de korte output en perfdata blijven volledig.

#### Voorbeeld

Hieronder een voorbeeld waarin vnStat alle interfaces automatisch toevoegt, maar voor twee uplinks een bekende maximumsnelheid meekrijgt:

```puppet
node 'router.dev.xxxx.nl' {
    class { 'vnstat':
        bandwidth_max => 1000,
        p95_critical  => 900,
        p95_warning   => 700,
    }

    vnstat::ethernet { 'ens192':
        bandwidth_max => 1000,
    }

    vnstat::ethernet { 'wan-uplink':
        bandwidth_max => 10000,
        interface     => 'ens224',
        p95_critical  => 8000,
        p95_warning   => 6000,
    }
}
```

Wanneer een nieuwere vnStat-versie extra interface-specifieke directives nodig heeft, hoort daarvoor een expliciete parameter in `vnstat::ethernet` te worden toegevoegd. Zo blijft zichtbaar welke configuratie de module ondersteunt.

## Checks
Voor dit project zijn diverse monitoring checks ontwikkeld waarmee je verschillende processen kunt bewaken. Binnen dit project worden de checks standaard aangeroepen door OpenITCOCKPIT, maar ze zijn bewust zo opgezet dat je ze ook kunt inzetten in andere monitoringsystemen zoals Naemon, Nagios of Icinga. Wil je alleen de checks gebruiken en niet de volledige module, dan is dat geen probleem. Houd er wel rekening mee dat sommige checks stukjes Ruby-code bevatten die je mogelijk moet verwijderen of aanpassen, afhankelijk van jouw omgeving.

De checks houden perfdata-labels bewust vrij van eenheden. Eenheden staan in de UOM van de perfdatawaarde, zoals `%`, `B`, `s` of `Mbps`, en long output wordt gesaneerd zodat ruwe `|`-tekens niet als extra perfdata-scheidingsteken worden geïnterpreteerd.

Bij WARNING, CRITICAL of UNKNOWN hoort de korte output direct de belangrijkste oorzaak te noemen, zoals de interface, unit of resource en de overschreden drempel. De korte output gebruikt geen losse statuslabels zoals `CRITICAL` of `WARNING` vóór de oorzaken; de exitcode draagt de machinestatus. De long output blijft bedoeld voor diagnose en extra context.

- [check_apt](https://github.com/DevSysEngineer/puppet-modules/blob/main/basic_settings/templates/monitoring/check_apt)
- [check_audit](https://github.com/DevSysEngineer/puppet-modules/blob/main/basic_settings/templates/monitoring/check_audit)
- [check_compose](https://github.com/DevSysEngineer/puppet-modules/blob/main/docker/files/check_compose)
- [check_eset](https://github.com/DevSysEngineer/puppet-modules/blob/main/basic_settings/templates/monitoring/check_eset)
- [check_gitlab](https://github.com/DevSysEngineer/puppet-modules/blob/main/gitlab/files/check_gitlab)
- [check_memory_pressure](https://github.com/DevSysEngineer/puppet-modules/blob/main/basic_settings/templates/monitoring/check_memory_pressure)
- [check_mirth_connect](https://github.com/DevSysEngineer/puppet-modules/blob/main/openitcockpit/templates/agent/check_mirth_connect)
- [check_mysql](https://github.com/DevSysEngineer/puppet-modules/blob/main/mysql/templates/check_mysql)
- [check_network](https://github.com/DevSysEngineer/puppet-modules/blob/main/basic_settings/templates/monitoring/check_network)
- [check_nftables](https://github.com/DevSysEngineer/puppet-modules/blob/main/basic_settings/templates/monitoring/check_nftables)
- [check_npm_audit](https://github.com/DevSysEngineer/puppet-modules/blob/main/basic_settings/files/monitoring/check_npm_audit)
- [check_puppet_agent](https://github.com/DevSysEngineer/puppet-modules/blob/main/basic_settings/templates/monitoring/puppet/check_agent)
- [check_rabbitmq](https://github.com/DevSysEngineer/puppet-modules/blob/main/rabbitmq/templates/check_rabbitmq)
- [check_ssh](https://github.com/DevSysEngineer/puppet-modules/blob/main/ssh/templates/check_ssh)
- [check_systemd_config](https://github.com/DevSysEngineer/puppet-modules/blob/main/basic_settings/files/monitoring/check_systemd_config)
- [check_systemd_service](https://github.com/DevSysEngineer/puppet-modules/blob/main/basic_settings/files/monitoring/check_systemd_service)
- [check_systemd_timer](https://github.com/DevSysEngineer/puppet-modules/blob/main/basic_settings/files/monitoring/check_systemd_timer)
- [check_systemd_timesyncd](https://github.com/DevSysEngineer/puppet-modules/blob/main/basic_settings/files/monitoring/check_systemd_timesyncd)
- [check_usb](https://github.com/DevSysEngineer/puppet-modules/blob/main/basic_settings/templates/monitoring/check_usb) # ID, ID@HH:MM-HH:MM, VID:PID@HH:MM-HH:MM, of ID:HH:MM-HH:MM
- [check_vnstat_interfaces](https://github.com/DevSysEngineer/puppet-modules/blob/main/vnstat/files/check_vnstat_interfaces)

## Voorbeelden
De map `examples/` bevat uitgebreidere Puppet-snippets dan de README. Gebruik deze bestanden als startpunt voor profielen en om te zien hoe veelgebruikte opties samenhangen.

- [examples/site.pp](examples/site.pp): Een compacte voorbeeldsite met basisinstellingen, webserver, PHP, SSH, Docker en MySQL.
- [examples/docker.pp](examples/docker.pp): Docker Compose, monitoringopties, Nginx-proxy, Authentik en Twenty.
- [examples/web.pp](examples/web.pp): Nginx, PHP-FPM, Let's Encrypt, security headers en reverse proxy's.
- [examples/data-services.pp](examples/data-services.pp): MySQL, RabbitMQ en vnStat.
- [examples/monitoring.pp](examples/monitoring.pp): OpenITCOCKPIT-agent en custom monitoringchecks.

## Contributie
Contributies zijn welkom! Voel je vrij om pull requests in te dienen of problemen te melden via GitHub.
