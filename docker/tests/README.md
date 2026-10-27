# Compile-tests voor docker

De tests compileren alle Docker-classes en defines met één exemplaar van de applicatiewrappers en hun benodigde integraties. De [centrale catalog](../../.tools/catalog/README.md#uitvoeren) voert beide manifests uit met [synthetische Debian 13-facts](facts/debian-13.json). De algemene afspraken staan in het [testbeleid](../../TESTS.md#moduletests-eenvoudig-houden).

## Inhoudsopgave

- [Inhoudsopgave](#inhoudsopgave)
- [Scenario’s en dependencies](#scenarios-en-dependencies)
- [Configuratiekeuzes](#configuratiekeuzes)

## Scenario’s en dependencies

[standalone.pp](manifests/standalone.pp) laadt de echte deelclasses `basic_settings::systemd` en `basic_settings::monitoring` voor back-ups en Compose-monitoring. Het declareert de hoofdclass van de serverbasis niet. [with_basic_settings.pp](manifests/with_basic_settings.pp) schakelt Docker in via `docker_enable` van `basic_settings`.

Beide scenario’s laden `nginx` voor de proxyconfiguratie. De applicatiewrappers instantiëren zelf de gedeelde Compose-, proxy-, back-up- en commandohelpers. De afzonderlijke Nextcloud-integraties gebruiken hetzelfde Nextcloud-exemplaar, zodat daarvoor geen extra applicatiecatalogi nodig zijn.

## Configuratiekeuzes

Verplichte wachtwoorden en sleutels komen uit synthetische facts. Domeinen, opslag en modelnamen zijn testwaarden. De compiler rendert de configuratie, maar haalt geen containers of modellen op, start geen services en voert geen back-ups uit.
