# Compile-tests voor netplanio

Beide scenario’s compileren de class `netplanio` en de defines `netplanio::ethernet` en `netplanio::wifi` met [synthetische Debian 13-facts](facts/debian-13.json). De [centrale catalog](../../.tools/catalog/README.md#uitvoeren) verzorgt de uitvoering volgens het [testbeleid](../../TESTS.md#moduletests-eenvoudig-houden).

## Inhoudsopgave

- [Inhoudsopgave](#inhoudsopgave)
- [Configuratie en declaratievolgorde](#configuratie-en-declaratievolgorde)

## Configuratie en declaratievolgorde

[standalone.pp](manifests/standalone.pp) gebruikt de zelfstandige Netplan-defaults met één ethernetinterface en één open synthetisch wifi-netwerk.

[with_basic_settings.pp](manifests/with_basic_settings.pp) selecteert `ip_configurator_package => 'netplan.io'` en `wireless_enable => true` in de serverbasis. Het laadt `basic_settings::network` expliciet vóór `netplanio`, zodat de netwerkclass de gedeelde packages declareert voordat Netplan controleert of zij al bestaan. Alleen beide hoofdclasses includen kan anders een dubbele declaratie van `Package['netplan.io']` veroorzaken. De netwerkclass zonder Netplan-selectie zou datzelfde pakket juist verwijderen.

De test past geen netwerkconfiguratie toe en vereist geen echte interfaces of toegangspunten.
