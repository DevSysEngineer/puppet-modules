# Compile-tests voor nginx

De tests compileren de class `nginx` en de defines `nginx::server` en `nginx::monitoring_cert` met één kleine HTTPS-vhost. De [centrale catalog](../../.tools/catalog/README.md#uitvoeren) ontdekt en voert beide manifests uit; het [testbeleid](../../TESTS.md#moduletests-eenvoudig-houden) bepaalt de vereiste basisdekking.

## Inhoudsopgave

- [Inhoudsopgave](#inhoudsopgave)
- [Scenario’s en invoer](#scenarios-en-invoer)
- [Configuratiekeuzes](#configuratiekeuzes)

## Scenario’s en invoer

| Manifest | Samenstelling |
| --- | --- |
| [standalone.pp](manifests/standalone.pp) | Alle nginx-onderdelen zonder de hoofdclass `basic_settings`. |
| [with_basic_settings.pp](manifests/with_basic_settings.pp) | Dezelfde nginx-configuratie na `basic_settings`. |

Beide gebruiken hetzelfde [synthetische Debian 13-factsbestand](facts/debian-13.json), inclusief invoer voor de serverbasis. Gedeelde defines van `basic_settings` blijven als echte dependency beschikbaar op het modulepad.

## Configuratiekeuzes

De vhost gebruikt synthetische domein- en certificaatpaden. PHP-FPM is uitgeschakeld omdat deze nginx-test daarvoor geen extra applicatiemodule nodig heeft. De certificaatcontrole wordt expliciet geïnstantieerd en de automatische registratie op de vhost staat uit, zodat de define precies eenmaal wordt gedeclareerd. Zonder actieve monitoringbackend declareert deze helper geen backendcheck, maar de define zelf wordt wel gecompileerd en in de dekking geteld.

De compiler hoeft de certificaatbestanden niet te openen. Deze tests installeren geen webserver en testen geen HTTPS-verbinding of uitvoering van de monitoringcheck.
