# Puppet-code, lintcontroles en hergebruik

<a id="puppet-lint-en-rubocop"></a>
<a id="doel-en-reikwijdte"></a>

Deze handleiding beschrijft hoe je Puppet-code voor de repository `puppet-modules` controleert. Je vindt hier de dagelijkse werkwijze, de lintcommando's en verwijzingen naar de [algemene Puppet-coderegels](docs/CODE_RULES.md), [regels voor Puppet-documentatie](docs/DOCUMENTATION_RULES.md) en [operationele regels](docs/OPERATIONAL_RULES.md). Ook lees je hoe je die controles in een ander Puppet-project gebruikt en hoe je ze onderhoudt.

Voor links buiten deze gem lees je de handleiding in de bijbehorende repositorycheckout.

**Puppet-lint** is een extern controleprogramma dat Puppet-broncode leest en afwijkingen van codeafspraken meldt. Zo'n programma heet een linter; iedere afzonderlijke controle heet een check. Je start het met het commando `puppet-lint`. Het programma heeft standaardchecks en kan extra checks uit uitbreidingen laden.

Voor deze repository zijn zulke uitbreidingen en de bijbehorende configuratie verzameld in **`lint-project`**, ons eigen Ruby-pakket, ook wel een gem genoemd. Dit pakket gebruikt Puppet-lint als controleprogramma en voegt de `project_*`-checks toe voor onder meer parameters, documentatie, bestandsrechten en shellcommando's. Daarnaast installeert het de externe lintplugins uit zijn gemspec. Je blijft de controles starten met `puppet-lint`; de projectconfiguratie laadt onze uitbreiding en bepaalt samen met het gedeelde regelprofiel welke checks en opties actief zijn.

