# Repositorycontroles

Deze ontwikkelsuite bewaakt de samenhang van deze repository: documentatielinks en navigatie, CI-configuratie en voorbeelden, testindeling en installatie van meerdere pakketten uit dezelfde bron. Zij levert geen runtimegem en wordt niet door afnemende projecten geïnstalleerd.

## Inhoudsopgave

- [Inhoudsopgave](#inhoudsopgave)
- [Uitvoeren](#uitvoeren)
- [Onderhoud](#onderhoud)

## Uitvoeren

**Werkmap:** Repositoryroot. **Shell:** POSIX shell. **Vereisten:** Ontwikkelbundle en Git-checkout. **Invoer:** Repositorydocumentatie, configuratie en synthetische consumerprojecten. **Wijzigt bestanden:** Tijdelijke consumerinstallaties; test-JUnit alleen bij expliciete rapportinstelling. **Verwacht resultaat:** Alle geselecteerde tests slagen.

```sh
bundle exec rake test:repository_checks
```

`bundle exec rake test` neemt deze suite mee. Rapportlocatie en eenmalige testbootstrap volgen de [gezamenlijke testinrichting](../README.md#gezamenlijke-tooltests). Generieke helpers staan bij shared; toolspecifiek gedrag wordt bij de betreffende tool getest.

## Onderhoud

Volg bij onderhoud ook de [gezamenlijke ontwikkelwerkwijze](../../CONTRIBUTING.md), het [testbeleid](../../TESTS.md) en het [gedeelde toolingonderhoud](../README.md#gedeeld-toolingonderhoud).

- Werk de betreffende tests hier bij wanneer workflows, package-indeling, instructies of documentatielinks veranderen. Houd toolgedrag bij de betrokken tool en deel helpers volgens het [gezamenlijke testonderhoud](../README.md#toolteststructuur-onderhouden).
- Breid de bestaande [linktests](tests/guide_links_test.rb) en gedeelde linkondersteuning uit voor navigatie. Neem nieuwe ongecommitte Markdown, relatieve doelen en ankers, en de agentroute van root via tooling naar ieder component met verwijzingen naar parents en eigen README mee. Bewijs gewijzigde controles met tijdelijke synthetische gevallen voor ontbrekende bestanden en gebroken links.
- Behoud [discoverycontroles](tests/test_structure_test.rb) bij gewijzigde testindeling. Verifieer dat zowel de gezamenlijke als geraakte gerichte taken de bedoelde tests ontdekken en uitvoeren.
- Review distributietests tegen de [onafhankelijke consumerroutes](../README.md#importeren-en-distribueren), met behoud van de lokale Bundler-override voor actuele werkbestanden zonder commits. Presenteer dit niet als externe beschikbaarheid of installatie van een ongepubliceerde revisie.
- Behoud de hieronder beschreven verificatiegrenzen: YAML-controles toetsen configuratie, synthetische parser-Rake-tests taakselectie en status, Bash-logregressies presentatie en oorspronkelijke processtatus. Zij voeren hosted CI niet uit en bewijzen geen gerenderde UI. Console- en reportergedrag blijft bij de betreffende tool; controleer fout- en errorpresentatie op het platform na menselijke publicatie.

De link- en navigatiecontroles nemen ook nieuwe, niet-gecommitte Markdown mee en bewaken de instructieketen van root via tooling naar de componenten, met terugverwijzingen en eigen README’s. Zij volgen de [Markdownafspraken](../lint/puppet/docs/DOCUMENTATION_RULES.md#markdown): repositorylinks zijn relatief, ook in voorbeelden en meegedistribueerde Markdown. Vaste repository- of branch-URL’s maken een checkout afhankelijk van een andere bron en horen daar niet thuis.

De distributietests gebruiken onafhankelijke consumerbundles en controleren de pathbron en Git-gemspecselectie. De Git-test gebruikt de huidige werkbestanden via een lokale Bundler-override, zonder commits te maken. Zij bewijst geen externe bereikbaarheid of installatie van een nog niet gepubliceerde revisie. De YAML-tests controleren configuratiecontracten; zij voeren GitHub of GitLab niet uit. De parser-Rake-tests controleren de repositorytaak en het consumervoorbeeld met synthetische manifests: bestandsselectie, dezelfde succes- en foutstatus met en zonder rapport, behoud van bestaande rapporten, lege selecties en rapportagefouten.

De logregressies voeren de bestaande Bash-stappen met synthetische commando’s uit: installatie vóór Bundler, oorspronkelijke pipelinecodes, conversieproblemen, checkoutwijzigingen, groepering en het stoppen van activiteit bij onderbreking. De dekkingscontrole houdt aanroepen en rapportpublicatie in workflow en beide CI-voorbeelden bij elkaar. Console- en reportercontracten blijven bij de betreffende tool. Lokale script- en XML-controles bewijzen geen gerenderde GitHub-/GitLab-weergave; beoordeel die afzonderlijk na publicatie.
