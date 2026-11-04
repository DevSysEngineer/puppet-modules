# Compile-tests voor basic_settings

Het [standalone manifest](manifests/standalone.pp) compileert alle classes en defines van de serverbasis met echte moduledependencies. De [centrale cataloguscontrole](../../.tools/catalog/README.md#uitvoeren) voert het uit met de twee factsbestanden hieronder. De algemene afspraken staan in het [testbeleid](../../TESTS.md#moduletests-eenvoudig-houden).

## Inhoudsopgave

- [Inhoudsopgave](#inhoudsopgave)
- [Scenario en invoer](#scenario-en-invoer)
- [Configuratiekeuzes](#configuratiekeuzes)

## Scenario en invoer

Beide manifests worden gecompileerd met [Debian 13](facts/debian-13.json) en [Ubuntu 24.04](facts/ubuntu-noble.json). Beide bestanden beschrijven een synthetische amd64 Linux-VM met twee processors en acht GiB geheugen; zij controleren de bestaande platformtakken van de serverbasis.

[`systemd_helpers.pp`](manifests/systemd_helpers.pp) compileert de vijf systemd-wrappers zonder de hoofdclass of targetstructuur. Dit controleert dat hun gedeelde reload ook zelfstandig beschikbaar is en slechts eenmaal wordt gedeclareerd. Ook het verwijderen van een service zonder monitoringbackend wordt gecompileerd.

`basic_settings` wordt niet met zichzelf gecombineerd. De combinatietests staan bij de modules die de serverbasis aanvullen.

## Configuratiekeuzes

De hoofdclass schakelt hostsbeheer en de OpenITCOCKPIT-monitoringbackend in. Daardoor worden ook de optionele hostsclass en de monitoringhelpers gecompileerd. De overige losse defines krijgen één hostsvermelding, een vergrendeld synthetisch account met cron- en sudoregel en een npm-auditregistratie.

De monitoringconfiguratie behoudt de compilatiecontrole op dubbele declaratie van `Package['python3']` door de NCSC-check en haar dependency. Een afzonderlijk defaultscenario is voor de dekking van classes en defines niet nodig; de combinatietests van andere modules compileren de serverbasis ook met defaults. Deze controle past geen catalogus toe en voert geen monitoringchecks uit.