`project-tools-ruby-lint` levert [Ruby-lint](../ruby-lint/README.md), `project-tools-metadata` levert [metadatacontrole](../metadata/README.md) en `project-tools-validate` levert [parservalidatie](../validate/README.md). Kies deze tools afzonderlijk in de [ontwikkelbundle](../README.md). De [tooltests](#tests-uitvoeren-en-uitbreiden) controleren lintchecks, correcties en installatie.

De lintdocumentatie bestaat uit vier centrale documenten: deze toolinghandleiding en de drie regelsbestanden [CODE_RULES.md](docs/CODE_RULES.md), [DOCUMENTATION_RULES.md](docs/DOCUMENTATION_RULES.md) en [OPERATIONAL_RULES.md](docs/OPERATIONAL_RULES.md). Iedere bron heeft een eigen verantwoordelijkheid:

| Bron | Verantwoordelijkheid |
| --- | --- |
| [`AGENTS.md`](../../AGENTS.md) | Repositorybrede workflow, engineering, security en documentatiebeheer; geen tweede verzameling Puppet-normen. |
| Deze [README](#inhoudsopgave) | Gebruik, installatie, configuratie, checks, CLI, CI, imports en onderhoud van de linttooling. |
| [`docs/CODE_RULES.md`](docs/CODE_RULES.md) | Algemene Puppet-coderegels, uitzonderingen en handmatige reviewcriteria voor iedere Puppet-wijziging. |
| [`docs/DOCUMENTATION_RULES.md`](docs/DOCUMENTATION_RULES.md) | Commentaar in Puppet-code, Puppet Strings en documentatie van Puppet-interfaces, met uitzonderingen en handmatige reviewcriteria. Algemene Markdown- en README-afspraken blijven in `AGENTS.md`. |
| [`docs/OPERATIONAL_RULES.md`](docs/OPERATIONAL_RULES.md) | Aanvullende Puppet-regels voor beheerde bestanden, rechten, beveiliging, systemd, shell en monitoring. |
| [`.puppet-lint.rc`](../../.puppet-lint.rc) en [gedeelde configuratie](config/) | Actieve lintconfiguratie. |
| [Projectchecks](lib/project_lint/checks/) | Feitelijk detectie- en autofixgedrag. |
| [Tooltests](tests) | Automatisch geverifieerde scenario's en regressies; uitsluitend bewijs voor de uitgevoerde scenario's. |

De drie regelsbestanden vormen de centrale code- en implementatiestandaard, ook voor regels zonder automatische check. [AGENTS.md](../../AGENTS.md#authority-and-rule-placement) bepaalt de plaatsing van nieuwe afspraken.

Een groene lintscan bewijst geen volledige normnaleving, geldige catalogus of correct runtimegedrag. Bij ontbrekende automatische dekking blijft de norm gelden en is handmatige review vereist. Bij strijdigheid beschrijf je norm en waargenomen gedrag afzonderlijk en registreer je het conflict in de oplevering; pas de norm of implementatie niet aan als redactionele oplossing. Corrigeer een feitelijk onjuiste CLI-beschrijving alleen met uitvoerbewijs. Behoud onduidelijke normen letterlijk en markeer de precieze onzekerheid. Een niet-uitgevoerde verplichte controle of onopgelost normconflict verhindert de eindstatus `Afgerond`.

## Leeswijzer

Gebruik je de tooling voor het eerst, begin dan bij de snelstart voor [deze repository](#snelstart-in-deze-repository) of [je eigen Puppet-project](#snelstart-in-een-ander-puppet-project). Voor een wijziging volg je de [dagelijkse werkwijze](#werkwijze-bij-een-wijziging). De onderwerpentabel verwijst naar de secties die je wijziging raakt; de taakroutes eronder verbinden die naslag met de benodigde stappen. Je hoeft de overige gespecialiseerde naslag niet vooraf door te nemen. Komt tijdens je werk een nieuwe afhankelijkheid of integratie in beeld, neem dan de bijbehorende sectie erbij.

Volg bij iedere Puppet-wijziging de toepasselijke algemene regels uit [CODE_RULES.md](docs/CODE_RULES.md). Raakt de wijziging commentaar, Puppet Strings of documentatie van Puppet-interfaces, lees en volg dan daarnaast de relevante regels uit [DOCUMENTATION_RULES.md](docs/DOCUMENTATION_RULES.md).

Raakt de wijziging beheerde bestanden of mappen, eigenaarschap of rechten, beveiliging, systemd of services, shellcode of shelltemplates, runtime-tools of operationele dependencies, of monitoringchecks en hun registratie, volg dan ook de relevante regels uit [OPERATIONAL_RULES.md](docs/OPERATIONAL_RULES.md). Beide aanvullende documenten kunnen tegelijk van toepassing zijn. Ze vervangen de algemene coderegels nooit.

Gebruik deze beslisstructuur om de toepasselijke documenten te kiezen. De onderwerpentabel eronder verwijst naar de relevante secties binnen die documenten.

| Je wijziging | Toepasselijke regelsbestanden |
| --- | --- |
| Algemene Puppet-code, zoals een parameterwijziging | [CODE_RULES.md](docs/CODE_RULES.md). |
| Commentaar, Puppet Strings of Puppet-interface-documentatie, zoals gewijzigde Strings bij een class | [CODE_RULES.md](docs/CODE_RULES.md) + [DOCUMENTATION_RULES.md](docs/DOCUMENTATION_RULES.md). |
| Bestanden, beveiliging, systemd, shell of monitoring, zoals een nieuwe systemd-service | [CODE_RULES.md](docs/CODE_RULES.md) + [OPERATIONAL_RULES.md](docs/OPERATIONAL_RULES.md). |
| Operationele Puppet-code met gewijzigde documentatie, zoals een monitoring-define met Puppet Strings | [CODE_RULES.md](docs/CODE_RULES.md) + [DOCUMENTATION_RULES.md](docs/DOCUMENTATION_RULES.md) + [OPERATIONAL_RULES.md](docs/OPERATIONAL_RULES.md). |

| Je taak | Lees hierbij |
| --- | --- |
| Een normaal Puppet-manifest aanpassen | [Basisopmaak](docs/CODE_RULES.md#basisopmaak) en [parameters en resources](docs/CODE_RULES.md#parameters-en-resources). |
| Verantwoordelijkheden tussen caller, component en template wijzigen | [Instellingen bij hun eigenaar houden](docs/CODE_RULES.md#instellingen-bij-hun-eigenaar-houden); controleer de gegevensstroom en het gedrag met de [aanvullende validatie](#aanvullende-validatie). |
| Commentaar of Puppet-interface-documentatie aanpassen | [Commentaar en documentatie](docs/DOCUMENTATION_RULES.md#commentaar-en-documentatie), waaronder [toelichtingen bij code](docs/DOCUMENTATION_RULES.md#toelichtingen-bij-code) en [interfacebeschrijvingen synchroniseren](docs/DOCUMENTATION_RULES.md#interfacebeschrijvingen-synchroniseren). |
| Puppet Strings aanpassen | [Puppet Strings](docs/DOCUMENTATION_RULES.md#puppet-strings), [lange regels](docs/CODE_RULES.md#lange-regels) en [waar de uitleg hoort](docs/DOCUMENTATION_RULES.md#waar-de-uitleg-hoort). |
| Resources of dependencies aanpassen | [Packageafhankelijkheden bij externe commando’s](docs/CODE_RULES.md#packageafhankelijkheden-bij-externe-commandos), [Resources en afhankelijkheden](docs/CODE_RULES.md#resources-en-afhankelijkheden), [resource references](docs/CODE_RULES.md#resource-references) en [volgorde en meldingen](docs/CODE_RULES.md#volgorde-en-meldingen). |
| Bestanden, privileges of shellcommando's aanpassen | [Bestanden en beveiliging](docs/OPERATIONAL_RULES.md#bestanden-en-beveiliging), inclusief [beheerheaders](docs/OPERATIONAL_RULES.md#door-puppet-beheerde-inhoud-markeren) en [helperlocaties](docs/OPERATIONAL_RULES.md#beheerhelpers-op-de-gedeelde-locatie-installeren); voer de [algemene beveiligingsreview](../../AGENTS.md#security-and-privacy) uit. |
| Een shellscript, Bash-script, shelltemplate of bijbehorende runtime-dependency aanpassen | [Shellscripts](docs/OPERATIONAL_RULES.md#shellscripts), inclusief [gedeelde helpers](docs/OPERATIONAL_RULES.md#shellhelpers-op-een-herkenbare-taak-afbakenen) en [runtime-tools](docs/OPERATIONAL_RULES.md#runtime-tools-op-hun-functie-beoordelen); voer de [projectbrede shellreview en validatie](../../AGENTS.md#shell-scripts) uit. |
| Een monitoringcheck of registratie aanpassen | [Monitoringchecks](docs/OPERATIONAL_RULES.md#monitoringchecks), [runtimebronkeuze](docs/OPERATIONAL_RULES.md#actuele-hosttoestand-uit-kernelgegevens-bepalen), [inspectiestatus](docs/OPERATIONAL_RULES.md#vastgestelde-afwijkingen-en-onvolledige-inspecties-onderscheiden) en [targets en monitoring](docs/OPERATIONAL_RULES.md#targets-en-monitoring); voer de [projectbrede monitoringreview en validatie](../../AGENTS.md#monitoring-checks) uit. |
| Systemd-integratie aanpassen | [Gedeelde services en systemd](docs/OPERATIONAL_RULES.md#gedeelde-services-en-systemd), inclusief de beoordeling per service. |
| Een lintmelding oplossen | [Een melding oplossen](#een-melding-oplossen); zoek de checknaam in het [checkoverzicht](#beschikbare-projectchecks). |
| Autofix uitvoeren | [Automatisch corrigeren](#automatisch-corrigeren-autofix) en de voorwaarden bij de betrokken check. |
| Ruby-code controleren of veilig corrigeren | [RuboCop gebruiken](#ruby-code-controleren). |
| Rapporten maken of een CI-uitslag onderzoeken | [Puppet-manifests valideren](#puppet-manifests-valideren), [lintrapporten maken](#lintrapporten-maken), [tooltests uitvoeren](#tests-uitvoeren-en-uitbreiden) en [CI van deze repository](#ci-van-deze-repository). |
| Een bestaande lintcheck aanpassen | [Een check toevoegen of wijzigen](#een-check-toevoegen-of-wijzigen) en de bijbehorende [technische werking](#technische-werking-van-de-checks). |
| Een nieuwe lintcheck of autofix ontwikkelen | [Linter ontwikkelen en onderhouden](#linter-ontwikkelen-en-onderhouden), inclusief [veilige autofixes](#veilige-autofixes-ontwikkelen). |
| De centrale linter in een ander Puppet-project gebruiken | [Gedeelde tooling hergebruiken](#gedeelde-tooling-hergebruiken), [aanbevolen projectstructuur](#aanbevolen-projectstructuur) en [installatie](#installatie-in-je-project). |
| Validatie, linting, tests en artifacts in een project met `global-modules` inrichten | [Een eigen rapportmap kiezen](#rapportmap-kiezen), [eigen code controleren](#eigen-code-controleren), [eigen manifests valideren](#eigen-manifests-valideren), [eigen tooltests](#eigen-tooltests), [rapporten en artifacts](#rapporten-en-artifacts-in-je-project) en het [CI-voorbeeld](#controle-in-ci). |

### Puppet-code wijzigen

Begin met de scan uit [Snelstart in deze repository](#snelstart-in-deze-repository). Pas bij je wijziging de relevante [Puppet-coderegels en reviewcriteria](#puppet-coderegels-en-reviewcriteria) toe en sluit af met de [Eindcontrole](#eindcontrole).

### Een lintmelding oplossen

Zoek de checknaam op in het [Checkregister](#checkregister) en lees de gekoppelde regel. [Meldingen, severity en exitcodes](#meldingen-severity-en-exitcodes) legt de uitvoer en foutstatus uit; bij installatie- of configuratieproblemen helpt [Problemen oplossen](#problemen-oplossen).

### Een autofix beoordelen

Lees bij de betrokken [Puppet-coderegel](#puppet-coderegels-en-reviewcriteria) welke correcties zijn toegestaan en wanneer de check ze weigert. Volg daarna [Autofix en suppressions](#autofix-en-suppressions) voor het uitvoeren van de correctie, de diffreview en de hercontrole.

### Een ander project aansluiten

Richt eerst een eigen bundle en configuratie in met [Snelstart in een ander Puppet-project](#snelstart-in-een-ander-puppet-project). [Importeren en distribueren](#importeren-en-distribueren) werkt de drie installatieroutes uit; met [Rapportage en CI](#rapportage-en-ci) neem je de controles op in je eigen pipeline.

### De linter onderhouden

Volg [Linter ontwikkelen en testen](#linter-ontwikkelen-en-testen) voor wijzigingen aan de projectchecks of tooling. Werk de bijbehorende uitleg bij volgens het [Documentatiecontract voor maintainers](#documentatiecontract-voor-maintainers) en voer de [Eindcontrole](#eindcontrole) uit.

## Inhoudsopgave

- [Leeswijzer](#leeswijzer)
  - [Puppet-code wijzigen](#puppet-code-wijzigen)
  - [Een lintmelding oplossen](#een-lintmelding-oplossen)
  - [Een autofix beoordelen](#een-autofix-beoordelen)
  - [Een ander project aansluiten](#een-ander-project-aansluiten)
  - [De linter onderhouden](#de-linter-onderhouden)
- [Inhoudsopgave](#inhoudsopgave)
- [Snelstart in deze repository](#snelstart-in-deze-repository)
  - [Werkwijze bij een wijziging](#werkwijze-bij-een-wijziging)
- [Snelstart in een ander Puppet-project](#snelstart-in-een-ander-puppet-project)
- [Installatie en compatibiliteit](#installatie-en-compatibiliteit)
  - [Benodigde omgeving](#benodigde-omgeving)
  - [Installatie](#installatie)
  - [Ruby op macOS](#ruby-op-macos)
  - [Gems installeren](#gems-installeren)
  - [Compatibiliteitslagen](#compatibiliteitslagen)
- [Configuratie, bestandsselectie en modulepad](#configuratie-bestandsselectie-en-modulepad)
  - [Werking van de controles](#werking-van-de-controles)
  - [Eigen lintconfiguratie](#eigen-lintconfiguratie)
  - [Aanroepen van modules controleren](#aanroepen-van-modules-controleren)
  - [Modulemetadata controleren](#modulemetadata-controleren)
    - [Metadata in modulemappen](#metadata-in-modulemappen)
    - [Metadata in de projectroot](#metadata-in-de-projectroot)
    - [Versiebron en rapportage](#versiebron-en-rapportage)
    - [Metadata automatisch herstellen](#metadata-automatisch-herstellen)
  - [Configuratie- en selectiegedrag](#configuratie--en-selectiegedrag)
- [Commando's en opties](#commandos-en-opties)
  - [Native opties](#native-opties)
  - [Reporterargumenten](#reporterargumenten)
  - [Omgevingsvariabelen](#omgevingsvariabelen)
- [Meldingen, severity en exitcodes](#meldingen-severity-en-exitcodes)
  - [Een melding oplossen](#een-melding-oplossen)
  - [Exitcodes van Puppet-lint](#exitcodes-van-puppet-lint)
  - [Exitcodes van puppet-lint-junit](#exitcodes-van-puppet-lint-junit)
  - [Exitcodes van validate-junit](#exitcodes-van-validate-junit)
  - [Overige validatiecommando's](#overige-validatiecommandos)
- [Checkregister](#checkregister)
  - [Beschikbare projectchecks](#beschikbare-projectchecks)
  - [Native checks in deze bundle](#native-checks-in-deze-bundle)
  - [Pluginchecks in deze bundle](#pluginchecks-in-deze-bundle)
  - [Automatische dekking en handmatige review](#automatische-dekking-en-handmatige-review)
- [Puppet-coderegels en reviewcriteria](#puppet-coderegels-en-reviewcriteria)
- [Autofix en suppressions](#autofix-en-suppressions)
  - [Automatisch corrigeren (autofix)](#automatisch-corrigeren-autofix)
- [Parservalidatie en Ruby-controles](#parservalidatie-en-ruby-controles)
  - [Ruby-code controleren](#ruby-code-controleren)
  - [Puppet-manifests valideren](#puppet-manifests-valideren)
  - [Aanvullende validatie](#aanvullende-validatie)
  - [Eigen manifests valideren](#eigen-manifests-valideren)
  - [Ruby controleren in een ander project](#ruby-controleren-in-een-ander-project)
  - [Aanvullende tests](#aanvullende-tests)
- [Rapportage en CI](#rapportage-en-ci)
  - [Lintrapporten maken](#lintrapporten-maken)
  - [Rapportmap kiezen](#rapportmap-kiezen)
  - [CI van deze repository](#ci-van-deze-repository)
  - [Rapporten en artifacts in je project](#rapporten-en-artifacts-in-je-project)
  - [Controle in CI](#controle-in-ci)
    - [Rapporten tonen in GitLab](#rapporten-tonen-in-gitlab)
- [Importeren en distribueren](#importeren-en-distribueren)
  - [Gedeelde tooling hergebruiken](#gedeelde-tooling-hergebruiken)
  - [Benodigdheden](#benodigdheden)
  - [Aanbevolen projectstructuur](#aanbevolen-projectstructuur)
  - [Installatie in je project](#installatie-in-je-project)
  - [Eigen code controleren](#eigen-code-controleren)
  - [Een gem bouwen en versie uitbrengen](#een-gem-bouwen-en-versie-uitbrengen)
  - [Git-dependency uit de monorepo](#git-dependency-uit-de-monorepo)
  - [Gebouwd gempakket installeren](#gebouwd-gempakket-installeren)
- [Linter ontwikkelen en testen](#linter-ontwikkelen-en-testen)
  - [Een check toevoegen of wijzigen](#een-check-toevoegen-of-wijzigen)
  - [Technische werking van de checks](#technische-werking-van-de-checks)
    - [Omvang en validatiestructuur](#omvang-en-validatiestructuur)
    - [Classcontroles en vindbare afnemers](#classcontroles-en-vindbare-afnemers)
    - [References en relatiecontext](#references-en-relatiecontext)
    - [Voorbereiding van voorwaarden](#voorbereiding-van-voorwaarden)
    - [Hints voor variabelegroepen](#hints-voor-variabelegroepen)
    - [Backendselectie en wrappers](#backendselectie-en-wrappers)
  - [Veilige autofixes ontwikkelen](#veilige-autofixes-ontwikkelen)
  - [Tests uitvoeren en uitbreiden](#tests-uitvoeren-en-uitbreiden)
  - [Versies bijwerken](#versies-bijwerken)
  - [Eigen tooltests](#eigen-tooltests)
    - [Testselectie en uitvoeropties](#testselectie-en-uitvoeropties)
    - [JUnit-rapportage instellen](#junit-rapportage-instellen)
- [Documentatiecontract voor maintainers](#documentatiecontract-voor-maintainers)
- [Problemen oplossen](#problemen-oplossen)
- [Eindcontrole](#eindcontrole)

## Snelstart in deze repository

<a id="code-controleren"></a>

Voer de controles uit vanuit de hoofdmap van deze repository, met de [ontwikkelomgeving](#benodigde-omgeving) en [gems](#gems-installeren) ingericht. Lokaal en in CI gebruiken we dezelfde expliciete lintconfiguratie:

**Werkmap:** Repositoryroot. **Shell:** POSIX shell. **Vereisten:** [ontwikkelbundle](#gems-installeren). **Invoer:** Gehele repository volgens rootconfiguratie. **Wijzigt bestanden:** Geen bronbestanden. **Verwacht resultaat:** Exitcode 0 bij volledige schone lintscan.

```sh
bundle exec puppet-lint --no-config --config .puppet-lint.rc .
```

Controleer vooraf of `.puppet-lint.rc` in de werkmap staat. De CLI slaat een ontbrekend configuratiebestand stilzwijgend over. De relatieve verwijzingen in dat bestand vereisen de repositoryroot als werkmap.

Een gerichte scan helpt tijdens het ontwikkelen. Gebruik hier `examples/site.pp` als bestaand voorbeeldpad en kies bij eigen werk vooraf het concrete gewijzigde manifest. De gerichte scan en correctie vervangen de volledige eindcontrole niet.

**Werkmap:** Repositoryroot. **Shell:** POSIX shell. **Vereisten:** Ontwikkelbundle. **Invoer:** examples/site.pp. **Wijzigt bestanden:** Geen bronbestanden. **Verwacht resultaat:** Manifestdiagnostics voor dit bestand; exitcode 0 bij schoon resultaat.

```sh
bundle exec puppet-lint --no-config --config .puppet-lint.rc examples/site.pp
```

Voer de correctiestap alleen uit als dit manifest tot de bedoelde wijzigingsscope behoort en de beschreven autofixvoorwaarden zijn beoordeeld.

**Werkmap:** Repositoryroot. **Shell:** POSIX shell. **Vereisten:** Ontwikkelbundle. **Invoer:** examples/site.pp. **Wijzigt bestanden:** Ondersteunde fixes in dat manifest. **Verwacht resultaat:** Diff beoordeeld en gewone hercontrole zonder resterende bevindingen.

```sh
bundle exec puppet-lint --no-config --config .puppet-lint.rc --fix examples/site.pp
git diff
bundle exec puppet-lint --no-config --config .puppet-lint.rc examples/site.pp
```

### Werkwijze bij een wijziging

1. Bekijk `git status --short` en lees de relevante code, modulemetadata en documentatie. Kies met de [leeswijzer](#leeswijzer) de codeafspraken voor je wijziging. De overige voorbereiding staat in [`AGENTS.md`](../../AGENTS.md#preparation).
2. Voer vóór het aanpassen een lintscan uit, zodat je weet welke meldingen al bestonden. Scan gewijzigde code opnieuw voordat je meldingen gaat corrigeren. Tijdens het ontwikkelen kun je de scan tot [één manifest](#werking-van-de-controles) beperken.
3. Gebruik een beschikbare [autofix](#automatisch-corrigeren-autofix) als die voor de betrokken code veilig en deterministisch is. Controleer daarvoor de voorwaarden bij de check. Beperk de correctie tot je wijziging en behoud gedrag, relaties en configuratie.
4. Scan de gecorrigeerde code opnieuw. De uitvoer van de fixrun kan nog meldingen over de oorspronkelijke regels bevatten.
5. Los de resterende meldingen handmatig op en herhaal de scan. Beoordeel ook het gedrag en de toepasselijke reviewcriteria; lint controleert alleen de automatisch vast te stellen eigenschappen.
6. Valideer ieder gewijzigd manifest afzonderlijk met de [Puppet-parser](#puppet-manifests-valideren). Controleer gewijzigd gedrag, templates, voorbeelden en metadata met de passende validators en tijdelijke synthetische invoer.
7. Voer bij linterontwikkeling de betrokken [tooltests](#tests-uitvoeren-en-uitbreiden) uit. Daarmee controleer je de toolwijziging; modulegedrag valideer je afzonderlijk.
8. Voer na alle correcties de volledige eindcontroles hieronder uit en voltooi de toepasselijke CI-controles. Ook na een geslaagde gerichte scan blijven de volledige lintscan en alle tooltests vereist.
9. Bekijk de uiteindelijke bestandsselectie en diff, inclusief de automatische correcties. Leg de validatie, reviewuitkomsten en eventuele beperkingen vast in de wijzigingsreview en laat de wijzigingen klaarstaan voor menselijke review en commit.

Gebruik voor de eindcontroles onderstaande opdrachten, in de [volgorde van het controleoverzicht](../README.md#ci-van-deze-repository). De [gezamenlijke snelstart](../README.md#snelstart-in-deze-repository) bevat daarnaast de afzonderlijke metadata- en dependencycontrole.

**Werkmap:** Repositoryroot. **Shell:** POSIX shell. **Vereisten:** Ontwikkelbundle; Ruby-controle wanneer toepasselijk. **Invoer:** Volledige eigen Puppet-/Ruby-code en tooltests. **Wijzigt bestanden:** Genegeerde JUnit-resultaten en toolcache. **Verwacht resultaat:** Alle controles afzonderlijk geslaagd; diff ter review.

```sh
bundle exec rake 'validate:puppet[.tools/validate/results/validate-report.xml]'
bundle exec puppet-lint --no-config --config .puppet-lint.rc .
bundle exec rubocop --config .rubocop.yml
bundle exec rake test
git diff --check
git diff --name-only
git diff
```

`rake test` ontdekt de tooltests recursief en voert ze allemaal uit. `test:lint` beperkt zich tot de lintertests. De overige [gerichte taken](../README.md#gezamenlijke-tooltests) kiezen hun eigen onderdeel; `test` voert alle toolsuites en repositorycontroles uit. Zonder expliciete rapportinstelling blijft de uitvoer in de console. `git diff --check` zoekt whitespacefouten; de laatste twee commando's tonen de gewijzigde bestanden en hun inhoud.

Gebruik bij wijzigingen aan Ruby-code de [RuboCop-werkwijze](#ruby-code-controleren) voor de beginscan, correcties en hercontrole.

## Snelstart in een ander Puppet-project

`lint-project 0.2.0` vereist een expliciete bron voor `project-tools-shared`. Volg bij een update de [consumermigratie](../README.md#migreren-naar-afzonderlijke-toolpakketten); voeg voor parserrapportage ook de zelfstandige validatorgem toe.

Deze snelstart gebruikt een eigen project; alleen de afzonderlijke [metadatacontrole](../metadata/README.md) vereist VERSION en rootmetadata. Voeg `global-modules` toe aan die projectroot. De gedeelde modules en gem staan in die checkout; je Gemfile, lockfile, configuratie en eigen manifests staan in de consumerroot. Gebruik voor een bestaand project dezelfde indeling met de daar vastgelegde submodulerevisie, zoals uitgewerkt bij [path-import](#installatie-in-je-project).

Vervang `<repository-url>` door de Git-URL van je goedgekeurde repository.

**Werkmap:** De eigen projectroot. **Shell:** POSIX shell met `set -e`. **Vereisten:** Git, nieuwste stabiele Ruby en Bundler, toegang tot de goedgekeurde Git- en gembron. **Invoer:** De hieronder aangemaakte `manifests/site.pp`. **Wijzigt bestanden:** Checkout `global-modules`, eigen Gemfile, lockfile, lintconfiguratie en synthetisch manifest. **Verwacht resultaat:** Installatie en een eerste volledige profielscan met exitcode 0.

```sh
set -e
git clone --recurse-submodules '<repository-url>' global-modules
LINT_REVISION="$(git -C global-modules rev-parse HEAD)"
printf 'Gekozen bronrevisie: %s\n' "$LINT_REVISION"
cat > Gemfile <<'RUBY'
source 'https://rubygems.org'

gem 'project-tools-shared', path: 'global-modules/.tools/shared', require: false
gem 'lint-project', path: 'global-modules/.tools/lint', require: false
RUBY
cat > .puppet-lint.rc <<'CONFIG'
--ignore-paths=global-modules/*,./global-modules/*,vendor/*,./vendor/*
CONFIG
mkdir -p modules manifests
printf '%s\n' '$values = concat([1], [2])' > manifests/site.pp
gem install bundler
export BUNDLE_VERSION=system
bundle install
LINT_GEM="$(bundle info --path lint-project)"
export PROJECT_TOOLS_MODULEPATH="$PWD/global-modules:$PWD/modules"
test -f .puppet-lint.rc
bundle exec puppet-lint --no-config --load "$LINT_GEM/lib/project_lint.rb" --config "$LINT_GEM/config/puppet-lint.rc" --config .puppet-lint.rc manifests
```

De resulterende indeling is:

```text
consumer/
├── Gemfile
├── Gemfile.lock
├── .puppet-lint.rc
├── global-modules/.tools/lint/lint-project.gemspec
├── modules/
└── manifests/site.pp
```

Het manifest is een **Volledig uitvoerbaar voorbeeld** voor het gedeelde lintprofiel plus de bovenstaande consumerconfiguratie. De path- en Git-integratietests controleren deze invoer en de tegenvariant `$values = [1] + [2]`, die `project_arrays` met warning en exitcode 1 oplevert. De Ruby-gem installeert geen Puppet-modules. De checkout is hier zowel de gembron als de plaats van eventuele Puppet-dependencies; een gebouwd pakket vereist die checkout niet.

Bewaar de gekozen bronrevisie en eigen lockfile in het versiebeheer van het consumerproject. Bij de aanbevolen Git-submodule legt de gitlink die revisie vast. Werk die revisie bewust bij en voer vervolgens `bundle update lint-project`, de eigen volledige lintscan, parservalidatie en toepasselijke Ruby-/toolcontroles uit. Een geslaagde synthetische scan bewijst nog niet dat alle eigen productiecode is geselecteerd.


## Installatie en compatibiliteit

Zie de [gezamenlijke toolinghandleiding](../README.md#installatie-en-compatibiliteit) voor deze procedure.

### Benodigde omgeving

Zie de [gezamenlijke toolinghandleiding](../README.md#benodigde-omgeving) voor deze procedure.

### Installatie

Zie de [gezamenlijke toolinghandleiding](../README.md#installatie) voor deze procedure.

### Ruby op macOS

Zie de [gezamenlijke toolinghandleiding](../README.md#ruby-op-macos) voor deze procedure.

### Gems installeren

Zie de [gezamenlijke toolinghandleiding](../README.md#gems-installeren) voor deze procedure.

### Compatibiliteitslagen

Zie de [gezamenlijke toolinghandleiding](../README.md#installatie-en-compatibiliteit) voor de ontwikkelomgeving en de [pakketkeuze](../README.md#pakketten-en-commandos) voor de dependencies per tool.

## Configuratie, bestandsselectie en modulepad

### Werking van de controles

`--no-config` slaat de automatisch geladen optiebestanden over. Daarna leest `--config .puppet-lint.rc` expliciet de [projectconfiguratie](../../.puppet-lint.rc). Die laadt het [library-entrypoint](lib/project_lint.rb) met `--load` en leest het [gedeelde profiel](config/puppet-lint.rc) met de native `--config`-optie. Het gedeelde profiel kiest de uitvoeropmaak en laat ook waarschuwingen een foutcode opleveren. De rootconfiguratie voegt de bestandsuitsluitingen van deze repository toe. De externe lintplugins uit de gemspec van `lint-project` worden via de bundle geladen.

De combinatie van beide opties voorkomt invloed van persoonlijke Puppet-lint-instellingen. Een gewone `bundle exec puppet-lint .` leest eerst `/etc/puppet-lint.rc`, daarna `~/.puppet-lint.rc` en ten slotte `.puppet-lint.rc` in de werkmap. Die instellingen worden samengevoegd. Daardoor kan een persoonlijke `--fix` of een eerder uitgeschakelde standaardcheck actief blijven. Alleen `--config` toevoegen voorkomt dat niet; alleen `--no-config` gebruiken laadt juist de projectinstellingen niet.

[Bundler-instellingen](#gems-installeren) bepalen welke gems worden gebruikt en waar die staan. Ze regelen niet welke optiebestanden Puppet-lint leest. Een ander project gebruikt [zijn eigen bundle](#installatie-in-je-project) en geeft de geïnstalleerde gem en configuratie expliciet aan de CLI door.

De afsluitende `.` selecteert de hele repository. Nieuwe manifests en bestanden in `examples/` worden automatisch gevonden; de CLI leest ook YAML. De [projectconfiguratie](../../.puppet-lint.rc) sluit vendored Git-submodules en gems onder `vendor/bundle` uit. ERB-templates met een YAML-extensie worden pas geldige YAML na renderen en vallen daarom buiten deze scan. Puppet-code in Strings of Markdown vraagt eveneens [afzonderlijke validatie](#aanvullende-validatie).

Voor een gerichte scan vervang je `.` door het manifestpad. Extra opties komen ná `--config .puppet-lint.rc`, zodat ze op de geladen projectchecks werken:

**Werkmap:** Repositoryroot. **Shell:** POSIX shell. **Vereisten:** Ontwikkelbundle. **Invoer:** Eén manifest; normale profielscan. **Wijzigt bestanden:** Geen bronbestanden. **Verwacht resultaat:** Gericht resultaat.

```sh
bundle exec puppet-lint --no-config --config .puppet-lint.rc examples/site.pp
```

**Werkmap:** Repositoryroot. **Shell:** POSIX shell. **Vereisten:** Ontwikkelbundle. **Invoer:** Eén manifest, alleen project_resource_references. **Wijzigt bestanden:** Geen bronbestanden. **Verwacht resultaat:** Alleen diagnose voor de genoemde check.

```sh
bundle exec puppet-lint --no-config --config .puppet-lint.rc --only-checks project_resource_references examples/site.pp
```

**Werkmap:** Repositoryroot. **Shell:** POSIX shell. **Vereisten:** Ontwikkelbundle. **Invoer:** Volledige lintselectie. **Wijzigt bestanden:** Geen bronbestanden. **Verwacht resultaat:** Actieve en genegeerde meldingen zichtbaar.

```sh
bundle exec puppet-lint --no-config --config .puppet-lint.rc --show-ignored .
```

**Werkmap:** Repositoryroot. **Shell:** POSIX shell. **Vereisten:** Ontwikkelbundle. **Invoer:** Volledige lintselectie. **Wijzigt bestanden:** Geen bronbestanden. **Verwacht resultaat:** Native JSON en ongewijzigde lintstatus.

```sh
bundle exec puppet-lint --no-config --config .puppet-lint.rc --json .
```

**Werkmap:** Repositoryroot. **Shell:** POSIX shell. **Vereisten:** Ontwikkelbundle. **Invoer:** Geen manifests; runtime-inventaris. **Wijzigt bestanden:** Geen bronbestanden. **Verwacht resultaat:** Alle geregistreerde checks, ook inactieve.

```sh
bundle exec puppet-lint --no-config --config .puppet-lint.rc --list-checks
```

Met `--only-checks` onderzoek je één of meer genoemde checks; deze beperkte selectie vervangt de eindscan niet. `--show-ignored` toont meldingen die door lintmarkeringen zijn onderdrukt. JSON verandert alleen de uitvoervorm en gebruikt dezelfde controles en exitcodes.

`--list-checks` toont welke checks beschikbaar zijn, inclusief uitgeschakelde checks. De lijst bewijst dus niet dat iedere check draait. Gebruik bij twijfel de proef met [een bekende fout](#een-melding-oplossen).

### Eigen lintconfiguratie

Bewaar projectspecifieke bestandsuitsluitingen in je eigen `.puppet-lint.rc`. De gewone lintregels en uitvoerinstellingen komen uit het meegeleverde `config/puppet-lint.rc`. Voor de aanbevolen indeling sluit je de gedeelde modules en geïnstalleerde gems uit van de eigen stijlscan:

```text
--ignore-paths=global-modules/*,./global-modules/*,vendor/*,./vendor/*
```

Houd de modules die nodig zijn voor interfacecontrole beschikbaar, ook als hun code buiten de stijlscan valt. Voeg geen regeluitsluitingen toe om echte fouten te verbergen; de toegestane lokale suppressions staan bij de betreffende [codeafspraken](docs/CODE_RULES.md#naslag).

De projectconfiguratie gebruikt alle standaard ingeschakelde checks en schakelt daarnaast `class_inherits_from_params_class` in. Ook nieuwe standaardchecks komen bij een update beschikbaar. De optionele checks voor 80 tekens, booleans tussen aanhalingstekens en code op hoofdniveau staan uit: dit project volgt de [regelgrens van 140 tekens](docs/CODE_RULES.md#lange-regels) en ondersteunt daemonstrings zoals `'true'` en uitvoerbare profielen. Bestaande stijlachterstand is geen reden om een check uit te schakelen of een module uit te zonderen.

### Aanroepen van modules controleren

`PROJECT_TOOLS_MODULEPATH` volgt de [gedeelde padvalidatie](../README.md#gedeeld-modulepad). Zonder deze variabele zoekt de linter vanaf de huidige werkmap als moduleverzameling en slaat hij de vendored namen `concat`, `debconf`, `reboot` en `stdlib` over. Stel de variabele in externe projecten expliciet in.

De resolver gebruikt eerst declaraties uit de actuele lintinvoer. Daarna kiest hij de eerste modulemap met de gevraagde modulenaam en zoekt daar `example/manifests/init.pp` voor `example`, of `example/manifests/item.pp` voor `example::item`. Ontbreekt dat manifest, dan zoekt hij niet verder in een latere kopie van de module. Bestanden achter symlinks buiten de ingestelde modulemap worden niet gelezen.

Controleer environments met verschillende modulepaden apart. Eén samengevoegde lijst kan een andere moduleversie kiezen dan Puppet op de server. De linter leest geen `environment.conf`.

> [!CAUTION]
> Een niet-vindbare declaratie kan geen melding over ontbrekende parameters opleveren. Een geslaagde scan bewijst daarom niet dat Puppet de catalogus kan compileren. Controleer aanroepen ook met de eigen catalogusvalidatie.

Bij vindbare declaraties controleert `project_interface_calls` verplichte parameters, inclusief `Optional[...]` zonder default. Argumenttypen, onbekende parameters, functies, dynamische classnamen, `include`/`contain`, Hiera, overerving en splats worden daarmee niet volledig gevalideerd.

`project_parameter_passthrough` gebruikt dezelfde vindbare defined types om per gefilterde key de bronwaarde of brondefault met de ontvangende parameterdefault te vergelijken. De bron wordt in de actuele lintinvoer opgezocht. Een onbekende bron, ontvanger of default geeft geen filtermelding; de [regel voor parameterdoorgifte](docs/CODE_RULES.md#aanroepen-en-publieke-interfaces) beschrijft de verdere grenzen en reviewcriteria.

### Modulemetadata controleren

Volg de [metadatagids](../metadata/README.md#modulemetadata-controleren) voor deze zelfstandige controle.

#### Metadata in modulemappen

Volg de [metadatagids](../metadata/README.md#metadata-in-modulemappen) voor deze zelfstandige controle.

#### Metadata in de projectroot

Volg de [metadatagids](../metadata/README.md#metadata-in-de-projectroot) voor deze zelfstandige controle.

#### Versiebron en rapportage

Volg de [metadatagids](../metadata/README.md#versiebron-en-rapportage) voor deze zelfstandige controle.

#### Metadata automatisch herstellen

Volg de [metadatagids](../metadata/README.md#metadata-automatisch-herstellen) voor deze zelfstandige controle.

### Configuratie- en selectiegedrag

<a id="gecontroleerde-configuratie--en-selectiescenarios"></a>

De tabel beschrijft het CLI-contract en de bijbehorende bron of regressietest. Uitkomsten van een afzonderlijke uitvoering horen in de wijzigingsreview.

| Scenario | Gedrag | Bron en regressiedekking |
| --- | --- | --- |
| Systeem- en gebruikersopties bevatten fix of uitgeschakelde checks | Automatisch geladen opties kunnen blijven gelden; `--no-config` plus het expliciete profiel sluit die bron uit | `CliConfigurationTest#test_project_configuration_isolates_system_and_personal_options_before_scanning_or_fixing` |
| Load gevolgd door gedeeld en lokaal configbestand | Entrypoint registreert checks; gedeeld profiel stelt opties in; lokale opties worden daarna per optietype verwerkt | `ExternalProjectTest#test_installation_loads_all_checks_without_a_repository_checkout` en de native configuratietests |
| Herhaalde booleans, lijsten en uitvoerformaat | Fix/relative blijven aan; ignore_paths, top_scope_variables en log_format worden vervangen | `CliConfigurationTest#test_repeated_configurations_replace_lists_and_formats_but_accumulate_boolean_flags` |
| Rapportpad uit environment en CLI | Het laatste CLI-rapportpad gaat vóór CODECLIMATE_REPORT_FILE; relatieve paden gebruiken de werkmap | Native `PuppetLint::OptParser`; vind de geïnstalleerde bron met `bundle info --path puppet-lint` en controleer `lib/puppet-lint/optparser.rb` |
| Expliciete configuratie ontbreekt | Stilzwijgend overgeslagen; schoon resultaat kan 0 zijn zonder projectchecks | `CliConfigurationTest#test_native_config_option_silently_skips_a_missing_file_without_loading_project_checks` |
| Entrypoint ontbreekt | LoadError, exitcode 1, geen native JSON-rapport | `CliConfigurationTest#test_relative_load_paths_use_the_working_directory_not_the_configuration_directory` |
| Eén of meerdere concrete bestanden | Alle bestaande concrete invoerbestanden worden geselecteerd | `CliScopeTest#test_file_arguments_and_first_directory_selection_have_distinct_semantics` |
| Eén of meerdere directories | De eerste directory wordt recursief gescand; verdere argumenten worden genegeerd | Dezelfde selectietest; gebruik één gezamenlijke root of concrete bestanden |
| Uitsluiting of lege selectie | Linter: 0 en JSON `[]`; converter: 1 en ReportError. | `CliScopeTest#test_zero_selected_files_succeeds_but_json_proves_the_empty_selection` en `PuppetJunitTest#test_invalid_or_empty_input_is_a_report_error_not_a_passing_scan` |
| Andere werkmap met relatieve load/config/invoer | Paden volgen de werkmap, niet de map van het optiebestand; corrigeer alle relatieve paden of gebruik absolute paden | Native CLI-test voor relatieve load en onafhankelijke consumerinstallaties |
| Dubbele modulenaam | De eerste modulemap overschaduwt de hele module; latere manifests vullen ontbrekende delen niet aan | `ExternalProjectTest#test_modulepath_order_shadows_entire_modules_and_keeps_dependencies_outside_style_scope` |
| Module beschikbaar maar uitgesloten van scan | Declaratieopzoeking kan haar lezen zonder de manifesten te linten | Dezelfde modulepadtest; ignore_paths en modulepath blijven afzonderlijke instellingen |
| Declaratie ontbreekt | Geen bewijs voor vereiste argumenten of ontvangende defaults; geen automatische interfacegarantie | `ExternalProjectTest` en `ExternalParameterPassthroughTest`; catalogusreview blijft verplicht |
| Modulepad ongeldig of symlink buiten modulemap | ArgumentError voor ongeldige roots; ontsnappende symlinks worden niet als declaratiebron gebruikt | `ExternalProjectTest#test_invalid_modulepaths_fail_even_without_calls` en `test_explicit_modulepath_resolves_vendored_names_and_refuses_escaping_symlinks` |

## Commando's en opties

De [native CLI-route](#werking-van-de-controles) en [consumerroute](#eigen-code-controleren) gebruiken dezelfde opties. Gerichte checkselectie is uitsluitend diagnose.

### Native opties

Deze tabel beschrijft Puppet-lint uit de [ontwikkelbundle](../../Gemfile.lock). Vraag de geïnstalleerde versie op met `bundle exec puppet-lint --version`. De defaults gelden voor beide expliciete projectroutes, tenzij de rij een verschil noemt. Een voorbeeld in de laatste kolom is een **Fragment** met aanvullende CLI-argumenten; voeg het toe aan de [volledige aanroep](#werking-van-de-controles), vóór de invoerpaden. De beschikbaarheid van een optie verandert het eindcontrole- en suppressiebeleid niet.

| Syntax | Doel | Default in het gebruikte profiel | Toegestane waarden | Herhalen/combineren | Wijzigt bestanden | Gebruik bij eindcontrole | Voorbeeld |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `--help`, `-h` | Native hulp tonen | Uit | Geen waarde | Stopt vóór de scan | Nee | Geen scanbewijs | `--help` |
| `--version` | Engineversie tonen | Uit | Geen waarde | Stopt vóór de scan | Nee | Alleen inventaris | `--version` |
| `--no-config` | Automatische systeem-, gebruikers- en werkmapconfiguratie overslaan | Expliciet in beide routes | Geen waarde | Expliciete `--config` blijft actief | Nee | Verplicht in de gedocumenteerde route | `--no-config` |
| `--config FILE`, `-c FILE` | Optiebestand laden | Rootconfiguratie of gedeeld en lokaal consumerprofiel | Bestandspad | Op volgorde; geneste configs direct bij het lezen | Nee, tenzij geladen opties muteren | Volledige profielen laden | `--config .puppet-lint.rc` |
| `--load FILE`, `-l FILE` | Ruby-checkbestand laden | Projectentrypoint | Bestaand Ruby-bestand | Iedere aanroep voert `load` uit | Voert Ruby-code uit; entrypoint zelf wijzigt geen bronnen | Gedocumenteerd entrypoint | `--load .tools/lint/lib/project_lint.rb` |
| `--load-from-puppet MODULEPATH` | Gemplugins uit Puppet-modulemappen laden | Geen | Met `:` gescheiden paden | Iedere aanroep doorloopt `*/lib/puppet-lint/plugins/*.rb` | Voert gevonden Ruby-code uit | Geen vervanging voor het projectentrypoint | `--load-from-puppet modules` |
| `--with-context` | Broncontext bij meldingen tonen | Uit | Geen waarde | Zet aan; geen resetoptie | Nee | Alleen lokale diagnose; broncontext kan gevoelig zijn | `--with-context` |
| `--with-filename` | Bestandsnaam tonen | Uit; CLI activeert dit bij meerdere bestanden | Geen waarde | `--log-format` gaat voor | Nee | Toegestaan | `--with-filename` |
| `--fail-on-warnings` | Actieve warnings laten falen | Aan | Geen waarde | Zet aan; geen resetoptie | Nee | Aan laten | `--fail-on-warnings` |
| `--error-level LEVEL` | Welke meldingen worden afgedrukt | `all` | `warning`, `error`, `all` | Laatste waarde geldt; verandert detectie niet | Nee | `all`; filter geen eindrapport weg | `--error-level all` |
| `--show-ignored` | Onderdrukte meldingen tonen | Uit | Geen waarde | Met gewone uitvoer of JSON | Nee | Aanvullende suppressiereview | `--show-ignored` |
| `--relative` | Modulelayout vanaf module-root beoordelen | Aan | Geen waarde | Zet aan; geen resetoptie | Nee | Aan laten | `--relative` |
| `--fix`, `-f` | Beschikbare native fixes schrijven | Uit | Geen waarde | Combineer alleen met bedoelde bestandsselectie | Ja, geselecteerde manifests | Verboden in CI-eindcontrole | `--fix` |
| `--log-format FORMAT` | Consoleformaat instellen | `%{path}:%{line}:%{column}: %{check}: %{kind}: %{message}` | Native placeholders hieronder | Laatste waarde; gaat voor `--with-filename` | Nee | Profiel behouden | `--log-format '%{check}: %{message}'` |
| `--json` | Native JSON naar stdout | Uit | Geen waarde | SARIF gaat voor wanneer beide aanstaan | Nee; shellredirectie kan een bestand schrijven | Voor de JUnit-pipe | `--json` |
| `--sarif` | Native SARIF naar stdout | Uit | Geen waarde | Gaat voor JSON | Nee; shellredirectie kan een bestand schrijven | Geen vervanging voor het voorgeschreven JUnit-artifact | `--sarif` |
| `--codeclimate-report-file FILE` | Native Code Climate-rapport opslaan | Geen, behalve bij `CODECLIMATE_REPORT_FILE` | Schrijfbaar bestandspad | Laatste CLI-waarde gaat voor environment | Ja, rapport | Geen vervanging voor JUnit | `--codeclimate-report-file /tmp/lint-report.json` |
| `--list-checks` | Alle geregistreerde checks tonen | Uit | Geen waarde | Bevat ook inactieve checks; stopt vóór scan | Nee | Alleen inventaris | `--list-checks` |
| `--only-checks CHECKS` | Alleen genoemde geregistreerde checks activeren | Geen beperking | Kommagescheiden namen uit [register](#checkregister) | Vervangt vorige selectie; onbekende namen worden niet afgekeurd | Nee, tenzij samen met fix | Uitsluitend diagnose | `--only-checks project_arrays,project_templates` |
| `--ignore-paths PATHS` | Bestanden uit stijlscan weren | Repository: rootconfig; gedeeld: native `vendor/**/*.pp` | Kommagescheiden globpatronen | Vervangt de lijst; bouwt niet op | Nee | Alleen projectselectie, geen foutverberging | `--ignore-paths 'vendor/*,global-modules/*'` |
| `--top-scope-variables VARS` | Toegestane topscopevariabelen instellen | Native lijst, niet gewijzigd door projectprofielen | Kommagescheiden variabelenamen | Vervangt vorige lijst | Nee | Alleen onderbouwde projectconfiguratie | `--top-scope-variables trusted,facts` |
| `--no-CHECK-check` | Bij parseropbouw bekende check uitzetten | Zie [register](#checkregister) | Native en pluginchecknamen | Zet genoemde check uit | Nee | Geen toestemming voor niet-toegestane suppressions | `--no-80chars-check` |
| `--CHECK-check` | Bij parseropbouw inactieve check activeren | Zie register | `80chars`, `quoted_booleans`, `code_on_top_scope`, `class_inherits_from_params_class` | Zet genoemde check aan | Nee | Gedeeld profiel bepaalt projectkeuze | `--class_inherits_from_params_class-check` |
| `PATH [PATH ...]` | Invoer selecteren | Geen | Eén directory of concrete bestanden | Eerste argument directory: overige argumenten worden genegeerd | Alleen met fix | Controleer de volledige bedoelde selectie | `examples/site.pp examples/web.pp` |

De placeholders voor `--log-format` zijn `%{filename}`, `%{path}`, `%{fullpath}`, `%{line}`, `%{column}`, `%{kind}`, `%{KIND}`, `%{check}` en `%{message}`. Het formatteken `%` is Ruby-formatteersyntax; een ongeldige placeholder kan de uitvoering afbreken. Gebruik voor eindcontrole het profiel.

De native parser bouwt check-specifieke schakelaars vóór `--load` wordt uitgevoerd. Daarom geeft `--no-project_arrays-check` in de ondersteunde route `invalid option` en exitcode 1. `--only-checks project_arrays` leest de registratie tijdens de verwerking en werkt wel. `--load-from-puppet` zoekt pluginbestanden en stelt **niet** `PROJECT_TOOLS_MODULEPATH` voor declaratieopzoeking in.

### Reporterargumenten

| Executable | Argumenten en invoer | Default en padbasis | Rapport en foutgedrag |
| --- | --- | --- | --- |
| `puppet-lint-junit` | Exact één rapportpad; native JSON-array via stdin | Geen default; relatief aan werkmap | Extensie wordt niet gecontroleerd. Bovenliggende map moet bestaan. Overschrijft het rapport; geldige warnings/errors worden XML-failures maar de converter zelf retourneert 0. |
| `rubocop` | `--config`, `--format progress --format junit --out FILE` | Eigen RuboCop-configuratie en expliciet rapportpad | Native formatter, geen afzonderlijke converter; zie [Ruby-controles](#ruby-code-controleren). |
| `rake test` / Minitest | `TEST=...`, `TESTOPTS=...` | Recursieve selectie van tooltests | Zie [testselectie](#testselectie-en-uitvoeropties) en [JUnit-initialisatie](#junit-rapportage-instellen). |

Het afzonderlijke `validate-junit` volgt de [validatorinterface](../validate/README.md#puppet-manifests-valideren).

### Omgevingsvariabelen

Dit is de publieke interface die de projectcode leest of die de ondersteunde procedures gebruiken. Native Ruby- en Bundler-instellingen blijven hun eigen interfaces. Tijdelijke voorbeeldvariabelen zijn apart gemarkeerd; zij zijn geen extra geminstelling.

| Naam | Doel | Unset | Lege waarde | Default | Padbasis | Prioriteit tegenover CLI/configuratie |
| --- | --- | --- | --- | --- | --- | --- |
| `PROJECT_TOOLS_MODULEPATH` | Modulebronnen voor structurele analyse | Werkmap; vendored namen uitgesloten | Fout | `Dir.pwd` | Bestaande absolute mappen, `:` op macOS/Linux | Geen CLI-equivalent; leest geen `environment.conf` |
| `BUNDLE_VERSION` | Actieve Bundler kiezen | Native lockfile-/Bundlerkeuze | Blijft een lege settingswaarde; `bundle --version` gebruikt hier de actieve Bundler | Procedures: `system` | Geen pad | Kies geïnstalleerde Bundler; geen Ruby-versiepin |
| `BUNDLE_IGNORE_CONFIG` | Persoonlijke Bundlerconfiguratie isoleren | Native Bundlerconfig actief | Negeert configuratie eveneens: aanwezigheid telt | CI: `1` | Geen pad | Betreft Bundler, niet Puppet-lint-optiebestanden |
| `BUNDLE_FROZEN` | Lockfile onveranderd vereisen | Native Bundlerdefault | Boolean false; frozen wordt niet vereist | CI: `true` | Eigen lockfile | Installatie faalt als resolutie moet wijzigen |
| `BUNDLE_PATH` | Installatiemap gems | Native Bundlerdefault | Expliciet leeg basispad, geen fallback naar systeemgems; vermijd dit in installatieprocedures | CI: `vendor/bundle` | Projectroot | Bundlerinstelling, geen manifestselectie |
| `BUNDLE_GEMFILE` | Gemfile selecteren | Gemfile vanaf werkmap | Zelfde zoekgedrag als unset: zoek Gemfile/gems.rb omhoog vanaf de werkmap | Eigen root-Gemfile | Native Bundlerpad | Niet naar bronrepository instellen voor consumers |
| `PATH` | Ruby en executables vinden | Shellomgeving | Lege zoekcomponent kan de werkmap doorzoeken; correcte Ruby-keuze is niet gegarandeerd | Actieve shell | Absolute zoekmappen | Homebrew-Ruby vóór systeem-Ruby |
| `GITHUB_ACTION` | Native lintannotaties activeren | Geen annotaties | Aan: aanwezigheid is bepalend | CI levert waarde | Geen pad | Verandert niet de diagnostiektelling |
| `CODECLIMATE_REPORT_FILE` | Native Code Climate-rapport | Geen rapport | Poging tot schrijven naar leeg pad faalt | Geen | Werkmap | CLI `--codeclimate-report-file` gaat voor |
| `MINITEST_REPORTERS_REPORTS_DIR` | Optionele Minitest-rapportage inschakelen | Alleen console-uitvoer | Native reporter schrijft in de werkmap; geef voor rapportage een niet-leeg pad op | Geen; CI kiest `.tools/results/tests` expliciet | Bij relatief pad: werkmap | Zie [testinrichting](../README.md#gezamenlijke-tooltests); raakt lint/parser niet |
| `PROJECT_REPORT_DIR` (voorbeeldafspraak) | Rapportkeuze consumer | Geen rapportkeuze ingesteld | Niet ondersteund als voorbeeldinvoer | Geen; voorbeelden stellen een pad in | Consumerroot | Shell geeft pad expliciet aan reporters of het parser-taakargument; geen geminterface |
| `LINT_GEM`, `LINT_SOURCE`, `LINT_REVISION`, `LINT_PACKAGE`, `CONSUMER_DIR` (tijdelijke voorbeeldvariabelen) | Paden en revisie in procedures benoemen | In ieder procedureblok eerst instellen | Niet toegestaan waar pad of revisie nodig is | In procedure bepaald | Zoals bij procedure vermeld | Geen door de gem gelezen instellingen |
| `lint_gem` (tijdelijke variabele in bestaande consumer- en CI-voorbeelden) | Bundlerlocatie bewaren | Voor gebruik instellen | Mislukte `bundle info` stopt procedure | `bundle info --path lint-project` | Absoluut gem-pad | Alleen shellargument |

Bundler kiest gewone settings in de volgorde tijdelijke CLI-instelling, lokale configuratie, environment, globale configuratie en default. `BUNDLE_IGNORE_CONFIG` slaat lokale en globale configuratie over, ook als de environmentwaarde leeg is. `BUNDLE_GEMFILE` heeft de hierboven beschreven eigen zoekroute. Controleer bij een Bundlerupdate de settings met `bundle config list`. Deze prioriteit staat los van Puppet-lint-opties; het gebruik van Bundler verandert geen lintprofiel.

De offline integratietests isoleren bovendien `RUBYOPT`, `RUBYLIB`, `BUNDLE_USER_HOME`, `GEM_HOME` en `GEM_PATH`. Alleen reeds geïnstalleerde Ruby-dependencies worden als lokale cache hergebruikt. Bij een nieuwe offline lockfile gebruiken deze synthetische tests `BUNDLE_LOCKFILE_CHECKSUMS=false`, omdat de lokale cache geen registrychecksums levert; dit is geen instelling in de consumerinstallatie of CI-voorbeelden.

## Meldingen, severity en exitcodes

### Een melding oplossen

Een lintmelding geeft het bestand, de regel, de kolom, de checknaam en de oorzaak. Zoek een `project_*`-check op in het [checkoverzicht](#beschikbare-projectchecks). De link leidt naar de codeafspraak en de voorwaarden voor correctie. Voor standaardchecks is er de [uitleg van Puppet-lint](https://puppetlabs.github.io/puppet-lint/#checks).

Lees de gemelde regel samen met het parameterblok, de resource of het commando waar hij bij hoort. Bepaal welke afwijking wordt gemeld en volg de [werkwijze](#werkwijze-bij-een-wijziging) om die te herstellen. `[review]` betekent dat inhoudelijke beoordeling nodig is of dat de constructie niet veilig automatisch kan worden gewijzigd. Ook zonder die markering kunnen reviewpunten gelden; het overzicht vermeldt de grenzen van iedere check.

Een waarschuwing laat de scan mislukken. Herstel de oorzaak volgens de codeafspraak. De toegestane uitzonderingen zijn beperkt tot [lange regels](docs/CODE_RULES.md#lange-regels) en de beschreven [Puppet-fileserverbronnen](docs/OPERATIONAL_RULES.md#templates-en-bestandsbronnen); andere checks uitschakelen of alleen een gunstige selectie draaien levert geen volledige controle op.

Stopt de linter voordat hij code controleert, controleer dan de Ruby-installatie, bundle en werkmap volgens [Gems installeren](#gems-installeren). Een ontbrekende plugin kan wijzen op een onvolledige installatie van de gem of een verkeerd entrypoint. Met [`--list-checks`](#werking-van-de-controles) zie je of de projectchecks zijn geladen.

Om te controleren of ze ook draaien, maak je tijdelijk buiten de repository een manifest met `$values = [1] + [2]`. Scan het volledige pad met de projectaanroep. Verwacht een foutcode en `project_arrays` bij dat bestand. Vervang de inhoud door `$values = concat([1], [2])`; nu hoort de proef te slagen. Verwijder het tijdelijke bestand daarna.

### Exitcodes van Puppet-lint

De tabellen gelden voor de expliciete profielen met `--fail-on-warnings` en `--error-level all`. Een warning en een error zijn verschillende severities, maar leveren beide exitcode 1. `[review]` is uitsluitend meldingstekst. `fixed` en `ignored` zijn uitkomstsoorten; zij zijn geen actieve warning/error.

| Geval | Exitcode | Stdout | Stderr | Rapportgedrag |
| --- | --- | --- | --- | --- |
| Schoon bestand | 0 | Stil; met JSON `[[]]` | Leeg | Native uitvoer; JUnit alleen via converter |
| Actieve warning | 1 | Diagnostic met warning of native JSON | Gewoonlijk leeg | JSON bevat de warning |
| Actieve error | 1 | Diagnostic met error of native JSON | Syntax geeft bovendien parseradvies | JSON bevat de error |
| Ongeldige optie | 1 | `puppet-lint: invalid option: {optie}` plus hulpaanwijzing | Leeg voor InvalidOption | Geen geldige native JSON |
| Ontbrekende invoer of bestand | 1 | `no file specified` of `no file specified or specified file does not exist` plus hulpaanwijzing | Leeg | Geen geldige native JSON |
| Ontbrekend expliciet configbestand | 0 bij verder schone run | Geen waarschuwing over het ontbrekende bestand | Leeg | Overige opties draaien; dit bewijst geen geladen projectprofiel |
| Ongeldige configoptie | 1 | InvalidOption plus hulpaanwijzing | Leeg | Geen geldige native JSON |
| Ontbrekend `--load`-bestand | 1 | Geen lintdiagnostics | LoadError met bestandsnaam en stacktrace | Geen JSON-rapport |
| Ongeldig modulepad | 1 | Geen geslaagde lintuitslag | ArgumentError met `PROJECT_TOOLS_MODULEPATH` | Geen compleet JSON-rapport |
| Lege directory of volledig uitgesloten manifestselectie | 0 | JSON `[]` | Leeg | Zonder gecontroleerde bestanden maakt de converter ReportError |
| Ongeldige native rapportbestemming | 1 | Eventueel reeds gemaakte JSON | Schrijffout, bijvoorbeeld EISDIR | Geen bruikbaar nieuw rapport op die bestemming |

`--error-level` filtert alleen de gepubliceerde meldingen, inclusief JSON. Het verandert de warning/error-exitstatus niet. Een warningrun met `--error-level error --json` kan dus `[[]]` afdrukken en toch met 1 eindigen. Gebruik deze filteroptie niet in eindrapporten. Zonder `--fail-on-warnings` zou een warningrun 0 kunnen geven; beide projectprofielen voorkomen dat.

Een ontbrekend configbestand is een vastgestelde native beperking. Daarom controleren de procedures het lokale bestand expliciet met `test -f`. Maak van de native nulcode geen bewijs dat alle regels zijn geladen. Fouten in Ruby-code of ongeldige waarden die niet als InvalidOption worden opgevangen kunnen met een stacktrace stoppen; zij worden niet vertaald naar een gezonde scan.

### Exitcodes van puppet-lint-junit

| Geval | Exitcode | Stdout | Stderr | Rapportgedrag |
| --- | --- | --- | --- | --- |
| Geldige JSON zonder actieve meldingen | 0 | `Puppet lint: no active findings.` | Leeg | Eén geslaagde testcase |
| Geldige JSON met warnings | 0 | Actieve diagnostics | Leeg | JUnit-failure per bestand/check |
| Geldige JSON met errors | 0 | Actieve diagnostics | Leeg | JUnit-failure per bestand/check |
| Ontbrekende/ongeldige JSON | 1 | Geen geslaagde scanmelding | `Invalid or missing Puppet-lint JSON; inspect the lint log.` | Parseerbare XML met ReportError als rapportpad schrijfbaar is |
| JSON `[]` | 1 | Geen geslaagde scanmelding | `No files were reported by Puppet-lint` | XML met ReportError |
| Ongeldige JSON-structuur of diagnosticvelden | 1 | Geen geslaagde scanmelding | `Expected native Puppet-lint JSON arrays` of `Invalid Puppet-lint diagnostic` | XML met ReportError |
| Geen of meerdere rapportargumenten | 1 | Leeg | Usage | Geen nieuw rapport |
| Laden gem/executable mislukt | 1 bij de gecontroleerde LoadError | Geen converteruitvoer | Ruby-/Bundlerfout | Geen nieuw rapport |
| Rapportpad onschrijfbaar of bovenliggende map ontbreekt | 1 | Geen complete conversie | `Cannot write Puppet-lint JUnit report: {fout}` | Geen bruikbaar nieuw rapport; oud bestand kan blijven bestaan als openen faalt |

De converter heeft geen lintconfiguratie, manifestselectie of warningbeleid: zulke combinaties zijn niet van toepassing omdat hij alleen stdin omzet. Exitcode 0 betekent geslaagde conversie, ook bij XML-failures. Bewaar de lintstatus met Bash `pipefail`; alleen het bestaan van XML is onvoldoende.

### Exitcodes van validate-junit

De zelfstandige gem `project-tools-validate` beheert deze controle. Volg de [validatorhandleiding](../validate/README.md#exitcodes-van-validate-junit) voor de aanroep, selectie en rapportage.

### Overige validatiecommando's

| Executable | Schoon | Bevinding of fout | Ongeldige invoer/configuratie | Rapportagefout en uitvoer |
| --- | --- | --- | --- | --- |
| `puppet parser validate` | 0, doorgaans stil | Syntaxfout: 1, native diagnostic | Ontbrekend bestand: 1; geen lintprofiel | Geen eigen XML; hiervoor bestaat validate-junit |
| `rubocop` | 0, console-overzicht | Offenses: 1; copseverity is niet de Puppet-severity | Ongeldige optie/configuratie: 2 | Foutstatus en native diagnostic; native JUnit-formatter schrijft alleen waar uitvoering dat bereikt |
| `rake test` | 0, testtelling; JUnit alleen bij expliciete rapportinstelling | Assertion/error: 1 | Taak-/laadfout: 1 | Reporter-/schrijffout: niet-nul; geen garantie op complete XML |

De aanvullende parser-, schema-, test- en rapportcontroles hebben geen `--fix`-route: syntax, ontbrekende inhoud, testverwachtingen en rapportbestemmingen vereisen hun eigen concrete correctie. RuboCop gebruikt zijn bestaande afzonderlijke veilige `--autocorrect`-route; de Puppet-lint-optie schakelt die niet in.

Controleer bij een uitvoerfout altijd de numerieke status én het rapport. Bestaande rapporten bewijzen geen geslaagde huidige run. De gedocumenteerde rapportcommando's vervangen hun eigen uitvoer; een mislukte start of mislukte opening kan een oud bestand laten staan.


## Checkregister

### Beschikbare projectchecks

De tabel beschrijft de automatische dekking en verwijst naar de volledige regel. **Voorwaardelijk** betekent dat de check alleen aantoonbaar geschikte constructies corrigeert; de voorwaarden staan bij die regel. **Geen** betekent dat de check geen autofix heeft. Beoordeel de genoemde reviewpunten wanneer je wijziging ze raakt, ook als de check geen melding geeft.

<!-- BEGIN PROJECT CHECK REGISTRY -->
| Check | Actief in repositoryprofiel | Actief in gedeeld profiel | Meldingsvarianten | Autofix | Regeluitleg |
| --- | --- | --- | --- | --- | --- |
| `project_parameter_order` | Ja | Ja | [Parameters met defaultafhankelijkheden sorteren](docs/CODE_RULES.md#parameters-met-defaultafhankelijkheden-sorteren) | Per meldingsvariant: onafhankelijke parameters sorteren; defaults met evaluatie en comments blijven ter review: [Parameters met defaultafhankelijkheden sorteren](docs/CODE_RULES.md#parameters-met-defaultafhankelijkheden-sorteren) | [Parameters met defaultafhankelijkheden sorteren](docs/CODE_RULES.md#parameters-met-defaultafhankelijkheden-sorteren) |
| `project_parameter_alignment` | Ja | Ja | [Parameterblokken volledig uitlijnen](docs/CODE_RULES.md#parameterblokken-volledig-uitlijnen) | Per meldingsvariant: [Parameterblokken volledig uitlijnen](docs/CODE_RULES.md#parameterblokken-volledig-uitlijnen) | [Parameterblokken volledig uitlijnen](docs/CODE_RULES.md#parameterblokken-volledig-uitlijnen) |
| `project_documentation` | Ja | Ja | [Publieke declaraties bij de code documenteren](docs/DOCUMENTATION_RULES.md#publieke-declaraties-bij-de-code-documenteren), [Strings API-markering](docs/DOCUMENTATION_RULES.md#strings-api-markering), [Strings-summary op één regel](docs/DOCUMENTATION_RULES.md#strings-summary-op-één-regel), [Strings-parametercontract](docs/DOCUMENTATION_RULES.md#strings-parametercontract), [Uitvoerbare Strings-voorbeelden](docs/DOCUMENTATION_RULES.md#uitvoerbare-strings-voorbeelden) | Per meldingsvariant: bestaande parametertags ordenen; ontbrekende inhoud blijft handmatig: [Publieke declaraties bij de code documenteren](docs/DOCUMENTATION_RULES.md#publieke-declaraties-bij-de-code-documenteren), [Strings API-markering](docs/DOCUMENTATION_RULES.md#strings-api-markering), [Strings-summary op één regel](docs/DOCUMENTATION_RULES.md#strings-summary-op-één-regel), [Strings-parametercontract](docs/DOCUMENTATION_RULES.md#strings-parametercontract), [Uitvoerbare Strings-voorbeelden](docs/DOCUMENTATION_RULES.md#uitvoerbare-strings-voorbeelden) | [Publieke declaraties bij de code documenteren](docs/DOCUMENTATION_RULES.md#publieke-declaraties-bij-de-code-documenteren), [Strings API-markering](docs/DOCUMENTATION_RULES.md#strings-api-markering), [Strings-summary op één regel](docs/DOCUMENTATION_RULES.md#strings-summary-op-één-regel), [Strings-parametercontract](docs/DOCUMENTATION_RULES.md#strings-parametercontract), [Uitvoerbare Strings-voorbeelden](docs/DOCUMENTATION_RULES.md#uitvoerbare-strings-voorbeelden) |
| `project_documentation_layout` | Ja | Ja | [Lange regels](docs/CODE_RULES.md#lange-regels), [Strings-summary op één regel](docs/DOCUMENTATION_RULES.md#strings-summary-op-één-regel), [Uitvoerbare Strings-voorbeelden](docs/DOCUMENTATION_RULES.md#uitvoerbare-strings-voorbeelden), [Strings-regelbreedte](docs/DOCUMENTATION_RULES.md#strings-regelbreedte), [Strings-taginspringing](docs/DOCUMENTATION_RULES.md#strings-taginspringing), [Strings-secties met commentregels scheiden](docs/DOCUMENTATION_RULES.md#strings-secties-met-commentregels-scheiden), [Lengtesuppressions in Strings begrenzen](docs/DOCUMENTATION_RULES.md#lengtesuppressions-in-strings-begrenzen) | Per meldingsvariant: [Lange regels](docs/CODE_RULES.md#lange-regels), [Strings-summary op één regel](docs/DOCUMENTATION_RULES.md#strings-summary-op-één-regel), [Uitvoerbare Strings-voorbeelden](docs/DOCUMENTATION_RULES.md#uitvoerbare-strings-voorbeelden), [Strings-regelbreedte](docs/DOCUMENTATION_RULES.md#strings-regelbreedte), [Strings-taginspringing](docs/DOCUMENTATION_RULES.md#strings-taginspringing), [Strings-secties met commentregels scheiden](docs/DOCUMENTATION_RULES.md#strings-secties-met-commentregels-scheiden), [Lengtesuppressions in Strings begrenzen](docs/DOCUMENTATION_RULES.md#lengtesuppressions-in-strings-begrenzen) | [Lange regels](docs/CODE_RULES.md#lange-regels), [Strings-summary op één regel](docs/DOCUMENTATION_RULES.md#strings-summary-op-één-regel), [Uitvoerbare Strings-voorbeelden](docs/DOCUMENTATION_RULES.md#uitvoerbare-strings-voorbeelden), [Strings-regelbreedte](docs/DOCUMENTATION_RULES.md#strings-regelbreedte), [Strings-taginspringing](docs/DOCUMENTATION_RULES.md#strings-taginspringing), [Strings-secties met commentregels scheiden](docs/DOCUMENTATION_RULES.md#strings-secties-met-commentregels-scheiden), [Lengtesuppressions in Strings begrenzen](docs/DOCUMENTATION_RULES.md#lengtesuppressions-in-strings-begrenzen) |
| `project_layout` | Ja | Ja | [Inspringing](docs/CODE_RULES.md#inspringing), [Spatie na komma’s](docs/CODE_RULES.md#spatie-na-kommas), [Meerregelige lijsten met een komma afsluiten](docs/CODE_RULES.md#meerregelige-lijsten-met-een-komma-afsluiten), [Inhoud direct na een openingsaccolade beginnen](docs/CODE_RULES.md#inhoud-direct-na-een-openingsaccolade-beginnen) | Per meldingsvariant: [Inspringing](docs/CODE_RULES.md#inspringing), [Spatie na komma’s](docs/CODE_RULES.md#spatie-na-kommas), [Meerregelige lijsten met een komma afsluiten](docs/CODE_RULES.md#meerregelige-lijsten-met-een-komma-afsluiten), [Inhoud direct na een openingsaccolade beginnen](docs/CODE_RULES.md#inhoud-direct-na-een-openingsaccolade-beginnen) | [Inspringing](docs/CODE_RULES.md#inspringing), [Spatie na komma’s](docs/CODE_RULES.md#spatie-na-kommas), [Meerregelige lijsten met een komma afsluiten](docs/CODE_RULES.md#meerregelige-lijsten-met-een-komma-afsluiten), [Inhoud direct na een openingsaccolade beginnen](docs/CODE_RULES.md#inhoud-direct-na-een-openingsaccolade-beginnen) |
| `project_comment_spacing` | Ja | Ja | [Toelichtingsblokken van eerdere code scheiden](docs/DOCUMENTATION_RULES.md#toelichtingsblokken-van-eerdere-code-scheiden) | Per meldingsvariant: [Toelichtingsblokken van eerdere code scheiden](docs/DOCUMENTATION_RULES.md#toelichtingsblokken-van-eerdere-code-scheiden) | [Toelichtingsblokken van eerdere code scheiden](docs/DOCUMENTATION_RULES.md#toelichtingsblokken-van-eerdere-code-scheiden) |
| `project_resource_sections` | Ja | Ja | [Een resource na een afgesloten blok toelichten](docs/DOCUMENTATION_RULES.md#een-resource-na-een-afgesloten-blok-toelichten) | Geen: Ontbrekende uitleg vergt kennis van het resourcegedrag | [Een resource na een afgesloten blok toelichten](docs/DOCUMENTATION_RULES.md#een-resource-na-een-afgesloten-blok-toelichten) |
| `project_resource_references` | Ja | Ja | [References van hetzelfde type samenvoegen](docs/CODE_RULES.md#references-van-hetzelfde-type-samenvoegen), [Titels in resource references sorteren](docs/CODE_RULES.md#titels-in-resource-references-sorteren), [Een overbodige buitenste dependency-array verwijderen](docs/CODE_RULES.md#een-overbodige-buitenste-dependency-array-verwijderen) | Per meldingsvariant: [References van hetzelfde type samenvoegen](docs/CODE_RULES.md#references-van-hetzelfde-type-samenvoegen), [Titels in resource references sorteren](docs/CODE_RULES.md#titels-in-resource-references-sorteren), [Een overbodige buitenste dependency-array verwijderen](docs/CODE_RULES.md#een-overbodige-buitenste-dependency-array-verwijderen) | [References van hetzelfde type samenvoegen](docs/CODE_RULES.md#references-van-hetzelfde-type-samenvoegen), [Titels in resource references sorteren](docs/CODE_RULES.md#titels-in-resource-references-sorteren), [Een overbodige buitenste dependency-array verwijderen](docs/CODE_RULES.md#een-overbodige-buitenste-dependency-array-verwijderen) |
| `project_if_sections` | Ja | Ja | [Voorwaarden toelichten](docs/DOCUMENTATION_RULES.md#voorwaarden-toelichten) | Geen: De betekenis en juiste reikwijdte van de toelichting zijn niet afleidbaar | [Voorwaarden toelichten](docs/DOCUMENTATION_RULES.md#voorwaarden-toelichten) |
| `project_variable_sections` | Ja | Ja | [Een variabelegroep bij blokbegin toelichten](docs/DOCUMENTATION_RULES.md#een-variabelegroep-bij-blokbegin-toelichten), [Een onafhankelijke groep na afhankelijke waarden beginnen](docs/DOCUMENTATION_RULES.md#een-onafhankelijke-groep-na-afhankelijke-waarden-beginnen) | Geen: Een zinvolle verklaring van de groep ontbreekt | [Een variabelegroep bij blokbegin toelichten](docs/DOCUMENTATION_RULES.md#een-variabelegroep-bij-blokbegin-toelichten), [Een onafhankelijke groep na afhankelijke waarden beginnen](docs/DOCUMENTATION_RULES.md#een-onafhankelijke-groep-na-afhankelijke-waarden-beginnen) |
| `project_class_check_reuse` | Ja | Ja | [Classcontroles hergebruiken](docs/CODE_RULES.md#classcontroles-hergebruiken) | Geen: Evaluatietijdstip en indirecte afnemers zijn niet volledig bewezen | [Classcontroles hergebruiken](docs/CODE_RULES.md#classcontroles-hergebruiken) |
| `project_exec_packages` | Ja | Ja | [Packageafhankelijkheden bij externe commando’s](docs/CODE_RULES.md#packageafhankelijkheden-bij-externe-commandos) | Geen: Pakketkeuze, beschikbaarheid en benodigde catalogusrelaties vragen bewijs | [Packageafhankelijkheden bij externe commando’s](docs/CODE_RULES.md#packageafhankelijkheden-bij-externe-commandos) |
| `project_packages` | Ja | Ja | [APT-opties expliciet afsluiten](docs/OPERATIONAL_RULES.md#apt-opties-expliciet-afsluiten) | Geen: APT-opties veranderen de geïnstalleerde pakketten en kunnen een geteste uitzondering vereisen | [APT-opties expliciet afsluiten](docs/OPERATIONAL_RULES.md#apt-opties-expliciet-afsluiten) |
| `project_guarded_packages` | Ja | Ja | [Gelijk ingestelde packageguards samenvoegen](docs/OPERATIONAL_RULES.md#gelijk-ingestelde-packageguards-samenvoegen) | Per meldingsvariant: [Gelijk ingestelde packageguards samenvoegen](docs/OPERATIONAL_RULES.md#gelijk-ingestelde-packageguards-samenvoegen) | [Gelijk ingestelde packageguards samenvoegen](docs/OPERATIONAL_RULES.md#gelijk-ingestelde-packageguards-samenvoegen) |
| `project_resource_list_reuse` | Ja | Ja | [Resourcelijsten hergebruiken](docs/CODE_RULES.md#resourcelijsten-hergebruiken) | Per meldingsvariant: [Resourcelijsten hergebruiken](docs/CODE_RULES.md#resourcelijsten-hergebruiken) | [Resourcelijsten hergebruiken](docs/CODE_RULES.md#resourcelijsten-hergebruiken) |
| `project_resource_dependencies` | Ja | Ja | [Resource-dependencies opbouwen](docs/CODE_RULES.md#resource-dependencies-opbouwen) | Per meldingsvariant: [Resource-dependencies opbouwen](docs/CODE_RULES.md#resource-dependencies-opbouwen) | [Resource-dependencies opbouwen](docs/CODE_RULES.md#resource-dependencies-opbouwen) |
| `project_files` | Ja | Ja | [Optionele resource-attributen vooraf bepalen](docs/CODE_RULES.md#optionele-resource-attributen-vooraf-bepalen), [Eigenaars en rechten](docs/OPERATIONAL_RULES.md#eigenaars-en-rechten) | Geen: Eigenaar, rechten en bronkeuze bepalen runtimegedrag | [Optionele resource-attributen vooraf bepalen](docs/CODE_RULES.md#optionele-resource-attributen-vooraf-bepalen), [Eigenaars en rechten](docs/OPERATIONAL_RULES.md#eigenaars-en-rechten) |
| `project_puppet_urls` | Ja | Ja | [Puppet-fileservermounts expliciet kiezen](docs/OPERATIONAL_RULES.md#puppet-fileservermounts-expliciet-kiezen) | Geen: De juiste fileservermount is niet afleidbaar | [Puppet-fileservermounts expliciet kiezen](docs/OPERATIONAL_RULES.md#puppet-fileservermounts-expliciet-kiezen) |
| `project_arrays` | Ja | Ja | [Arrays met concat combineren](docs/CODE_RULES.md#arrays-met-concat-combineren) | Voorwaardelijk: bewezen arrayoperanden op één regel; onbekende typen en meerregelige expressies blijven ter review: [Arrays met concat combineren](docs/CODE_RULES.md#arrays-met-concat-combineren) | [Arrays met concat combineren](docs/CODE_RULES.md#arrays-met-concat-combineren) |
| `project_templates` | Ja | Ja | [Gegenereerde configuratie met ERB renderen](docs/OPERATIONAL_RULES.md#gegenereerde-configuratie-met-erb-renderen) | Geen: ERB/EPP-conversie vereist kennis van template-inhoud en scope | [Gegenereerde configuratie met ERB renderen](docs/OPERATIONAL_RULES.md#gegenereerde-configuratie-met-erb-renderen) |
| `project_shared_conditions` | Ja | Ja | [Gedeelde voorwaarden om resources groeperen](docs/CODE_RULES.md#gedeelde-voorwaarden-om-resources-groeperen) | Geen: Samenvoegen verandert scopes, fallbackgedrag en evaluatievolgorde | [Gedeelde voorwaarden om resources groeperen](docs/CODE_RULES.md#gedeelde-voorwaarden-om-resources-groeperen) |
| `project_positive_flow` | Ja | Ja | [De grootste verwerking vóór de korte afhandeling plaatsen](docs/CODE_RULES.md#de-grootste-verwerking-vóór-de-korte-afhandeling-plaatsen), [Validatie om haar afhankelijke implementatie plaatsen](docs/CODE_RULES.md#validatie-om-haar-afhankelijke-implementatie-plaatsen) | Geen: Takken verplaatsen kan conditionele captures, scopes en elsif-prioriteit veranderen | [De grootste verwerking vóór de korte afhandeling plaatsen](docs/CODE_RULES.md#de-grootste-verwerking-vóór-de-korte-afhandeling-plaatsen), [Validatie om haar afhankelijke implementatie plaatsen](docs/CODE_RULES.md#validatie-om-haar-afhankelijke-implementatie-plaatsen) |
| `project_shell` | Ja | Ja | [Shellcommando's in Puppet](docs/OPERATIONAL_RULES.md#shellcommandos-in-puppet) | Geen: De grens tussen shellsyntax en dynamische argumenten is niet eenduidig | [Shellcommando's in Puppet](docs/OPERATIONAL_RULES.md#shellcommandos-in-puppet) |
| `project_interface_calls` | Ja | Ja | [Alle verplichte argumenten doorgeven](docs/CODE_RULES.md#alle-verplichte-argumenten-doorgeven) | Geen: De bedoelde argumentwaarde ontbreekt | [Alle verplichte argumenten doorgeven](docs/CODE_RULES.md#alle-verplichte-argumenten-doorgeven) |
| `project_parameter_passthrough` | Ja | Ja | [Overbodige parameterdoorgifte rechtstreeks schrijven](docs/CODE_RULES.md#overbodige-parameterdoorgifte-rechtstreeks-schrijven) | Per meldingsvariant: inline identiteitshash; filters, gedeelde hashes en conflicten blijven ter review: [Overbodige parameterdoorgifte rechtstreeks schrijven](docs/CODE_RULES.md#overbodige-parameterdoorgifte-rechtstreeks-schrijven) | [Overbodige parameterdoorgifte rechtstreeks schrijven](docs/CODE_RULES.md#overbodige-parameterdoorgifte-rechtstreeks-schrijven) |
| `project_monitoring_backend` | Ja | Ja | [Targets en monitoring](docs/OPERATIONAL_RULES.md#targets-en-monitoring) | Geen: Backendkeuze kan functioneel gedrag bevatten | [Targets en monitoring](docs/OPERATIONAL_RULES.md#targets-en-monitoring) |
| `project_suppressions` | Ja | Ja | [Alleen toegestane suppressions gebruiken](docs/CODE_RULES.md#alleen-toegestane-suppressions-gebruiken) | Geen: Verwijderen kan andere fixes vrijgeven voordat hun gevolgen zijn beoordeeld | [Alleen toegestane suppressions gebruiken](docs/CODE_RULES.md#alleen-toegestane-suppressions-gebruiken) |
<!-- END PROJECT CHECK REGISTRY -->

`require 'project_lint'` registreert de checks; de configuratieprofielen bepalen afzonderlijk hun activatie. `--list-checks` toont alleen beschikbaarheid. Controleer bij wijzigingen aan de bundle of registratie dit overzicht tegen het entrypoint, beide profielen en de [configuratietests](tests/cli_configuration_test.rb). De [rootlockfile](../../Gemfile.lock) beheert de gebruikte gemversies. Leg uitvoeringsresultaten vast in de wijzigingsreview.

### Native checks in deze bundle

| Check | Bron | Actief in repositoryprofiel | Actief in gedeeld profiel | Autofix en handmatige gevallen |
| --- | --- | --- | --- | --- |
| `arrow_on_right_operand_line` | [puppet-lint](https://github.com/puppetlabs/puppet-lint) | Ja | Ja | Native beschikbaar; bron- en tokenvoorwaarden van de gebundelde check blijven gelden |
| `autoloader_layout` | [puppet-lint](https://github.com/puppetlabs/puppet-lint) | Ja | Ja | Geen: Bestandsverplaatsing raakt imports en module-indeling |
| `class_inherits_from_params_class` | [puppet-lint](https://github.com/puppetlabs/puppet-lint) | Ja | Ja | Geen: Een ander defaultmodel vereist interfacekeuzes |
| `code_on_top_scope` | [puppet-lint](https://github.com/puppetlabs/puppet-lint) | Nee | Nee | Geen: Uitgeschakeld; verplaatsen verandert de scope |
| `inherits_across_namespaces` | [puppet-lint](https://github.com/puppetlabs/puppet-lint) | Ja | Ja | Geen: Overerving bepaalt defaults en gedrag |
| `names_containing_dash` | [puppet-lint](https://github.com/puppetlabs/puppet-lint) | Ja | Ja | Geen: Hernoemen raakt publieke afnemers |
| `names_containing_uppercase` | [puppet-lint](https://github.com/puppetlabs/puppet-lint) | Ja | Ja | Native beschikbaar; bron- en tokenvoorwaarden van de gebundelde check blijven gelden |
| `nested_classes_or_defines` | [puppet-lint](https://github.com/puppetlabs/puppet-lint) | Ja | Ja | Geen: Verplaatsen verandert scope en vindbaarheid |
| `parameter_order` | [puppet-lint](https://github.com/puppetlabs/puppet-lint) | Ja | Ja | Via project_parameter_order voor onafhankelijke parameters; overige defaults vragen evaluatiereview |
| `right_to_left_relationship` | [puppet-lint](https://github.com/puppetlabs/puppet-lint) | Ja | Ja | Toegevoegd aan native check: twee letterlijke references op één regel; ketens, declaraties en dynamische titels blijven handmatig |
| `variable_scope` | [puppet-lint](https://github.com/puppetlabs/puppet-lint) | Ja | Ja | Geen: De bedoelde lokale of topscopevariabele is onbekend |
| `slash_comments` | [puppet-lint](https://github.com/puppetlabs/puppet-lint) | Ja | Ja | Native beschikbaar; bron- en tokenvoorwaarden van de gebundelde check blijven gelden |
| `star_comments` | [puppet-lint](https://github.com/puppetlabs/puppet-lint) | Ja | Ja | Native beschikbaar; bron- en tokenvoorwaarden van de gebundelde check blijven gelden |
| `case_without_default` | [puppet-lint](https://github.com/puppetlabs/puppet-lint) | Ja | Ja | Geen: De juiste fallback is onbekend |
| `selector_inside_resource` | [puppet-lint](https://github.com/puppetlabs/puppet-lint) | Ja | Ja | Geen: Variabelenaam en veilige evaluatieplaats vereisen review |
| `documentation` | [puppet-lint](https://github.com/puppetlabs/puppet-lint) | Ja | Ja | Geen: De ontbrekende omschrijving is inhoudelijk |
| `unquoted_node_name` | [puppet-lint](https://github.com/puppetlabs/puppet-lint) | Ja | Ja | Native beschikbaar; bron- en tokenvoorwaarden van de gebundelde check blijven gelden |
| `duplicate_params` | [puppet-lint](https://github.com/puppetlabs/puppet-lint) | Ja | Ja | Geen: Welke waarde bedoeld is, is onbekend |
| `ensure_first_param` | [puppet-lint](https://github.com/puppetlabs/puppet-lint) | Ja | Ja | Native: alleen herkenbare attribuutgrenzen; anders handmatig |
| `ensure_not_symlink_target` | [puppet-lint](https://github.com/puppetlabs/puppet-lint) | Ja | Ja | Native beschikbaar; bron- en tokenvoorwaarden van de gebundelde check blijven gelden |
| `file_mode` | [puppet-lint](https://github.com/puppetlabs/puppet-lint) | Ja | Ja | Native: alleen drie octale cijfers; overige modes vragen een rechtenkeuze |
| `unquoted_file_mode` | [puppet-lint](https://github.com/puppetlabs/puppet-lint) | Ja | Ja | Native beschikbaar; bron- en tokenvoorwaarden van de gebundelde check blijven gelden |
| `unquoted_resource_title` | [puppet-lint](https://github.com/puppetlabs/puppet-lint) | Ja | Ja | Native beschikbaar; bron- en tokenvoorwaarden van de gebundelde check blijven gelden |
| `double_quoted_strings` | [puppet-lint](https://github.com/puppetlabs/puppet-lint) | Ja | Ja | Native beschikbaar; bron- en tokenvoorwaarden van de gebundelde check blijven gelden |
| `only_variable_string` | [puppet-lint](https://github.com/puppetlabs/puppet-lint) | Ja | Ja | Native beschikbaar; bron- en tokenvoorwaarden van de gebundelde check blijven gelden |
| `puppet_url_without_modules` | [puppet-lint](https://github.com/puppetlabs/puppet-lint) | Ja | Ja | Geen: Project weigert de upstream-fix: een mount mag niet worden geraden |
| `quoted_booleans` | [puppet-lint](https://github.com/puppetlabs/puppet-lint) | Nee | Nee | Geen: Uitgeschakeld; conversie kan het waardetype veranderen |
| `single_quote_string_with_variables` | [puppet-lint](https://github.com/puppetlabs/puppet-lint) | Ja | Ja | Geen: Letterlijke tekst of interpolatie is een inhoudelijke keuze |
| `variables_not_enclosed` | [puppet-lint](https://github.com/puppetlabs/puppet-lint) | Ja | Ja | Native beschikbaar; bron- en tokenvoorwaarden van de gebundelde check blijven gelden |
| `variable_contains_dash` | [puppet-lint](https://github.com/puppetlabs/puppet-lint) | Ja | Ja | Geen: Hernoemen vereist alle afnemers |
| `variable_is_lowercase` | [puppet-lint](https://github.com/puppetlabs/puppet-lint) | Ja | Ja | Geen: Hernoemen vereist alle afnemers |
| `140chars` | [puppet-lint](https://github.com/puppetlabs/puppet-lint) | Ja | Ja | Geen: Vrije code opdelen vereist syntax- en commentcontext |
| `2sp_soft_tabs` | [puppet-lint](https://github.com/puppetlabs/puppet-lint) | Ja | Ja | Via project_layout voor bewezen arrayinspringing; overige blokniveaus niet afleidbaar uit pariteit |
| `80chars` | [puppet-lint](https://github.com/puppetlabs/puppet-lint) | Nee | Nee | Geen: Uitgeschakeld; projectbreedte is 140 |
| `arrow_alignment` | [puppet-lint](https://github.com/puppetlabs/puppet-lint) | Ja | Ja | Native: weigert negatieve witruimte |
| `hard_tabs` | [puppet-lint](https://github.com/puppetlabs/puppet-lint) | Ja | Ja | Native beschikbaar; bron- en tokenvoorwaarden van de gebundelde check blijven gelden |
| `space_before_arrow` | [puppet-lint](https://github.com/puppetlabs/puppet-lint) | Ja | Ja | Native, aangevuld voor ontbrekende witruimte vóór de pijl; comments worden niet verplaatst |
| `trailing_whitespace` | [puppet-lint](https://github.com/puppetlabs/puppet-lint) | Ja | Ja | Native beschikbaar; bron- en tokenvoorwaarden van de gebundelde check blijven gelden |
| `legacy_facts` | [puppet-lint](https://github.com/puppetlabs/puppet-lint) | Ja | Ja | Voorwaardelijk: native mapping in manifests; niet-omzetbare facts behouden hun hashkey en melding. YAML mist schrijfbare brontokens en blijft detectie |
| `top_scope_facts` | [puppet-lint](https://github.com/puppetlabs/puppet-lint) | Ja | Ja | Native beschikbaar; bron- en tokenvoorwaarden van de gebundelde check blijven gelden |

### Pluginchecks in deze bundle

| Check | Bron | Actief in repositoryprofiel | Actief in gedeeld profiel | Autofix en handmatige gevallen |
| --- | --- | --- | --- | --- |
| `parameter_types` | [puppet-lint-param-types](https://github.com/voxpupuli/puppet-lint-param-types) | Ja | Ja | Geen: Het bedoelde typecontract is niet afleidbaar |
| `trailing_comma` | [puppet-lint-trailing_comma-check](https://github.com/voxpupuli/puppet-lint-trailing_comma-check) | Ja | Ja | Native beschikbaar; bron- en tokenvoorwaarden van de gebundelde check blijven gelden |

De checks voor opmaak bewijzen niet dat commentaar inhoudelijk klopt. Voor systemd-hardening, transportbeveiliging, shellgedrag, monitoringdefaults, uitvoertijd en gedeelde checkexecutables bestaat hier geen volledige automatische lintcontrole. De inhoudelijke criteria staan in de gekoppelde regels; de [projectbrede validatieverplichtingen](../../AGENTS.md#validation-and-testing) blijven daarnaast gelden.


De [native CLI-proeven](tests/native_autofix_test.rb) voeren de beschikbare standaard- en pluginfixes uit, inclusief hercontrole en een ongewijzigde tweede run. De [aanvullende CLI-proeven](tests/cli_safe_fixes_test.rb) bewaken nieuwe projectfixes en de native reference-richting; [cli_diagnostics_test.rb](tests/cli_diagnostics_test.rb) controleert behoud van fileservermounts. De bestaande checkspecifieke CLI-tests blijven de grenzen, interacties en suppressions controleren. De YAML-route van Puppet-lint ondersteunt detectie van legacy facts maar schrijft geen fixes: de parser levert waarden zonder eenduidige schrijfposities voor onder meer aliases en meerregelige scalars. De fixaanroep behoudt deze meldingen zonder een Puppet-tokenstream te renderen; de facts-conversie in deze tabel geldt voor manifests.


### Automatische dekking en handmatige review

Bepaal de dekking per norm en per meldingsvariant aan de hand van haar velden `Automatische controle`, `Detectiegrenzen`, `Autofix` en `Verificatie`. Detectie en correctie zijn afzonderlijke eigenschappen:

| Status | Betekenis voor de beoordeling |
| --- | --- |
| Volledig geautomatiseerd binnen het beschreven bereik | De check detecteert de beschreven gevallen; controleer de grenzen en het uitgevoerde bewijs voordat je volledige dekking claimt. |
| Gedeeltelijk geautomatiseerd | Een check beoordeelt slechts een deel van de norm; de overige gevallen vragen handmatige review. |
| Alleen detectie | Een melding is beschikbaar, maar er is geen veilige automatische correctie voor deze variant. |
| Autofix beschikbaar | Alleen de gedocumenteerde varianten en voorwaarden mogen automatisch worden gecorrigeerd; hercontrole blijft nodig. |
| Geen automatische controle | De norm vereist handmatige review en waar toepasselijk afzonderlijke functionele validatie. |

Het ontbreken van een check, gedeeltelijke detectie of het ontbreken van veilige autofix verandert de eigenaar of verplichting van de norm niet. Zo controleren `project_files` en `project_shell` bepaalde Puppet-attributen en escaping, maar geen beheerheaders, algemene shellstijl of gedeelde executablelevenscyclus. De regels vermelden die beperkingen bij het betreffende contract. Signaleer een betrouwbare mogelijkheid voor detectie of veilige correctie als lintverbetering; een documentatieverplaatsing geeft geen opdracht om die verbetering te implementeren.

## Puppet-coderegels en reviewcriteria

De volledige Puppet-coderegels en reviewcriteria staan in [CODE_RULES.md](docs/CODE_RULES.md), [DOCUMENTATION_RULES.md](docs/DOCUMENTATION_RULES.md) en [OPERATIONAL_RULES.md](docs/OPERATIONAL_RULES.md). De drie bestanden beschrijven per regel de norm, detectiegrenzen, autofixvoorwaarden, uitzonderingen, voorbeelden en handmatige review. Iedere regel heeft één autoritatieve locatie.

Volg bij iedere Puppet-wijziging de toepasselijke algemene regels:

- [Basisopmaak](docs/CODE_RULES.md#basisopmaak), inclusief inspringing, komma's en lange regels.
- [Parameters en resources](docs/CODE_RULES.md#parameters-en-resources).

Raakt de wijziging commentaar, Puppet Strings of documentatie van Puppet-interfaces, volg dan daarnaast de regels voor [Commentaar en documentatie](docs/DOCUMENTATION_RULES.md#commentaar-en-documentatie), inclusief [Puppet Strings](docs/DOCUMENTATION_RULES.md#puppet-strings).

Raakt de wijziging operationele onderdelen, volg dan daarnaast de relevante regels uit deze groepen:

- [Bestanden en beveiliging](docs/OPERATIONAL_RULES.md#bestanden-en-beveiliging).
- [Gedeelde services en systemd](docs/OPERATIONAL_RULES.md#gedeelde-services-en-systemd).
- [Shellscripts](docs/OPERATIONAL_RULES.md#shellscripts).
- [Monitoringchecks](docs/OPERATIONAL_RULES.md#monitoringchecks).

Bij een wijziging aan zowel operationele code als de documentatie daarvan gelden beide aanvullende documenten, zoals uitgewerkt in de [leeswijzer](#leeswijzer). Voor een concrete lintmelding vind je de bijbehorende regel via het [checkregister](#checkregister). De algemene werkwijze voor automatische correcties en suppressions volgt hieronder.

## Autofix en suppressions

Een autofix corrigeert een vastgestelde afwijking; een suppression onderdrukt een melding. Beoordeel eerst de norm en de correctievoorwaarden bij de betrokken regel. De [suppressieregel](docs/CODE_RULES.md#alleen-toegestane-suppressions-gebruiken) beschrijft welke markeringen zijn toegestaan en hoe je ze begrenst. Hieronder staat hoe je een toegestane automatische correctie uitvoert en controleert.

### Automatisch corrigeren (autofix)

Met `--fix` schrijft Puppet-lint ondersteunde correcties rechtstreeks naar de geselecteerde bestanden. Begin met een gewone scan en beoordeel de [voorwaarden van de betrokken checks](#beschikbare-projectchecks) voordat je de correctie uitvoert.

Kies de bestanden die bij je wijziging horen. De eerste aanroep hieronder corrigeert de volledige projectscope en is alleen geschikt wanneer die hele scope is bedoeld. De tweede beperkt de correctie tot één manifest; de derde selecteert daarnaast één check:

**Werkmap:** Repositoryroot. **Shell:** POSIX shell. **Vereisten:** Ontwikkelbundle. **Invoer:** Gehele projectscope, uitsluitend wanneer die volledige scope is geautoriseerd. **Wijzigt bestanden:** Geselecteerde manifests. **Verwacht resultaat:** Ondersteunde correcties; resterende warnings/errors blijven falen.

```sh
bundle exec puppet-lint --no-config --config .puppet-lint.rc --fix .
```

**Werkmap:** Repositoryroot. **Shell:** POSIX shell. **Vereisten:** Ontwikkelbundle. **Invoer:** Alleen examples/site.pp. **Wijzigt bestanden:** Geselecteerde manifests. **Verwacht resultaat:** Ondersteunde correcties; resterende warnings/errors blijven falen.

```sh
bundle exec puppet-lint --no-config --config .puppet-lint.rc --fix examples/site.pp
```

**Werkmap:** Repositoryroot. **Shell:** POSIX shell. **Vereisten:** Ontwikkelbundle. **Invoer:** Alleen examples/site.pp en project_resource_references. **Wijzigt bestanden:** Geselecteerde manifests. **Verwacht resultaat:** Ondersteunde correcties; resterende warnings/errors blijven falen.

```sh
bundle exec puppet-lint --no-config --config .puppet-lint.rc --fix --only-checks project_resource_references examples/site.pp
```

Zonder `--only-checks` worden de beschikbare fixes van zowel standaardchecks als projectchecks gebruikt. Een check kan een melding laten staan wanneer de code niet veilig te herschrijven is. De concrete grenzen staan bij [inspringing](docs/CODE_RULES.md#inspringing), [komma's](docs/CODE_RULES.md#kommas), [parameteruitlijning](docs/CODE_RULES.md#parameters-en-instellingen), [commentaarscheiding](docs/DOCUMENTATION_RULES.md#toelichtingen-bij-code), [resource references](docs/CODE_RULES.md#resource-references), [packagegroepen](docs/OPERATIONAL_RULES.md#pakketten-en-mappen) en [Puppet Strings](docs/DOCUMENTATION_RULES.md#puppet-strings).

Geslaagde correcties verschijnen als `fixed`. Een resterende waarschuwing of fout geeft nog steeds een foutcode. Scan daarna zonder `--fix` opnieuw: Puppet-lint verzamelt alle meldingen vóór het corrigeren, waardoor bijvoorbeeld een lengtemelding nog over de oorspronkelijke regel kan gaan.

Bij een syntaxfout schrijft de CLI het manifest niet weg. Genegeerde meldingen worden evenmin gecorrigeerd. Bekijk na de correctieronde de volledige diff en volg de [verdere afronding](#werkwijze-bij-een-wijziging). De gewone projectaanroep en CI controleren alleen; voor correctie gebruik je expliciet `--fix`. Er is geen aparte Rake-task of formatter voor nodig.

## Parservalidatie en Ruby-controles

### Ruby-code controleren

Gebruik de [Ruby-linthandleiding](../ruby-lint/README.md#ruby-code-controleren) voor deze zelfstandige tool.

### Puppet-manifests valideren

De zelfstandige gem `project-tools-validate` beheert deze controle. Volg de [validatorhandleiding](../validate/README.md#puppet-manifests-valideren) voor de aanroep, selectie en rapportage.

### Aanvullende validatie

Voer [metadata- en schemacontrole](../metadata/README.md) afzonderlijk uit.

Puppet-voorbeelden in Strings en Markdown worden niet door de gewone lintscan gevonden. Werk ze tijdelijk buiten de repository uit tot uitvoerbare invoer en controleer die met de projectlintregels en de parser. Render gewijzigde templates voordat je het resulterende formaat tegen de [operationele bestands- en shellregels](docs/OPERATIONAL_RULES.md) beoordeelt.

Bij gedragswijzigingen onderzoek je wat er op de host verandert: welke bestanden worden geschreven, welke services herstarten en welke rechten of verbindingen daarvoor nodig zijn. Controleer normaal gebruik en een praktisch foutgeval met synthetische invoer. Neem bij een gedeelde bouwsteen alle geraakte gebruikers mee. Voor monitoring gelden de [bijbehorende scenario's](../../AGENTS.md#monitoring-validation); voor dependencies de [prerequisitereview](docs/CODE_RULES.md#resources-en-afhankelijkheden).

Deze functionele controles blijven volgens de [testafspraken](../../AGENTS.md#test-scope) buiten de repositorytests. Leg de uitgevoerde commando's, resultaten en resterende onzekerheid vast in de review.

### Eigen manifests valideren

De zelfstandige gem `project-tools-validate` beheert deze controle. Volg de [validatorhandleiding](../validate/README.md#eigen-manifests-valideren) voor de aanroep, selectie en rapportage.

### Ruby controleren in een ander project

Gebruik de [Ruby-linthandleiding](../ruby-lint/README.md#ruby-controleren-in-een-ander-project) voor deze zelfstandige tool.

### Aanvullende tests

Voer naast linting en de [parservalidatie](#eigen-manifests-valideren) de gedragstests van je eigen project uit, met de Puppet- of OpenVox-versie, facts en Hiera die je daarvoor gebruikt. De ontwikkelbundle van de moduleverzameling is geen vereiste.

De gemtests controleren het lintgereedschap. Ze vervangen geen catalogus-, template-, script- of monitoringvalidatie van afnemende projecten.

## Rapportage en CI

### Lintrapporten maken

Het Puppet-lintrapport gebruikt JUnit XML onder `.tools/lint/results/`. Andere tools en gezamenlijke testresultaten hebben hun eigen [locaties](../README.md#ci-van-deze-repository). De gegenereerde rapportmappen zijn uitgesloten van versiebeheer. Afnemende projecten kiezen hun [eigen rapportmap](#rapportmap-kiezen). De onderstaande aanroepen gebruiken dezelfde configuratie, bestandsselectie en foutstatus als de gewone scans. Voer ze afzonderlijk uit vanuit de repositoryroot, met de [ontwikkelbundle](#gems-installeren) geïnstalleerd.

Puppet-lint levert zijn native JSON-uitvoer via een pipe aan `puppet-lint-junit`, de rapportomzetter uit `lint-project`. Die schrijft JUnit XML en toont actieve en gecorrigeerde meldingen met bronpositie in de console. De converter sorteert op pad, regel, kolom en check; de telling `Files reported` komt uit de native JSON-groepen en is geen JUnit-testcasetelling. Fouten, waarschuwingen, fixes en genegeerde bevindingen hebben afzonderlijke tellingen. De aanroep blijft eigenaar van start, activiteit en de uiteindelijke scanstatus volgens het [centrale logcontract](../README.md#joblogs); de converter kan uit JSON geen waarschuwingdrempel of oorspronkelijke processtatus reconstrueren. Ook bij een onschrijfbaar rapport blijven beschikbare lintbevindingen zichtbaar. Gebruik Bash met `pipefail`:

**Werkmap:** Repositoryroot. **Shell:** Bash met pipefail. **Vereisten:** Ontwikkelbundle. **Invoer:** Volledige lintselectie. **Wijzigt bestanden:** Puppet-lint-JUnit in .tools/lint/results. **Verwacht resultaat:** Lint- én conversiestatus behouden.

```bash
set -o pipefail
mkdir -p .tools/lint/results
bundle exec puppet-lint --no-config --config .puppet-lint.rc --json . | bundle exec puppet-lint-junit .tools/lint/results/puppet-lint-report.xml
```

`pipefail` bewaart de foutstatus van Puppet-lint en laat ook een mislukte omzetting falen. De omzetter controleert geen Puppet-code en voert de linter niet opnieuw uit. De JSON-invoer blijft intern in de pipe; het opgeslagen artifact bevat XML. Gebruik het gedeelde profiel met `--fail-on-warnings`, zodat actieve waarschuwingen zowel de job als het rapport laten falen.

Het Puppet-rapport groepeert actieve meldingen per bestand en check in één JUnit-testcase. De fouttekst bevat alle bijbehorende regels, kolommen en meldingen. Genegeerde en gecorrigeerde meldingen tellen niet als fout. Een scan zonder actieve bevindingen krijgt één geslaagde testcase voor de gehele scan; dat is geen telling van gecontroleerde manifests of functionele tests. Ontbrekende of ongeldige JSON-invoer en een scan zonder gerapporteerde bestanden leveren een rapport met `ReportError` en een foutcode op. Het opgegeven rapportbestand wordt bij iedere uitvoering vervangen; een eventuele bovenliggende map moet bestaan.

Voor Ruby-rapporten gebruik je de [native RuboCop-aanroep](../README.md#rapporten-en-artifacts-in-je-project). De [parservalidatie](../validate/README.md) en [tooltests](../README.md#gezamenlijke-tooltests) houden hun eigen rapporten.

### Rapportmap kiezen

Zie de [gezamenlijke toolinghandleiding](../README.md#rapportmap-kiezen) voor deze procedure.

### CI van deze repository

Zie de [gezamenlijke toolinghandleiding](../README.md#ci-van-deze-repository) voor deze procedure.

### Rapporten en artifacts in je project

Zie de [gezamenlijke toolinghandleiding](../README.md#rapporten-en-artifacts-in-je-project) voor deze procedure.

### Controle in CI

Zie de [gezamenlijke toolinghandleiding](../README.md#controle-in-ci) voor deze procedure.

#### Rapporten tonen in GitLab

Zie de [gezamenlijke toolinghandleiding](../README.md#rapporten-tonen-in-gitlab) voor deze procedure.

## Importeren en distribueren

<a id="de-linter-gebruiken-in-een-ander-puppet-project"></a>

Zie de [gezamenlijke toolinghandleiding](../README.md#importeren-en-distribueren) voor deze procedure.

### Gedeelde tooling hergebruiken

Zie de [gezamenlijke toolinghandleiding](../README.md#gedeelde-tooling-hergebruiken) voor deze procedure.

### Benodigdheden

Zie de [gezamenlijke toolinghandleiding](../README.md#benodigdheden) voor deze procedure.

### Aanbevolen projectstructuur

Zie de [gezamenlijke toolinghandleiding](../README.md#aanbevolen-projectstructuur) voor deze procedure.

### Installatie in je project

Zie de [gezamenlijke toolinghandleiding](../README.md#installatie-in-je-project) voor deze procedure.

### Eigen code controleren

Het voorbeeld hieronder controleert twee concrete manifests. Stel het modulepad in voor het opzoeken van declaraties; [metadata](../metadata/README.md) heeft een eigen commando.

**Werkmap:** Consumerroot. **Shell:** POSIX shell met errexit. **Vereisten:** Eigen bundle, lokale configuratie en bestaande genoemde manifests/modulemappen. **Invoer:** De twee expliciet genoemde bestanden. **Wijzigt bestanden:** Geen bronbestanden. **Verwacht resultaat:** Volledige profielcontrole van deze selectie.

```sh
set -e
lint_gem="$(bundle info --path lint-project)"
export PROJECT_TOOLS_MODULEPATH="$PWD/global-modules:$PWD/modules"
test -f .puppet-lint.rc
bundle exec puppet-lint --no-config --load "$lint_gem/lib/project_lint.rb" --config "$lint_gem/config/puppet-lint.rc" --config .puppet-lint.rc environments/production/manifests/site.pp modules/profile/manifests/init.pp
```

Vervang de modulemappen en manifestpaden door bestaande paden in jouw project. De paden in `PROJECT_TOOLS_MODULEPATH` moeten absoluut zijn en dezelfde volgorde hebben als in de gekozen Puppet environment; het voorbeeld volgt de [module-installatie](../../README.md#installatie), met `global-modules` vóór `modules`. Voeg andere gebruikte modulemappen expliciet toe. Het voorbeeld stopt met `set -e` bij een fout. `test -f` is nodig omdat de native CLI een ontbrekend optiebestand stilzwijgend overslaat. `--no-config` voorkomt dat systeem- of persoonlijke lintopties worden ingelezen. De twee `--config`-opties lezen eerst het gedeelde profiel en vervolgens je eigen bestandsuitsluitingen.

Geef één directory op om die recursief te scannen, of geef één of meer concrete manifestbestanden mee. De native CLI ondersteunt geen combinatie van meerdere directoryscans in één aanroep. Controleer iedere eigen manifestmap wanneer je project meerdere mappen gebruikt en laat CI bij een ontbrekende of lege selectie falen. De keuze van te controleren bestanden is een verantwoordelijkheid van je project; de linter kan niet vaststellen of je alle productiecode hebt geselecteerd.

Plaats aanvullende lintopties na beide `--config`-opties en vóór de manifestpaden. Dezelfde CLI biedt de volgende mogelijkheden:

| Doel | Optie | Gebruik |
| --- | --- | --- |
| Gewone controle | Geen extra optie | Alle actieve regels uit het gedeelde profiel, met je eigen bestandsselectie. |
| Automatisch corrigeren | `--fix` | Alleen lokaal, na beoordeling van de [autofixvoorwaarden](#automatisch-corrigeren-autofix); controleer de diff en scan opnieuw zonder `--fix`. |
| Een check onderzoeken | `--only-checks project_arrays` | Een gerichte selectie tijdens het onderzoeken; de eindcontrole bevat alle gedeelde regels. |
| Onderdrukte meldingen bekijken | `--show-ignored` | Zicht op toegestane lokale suppressions. |
| Een lintrapport maken | `--json` | Native invoer voor de [JUnit-omzetter](#rapporten-en-artifacts-in-je-project), met dezelfde controles en foutstatus. |
| Beschikbare checks bekijken | `--list-checks` | Laat hierbij de manifestpaden weg; de lijst bevat ook uitgeschakelde checks en bewijst geen volledige scan. |

### Een gem bouwen en versie uitbrengen

Het [versienummer en de runtime-afhankelijkheden](lint-project.gemspec) horen bij de gem. Bouw na de volledige validatie een pakket vanuit zijn eigen map:

**Werkmap:** Repositoryroot; cd kiest daarna .tools/lint. **Shell:** POSIX shell. **Vereisten:** Volledige bronvalidatie en RubyGems. **Invoer:** Gemspec en pakketbestanden. **Wijzigt bestanden:** /tmp/lint-project.gem. **Verwacht resultaat:** Lokaal pakket gebouwd.

```sh
cd .tools/lint
gem build lint-project.gemspec --output /tmp/lint-project.gem
```

Het pakket bevat alleen `lib/`, `bin/`, `config/`, `README.md`, `docs/CODE_RULES.md`, `docs/DOCUMENTATION_RULES.md`, `docs/OPERATIONAL_RULES.md` en de licentie, inclusief `puppet-lint-junit` en een expliciete dependency op `project-tools-shared`. De [pakketprocedure](../README.md#gebouwd-gempakket-installeren) bouwt en levert shared afzonderlijk mee. Tests, ontwikkelgems en Puppet-modules zijn geen onderdeel van de distributie. Publicatie naar RubyGems is niet nodig; je kunt het bestand via je eigen goedgekeurde distributieroute beschikbaar maken. Een ontvangend project installeert zijn eigen dependencies en bewaart zijn eigen lockfile.

Volg bij een update de [consumermigratie](../README.md#migreren-naar-afzonderlijke-toolpakketten) voor de afzonderlijke metadata- en Ruby-tools en gewijzigde gedeelde instellingen.

Het [checkoverzicht](#beschikbare-projectchecks) vermeldt de actieve controles en verwijst naar hun detectie- en autofixvoorwaarden. Let bij de [packageguard-fix](docs/OPERATIONAL_RULES.md#gelijk-ingestelde-packageguards-samenvoegen) op de runtimevoorwaarde: de gegenereerde Puppet-code gebruikt `ensure_packages()` uit stdlib; de linter levert die module niet mee. Conflicterende package-attributen blijven als catalogusfout zichtbaar.

Behandel checknamen, meldingsniveaus, veilige fixresultaten, `PROJECT_TOOLS_MODULEPATH`, het entrypoint, de gedeelde configuratiepaden en de rapportcommando's als publieke interfaces. Beoordeel wijzigingen aan deze interfaces volgens het [versie- en releasebeleid](../../AGENTS.md#versioning-and-releases) en valideer het gebouwde pakket vanuit een onafhankelijk project. Houd consumerinstallatie en CI-voorbeelden afgestemd op de [aanbevolen projectstructuur](#aanbevolen-projectstructuur); documenteer ondersteunde afwijkingen zonder implementatie of gedeelde profielen te dupliceren. Verhoog de gemversie bij een uitgave en beschrijf wijzigingen die afnemers raken. Wijzigingen aan actieve regels en profielen kunnen bestaande projecten laten falen; laat afnemers zo’n update bewust uitvoeren met Bundler en hun eigen CI. Werk een Git-afnemer bij naar een gecontroleerde revisie en een pakketafnemer naar een gecontroleerde gemversie.

### Git-dependency uit de monorepo

Zie de [gezamenlijke toolinghandleiding](../README.md#git-dependency-uit-de-monorepo) voor deze procedure.

### Gebouwd gempakket installeren

Zie de [gezamenlijke toolinghandleiding](../README.md#gebouwd-gempakket-installeren) voor deze procedure.

## Linter ontwikkelen en testen

<a id="linter-ontwikkelen-en-onderhouden"></a>

Dit gedeelte is bedoeld voor wijzigingen aan de linter en zijn configuratieroute. Gezamenlijke installatie, distributie en CI staan in de [toolinghandleiding](../README.md). Voor een gewone Puppet-wijziging volstaan de [werkwijze](#werkwijze-bij-een-wijziging) en de relevante codeafspraken.

### Een check toevoegen of wijzigen

Zoek eerst de bestaande codeafspraak en bepaal welk onderdeel automatisch vast te stellen is en welk onderdeel review blijft. Controleer of een standaardcheck, geïnstalleerde plugin of bestaande projectcheck het probleem al afhandelt. Breid die waar mogelijk uit; voeg geen tweede detectie- of correctiepad toe voor hetzelfde contract.

Beoordeel bij iedere nieuwe of gewijzigde lintregel expliciet, per meldingsvariant, of de gevonden afwijking automatisch en betrouwbaar kan worden gecorrigeerd. Dit geldt ook voor bestaande checks zonder autofix. Implementeer een autofix wanneer de beschikbare informatie de juiste correctie eenduidig bepaalt en behoud van gedrag en gegevens kan worden aangetoond. Is slechts een deel veilig herstelbaar, implementeer dan dat deel en laat alleen het niet-eenduidige gedeelte voor handmatige correctie staan.

Voeg geen autofix toe wanneer daarvoor onbewezen aannames of inhoudelijke ontwerpkeuzes nodig zijn die gedrag kunnen veranderen of gegevens kunnen beschadigen. Leg de beoordeling per meldingsvariant vast bij `Autofix` en `Autofixvoorwaarden` van de betrokken regel, volgens het [documentatiecontract](#documentatiecontract-voor-maintainers). Beschrijf bij ontbrekende of gedeeltelijke autofix concreet welke informatie ontbreekt, welke keuze handmatige beoordeling vereist of welke technische beperking betrouwbaar herstel verhindert.

Iedere manifestregel staat in één bestand onder [`lib/project_lint/checks/`](lib/project_lint/checks/). Dat bestand bevat de `PuppetLint.new_check(:project_...)`-registratie, de `check`-methode en een eventuele `fix(problem)`. De bestandsnaam volgt de checknaam zonder het voorvoegsel `project_`; de Ruby-module staat onder `ProjectLint::Checks`. Voeg het bestand met een gewone `require` toe aan [`lib/project_lint.rb`](lib/project_lint.rb).

Meldingen moeten de oorzaak en een bruikbare bronpositie geven; neem geen willekeurige bronwaarden in diagnostiek of JSON op. Gebruik `[review]` als de analyse geen voldoende bewijs voor de gewenste eigenschap of correctie kan leveren.

Werk bij een gewijzigde codeafspraak de relevante regel en het [checkoverzicht](#beschikbare-projectchecks) samen bij. Geef aan wat detectie en autofix daadwerkelijk dekken en wat handmatig blijft. Verander je een algemene conventie, neem dan de regressietests en alle geraakte first-party code in dezelfde wijziging mee. De [documentatie-indeling](../../AGENTS.md#lint-documentation-maintenance) bepaalt waar nieuwe kennis thuishoort.

Voeg tooltests toe die geldig en ongeldig gebruik, grensgevallen en de grenzen van de analyse controleren. Volg voor hun plaatsing en uitvoering de [testhandleiding](#tests-uitvoeren-en-uitbreiden). De tests gebruiken het echte library-entrypoint en de native configuratie. Wijzig je packaging, configuratie of de CLI-aanroep, test dan ook installatie, exitcodes, geladen regels en isolatie van persoonlijke opties vanuit een apart project.

Voer tijdens het werk `bundle exec rake test:lint` uit en sluit af met de [volledige eindcontroles](#werkwijze-bij-een-wijziging). Tests van linteroutput mogen de parser gebruiken om geldige correcties te bewijzen; algemene module-, script- en monitoringtests blijven buiten deze testsuite. Voor autofix gelden de aanvullende criteria onder [Veilige autofixes ontwikkelen](#veilige-autofixes-ontwikkelen).

### Technische werking van de checks

De interne gem maakt de runtime-afhankelijkheden, laadpaden en gedeelde profielen beschikbaar aan andere projecten zonder dat zij onze ontwikkelbundle hoeven te gebruiken. De gem volgt de [RubyGems-libraryconventies](https://guides.rubygems.org/make-your-own-gem/): een entrypoint, eigen code onder `ProjectLint` en runtime-afhankelijkheden in de [gemspec](lint-project.gemspec). Het root-Gemfile en Rakefile blijven verantwoordelijk voor de ontwikkeling van alle repositorytools. Houd ontwikkelafhankelijkheden en orkestratie daar; een tweede ontwikkelbundle binnen de gem is niet nodig. Gebruik lokaal en in CI dezelfde Bundler-, Rake- en native CLI-routes. De [Bundler-documentatie](https://bundler.io/guides/git.html) beschrijft hoe dezelfde gem vanuit een checkout of Git-bron kan worden gebruikt.

```text
.tools/lint/
├── lint-project.gemspec
├── bin/
│   └── puppet-lint-junit     # Omzetting van native lintuitvoer naar JUnit XML.
├── lib/
│   ├── project_lint.rb
│   └── project_lint/
│       ├── checks/          # Registratie, detectie en autofix per regel.
│       └── ...              # Gedeelde domeinlogica en complexe bronanalyse.
├── config/                  # Gedeeld Puppet-lint-profiel.
├── tests/                    # Gedragstests van deze gem.
├── README.md                # Gebruik en onderhoud van de tooling.
└── docs/
    ├── CODE_RULES.md          # Algemene Puppet-coderegels en reviewcriteria.
    ├── DOCUMENTATION_RULES.md # Puppet-codecommentaar, Strings en interface-documentatie.
    └── OPERATIONAL_RULES.md   # Aanvullende operationele Puppet-regels.
```

Puppet-lint blijft de lintengine. De checks gebruiken zijn tokens, `notify`, suppressions, `PuppetLint::NoFix`, `add_token` en `remove_token`. Geef deze native API’s voor registratie, configuratie, diagnostiek, suppressions en autofix voorrang op eigen infrastructuur. De native CLI bepaalt opties, manifestdetectie, rapportage, foutstatus en correcties. Eenvoudige tokenchecks, zoals de controle van Puppet-URLs, hebben geen AST nodig.

[`PuppetJunit`](lib/project_lint/puppet_junit.rb) verwerkt uitsluitend de native JSON-uitvoer voor de [JUnit-rapportage](#lintrapporten-maken). Het uitvoerbare commando `puppet-lint-junit` komt uit dezelfde gem. De omzetter gebruikt `builder` voor XML-escaping, neemt alleen diagnostische velden op en wijzigt geen lintconfiguratie. De [reportertests](tests/puppet_junit_test.rb) controleren geldige en ongeldige invoer, unieke testcases en foutdetails; de [pakkettest](tests/external_junit_test.rb) controleert de volledige pipe vanuit een onafhankelijk geïnstalleerde gem.

[`JunitReport`](lib/project_lint/junit_report.rb) verwijst naar de gedeelde XML-schrijver in `project-tools-shared`. De zelfstandige [validatorgem](../validate/README.md) beheert parserorkestratie en de bijbehorende tests.

[`Ast`](lib/project_lint/ast.rb) voegt alleen de structurele informatie van de OpenVox-parser toe: declaraties, expressies, resources en hun omliggende scopes. De tokenindexen van Puppet-lint leveren die volledige structuur niet. Alle structurele checks delen één AST voor de huidige lintinvoer; een nieuwe scan vervangt die analyse, ook bij gelijke tekst in een ander bestand. De analyse voert geen Puppet-functies of catalogi uit. Alleen echte `Puppet::ParseError`-meldingen worden omgezet naar een syntaxfout; programmeerfouten blijven fouten. Een onbekende constructie krijgt waar nodig een reviewmelding.

Houd Ruby-helpers binnen `ProjectLint` met conventionele namespace-gebaseerde require-paden. Introduceer geen helperconstants op topniveau of veranderlijke configuratie die tijdens laden wordt vastgelegd.

Gedeelde helpers beschrijven concrete begrippen, zoals resource-attributen, commentaargrenzen, variabeleafhankelijkheden en modulepaden. Checks met een complexe zelfstandige analyse, zoals backendherkomst of shellescaping, houden die analyse apart. Methoden die alleen een check ondersteunen staan bij die check. Een grotere analyse kan binnen hetzelfde bestand worden onderverdeeld, bijvoorbeeld in commentaaropmaak, regelbreedte en suppressions. Houd die onderdelen inhoudelijk samenhangend en blijf de bestaande RuboCop-regels volgen. Extraheer alleen bestaande gedeelde complexiteit of een substantiële zelfstandige analyse; houd eenvoudige checkspecifieke methoden bij hun check en voeg geen speculatieve abstracties toe.

Het entrypoint laadt eerst `puppet-lint` en daarna de eigen checks. Gebruik daarom `--load` zoals in de voorbeelden, of `require 'project_lint'` vanuit Ruby. Automatische registratie van manifestchecks via `lib/puppet-lint/plugins/` wordt bewust niet gebruikt: Puppet-lint laadt gemplugins met `load`, in gemvolgorde. De externe trailing-comma-plugin bewaart oorspronkelijke tokenankers die referencefixes kunnen verwijderen. Door het projectentrypoint na de engine te laden, zijn de upstream-fixes al geregistreerd en blijven beide transformaties bruikbaar. De integratietests bewaken deze laadroute en herhaald laden veroorzaakt geen dubbele registraties. De [native API](https://puppet-lint.com/developer/api/) en de onderhouden [parameterplugin](https://github.com/voxpupuli/puppet-lint-param-types) zijn het uitgangspunt voor nieuwe checks; afhankelijkheden en hun werkelijk geïnstalleerde implementatie bepalen de grenzen van autofix.

[`native_fixes.rb`](lib/project_lint/native_fixes.rb) vult de bestaande native checks voor reference-richting en pijlspaties aan en begrenst facts-conversie tot aantoonbaar schrijfbare invoer. De Puppet-URL-check weigert daarnaast de upstream-mountkeuze. Deze uitbreidingen behouden de bestaande checknamen, selectie, suppressions en fixafhandeling; zij registreren geen concurrerende checks.


[`ModuleResolver`](lib/project_lint/module_resolver.rb) leest het modulepad bij het maken van een analyse, zodat een volgende scan gewijzigde environmentinstellingen kan gebruiken. Gevonden bestanden worden alleen binnen die analyse gecachet en bij gewijzigde bestandsmetadata opnieuw gelezen. Er zijn geen modulepaden die tijdens `require` als globale constants worden vastgelegd. De regels voor vindbaarheid staan bij [Aanroepen van modules controleren](#aanroepen-van-modules-controleren).

#### Omvang en validatiestructuur

`project_positive_flow` meldt een `if`-tak die minder codestructuur bevat dan de bijbehorende `else`. Een opdracht telt als één onderdeel; geneste blokken, resource-instanties, attributen en elementen in arrays, hashes en selectors tellen mee. Commentaar, witruimte, de lengte van strings en gewone functieargumenten tellen niet als extra opdrachten. Naast deze algemene vergelijking controleert dezelfde check de afsluitende structuur van validaties met `fail(...)` en `warning(...)`.

De validatiecontrole herkent rechtstreekse Puppet-aanroepen van `warning()` en `fail()`, ook met een voorloop-`::`. Strings, commentaar, parameterdefaults, afzonderlijke functiedefinities en functies zoals `example::warning()` vallen erbuiten. De positie wordt bepaald via de omliggende opdrachten en blokken, niet via de fysieke regelvolgorde.

#### Classcontroles en vindbare afnemers

`project_class_check_reuse` controleert letterlijke classnamen in de body van iedere class en ieder defined type afzonderlijk. De check telt echte variabelereferenties, inclusief interpolatie en gekwalificeerde verwijzingen vanuit vindbare manifests in het modulepad. Rechtstreeks gebruik via `@variabele` in statisch benoemde ERB-templates en `inline_template` telt ook mee. Commentaar, gewone stringtekst en gelijknamige lokale lambdavariabelen tellen niet als hergebruik. Dynamische classnamen, parameterdefaults, andere resourcetypen en indirecte template- of functielookups vallen buiten deze analyse; beoordeel die bij de review.

Voor hergebruik uit een gecontroleerde class onderzoekt de check de geldige tak van een omvattende `if`, inclusief haakjes en `and` in de voorwaarde. Hij zoekt de class eerst in de huidige bron en daarna via het modulepad. Eén rechtstreekse toekenning van dezelfde classcontrole aan een classvariabele levert een `[review]`-melding op. Toekenningen in lambda's of geneste declaraties, meervoudige toekenningen en samengestelde of omgekeerde resultaten tellen niet mee. Een `or`, negatieve controle, `else` of controle in een andere declaratie bewijst geen beschikbaarheid. Ook deze melding heeft geen autofix: voorwaardelijke toekenningen en verschillen in evaluatiemoment vragen beoordeling van de effectieve catalogus.

#### References en relatiecontext

`project_resource_references` gebruikt de Puppet-AST om directe elementen van iedere array per resourcetype te groeperen. De analyse loopt via de omvattende expressies naar de relatiecontext; ingebouwde datatypen en lokale typealiases worden uitgesloten. De correctie hergebruikt de oorspronkelijke titeltokens in de eerste reference en verwijdert de overige references van dat type elk met hun voorafgaande komma. Daardoor blijven tussenliggende elementen en fixes van andere checks behouden, ook wanneer meerdere typen door elkaar staan. De regels voor sortering, dubbele titels en het verwijderen van de buitenste array staan bij [Resource references](docs/CODE_RULES.md#resource-references).

#### Voorbereiding van voorwaarden

`project_if_sections` volgt opeenvolgende toekenningen terug vanaf de variabelen in de voorwaarde, ook als een afhankelijkheid via een andere variabele loopt. De voorwaarden van aansluitende `elsif`-takken tellen mee bij dezelfde voorbereiding. Een losstaande toekenning of andere opdracht onderbreekt die reeks. Commentaar bij een eerder blok of een bovenliggende voorwaarde geldt niet voor een geneste `if`. Bij een toekenning zoals `$result = if ...` staat de toelichting boven de toekenning en eventuele voorbereiding. De check deelt de analyse van variabeleafhankelijkheden met `project_variable_sections`; de betekenis van de toelichting blijft onderdeel van de inhoudelijke review.

`project_shared_conditions` zoekt binnen hetzelfde opdrachtenblok naar resourcegroepen met dezelfde voorwaarde als een bestaand `if`-blok. Ook een voorwaarde die met diezelfde controle begint en daarna met `and` verdergaat, wordt herkend. De melding wijst naar het bestaande blok; de [regelbeschrijving](docs/CODE_RULES.md#gedeelde-voorwaarden-om-resources-groeperen) beschrijft de expressievormen, analysegrenzen en vereiste review.

#### Hints voor variabelegroepen

Ontbreekt de toelichting bij de eerste variabele na `{`, dan kan de melding ook naar een latere groep in hetzelfde blok verwijzen. Daarvoor moeten de eerste toekenningen dezelfde buitenste functie aanroepen, bijvoorbeeld `stdlib::shell_escape(...)`. De check kijkt alleen voorbij andere toekenningen en stopt zodra de oorspronkelijke variabele wordt gebruikt. Functieaanroepen met een eigen lambdablok vormen zelf geen kandidaat. De melding noemt de regel van het bestaande commentaar, zodat je kunt beoordelen of samenvoegen de code duidelijker maakt. De hint is geen bewijs van inhoudelijke samenhang: controleer ook of de volgorde van uitvoeren mag veranderen.

#### Backendselectie en wrappers

`project_monitoring_backend` volgt de centrale packagewaarde door toekenningen en voorwaarden. Parameters die aantoonbaar als `package` worden doorgegeven aan een monitoringaanroep tellen ook mee. De check herkent lokale wrappers en statisch benoemde wrappers in het ingestelde modulepad, inclusief classes via `include`, `contain` en `require`. Hij meldt de oorspronkelijke backendselectie één keer, ook als meerdere aanroepen ervan afhangen. Gewone pakketkeuzes zonder die relatie vallen buiten de check; `monitoring_custom` zelf blijft verantwoordelijk voor de concrete backendimplementatie.

### Veilige autofixes ontwikkelen

Begin bij de gebruikte bundle: controleer `bundle exec puppet-lint --no-config --config .puppet-lint.rc --version` en bekijk de implementatie met `bundle show puppet-lint`. Gebruik bestaande checks en veilige correcties van Puppet-lint, geïnstalleerde plugins en projectchecks. Dupliceer ondersteunde detectie of correctie niet handmatig of in een apart hulpmiddel.

Gebruik voor Puppet-code uitsluitend het native `puppet-lint`-fixmechanisme; bouw geen aparte formatter of autofixengine. Iedere custom fix moet idempotent zijn en voldoet aan de [correctieveiligheid in de dagelijkse werkwijze](#werkwijze-bij-een-wijziging): veilig, deterministisch en binnen scope, met behoud van functioneel gedrag, Puppet-relaties, dependencies en configuratie.

Werk de [autofixbeoordeling bij checkontwikkeling](#een-check-toevoegen-of-wijzigen) uit voor de hele constructie die je wijzigt; alleen de gemelde regel bekijken is niet voldoende. Behoud bij de bronbewerking ook commentaar. Controleer dat het resultaat geldige Puppet-code is en dat dezelfde regel na de correctie geen melding meer geeft.

`project_guarded_packages` gebruikt de gedeelde AST voor guards, scopes en attribuutvergelijking. De tokenanalyse bepaalt alleen de te vervangen gebieden en de concrete opmaak. De fix draait na die van de bestaande checks en leest de actuele attribuuttokens, zodat eerdere quote- en kommafixes behouden blijven. De [voorwaarden voor packagegroepen](docs/OPERATIONAL_RULES.md#pakketten-en-mappen) beschrijven wanneer het vervangingsplan wordt geweigerd. De diagnose noemt de packagenamen en geeft controltekens met escapes weer; attribuutwaarden en AST-objecten worden niet aan de melding toegevoegd.

Implementeer `fix(problem)` naast `check` in de betreffende `ProjectLint::Checks`-module. Registreer die module in hetzelfde bestand met `PuppetLint.new_check(:project_...) { include CheckModule }`, zoals de bestaande checks doen. Bewaar tijdens `check` de betrokken tokenobjecten en de voorwaarden voor correctie. Geef de melding een index naar die context, zoals de bestaande projectchecks doen, zodat JSON-diagnostiek geen bronwaarden bevat. Controleer alle voorwaarden voordat je tokens wijzigt. Gebruik `PuppetLint::NoFix` wanneer die voorwaarden niet gelden; Puppet-lint behoudt dan de oorspronkelijke melding.

Gebruik `add_token`, `remove_token` en de eigenschappen van bestaande tokens voor de correctie. Hergebruik tokens die andere checks ook kunnen aanpassen en bepaal benodigde afstanden uit de actuele tokeninhoud. Regel- en kolomnummers blijven tijdens de fixfase bij de oorspronkelijke bron horen. De gedeelde helpers in [`TokenHelpers`](lib/project_lint/token_helpers.rb) ondersteunen tokengebieden en witruimte; zij parsen of herschrijven geen volledig bestand.

Puppet-lint voert eerst alle checks uit en daarna de fixes. Houd daarom rekening met eerder gewijzigde of verwijderde tokens. De parameteruitlijning vernieuwt vlak vóór haar fixes de meldingen op de bewaarde tokens via de native `run`-methode: een eerdere komma- of tabcorrectie kan de breedte van een type veranderen. De documentatiecheck leest na parameterordening en commentopmaak opnieuw de actuele commenttokens, zodat beschrijvingen en ingevoegde scheidingsregels correct meeverhuizen. De native afhandeling van `lint:ignore` en `fix(problem)` blijft daarbij actief. Een correctie over meerdere regels moet ook controleren of zij een genegeerd deel zou veranderen.

Voeg volgens de [testhandleiding](#tests-uitvoeren-en-uitbreiden) regressietests toe voor detectie zonder wijziging, exacte uitvoer, een schone hercontrole en een ongewijzigde tweede fixrun. Test ook ongeschikte invoer, genegeerde meldingen, comments, strings, meerdere problemen, geneste constructies en samenwerking met de actieve upstream-checks. Test de native CLI op tijdelijke bestanden om de schrijfhandeling en exitcodes te controleren, inclusief selectie via configuratie, gedeeltelijke correcties en onveilige gevallen. Beschouw autofix pas als ondersteund wanneer die normale `--fix`-aanroep aantoonbaar de bedoelde wijzigingen schrijft en de hercontrole de opgeloste melding niet meer geeft. Parservalidatie van de geproduceerde uitvoer hoort bij het fixcontract; een algemene syntaxsuite voor modules hoort niet bij deze tooltests.

De normale CLI-aanroep en CI blijven alleen controleren. Schakel `fix` uitsluitend in bij een expliciete correctiestap en voeg geen tweede formatter of automatische commitstap toe.

### Tests uitvoeren en uitbreiden

Alle lintertests staan onder [`.tools/lint/tests/`](tests), inclusief tests voor CLI, rapportage en gebruik vanuit andere projecten. Bewaar ook hun helpers en fixtures daar. De [projectbrede testscope](../../AGENTS.md#test-scope) bepaalt welk gedrag in repositorytests thuishoort.

Voer tests uit vanuit de repositoryroot, na [installatie van de ontwikkelbundle](#gems-installeren):

**Werkmap:** Repositoryroot. **Shell:** POSIX shell. **Vereisten:** Ontwikkelbundle. **Invoer:** Alle tooltests of alleen de lintertests. **Wijzigt bestanden:** Tijdelijke testinvoer; rapporten alleen bij expliciete instelling. **Verwacht resultaat:** Niet-lege selectie zonder failures, errors of onverklaarde skips.

```sh
bundle exec rake test
bundle exec rake test:lint
```

De [gezamenlijke testtaken](../README.md#gezamenlijke-tooltests) beheren discovery, rapportbestemming en reporterlevenscyclus voor alle tools en repositorycontroles. De lint-testhelper laadt de [gedeelde bootstrap](../shared/README.md#testondersteuning) en voegt de native lintconfiguratie toe. De [teststructuurcontrole](../repository-checks/tests/test_structure_test.rb) bewaakt dat `test:lint` alleen lintertests selecteert.

Een gewone checktest erft rechtstreeks van `Minitest::Test` en gebruikt [`test_helper.rb`](tests/test_helper.rb) voor de native lintaanroep. Zet korte Puppet-invoer en verwachte meldingen in de test zelf. De gedeelde `findings`-helper selecteert één regel via de publieke configuratie en herstelt die configuratie na de aanroep. Er zijn geen gespecialiseerde testbasisklassen of fixtures die op de naam van de testmethode worden opgezocht.

```ruby
require_relative 'test_helper'

class ArraysTest < Minitest::Test
  include LintTestSupport

  def test_array_addition_requires_concat
    problems = findings('$values = [1] + [2]', :project_arrays)
    assert_equal [:warning], problems.map { |problem| problem[:kind] }
    assert_includes problems.first[:message], 'concat'
    assert_empty findings('$values = concat([1], [2])', :project_arrays)
  end
end
```

Gebruik `assert_fix(before, after, :project_check_name)` voor detectie, exacte correctie, parservalidatie van de gecorrigeerde uitvoer, een schone hercontrole en een ongewijzigde tweede fixrun. Controleer onveilige constructies ook met `fix: true`: hun invoer moet behouden blijven. De tests voor [referencefixes](tests/reference_merging_test.rb) en [documentatie](tests/documentation_structure_test.rb) laten beide kanten zien. De [interactietests](tests/cross_check_autofix_test.rb) controleren gedeelde tokengebieden met meerdere checks.

De `cli_*_test.rb`-bestanden controleren native bestandsuitvoer, exitcodes, configuratie en suppressions. [`external_project_test.rb`](tests/external_project_test.rb) bouwt en installeert de echte `.gem` in een tijdelijk project met een eigen bundle. [`external_isolation_test.rb`](tests/external_isolation_test.rb) controleert dat lint zonder metadata werkt, metadata niet wijzigt en geen andere zelfstandige tools installeert. De tests gebruiken reeds geïnstalleerde dependencies en `bundle install --local`; ze hebben geen netwerk, productiegegevens of beheerde hosts nodig. Grotere of hergebruikte Puppet-fragmenten staan als afzonderlijke `.pp`-fixtures bij de tests. De expliciete `fixture`-aanroep wijst naar dat bestand; `fixture_set` leest een benoemde verzameling en faalt als die leeg is. Korte invoer staat direct in Ruby. De CLI-tests hebben daarnaast synthetische Ruby-invoer voor het laden van plugins en persoonlijke configuratie.

Onderzoek een fout eerst bij de vermelde input en assertion. Voer de betreffende test tijdens het ontwikkelen apart uit, bijvoorbeeld `bundle exec ruby .tools/lint/tests/reference_merging_test.rb`, en sluit af met alle tooltests. Voor de GitHub-uitvoervorm kun je `GITHUB_ACTION=synthetic_test bundle exec rake test` gebruiken; diagnostiektellingen moeten in beide uitvoervormen gelijk blijven.

Test uitsluitend de toolcontracten. Puppet-fragmenten om een lintmelding of autofix te controleren horen hier wel thuis; algemene module-, catalogus-, template-, script- en monitoringtests niet. Gebruik daarvoor bestaande validators en tijdelijke controles buiten de repository, volgens [de testscope](../../AGENTS.md#test-scope). Bewaar een fixture alleen als een groter of hergebruikt scenario daarmee duidelijker wordt.

### Versies bijwerken

Zie de [gezamenlijke toolinghandleiding](../README.md#versies-bijwerken) voor deze procedure.

### Eigen tooltests

Zie de [gezamenlijke toolinghandleiding](../README.md#eigen-tooltests) voor deze procedure.

#### Testselectie en uitvoeropties

Zie de [gezamenlijke toolinghandleiding](../README.md#testselectie-en-uitvoeropties) voor deze procedure.

#### JUnit-rapportage instellen

Zie de [gezamenlijke toolinghandleiding](../README.md#junit-rapportage-instellen) voor deze procedure.

## Documentatiecontract voor maintainers

Gebruik dit contract wanneer je een regel in [CODE_RULES.md](docs/CODE_RULES.md), [DOCUMENTATION_RULES.md](docs/DOCUMENTATION_RULES.md) of [OPERATIONAL_RULES.md](docs/OPERATIONAL_RULES.md), of een checkbeschrijving of gebruiksprocedure in deze README bijwerkt. De algemene afspraken voor de inhoudsopgave en samenhang binnen ieder onderwerp staan in [`AGENTS.md`](../../AGENTS.md#markdown). Het onderstaande schema bepaalt welke informatie iedere Puppet-regel daarnaast moet bevatten.

Iedere onafhankelijke Puppet-regel krijgt in `docs/CODE_RULES.md`, `docs/DOCUMENTATION_RULES.md` of `docs/OPERATIONAL_RULES.md` een eigen `##`- of `###`-subsectie op precies één autoritatieve locatie. Gebruik de onderstaande velden exact in deze volgorde; laat geen veld leeg. Laat verplichte velden niet weg en hernoem of combineer ze niet, tenzij de eigenaar expliciet om een schemawijziging vraagt. Een regel kan meerdere checks hebben en een check meerdere regels: verbind ze met links naar de betreffende secties in de vier documenten, zonder een tweede regelnummering. Plaats de norm bij het beslispunt waarvoor het document verantwoordelijk is en verwijs vanuit de andere regelsbestanden gericht naar die norm.

```markdown
**Norm**
**Herkomst**
**Toepassingsgebied**
**Automatische controle**
**Detectiegrenzen**
**Meldingen en severity**
**Autofix**
**Autofixvoorwaarden**
**Toegestane uitzonderingen**
**Suppressions**
**Onjuist voorbeeld**
**Correct voorbeeld**
**Grensgevallen**
**Handmatige review**
**Verificatie**
```

Koppen die uitsluitend regels groeperen dragen `<!-- lint-rule-group -->`; zij bevatten zelf geen tweede norm. De structuurtest controleert ieder overig regelblok op het volledige schema, ook wanneer een veld geheel ontbreekt.

Formuleer toepasselijkheid en vereiste actie rechtstreeks. Behoud of bestaand beleid verplicht, verboden, aanbevolen of toegestaan is. Houd voorwaarden, toegestane uitzonderingen, analysegrenzen en weigeringen van autofix bij de betreffende norm.

`Herkomst` is `Projectregel`, `Upstreamregel`, `Projectspecificatie van upstream` of `Nog niet vastgesteld`; bij upstream hoort een bronverwijzing. De laatste waarde verwijst naar een open verificatiepunt in de oplevering. `Automatische controle` noemt de exacte checknamen of letterlijk `Geen automatische controle`. Beschrijf bij iedere meldingsvariant de trigger, werkelijke severity en variabele tekstdelen. `[review]` is een tekstlabel, geen severity.

`Autofix` is per variant `Geen`, `Voorwaardelijk` of `Alle gedocumenteerde gevallen`, onderbouwd door uitvoering. Beschrijf alle correcties en weigeringsvoorwaarden. Een gemiste detectie is geen toegestane uitzondering. Suppressions noemen naam, syntax, plaats en begrenzing of verbieden suppressie expliciet. Gebruik `Geen` of `Niet van toepassing` uitsluitend met een concrete reden; ontbrekend bewijs krijgt `Nog niet vastgesteld` en een open punt.

Beschrijf bij `Verificatie` hoe de lezer het contract controleert en welke tests dat gedrag bewaken. Bewaar concrete uitvoeringsresultaten, tijdelijke bevindingen en open beslispunten bij de betreffende wijzigingsreview of het uitvoeringsrapport, volgens de [centrale documentatieafspraken](../../AGENTS.md#durable-documentation). Houd een noodzakelijke beperking of workaround daarnaast vindbaar bij de betrokken gebruiksinstructie.

Label voorbeelden als `Fragment`, `Volledig uitvoerbaar voorbeeld` of `Handmatig reviewscenario`. Een fragment kan uitsluitend voor benoemde checks groen zijn. Controleer juiste en onjuiste varianten, elke uitzonderings- en begrenzingscategorie, exacte fixes, hercontrole en een ongewijzigde tweede fixrun. Volledige voorbeelden slagen onder het volledige benoemde profiel. Handmatige normen benoemen de concrete reviewstappen en beoordelingscriteria.

Het centrale projectcheckregister staat uitsluitend in deze README, tussen `<!-- BEGIN PROJECT CHECK REGISTRY -->` en `<!-- END PROJECT CHECK REGISTRY -->`. Gebruik exact de kolommen `Check`, `Actief in repositoryprofiel`, `Actief in gedeeld profiel`, `Meldingsvarianten`, `Autofix` en `Regeluitleg`. Iedere geregistreerde projectcheck heeft één rij; controleer ontbrekende, onbekende en dubbele namen afzonderlijk. Verifieer runtimeregistratie, profielactivatie, diagnostische dekking en regelverwijzingen als afzonderlijke eigenschappen. Classificeer de fixdekking per variant, niet op grond van alleen een aanwezige fixmethode. Gemengde fixdekking heet `Per meldingsvariant` en verwijst naar de uitwerking in `docs/CODE_RULES.md`, `docs/DOCUMENTATION_RULES.md` of `docs/OPERATIONAL_RULES.md`. Regelverwijzingen uit het register wijzen rechtstreeks naar de betreffende autoritatieve headings. Maak geen tweede register in een regelsbestand.

Werk bij gewijzigde checks, diagnostics, severity, defaults, autofixes, suppressions, configuratie, dependencies, reporters of consumerinterfaces de betrokken regelvelden in `docs/CODE_RULES.md`, `docs/DOCUMENTATION_RULES.md` en `docs/OPERATIONAL_RULES.md`, registerrijen en procedures in deze README, implementatie en tooltests samen bij. Onderbouw een conclusie zonder documentatie-impact met de daadwerkelijk beoordeelde interfaces. Controleer versieclaims tegen de gedeclareerde constraints en opgeloste dependencies. Houd gedeclareerde compatibiliteit, geïnstalleerde versies, werkelijk geteste combinaties en ontwikkelbeleid afzonderlijk.

Verifieer gewijzigde configuratie-instructies tegen de geïnstalleerde CLI, loader en tooltests. Bepaal prioriteit per optietype; ga er niet van uit dat iedere latere waarde de eerdere vervangt. Test gewijzigde downstreamprocedures in een onafhankelijk consumerproject met eigen Gemfile, lockfile, lokale configuratie en manifestselectie. Valideer iedere beschreven installatieroute afzonderlijk, inclusief het gebouwde pakket wanneer dat wordt gedistribueerd; een geslaagde path-installatie bewijst geen Git- of pakketinstallatie. Controleer succesvolle en mislukte commando’s, numerieke exitstatus en rapportproductie. Een geslaagde rapportconversie mag een mislukte lint- of validatierun niet verbergen.

Vermeld vóór ieder procedureblok `Werkmap`, `Shell`, `Vereisten`, `Invoer`, `Wijzigt bestanden` en `Verwacht resultaat`. Definieer alle variabelen en vervangbare paden vooraf. Bij gewijzigde context begint een nieuw contextblok. Behoud headingankers zonder dubbele id's en werk inkomende links bij wanneer de doelheading tussen de vier bestanden verhuist. Leg verplaatste, samengevoegde en gecorrigeerde verplichtingen, uitzonderingen, waarschuwingen en gebruiksroutes met hun vorige en nieuwe locatie en bewijs vast in de oplevering, niet in een nieuw repositorydocument. Automatische tests bewaken inventarissen, links en uitvoercontracten; inhoudsbehoud en begrijpelijkheid blijven handmatige review volgens de [documentatiereview](../../AGENTS.md#lint-documentation-maintenance). Verander lintgedrag of een norm niet om een documentatieverschil weg te werken; beschrijf de norm en het waargenomen gedrag afzonderlijk wanneer de bedoelde oplossing nog niet vaststaat.

De lintnormen en lintspecifieke procedures staan in exact deze README, `docs/CODE_RULES.md`, `docs/DOCUMENTATION_RULES.md` en `docs/OPERATIONAL_RULES.md`. Houd lintspecifieke procedures en het centrale checkregister hier, algemene Puppet-regels in `docs/CODE_RULES.md`, regels voor Puppet-codecommentaar, Puppet Strings en interface-documentatie in `docs/DOCUMENTATION_RULES.md` en aanvullende operationele regels in `docs/OPERATIONAL_RULES.md`. De [structuurtest](tests/guide_structure_test.rb) controleert deze indeling en bewaakt dat ieder bestand afzonderlijk strikt kleiner blijft dan 300 KiB (307200 bytes). De foutmelding noemt het bestand, de actuele grootte en de projectlimiet. De [documentatiecontracttest](tests/guide_contract_test.rb) bewaakt daarnaast de registratie, regelverwijzingen en verplichte velden in de drie regelsbestanden. Beide tests beoordelen het contract; ze wijzigen geen documentatie.

Controleer bij een overschrijding eerst of informatie volgens het autoriteitsmodel in een van de andere drie documenten thuishoort. Verwijder of verkort geen noodzakelijke verdieping, voorbeelden of voorwaarden en combineer geen onafhankelijke regels uitsluitend om ruimte te besparen. Maak niet automatisch een vijfde lintdocument. De [gezamenlijke toolinghandleiding](../README.md) en de packagehandleidingen voor shared en dependencycontrole beheren uitsluitend hun eigen interfaces, geen lintnormen. Is de verdeling correct en verdere opsplitsing nodig, behandel dat dan als een afzonderlijke, expliciet te beoordelen architectuurwijziging.

## Problemen oplossen

| Probleem | Controle en herstel |
| --- | --- |
| Bundler mist de gem of een executable | Controleer Ruby, `Gem.bindir`, PATH en de eigen Gemfile. Installeer het pakket of configureer de gembron en voer `bundle install` uit. |
| Projectchecks ontbreken | Controleer `bundle show lint-project` en gebruik `--load` vóór andere projectopties. `--list-checks` moet de `project_*`-checks tonen. |
| Persoonlijke opties hebben invloed | Gebruik `--no-config` vóór de expliciete configuratiebestanden. |
| Een scan slaagt terwijl eigen code fout is | Controleer of alle eigen manifests geselecteerd zijn. Probeer tijdelijk `$values = [1] + [2]`; verwacht `project_arrays` en een foutcode. `concat([1], [2])` hoort die melding op te lossen. |
| Een onjuiste aanroep geeft geen melding | Controleer modulepad, modulevolgorde en manifestlocatie; valideer de catalogus voor gedrag dat lint niet kan bewijzen. |
| De lokale configuratie ontbreekt | Herstel `.puppet-lint.rc`; vertrouw niet op de native CLI om een ontbrekend optiebestand te melden. |

## Eindcontrole

Volg de volledige [werkwijze](#werkwijze-bij-een-wijziging). Een beperkte scan of geslaagde rapportconversie vervangt geen vereiste controle. Noteer ieder commando, exitcode, rapport en eventuele beperking afzonderlijk. Laat gevalideerde wijzigingen in de werkboom voor menselijke review en commit.
