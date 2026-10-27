# Compile-tests voor openitcockpit

De tests compileren de vier classes `openitcockpit`, `openitcockpit::agent`, `openitcockpit::agent_mirth_connect` en `openitcockpit::server`. De [centrale catalog](../../.tools/catalog/README.md#uitvoeren) gebruikt daarvoor [synthetische Debian 13-facts](facts/debian-13.json). De algemene afspraken staan in het [testbeleid](../../TESTS.md#moduletests-eenvoudig-houden).

## Inhoudsopgave

- [Inhoudsopgave](#inhoudsopgave)
- [Dependencies](#dependencies)
- [Agentconfiguratie](#agentconfiguratie)

## Dependencies

[standalone.pp](manifests/standalone.pp) laadt `basic_settings::login` voor de gedeelde sudo-voorziening en declareert de echte commandopackages `coreutils` en `grep` die de serverclass vereist. De hoofdclass van de serverbasis blijft uit. [with_basic_settings.pp](manifests/with_basic_settings.pp) krijgt deze voorzieningen via `basic_settings`.

## Agentconfiguratie

Beide manifests gebruiken een volledige pushconfiguratie met een synthetische URL en API-key. De huidige [agentclass](../manifests/agent.pp) levert bij uitgeschakelde push een gewone lege string voor `push_apikey_correct`; de configuratietemplate verwacht daarop `unwrap`, waardoor de defaultconfiguratie niet compileert. De tests kiezen daarom één geldige configuratie met een `Sensitive`-waarde. Dit dekt de agentclass, maar bewijst niet dat de uitgeschakelde pushvariant werkt.

Het verplichte Grafana-wachtwoord komt eveneens uit de synthetische facts. De compile-tests maken geen verbinding met een monitoringserver en gebruiken geen productiecredentials.
