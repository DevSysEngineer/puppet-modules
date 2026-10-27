# PHP 8 gebruiken

Met `php8` kies je de PHP 8 minorversie en extensies. Declareer daarna `php8::cli` voor opdrachtregeltaken, `php8::fpm` voor webapplicaties, of beide. De classes delen de versie, extensies en het INI-template, maar beheren hun eigen instellingen. `basic_settings` en Nginx zijn optionele integraties.

## Inhoudsopgave

- [Inhoudsopgave](#inhoudsopgave)
- [Voorbereiding](#voorbereiding)
- [Alleen PHP CLI](#alleen-php-cli)
- [Zelfstandig PHP-FPM](#zelfstandig-php-fpm)
- [Samen met basic_settings](#samen-met-basic_settings)
- [Servicebeheer en integraties](#servicebeheer-en-integraties)
- [Tests en uitgebreide voorbeelden](#tests-en-uitgebreide-voorbeelden)

## Voorbereiding

Zorg dat de gekozen versie en extensies in de APT-bronnen van de host beschikbaar zijn. `php8` richt zelf geen pakketbron in. Gebruik de moduleset met de dependencies uit de [installatiehandleiding](../README.md#installatie); de gedeelde helpers van `basic_settings` blijven beschikbaar op het modulepad zonder dat je de hoofdclass hoeft te declareren.

Declareer `php8` eenmaal vóór de CLI- en FPM-classes. De hoofdclass installeert de gedeelde pakketten en gevraagde extensies; de runtimepakketten worden door de gekozen CLI- en FPM-classes geïnstalleerd. Bestaande PHP-pakketten worden hierbij niet opgeschoond. De [Puppet Strings](manifests/init.pp) beschrijven versie- en extensiekeuzes.

## Alleen PHP CLI

Dit voorbeeld installeert PHP CLI met een eigen geheugenlimiet en tijdzone. Het declareert geen FPM-service of webserver:

```puppet
include php8

class { 'php8::cli':
  ini_settings => {
    'date.timezone' => 'Europe/Amsterdam',
    'memory_limit'  => '256M',
  },
}
```

Composer wordt standaard eenmalig geïnstalleerd na controle van de installerhandtekening. Zet `composer_enable => false` wanneer je Composer elders beheert; deze keuze verwijdert een bestaande installatie niet. Met de standaard bestandsinstellingen kiest de module ook de geïnstalleerde CLI-versie voor `/usr/bin/php`.

Zonder een eerder gedeclareerde `basic_settings::timezone` voegt de module geen tijdzonedefault toe. Je kunt zoals hierboven `date.timezone` instellen of PHP zijn bestaande configuratie laten gebruiken. De [CLI Strings](manifests/cli.pp) beschrijven de instellingen en voorwaarden.

## Zelfstandig PHP-FPM

Declareer na de gedeelde PHP-class de FPM-class en minstens één pool:

```puppet
include php8
include php8::fpm

php8::fpm_pool { 'app': }
```

De pool gebruikt standaard `www-data` en de Unix-socket `/run/php/php-fpm.sock`. De module maakt geen webserver aan. Configureer je eigen FastCGI-client met dezelfde socket en passende gebruikers- en groepsrechten. Geef aanvullende pools een eigen `listen`-adres om conflicten te voorkomen.

FPM neemt zijn globale configuratie en volledige poolmap over. Onbeheerde pools, inclusief de distributiepool, verdwijnen. Neem benodigde pools daarom vóór uitrol op in Puppet. De module plaatst CLI- en FPM-instellingen in afzonderlijke `99-custom-settings.ini`-bestanden; expliciete INI-instellingen gelden alleen voor de betreffende class. `expose_php` blijft door de module beheerd.

Zonder gedeelde opstartintegratie start Puppet FPM en schakelt het automatisch opstarten in. Zie de [FPM Strings](manifests/fpm.pp) en [poolinstellingen](manifests/fpm_pool.pp) voor de publieke interfaces.

## Samen met basic_settings

Declareer de serverbasis eerst. Dit voorbeeld gebruikt haar PHP-pakketbron en tijdzone voor zowel CLI als FPM, zonder Nginx te vereisen:

```puppet
class { 'basic_settings':
  server_timezone => 'Europe/Amsterdam',
  sury_enable     => true,
}

# Prepare the PHP version and extensions after the package source.
class { 'php8':
  curl          => true,
  minor_version => 3,
  require       => Class['basic_settings'],
}

include php8::cli
include php8::fpm

php8::fpm_pool { 'app': }
```

Laat `php8::fpm` en de pool weg als je alleen CLI nodig hebt. Laat `php8::cli` weg als je alleen FPM wilt beheren. Een expliciete `date.timezone` in de betreffende `ini_settings` gaat vóór de gedeelde tijdzone. Voor alleen tijdzone-integratie kun je ook `basic_settings::timezone` vóór de PHP-classes declareren.

## Servicebeheer en integraties

FPM gebruikt dezelfde optionele voorzieningen als Nginx. Declareer ze vóór `php8::fpm`: alleen aanwezig zijn op het modulepad of een `require`-relatie toevoegen bepaalt de evaluatievolgorde niet.

- Met een gedeclareerd `Package['systemd']` maakt FPM zijn systemd-drop-ins met de bestaande hardening. Zonder die pakketdeclaratie blijft de serviceconfiguratie van de distributie leidend.
- Met een vooraf gedeclareerde `nginx`-class en systemd blijft de FPM-service aan Nginx gekoppeld en neemt zij diens procesprioriteit over. Zonder Nginx, maar met `basic_settings::systemd`, wordt FPM aan het gedeelde services-target gekoppeld.
- Bij deze gedeelde opstartintegratie schakelt Puppet de normale service-enablement uit. Het target of Nginx verzorgt de start; een gestopte service blijft tijdens Puppet-runs gestopt. Zonder die integratie beheert Puppet de service rechtstreeks als actief en ingeschakeld.
- Actieve monitoring registreert de bestaande FPM-servicecheck. Een beschikbare logrotatevoorziening beheert de logrotatie. De [serverbasis](../README.md#basic_settings) blijft eigenaar van deze voorzieningen.

Wijzigingen aan FPM-configuratie en pools melden een herstart aan de service. Controleer de gegenereerde configuratie, sockettoegang en het opstartgedrag eerst op een testhost. Stem geheugenlimieten en het aantal workers af op je applicatie en beschikbare geheugen.

## Tests en uitgebreide voorbeelden

De [compile-tests](tests/README.md) controleren zelfstandig gebruik van CLI en FPM, afzonderlijk en samen, en de combinatie met `basic_settings` via de bestaande gedeelde catalog-runner.

- [Webconfiguratie](../examples/web.pp): CLI, FPM, meerdere INI-instellingen en een Nginx-vhost.
- [Serverprofiel](../examples/site.pp): PHP-FPM als onderdeel van een gecombineerde serverinrichting.
- [Projectoverzicht](../README.md#php8): Ingang naar PHP en de overige modules.
