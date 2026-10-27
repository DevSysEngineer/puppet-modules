# Compile-tests voor php8

De tests compileren PHP en PHP-FPM met één pool. De [centrale catalog](../../.tools/catalog/README.md#uitvoeren) voert beide manifests uit met [synthetische Debian 13-facts](facts/debian-13.json). De algemene afspraken staan in het [testbeleid](../../TESTS.md#moduletests-eenvoudig-houden).

## Inhoudsopgave

- [Inhoudsopgave](#inhoudsopgave)
- [Scenario’s en dependencies](#scenarios-en-dependencies)
- [Uitzondering voor PHP-CLI](#uitzondering-voor-php-cli)

## Scenario’s en dependencies

[standalone.pp](manifests/standalone.pp) compileert `php8`, `php8::fpm` en `php8::fpm_pool` zonder de hoofdclass `basic_settings`. Het laadt wel de echte deelclass `basic_settings::systemd`, omdat PHP-FPM de gedeelde systemd-package en unitvoorzieningen gebruikt.

[with_basic_settings.pp](manifests/with_basic_settings.pp) compileert alle vier definities, inclusief `php8::cli`, na de serverbasis.

## Uitzondering voor PHP-CLI

De class [php8::cli](../manifests/cli.pp) leest bij het samenstellen van de INI-instellingen onvoorwaardelijk `$basic_settings::server_timezone`. Zonder de hoofdclass is die variabele niet beschikbaar en faalt de compilatie. Ook een expliciete `date.timezone` in `ini_settings` voorkomt het lezen van de ontbrekende variabele niet.

Daarom ontbreekt alleen `php8::cli` in het standalone scenario. De dekkingsuitvoer toont daar drie van de vier definities en noemt de ontbrekende class; de combinatietest dekt alle vier. Deze uitzondering kan vervallen zodra PHP-CLI een zelfstandige tijdzoneconfiguratie ondersteunt.
