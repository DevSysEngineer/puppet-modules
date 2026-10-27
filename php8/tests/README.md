# Compile-tests voor php8

De tests compileren de PHP-classes en één FPM-pool met [synthetische Debian 13-facts](facts/debian-13.json). De [centrale catalog](../../.tools/catalog/README.md#uitvoeren) ontdekt de manifests automatisch. Het [testbeleid](../../TESTS.md#moduletests-eenvoudig-houden) bepaalt de basisdekking en de grenzen van deze compilatiecontrole.

## Inhoudsopgave

- [Inhoudsopgave](#inhoudsopgave)
- [Scenario’s en invoer](#scenarios-en-invoer)
- [Configuratiekeuzes](#configuratiekeuzes)

## Scenario’s en invoer

| Manifest | Samenstelling |
| --- | --- |
| [standalone.pp](manifests/standalone.pp) | `php8`, `php8::cli`, `php8::fpm` en `php8::fpm_pool`, zonder `basic_settings`, zijn deelclasses of Nginx. |
| [with_basic_settings.pp](manifests/with_basic_settings.pp) | Dezelfde vier definities na de hoofdclass `basic_settings`, zonder Nginx. |
| [cli_only.pp](manifests/cli_only.pp) | `php8` en `php8::cli`, zonder FPM, Nginx of de serverbasis. |
| [fpm_only.pp](manifests/fpm_only.pp) | `php8`, `php8::fpm` en `php8::fpm_pool`, zonder CLI, Nginx of de serverbasis. |

De eerste twee scenario’s dekken alle classes en defines. De afzonderlijke CLI- en FPM-scenario’s controleren dat beide ook compileren zonder resources die de andere class levert. Het ontbreken van respectievelijk de FPM-definities en de CLI-class in hun dekkingsuitvoer is daarom bewust; deze tests vervangen het volledige standalone scenario niet.

## Configuratiekeuzes

Alle scenario’s gebruiken hetzelfde factsbestand en de standaardparameters. Waar CLI wordt gedeclareerd, blijft Composer ingeschakeld, zodat ook zijn pakket- en uitvoeringsrelaties compileren. De combinatietest gebruikt de echte tijdzone-, systemd-, monitoring- en logrotatevoorzieningen van `basic_settings`. Zonder Nginx wordt daarbij de rechtstreekse koppeling van FPM aan het gedeelde services-target gecompileerd.

Deze tests passen geen resources toe. Zij bewijzen geen pakketbeschikbaarheid, Composer-download, werkende FPM-service of bereikbare socket. Gebruik de [modulehandleiding](../README.md) voor de voorwaarden bij een uitrol.
