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

Werk bij wijzigingen aan workflow, package-indeling, instructies of documentatielinks de bijbehorende tests hier bij. De linkcontrole volgt de [Markdownafspraken](../../AGENTS.md#markdown): repositorylinks zijn relatief, ook in voorbeelden en meegedistribueerde Markdown. Vaste repository- of branch-URL’s maken een checkout afhankelijk van een andere bron en horen daar niet thuis.

De distributietests gebruiken onafhankelijke consumerbundles en controleren de pathbron en Git-gemspecselectie. De Git-test gebruikt de huidige werkbestanden via een lokale Bundler-override, zonder commits te maken. Zij bewijst geen externe bereikbaarheid of installatie van een nog niet gepubliceerde revisie. De YAML-tests controleren configuratiecontracten; zij voeren GitHub of GitLab niet uit. De parser-Rake-tests controleren de repositorytaak en het consumervoorbeeld met synthetische manifests: bestandsselectie, dezelfde succes- en foutstatus met en zonder rapport, behoud van bestaande rapporten, lege selecties en rapportagefouten.
