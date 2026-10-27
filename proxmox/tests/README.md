# Compile-test voor proxmox

De test compileert Proxmox met de serverbasis op het ondersteunde Debian 12-platform. De [centrale catalog](../../.tools/catalog/README.md#uitvoeren) ontdekt dit scenario automatisch. De algemene afspraken staan in het [testbeleid](../../TESTS.md#moduletests-eenvoudig-houden).

## Inhoudsopgave

- [Inhoudsopgave](#inhoudsopgave)
- [Scenario en invoer](#scenario-en-invoer)
- [Uitzondering voor standalone](#uitzondering-voor-standalone)

## Scenario en invoer

[with_basic_settings.pp](manifests/with_basic_settings.pp) laadt `basic_settings` en daarna `proxmox`, met [synthetische Debian 12-facts](facts/debian-12.json). Daarmee wordt de enige class van deze module gecompileerd; de module bevat geen defined types.

## Uitzondering voor standalone

De [Proxmox-class](../manifests/init.pp) vereist expliciet de hoofdclass `basic_settings` en gebruikt haar platformdetectie om de kernel voor Debian 12 te kiezen. Zonder die class weigert zij vóór de pakketdeclaraties te compileren. Andere releases hebben geen ondersteunde kernelmapping.

Daarom is er uitsluitend een combinatietest. Een standalone test wordt pas toepasbaar wanneer de module een zelfstandige platformconfiguratie ondersteunt; een nagebootste serverbasis zou dit contract niet controleren.
