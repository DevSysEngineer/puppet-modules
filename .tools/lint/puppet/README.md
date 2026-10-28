# Puppet-code, lintcontroles en hergebruik

<a id="puppet-lint-en-rubocop"></a>
<a id="doel-en-reikwijdte"></a>

Deze handleiding beschrijft hoe je Puppet-code voor de repository `puppet-modules` controleert. Je vindt hier de dagelijkse werkwijze, de lintcommando's en verwijzingen naar de [algemene coderegels en aanvullende Puppet-regels](docs/CODE_RULES.md), [documentatienormen](docs/DOCUMENTATION_RULES.md) en [operationele regels](docs/OPERATIONAL_RULES.md). Ook lees je hoe je die controles in een ander Puppet-project gebruikt en hoe de linter is opgebouwd. Voor onderhoud in de ontwikkelcheckout volg je de [onderhoudsafspraken](#linter-ontwikkelen-en-testen).

Voor links buiten deze gem lees je de handleiding in de bijbehorende repositorycheckout.

**Puppet-lint** is een extern controleprogramma dat Puppet-broncode leest en afwijkingen van codeafspraken meldt. Zo'n programma heet een linter; iedere afzonderlijke controle heet een check. Je start het met het commando `puppet-lint`. Het programma heeft standaardchecks en kan extra checks uit uitbreidingen laden.

Voor deze repository zijn zulke uitbreidingen en de bijbehorende configuratie verzameld in **`lint-project`**, ons eigen Ruby-pakket, ook wel een gem genoemd. Dit pakket gebruikt Puppet-lint als controleprogramma en voegt de `project_*`-checks toe voor onder meer parameters, documentatie, bestandsrechten en shellcommando's. Daarnaast installeert het de externe lintplugins uit zijn gemspec. Je blijft de controles starten met `puppet-lint`; de projectconfiguratie laadt onze uitbreiding en bepaalt samen met het gedeelde regelprofiel welke checks en opties actief zijn.

`project-tools-ruby-lint` levert [Ruby-lint](../ruby/README.md), `project-tools-metadata` levert [metadatacontrole](../../metadata/README.md) en `project-tools-syntax` levert [parservalidatie](../../syntax/README.md). Kies deze tools afzonderlijk in de [ontwikkelbundle](../../README.md). De [tooltests](#tests-uitvoeren-en-uitbreiden) controleren lintchecks, correcties en installatie.

Gebruik de [leeswijzer](#leeswijzer) om de toepasselijke normen te kiezen. De [centrale informatieplaatsing](docs/DOCUMENTATION_RULES.md#informatieplaatsing) bepaalt hun eigenaar; de [profielen](#configuratie-bestandsselectie-en-modulepad) en het [checkregister](#checkregister) verbinden die normen met de actieve controles.

Een groene lintscan bewijst geen volledige normnaleving, geldige catalogus of correct runtimegedrag. Bij ontbrekende automatische dekking blijft de norm gelden en is handmatige review vereist. Bij strijdigheid beschrijf je norm en waargenomen gedrag afzonderlijk en registreer je het conflict in de oplevering; pas de norm of implementatie niet aan als redactionele oplossing. Corrigeer een feitelijk onjuiste CLI-beschrijving alleen met uitvoerbewijs. Behoud onduidelijke normen letterlijk en markeer de precieze onzekerheid. Een niet-uitgevoerde verplichte controle of onopgelost normconflict verhindert de eindstatus `Afgerond`.

## Leeswijzer

Gebruik je de tooling voor het eerst, begin dan bij de snelstart voor [deze repository](#snelstart-in-deze-repository) of [je eigen Puppet-project](#snelstart-in-een-ander-puppet-project). Voor een wijziging volg je de [dagelijkse werkwijze](#werkwijze-bij-een-wijziging). De onderwerpentabel verwijst naar de secties die je wijziging raakt; de taakroutes eronder verbinden die naslag met de benodigde stappen. Je hoeft de overige gespecialiseerde naslag niet vooraf door te nemen. Komt tijdens je werk een nieuwe afhankelijkheid of integratie in beeld, neem dan de bijbehorende sectie erbij.

Volg bij iedere codewijziging de [algemene ontwerpregels](docs/CODE_RULES.md#algemene-ontwerpregels), ook voor Ruby, scripts en tooling. Voor Puppet gelden daarnaast de toepasselijke syntax-, parameter- en resourceregels in datzelfde bestand. Raakt de wijziging documentatie of codecommentaar, inclusief Puppet Strings en interfacebeschrijvingen, lees en volg dan daarnaast de relevante regels uit [DOCUMENTATION_RULES.md](docs/DOCUMENTATION_RULES.md).

Raakt de wijziging beheerde bestanden of mappen, eigenaarschap of rechten, beveiliging, systemd of services, shellcode of shelltemplates, runtime-tools of operationele dependencies, of monitoringchecks en hun registratie, volg dan ook de relevante regels uit [OPERATIONAL_RULES.md](docs/OPERATIONAL_RULES.md). Beide aanvullende documenten kunnen tegelijk van toepassing zijn. Ze vervangen de algemene coderegels nooit.

| Je taak | Lees hierbij |
| --- | --- |
| Gedrag delen of interfaces tussen componenten wijzigen | [Gedeelde implementaties](docs/CODE_RULES.md#gelijk-gedrag-in-één-implementatie-onderhouden) en [verantwoordelijkheden en interfaces](docs/CODE_RULES.md#verantwoordelijkheden-en-interfaces-afbakenen). |
| Een normaal Puppet-manifest aanpassen | [Basisopmaak](docs/CODE_RULES.md#basisopmaak) en [parameters en resources](docs/CODE_RULES.md#parameters-en-resources). |
| Verantwoordelijkheden tussen caller, component en template wijzigen | [Instellingen bij hun eigenaar houden](docs/CODE_RULES.md#instellingen-bij-hun-eigenaar-houden); controleer de gegevensstroom en het gedrag met de [aanvullende validatie](#aanvullende-validatie). |
| Commentaar of Puppet-interface-documentatie aanpassen | [Commentaar en documentatie](docs/DOCUMENTATION_RULES.md#commentaar-en-documentatie), waaronder [toelichtingen bij code](docs/DOCUMENTATION_RULES.md#toelichtingen-bij-code) en [interfacebeschrijvingen synchroniseren](docs/DOCUMENTATION_RULES.md#interfacebeschrijvingen-synchroniseren). |
| Puppet Strings aanpassen | [Puppet Strings](docs/DOCUMENTATION_RULES.md#puppet-strings), [lange regels](docs/CODE_RULES.md#lange-regels) en [waar de uitleg hoort](docs/DOCUMENTATION_RULES.md#waar-de-uitleg-hoort). |
| Resources of dependencies aanpassen | [Packageafhankelijkheden bij externe commando’s](docs/CODE_RULES.md#packageafhankelijkheden-bij-externe-commandos), [Resources en afhankelijkheden](docs/CODE_RULES.md#resources-en-afhankelijkheden), [resource references](docs/CODE_RULES.md#resource-references) en [volgorde en meldingen](docs/CODE_RULES.md#volgorde-en-meldingen). |
| Bestanden, privileges of shellcommando's aanpassen | [Bestanden en beveiliging](docs/OPERATIONAL_RULES.md#bestanden-en-beveiliging), inclusief [beheerheaders](docs/OPERATIONAL_RULES.md#door-puppet-beheerde-inhoud-markeren) en [helperlocaties](docs/OPERATIONAL_RULES.md#beheerhelpers-op-de-gedeelde-locatie-installeren); voer de [algemene beveiligingsreview](../../../CONTRIBUTING.md#veilig-werken-en-gegevensdeling) uit. |
| Een shellscript, Bash-script, shelltemplate of bijbehorende runtime-dependency aanpassen | [Shellscripts](docs/OPERATIONAL_RULES.md#shellscripts), inclusief [gedeelde helpers](docs/OPERATIONAL_RULES.md#shellhelpers-op-een-herkenbare-taak-afbakenen) en [runtime-tools](docs/OPERATIONAL_RULES.md#runtime-tools-op-hun-functie-beoordelen); voer de [projectbrede shellvalidatie](../../../TESTS.md#shellvalidatie) uit. |
| Een monitoringcheck of registratie aanpassen | [Monitoringchecks](docs/OPERATIONAL_RULES.md#monitoringchecks), [runtimebronkeuze](docs/OPERATIONAL_RULES.md#actuele-hosttoestand-uit-kernelgegevens-bepalen), [inspectiestatus](docs/OPERATIONAL_RULES.md#vastgestelde-afwijkingen-en-onvolledige-inspecties-onderscheiden) en [targets en monitoring](docs/OPERATIONAL_RULES.md#targets-en-monitoring); voer de [projectbrede monitoringreview en validatie](docs/OPERATIONAL_RULES.md#monitoringchecks) uit. |
| Systemd-integratie aanpassen | [Gedeelde services en systemd](docs/OPERATIONAL_RULES.md#gedeelde-services-en-systemd), inclusief de beoordeling per service. |
| Een lintmelding oplossen | [Een melding oplossen](#een-melding-oplossen); zoek de checknaam in het [checkoverzicht](#beschikbare-projectchecks). |
| Autofix uitvoeren | [Automatisch corrigeren](#automatisch-corrigeren-autofix) en de voorwaarden bij de betrokken check. |
| Ruby-code controleren of veilig corrigeren | [RuboCop gebruiken](#ruby-code-controleren). |
| Rapporten maken of een CI-uitslag onderzoeken | [Puppet-manifests valideren](#puppet-manifests-valideren), [lintrapporten maken](#lintrapporten-maken), [tooltests uitvoeren](#tests-uitvoeren-en-uitbreiden) en [CI van deze repository](#ci-van-deze-repository). |
| Een bestaande lintcheck aanpassen | [Checkontwikkeling](#checkontwikkeling) en de bijbehorende [technische werking](#technische-werking-van-de-checks). |
| Een nieuwe lintcheck of autofix ontwikkelen | [Linter ontwikkelen en onderhouden](#linter-ontwikkelen-en-onderhouden), inclusief [veilige autofixontwikkeling](#veilige-autofix-ontwikkelen). |
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

Begin in de ontwikkelcheckout bij het [lintonderhoud](#linter-ontwikkelen-en-testen), na de [gezamenlijke ontwikkelwerkwijze](../../../CONTRIBUTING.md) en het [gedeelde toolingonderhoud](../../README.md#gedeeld-toolingonderhoud). De [technische uitleg en testaanroepen](#linter-ontwikkelen-en-testen) hieronder beschrijven de architectuur en beschikbare verificatie. Voor gewone Puppet-wijzigingen gebruik je de dagelijkse werkwijze en relevante normen.

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
  - [Exitcodes van syntax-junit](#exitcodes-van-syntax-junit)
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
  - [Checkontwikkeling](#checkontwikkeling)
  - [Architectuurreview](#architectuurreview)
  - [Veilige autofix ontwikkelen](#veilige-autofix-ontwikkelen)
  - [Linttests onderhouden](#linttests-onderhouden)
  - [Technische werking van de checks](#technische-werking-van-de-checks)
    - [Herhaalde functieaanroepen](#herhaalde-functieaanroepen)
    - [Omvang en validatiestructuur](#omvang-en-validatiestructuur)
    - [Classcontroles en vindbare afnemers](#classcontroles-en-vindbare-afnemers)
    - [References en relatiecontext](#references-en-relatiecontext)
    - [Voorbereiding van voorwaarden](#voorbereiding-van-voorwaarden)
    - [Hints voor variabelegroepen](#hints-voor-variabelegroepen)
    - [Backendselectie en wrappers](#backendselectie-en-wrappers)
  - [Autofixinteracties](#autofixinteracties)
  - [Tests uitvoeren en uitbreiden](#tests-uitvoeren-en-uitbreiden)
  - [Versies bijwerken](#versies-bijwerken)
  - [Eigen tooltests](#eigen-tooltests)
    - [Testselectie en uitvoeropties](#testselectie-en-uitvoeropties)
    - [JUnit-rapportage instellen](#junit-rapportage-instellen)
- [Documentatiecontract voor maintainers](#documentatiecontract-voor-maintainers)
  - [Grenzen van de lintdocumentatie](#grenzen-van-de-lintdocumentatie)
  - [Lintdocumentatie onderhouden](#lintdocumentatie-onderhouden)
    - [Documentatiewijzigingen verifiëren](#documentatiewijzigingen-verifiëren)
  - [Schema voor regels en procedures](#schema-voor-regels-en-procedures)
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

Beoordeel de correctie via de [veilige Git-inspectie](../../../CONTRIBUTING.md#git-inspectie). Voer de correctiestap alleen uit als dit manifest tot de bedoelde wijzigingsscope behoort en de beschreven autofixvoorwaarden zijn beoordeeld.

**Werkmap:** Repositoryroot. **Shell:** POSIX shell. **Vereisten:** Ontwikkelbundle. **Invoer:** examples/site.pp. **Wijzigt bestanden:** Ondersteunde fixes in dat manifest. **Verwacht resultaat:** Diff beoordeeld en gewone hercontrole zonder resterende bevindingen.

```sh
bundle exec puppet-lint --no-config --config .puppet-lint.rc --fix examples/site.pp
bundle exec puppet-lint --no-config --config .puppet-lint.rc examples/site.pp
```

### Werkwijze bij een wijziging

Gebruik `stdlib::ensure_packages()` volgens de [packageafspraken](docs/CODE_RULES.md#packageafhankelijkheden-bij-externe-commandos). De bestaande lintanalyses ondersteunen deze functie en de autofixes genereren de namespaced aanroep. De [cataloguscontrole](../../catalog/README.md#native-deprecations-afkeuren) beoordeelt deprecations tijdens evaluatie.

1. Volg de [voorbereiding en Git-inspectie](../../../CONTRIBUTING.md#bestaande-situatie-onderzoeken) en lees de relevante code, modulemetadata en documentatie na de vereiste voorcontrole. Kies met de [leeswijzer](#leeswijzer) de toepasselijke codeafspraken.
2. Voer vóór het aanpassen een lintscan uit, zodat je weet welke meldingen al bestonden. Scan gewijzigde code opnieuw voordat je meldingen gaat corrigeren. Tijdens het ontwikkelen kun je de scan tot [één manifest](#werking-van-de-controles) beperken.
3. Gebruik een beschikbare [autofix](#automatisch-corrigeren-autofix) als die voor de betrokken code veilig en deterministisch is. Controleer daarvoor de voorwaarden bij de check. Beperk de correctie tot je wijziging en behoud gedrag, relaties en configuratie.
4. Scan de gecorrigeerde code opnieuw. De uitvoer van de fixrun kan nog meldingen over de oorspronkelijke regels bevatten.
5. Los de resterende meldingen handmatig op en herhaal de scan. Beoordeel ook het gedrag en de toepasselijke reviewcriteria; lint controleert alleen de automatisch vast te stellen eigenschappen.
6. Valideer ieder gewijzigd manifest afzonderlijk met de [Puppet-parser](#puppet-manifests-valideren). Controleer gewijzigd gedrag, templates, voorbeelden en metadata met de passende validators en tijdelijke synthetische invoer.
7. Voer bij linterontwikkeling de betrokken [tooltests](#tests-uitvoeren-en-uitbreiden) uit. Daarmee controleer je de toolwijziging; modulegedrag valideer je afzonderlijk.
8. Voer na alle correcties de volledige eindcontroles hieronder uit en voltooi de toepasselijke CI-controles. Ook na een geslaagde gerichte scan blijven de volledige lintscan en alle tooltests vereist.
9. Bekijk de uiteindelijke bestandsselectie en diff, inclusief de automatische correcties. Leg de validatie, reviewuitkomsten en eventuele beperkingen vast in de wijzigingsreview en laat de wijzigingen klaarstaan voor menselijke review en commit.

[TESTS.md](../../../TESTS.md#controlevolgorde-en-verplichte-eindcontroles) bepaalt alle verplichte eindcontroles en hun volgorde. Onderstaande lintgerelateerde aanroepen vormen samen geen volledige eindcontrole; volg ook de daar gekoppelde metadata- en dependency-instructies. De secrets-gate moet slagen voordat volgende controles broninformatie tonen.

**Werkmap:** Repositoryroot. **Shell:** POSIX shell. **Vereisten:** Ontwikkelbundle; Ruby-controle wanneer toepasselijk. **Invoer:** Volledige eigen Puppet-/Ruby-code en tooltests. **Wijzigt bestanden:** Genegeerde JUnit-resultaten en toolcache. **Verwacht resultaat:** Alle controles afzonderlijk geslaagd; diff ter review.

```sh
bundle exec rake secrets:puppet
bundle exec rake 'syntax:puppet[.tools/syntax/results/syntax-report.xml]'
bundle exec puppet-lint --no-config --config .puppet-lint.rc .
bundle exec rubocop --config .rubocop.yml
bundle exec rake test
```

`rake test` ontdekt de tooltests recursief en voert ze allemaal uit. `test:lint` beperkt zich tot de lintertests. De overige [gerichte taken](../../README.md#gezamenlijke-tooltests) kiezen hun eigen onderdeel; `test` voert alle toolsuites en repositorycontroles uit. Zonder expliciete rapportinstelling blijft de uitvoer in de console. Voer whitespace- en inhoudsreview uit volgens de [Git-inspectie](../../../CONTRIBUTING.md#git-inspectie); die bepaalt wanneer originele bestanden of uitsluitend analysekopieën mogen worden vergeleken.

Gebruik bij wijzigingen aan Ruby-code de [RuboCop-werkwijze](#ruby-code-controleren) voor de beginscan, correcties en hercontrole.

## Snelstart in een ander Puppet-project

`lint-project 0.2.0` vereist een expliciete bron voor `project-tools-shared`. Volg bij een update de [consumermigratie](../../README.md#migreren-naar-afzonderlijke-toolpakketten); voeg voor parserrapportage ook de zelfstandige validatorgem toe.

Deze snelstart gebruikt een eigen project; alleen de afzonderlijke [metadatacontrole](../../metadata/README.md) vereist VERSION en rootmetadata. Voeg `global-modules` toe aan die projectroot. De gedeelde modules en gem staan in die checkout; je Gemfile, lockfile, configuratie en eigen manifests staan in de consumerroot. Gebruik voor een bestaand project dezelfde indeling met de daar vastgelegde submodulerevisie, zoals uitgewerkt bij [path-import](#installatie-in-je-project).

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
gem 'lint-project', path: 'global-modules/.tools/lint/puppet', require: false
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
├── global-modules/.tools/lint/puppet/lint-project.gemspec
├── modules/
└── manifests/site.pp
```

Het manifest is een **Volledig uitvoerbaar voorbeeld** voor het gedeelde lintprofiel plus de bovenstaande consumerconfiguratie. De path- en Git-integratietests controleren deze invoer en de tegenvariant `$values = [1] + [2]`, die `project_arrays` met warning en exitcode 1 oplevert. De Ruby-gem installeert geen Puppet-modules. De checkout is hier zowel de gembron als de plaats van eventuele Puppet-dependencies; een gebouwd pakket vereist die checkout niet.

Bewaar de gekozen bronrevisie en eigen lockfile in het versiebeheer van het consumerproject. Bij de aanbevolen Git-submodule legt de gitlink die revisie vast. Werk die revisie bewust bij en voer vervolgens `bundle update lint-project`, de eigen volledige lintscan, parservalidatie en toepasselijke Ruby-/toolcontroles uit. Een geslaagde synthetische scan bewijst nog niet dat alle eigen productiecode is geselecteerd.


## Installatie en compatibiliteit

Zie de [gezamenlijke toolinghandleiding](../../README.md#installatie-en-compatibiliteit) voor deze procedure.

### Benodigde omgeving

Zie de [gezamenlijke toolinghandleiding](../../README.md#benodigde-omgeving) voor deze procedure.

### Installatie

Zie de [gezamenlijke toolinghandleiding](../../README.md#installatie) voor deze procedure.

### Ruby op macOS

Zie de [gezamenlijke toolinghandleiding](../../README.md#ruby-op-macos) voor deze procedure.

### Gems installeren

Zie de [gezamenlijke toolinghandleiding](../../README.md#gems-installeren) voor deze procedure.

### Compatibiliteitslagen

Zie de [gezamenlijke toolinghandleiding](../../README.md#installatie-en-compatibiliteit) voor de ontwikkelomgeving en de [pakketkeuze](../../README.md#pakketten-en-commandos) voor de dependencies per tool.

## Configuratie, bestandsselectie en modulepad

### Werking van de controles

`--no-config` slaat de automatisch geladen optiebestanden over. Daarna leest `--config .puppet-lint.rc` expliciet de [projectconfiguratie](../../../.puppet-lint.rc). Die laadt het [library-entrypoint](lib/project_lint.rb) met `--load` en leest het [gedeelde profiel](config/puppet-lint.rc) met de native `--config`-optie. Het gedeelde profiel kiest de uitvoeropmaak en laat ook waarschuwingen een foutcode opleveren. De rootconfiguratie voegt de bestandsuitsluitingen van deze repository toe. De externe lintplugins uit de gemspec van `lint-project` worden via de bundle geladen.

De combinatie van beide opties voorkomt invloed van persoonlijke Puppet-lint-instellingen. Een gewone `bundle exec puppet-lint .` leest eerst `/etc/puppet-lint.rc`, daarna `~/.puppet-lint.rc` en ten slotte `.puppet-lint.rc` in de werkmap. Die instellingen worden samengevoegd. Daardoor kan een persoonlijke `--fix` of een eerder uitgeschakelde standaardcheck actief blijven. Alleen `--config` toevoegen voorkomt dat niet; alleen `--no-config` gebruiken laadt juist de projectinstellingen niet.

[Bundler-instellingen](#gems-installeren) bepalen welke gems worden gebruikt en waar die staan. Ze regelen niet welke optiebestanden Puppet-lint leest. Een ander project gebruikt [zijn eigen bundle](#installatie-in-je-project) en geeft de geïnstalleerde gem en configuratie expliciet aan de CLI door.

De afsluitende `.` selecteert de hele repository. Nieuwe manifests en bestanden in `examples/` worden automatisch gevonden; de CLI leest ook YAML. De [projectconfiguratie](../../../.puppet-lint.rc) sluit vendored Git-submodules en gems onder `vendor/bundle` uit. ERB-templates met een YAML-extensie worden pas geldige YAML na renderen en vallen daarom buiten deze scan. Puppet-code in Strings of Markdown vraagt eveneens [afzonderlijke validatie](#aanvullende-validatie).

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

Houd de modules die nodig zijn voor interfacecontrole beschikbaar, ook als hun code buiten de stijlscan valt. Voeg geen regeluitsluitingen toe om echte fouten te verbergen; de toegestane lokale suppressions staan bij de betreffende [codeafspraken](docs/CODE_RULES.md).

De projectconfiguratie gebruikt alle standaard ingeschakelde checks en schakelt daarnaast `class_inherits_from_params_class` in. Ook nieuwe standaardchecks komen bij een update beschikbaar. De optionele checks voor 80 tekens, booleans tussen aanhalingstekens en code op hoofdniveau staan uit: dit project volgt de [regelgrens van 140 tekens](docs/CODE_RULES.md#lange-regels) en ondersteunt daemonstrings zoals `'true'` en uitvoerbare profielen. Bestaande stijlachterstand is geen reden om een check uit te schakelen of een module uit te zonderen.

### Aanroepen van modules controleren

`PROJECT_TOOLS_MODULEPATH` volgt de [gedeelde padvalidatie](../../README.md#gedeeld-modulepad). Zonder deze variabele zoekt de linter vanaf de huidige werkmap als moduleverzameling en slaat hij de vendored namen `concat`, `debconf`, `reboot` en `stdlib` over. Stel de variabele in externe projecten expliciet in.

De resolver gebruikt eerst declaraties uit de actuele lintinvoer. Daarna kiest hij de eerste modulemap met de gevraagde modulenaam en zoekt daar `example/manifests/init.pp` voor `example`, of `example/manifests/item.pp` voor `example::item`. Ontbreekt dat manifest, dan zoekt hij niet verder in een latere kopie van de module. Bestanden achter symlinks buiten de ingestelde modulemap worden niet gelezen.

Controleer environments met verschillende modulepaden apart. Eén samengevoegde lijst kan een andere moduleversie kiezen dan Puppet op de server. De linter leest geen `environment.conf`.

> [!CAUTION]
> Een niet-vindbare declaratie kan geen melding over ontbrekende parameters opleveren. Een geslaagde scan bewijst daarom niet dat Puppet de catalogus kan compileren. Controleer aanroepen ook met de eigen catalogusvalidatie.

Bij vindbare defined types controleert `project_interface_calls` ontbrekende verplichte argumenten, inclusief `Optional[...]` zonder default. Ontbrekende classargumenten worden overgeslagen, ook bij resource-style classdeclaraties: Puppet kan die via automatische parameterlookup uit Hiera krijgen. De linter voert geen lookups uit en leest geen private configuratiedata. Controleer beschikbaarheid en type van classwaarden met cataloguscompilatie in de juiste environment- en nodecontext.

Argumenttypen, onbekende parameters, functies, dynamische namen, `include`/`contain`, overerving en splats worden niet volledig gevalideerd. Ook resource defaults worden niet geanalyseerd, hoewel Puppet die bij defined types kan gebruiken. De [interfaceafspraak en detectiegrenzen](docs/CODE_RULES.md#alle-verplichte-argumenten-doorgeven) beschrijven het onderscheid tussen projectafspraken, lintcontrole en catalogusvalidatie.

`project_parameter_passthrough` gebruikt dezelfde vindbare defined types om per gefilterde key de bronwaarde of brondefault met de ontvangende parameterdefault te vergelijken. De bron wordt in de actuele lintinvoer opgezocht. Een onbekende bron, ontvanger of default geeft geen filtermelding; de [regel voor parameterdoorgifte](docs/CODE_RULES.md#aanroepen-en-publieke-interfaces) beschrijft de verdere grenzen en reviewcriteria.

### Modulemetadata controleren

Volg de [metadatagids](../../metadata/README.md#modulemetadata-controleren) voor deze zelfstandige controle.

#### Metadata in modulemappen

Volg de [metadatagids](../../metadata/README.md#metadata-in-modulemappen) voor deze zelfstandige controle.

#### Metadata in de projectroot

Volg de [metadatagids](../../metadata/README.md#metadata-in-de-projectroot) voor deze zelfstandige controle.

#### Versiebron en rapportage

Volg de [metadatagids](../../metadata/README.md#versiebron-en-rapportage) voor deze zelfstandige controle.

#### Metadata automatisch herstellen

Volg de [metadatagids](../../metadata/README.md#metadata-automatisch-herstellen) voor deze zelfstandige controle.

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

Deze tabel beschrijft Puppet-lint uit de [ontwikkelbundle](../../../Gemfile.lock). Vraag de geïnstalleerde versie op met `bundle exec puppet-lint --version`. De defaults gelden voor beide expliciete projectroutes, tenzij de rij een verschil noemt. Een voorbeeld in de laatste kolom is een **Fragment** met aanvullende CLI-argumenten; voeg het toe aan de [volledige aanroep](#werking-van-de-controles), vóór de invoerpaden. De beschikbaarheid van een optie verandert het eindcontrole- en suppressiebeleid niet.

| Syntax | Doel | Default in het gebruikte profiel | Toegestane waarden | Herhalen/combineren | Wijzigt bestanden | Gebruik bij eindcontrole | Voorbeeld |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `--help`, `-h` | Native hulp tonen | Uit | Geen waarde | Stopt vóór de scan | Nee | Geen scanbewijs | `--help` |
| `--version` | Engineversie tonen | Uit | Geen waarde | Stopt vóór de scan | Nee | Alleen inventaris | `--version` |
| `--no-config` | Automatische systeem-, gebruikers- en werkmapconfiguratie overslaan | Expliciet in beide routes | Geen waarde | Expliciete `--config` blijft actief | Nee | Verplicht in de gedocumenteerde route | `--no-config` |
| `--config FILE`, `-c FILE` | Optiebestand laden | Rootconfiguratie of gedeeld en lokaal consumerprofiel | Bestandspad | Op volgorde; geneste configs direct bij het lezen | Nee, tenzij geladen opties muteren | Volledige profielen laden | `--config .puppet-lint.rc` |
| `--load FILE`, `-l FILE` | Ruby-checkbestand laden | Projectentrypoint | Bestaand Ruby-bestand | Iedere aanroep voert `load` uit | Voert Ruby-code uit; entrypoint zelf wijzigt geen bronnen | Gedocumenteerd entrypoint | `--load .tools/lint/puppet/lib/project_lint.rb` |
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
| `puppet-lint-junit` | Optioneel `--result-status`, daarna exact één rapportpad; native JSON-array via stdin | Geen default; relatief aan werkmap | Extensie wordt niet gecontroleerd. Bovenliggende map moet bestaan. Overschrijft het rapport; Geldige warnings/errors worden XML-failures; gewone conversie retourneert 0. Met `--result-status` geeft geslaagde conversie met actieve bevindingen 10. |
| `rubocop` | `--config`, `--format progress --format junit --out FILE` | Eigen RuboCop-configuratie en expliciet rapportpad | Native formatter, geen afzonderlijke converter; zie [Ruby-controles](#ruby-code-controleren). |
| `rake test` / Minitest | `TEST=...`, `TESTOPTS=...` | Recursieve selectie van tooltests | Zie [testselectie](#testselectie-en-uitvoeropties) en [JUnit-initialisatie](#junit-rapportage-instellen). |

Het afzonderlijke `syntax-junit` volgt de [validatorinterface](../../syntax/README.md#puppet-manifests-valideren).

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
| `MINITEST_REPORTERS_REPORTS_DIR` | Optionele Minitest-rapportage inschakelen | Alleen console-uitvoer | Native reporter schrijft in de werkmap; geef voor rapportage een niet-leeg pad op | Geen; CI kiest `.tools/results/tests` expliciet | Bij relatief pad: werkmap | Zie [testinrichting](../../README.md#gezamenlijke-tooltests); raakt lint/parser niet |
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

Gebruik `bundle exec puppet-lint-junit --help` of `-h` voor de opties. Help volgt het [gezamenlijke CLI-contract](../../README.md#cli-en-rapportage): status 0, gebruiksuitleg op stdout, lege stderr en geen verwerking van stdin of rapportbestand. Onbekende opties geven status 1 met gebruiksuitleg, zonder rapport te schrijven. Voor een bestand waarvan de naam met een streepje begint, gebruik je `--` vóór het pad.

Deze tabel beschrijft de gewone conversie zonder `--result-status`.

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

Met `--result-status` vóór het rapportpad retourneert de converter 10 wanneer de native JSON geldig en niet leeg is, actieve warnings of errors bevat en het JUnit-bestand succesvol is geschreven en gesloten. Zonder actieve bevindingen blijft de code 0; fixed en ignored tellen niet als actieve bevindingen. Conversie- en schrijffouten blijven 1, ook als er al bevindingen zijn getoond. Deze optionele code is een bevindingensignaal, geen native lintstatus. De [CI-aanroepen](../../README.md#controle-in-ci) verwerken het signaal en behouden de oorspronkelijke lint- en conversiefoutstatus; gebruik deze optie niet als vervanging van gewone `pipefail` zonder die afhandeling.

De converter heeft geen lintconfiguratie, manifestselectie of warningbeleid: zulke combinaties zijn niet van toepassing omdat hij alleen stdin omzet. Zonder `--result-status` betekent exitcode 0 geslaagde conversie, ook bij XML-failures. Bewaar de lintstatus met Bash `pipefail`; alleen het bestaan van XML is onvoldoende.

### Exitcodes van syntax-junit

De zelfstandige gem `project-tools-syntax` beheert deze controle. Volg de [validatorhandleiding](../../syntax/README.md#exitcodes-van-syntax-junit) voor de aanroep, selectie en rapportage.

### Overige validatiecommando's

| Executable | Schoon | Bevinding of fout | Ongeldige invoer/configuratie | Rapportagefout en uitvoer |
| --- | --- | --- | --- | --- |
| `puppet parser validate` | 0, doorgaans stil | Syntaxfout: 1, native diagnostic | Ontbrekend bestand: 1; geen lintprofiel | Geen eigen XML; hiervoor bestaat syntax-junit |
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
| `project_layout` | Ja | Ja | [Arrayopmaak en inspringing](docs/CODE_RULES.md#inspringing), [Spatie na komma’s](docs/CODE_RULES.md#spatie-na-kommas), [Meerregelige lijsten met een komma afsluiten](docs/CODE_RULES.md#meerregelige-lijsten-met-een-komma-afsluiten), [Inhoud direct na een openingsaccolade beginnen](docs/CODE_RULES.md#inhoud-direct-na-een-openingsaccolade-beginnen) | Per meldingsvariant: [Arrayopmaak en inspringing](docs/CODE_RULES.md#inspringing), [Spatie na komma’s](docs/CODE_RULES.md#spatie-na-kommas), [Meerregelige lijsten met een komma afsluiten](docs/CODE_RULES.md#meerregelige-lijsten-met-een-komma-afsluiten), [Inhoud direct na een openingsaccolade beginnen](docs/CODE_RULES.md#inhoud-direct-na-een-openingsaccolade-beginnen) | [Arrayopmaak en inspringing](docs/CODE_RULES.md#inspringing), [Spatie na komma’s](docs/CODE_RULES.md#spatie-na-kommas), [Meerregelige lijsten met een komma afsluiten](docs/CODE_RULES.md#meerregelige-lijsten-met-een-komma-afsluiten), [Inhoud direct na een openingsaccolade beginnen](docs/CODE_RULES.md#inhoud-direct-na-een-openingsaccolade-beginnen) |
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
| `project_interface_calls` | Ja | Ja | [Ontbrekende verplichte defineargumenten](docs/CODE_RULES.md#alle-verplichte-argumenten-doorgeven) | Geen: De bedoelde definewaarde is niet afleidbaar | [Alle verplichte argumenten doorgeven](docs/CODE_RULES.md#alle-verplichte-argumenten-doorgeven) |
| `project_parameter_passthrough` | Ja | Ja | [Overbodige parameterdoorgifte rechtstreeks schrijven](docs/CODE_RULES.md#overbodige-parameterdoorgifte-rechtstreeks-schrijven) | Per meldingsvariant: inline identiteitshash; filters, gedeelde hashes en conflicten blijven ter review: [Overbodige parameterdoorgifte rechtstreeks schrijven](docs/CODE_RULES.md#overbodige-parameterdoorgifte-rechtstreeks-schrijven) | [Overbodige parameterdoorgifte rechtstreeks schrijven](docs/CODE_RULES.md#overbodige-parameterdoorgifte-rechtstreeks-schrijven) |
| `project_monitoring_backend` | Ja | Ja | [Targets en monitoring](docs/OPERATIONAL_RULES.md#targets-en-monitoring) | Geen: Backendkeuze kan functioneel gedrag bevatten | [Targets en monitoring](docs/OPERATIONAL_RULES.md#targets-en-monitoring) |
| `project_suppressions` | Ja | Ja | [Alleen toegestane suppressions gebruiken](docs/CODE_RULES.md#alleen-toegestane-suppressions-gebruiken) | Geen: Verwijderen kan andere fixes vrijgeven voordat hun gevolgen zijn beoordeeld | [Alleen toegestane suppressions gebruiken](docs/CODE_RULES.md#alleen-toegestane-suppressions-gebruiken) |
| `project_duplicate_function_calls` | Ja | Ja | [Herhaalde zuivere functieaanroepen lokaal hergebruiken](docs/CODE_RULES.md#herhaalde-zuivere-functieaanroepen-lokaal-hergebruiken) | Voorwaardelijk: één lokale variabele per bewezen groep; onzekere verplaatsing blijft handmatig: [Herhaalde zuivere functieaanroepen lokaal hergebruiken](docs/CODE_RULES.md#herhaalde-zuivere-functieaanroepen-lokaal-hergebruiken) | [Herhaalde zuivere functieaanroepen lokaal hergebruiken](docs/CODE_RULES.md#herhaalde-zuivere-functieaanroepen-lokaal-hergebruiken) |
<!-- END PROJECT CHECK REGISTRY -->

`require 'project_lint'` registreert de checks; de configuratieprofielen bepalen afzonderlijk hun activatie. `--list-checks` toont alleen beschikbaarheid. Controleer bij wijzigingen aan de bundle of registratie dit overzicht tegen het entrypoint, beide profielen en de [configuratietests](tests/cli/configuration_test.rb). De [rootlockfile](../../../Gemfile.lock) beheert de gebruikte gemversies. Leg uitvoeringsresultaten vast in de wijzigingsreview.

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

De checks voor opmaak bewijzen niet dat commentaar inhoudelijk klopt. Voor systemd-hardening, transportbeveiliging, shellgedrag, monitoringdefaults, uitvoertijd en gedeelde checkexecutables bestaat hier geen volledige automatische lintcontrole. De inhoudelijke criteria staan in de gekoppelde regels; de [projectbrede validatieverplichtingen](../../../TESTS.md#testbeleid-en-validatie) blijven daarnaast gelden.


De [native CLI-proeven](tests/native_autofix_test.rb) voeren de beschikbare standaard- en pluginfixes uit, inclusief hercontrole en een ongewijzigde tweede run. De [aanvullende CLI-proeven](tests/cli/safe_fixes_test.rb) bewaken nieuwe projectfixes en de native reference-richting; [cli/diagnostics_test.rb](tests/cli/diagnostics_test.rb) controleert behoud van fileservermounts. De bestaande checkspecifieke CLI-tests blijven de grenzen, interacties en suppressions controleren. De YAML-route van Puppet-lint ondersteunt detectie van legacy facts maar schrijft geen fixes: de parser levert waarden zonder eenduidige schrijfposities voor onder meer aliases en meerregelige scalars. De fixaanroep behoudt deze meldingen zonder een Puppet-tokenstream te renderen; de facts-conversie in deze tabel geldt voor manifests.


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

De algemene codeprincipes, Puppet-coderegels en aanvullende reviewcriteria staan in [CODE_RULES.md](docs/CODE_RULES.md), [DOCUMENTATION_RULES.md](docs/DOCUMENTATION_RULES.md) en [OPERATIONAL_RULES.md](docs/OPERATIONAL_RULES.md). De drie bestanden beschrijven per regel de norm, detectiegrenzen, autofixvoorwaarden, uitzonderingen, voorbeelden en handmatige review. Iedere regel heeft één autoritatieve locatie.

Volg bij iedere Puppet-wijziging de toepasselijke algemene regels:

- [Algemene ontwerpregels](docs/CODE_RULES.md#algemene-ontwerpregels) voor alle eigen code, inclusief tooling.
- [Basisopmaak](docs/CODE_RULES.md#basisopmaak) voor Puppet, inclusief inspringing, komma's en lange regels.
- [Parameters en resources](docs/CODE_RULES.md#parameters-en-resources).

Raakt de wijziging documentatie of codecommentaar, inclusief Puppet Strings en interfacebeschrijvingen, volg dan daarnaast de regels voor [Commentaar en documentatie](docs/DOCUMENTATION_RULES.md#commentaar-en-documentatie), inclusief [Puppet Strings](docs/DOCUMENTATION_RULES.md#puppet-strings).

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

Zonder `--only-checks` worden de beschikbare fixes van zowel standaardchecks als projectchecks gebruikt. Een check kan een melding laten staan wanneer de code niet veilig te herschrijven is. De concrete grenzen staan bij [arrayopmaak en inspringing](docs/CODE_RULES.md#inspringing), [komma's](docs/CODE_RULES.md#kommas), [parameteruitlijning](docs/CODE_RULES.md#parameters-en-instellingen), [commentaarscheiding](docs/DOCUMENTATION_RULES.md#toelichtingen-bij-code), [resource references](docs/CODE_RULES.md#resource-references), [packagegroepen](docs/OPERATIONAL_RULES.md#pakketten-en-mappen) en [Puppet Strings](docs/DOCUMENTATION_RULES.md#puppet-strings).

Arrayopmaak kan arrays zowel samenvouwen als uitvouwen volgens de [60/140-grenzen en beschermde regio’s](docs/CODE_RULES.md#inspringing). De afsluitende arrayfase verwerkt de bron na andere native fixes en hercontroleert bij arraymeldingen de actieve diagnostiek, inclusief opgeloste of resterende lengtemeldingen. Zonder `--fix` of met uitgeschakeld `project_layout` verandert deze fase niets.

Geslaagde correcties verschijnen als `fixed`. Een resterende waarschuwing of fout geeft nog steeds een foutcode. Scan daarna zonder `--fix` opnieuw: buiten de afsluitende arrayfase kunnen meldingen nog over de oorspronkelijke bron gaan.

Bij een syntaxfout schrijft de CLI het manifest niet weg. Genegeerde meldingen worden evenmin gecorrigeerd. Bekijk na de correctieronde de volledige diff en volg de [verdere afronding](#werkwijze-bij-een-wijziging). De gewone projectaanroep en CI controleren alleen; voor correctie gebruik je expliciet `--fix`. Er is geen aparte Rake-task of formatter voor nodig.

## Parservalidatie en Ruby-controles

### Ruby-code controleren

Gebruik de [Ruby-linthandleiding](../ruby/README.md#ruby-code-controleren) voor deze zelfstandige tool.

### Puppet-manifests valideren

De zelfstandige gem `project-tools-syntax` beheert deze controle. Volg de [validatorhandleiding](../../syntax/README.md#puppet-manifests-valideren) voor de aanroep, selectie en rapportage.

### Aanvullende validatie

Voer [metadata- en schemacontrole](../../metadata/README.md) afzonderlijk uit.

Puppet-voorbeelden in Strings en Markdown worden niet door de gewone lintscan gevonden. Werk ze tijdelijk buiten de repository uit tot uitvoerbare invoer en controleer die met de projectlintregels en de parser. Render gewijzigde templates voordat je het resulterende formaat tegen de [operationele bestands- en shellregels](docs/OPERATIONAL_RULES.md) beoordeelt.

Bij gedragswijzigingen onderzoek je wat er op de host verandert: welke bestanden worden geschreven, welke services herstarten en welke rechten of verbindingen daarvoor nodig zijn. Controleer normaal gebruik en een praktisch foutgeval met synthetische invoer. Neem bij een gedeelde bouwsteen alle geraakte gebruikers mee. Voor monitoring gelden de [bijbehorende scenario's](../../../TESTS.md#monitoringvalidatie); voor dependencies de [prerequisitereview](docs/CODE_RULES.md#resources-en-afhankelijkheden).

Deze functionele controles blijven volgens de [testafspraken](../../../TESTS.md#testscope-en-plaatsing) buiten de repositorytests. Leg de uitgevoerde commando's, resultaten en resterende onzekerheid vast in de review.

### Eigen manifests valideren

De zelfstandige gem `project-tools-syntax` beheert deze controle. Volg de [validatorhandleiding](../../syntax/README.md#eigen-manifests-valideren) voor de aanroep, selectie en rapportage.

### Ruby controleren in een ander project

Gebruik de [Ruby-linthandleiding](../ruby/README.md#ruby-controleren-in-een-ander-project) voor deze zelfstandige tool.

### Aanvullende tests

Voer naast linting en de [parservalidatie](#eigen-manifests-valideren) de gedragstests van je eigen project uit, met de Puppet- of OpenVox-versie, facts en Hiera die je daarvoor gebruikt. De ontwikkelbundle van de moduleverzameling is geen vereiste.

De gemtests controleren het lintgereedschap. Ze vervangen geen catalogus-, template-, script- of monitoringvalidatie van afnemende projecten.

## Rapportage en CI

### Lintrapporten maken

Het Puppet-lintrapport gebruikt JUnit XML onder `.tools/lint/puppet/results/`. Andere tools en gezamenlijke testresultaten hebben hun eigen [locaties](../../README.md#ci-van-deze-repository). De gegenereerde rapportmappen zijn uitgesloten van versiebeheer. Afnemende projecten kiezen hun [eigen rapportmap](#rapportmap-kiezen). De onderstaande aanroepen gebruiken dezelfde configuratie, bestandsselectie en foutstatus als de gewone scans. Voer ze afzonderlijk uit vanuit de repositoryroot, met de [ontwikkelbundle](#gems-installeren) geïnstalleerd.

Puppet-lint levert zijn native JSON-uitvoer via een pipe aan `puppet-lint-junit`, de rapportomzetter uit `lint-project`. Die schrijft JUnit XML en toont actieve en gecorrigeerde meldingen met bronpositie in de console. De converter sorteert op pad, regel, kolom en check; de telling `Files reported` komt uit de native JSON-groepen en is geen JUnit-testcasetelling. Fouten, waarschuwingen, fixes en genegeerde bevindingen hebben afzonderlijke tellingen. De aanroep blijft eigenaar van start, activiteit en de uiteindelijke scanstatus volgens het [centrale logcontract](../../README.md#joblogs); de converter kan uit JSON geen waarschuwingdrempel of oorspronkelijke processtatus reconstrueren. Ook bij een onschrijfbaar rapport blijven beschikbare lintbevindingen zichtbaar. Gebruik Bash met `pipefail`:

**Werkmap:** Repositoryroot. **Shell:** Bash met pipefail. **Vereisten:** Ontwikkelbundle. **Invoer:** Volledige lintselectie. **Wijzigt bestanden:** Puppet-lint-JUnit in .tools/lint/puppet/results. **Verwacht resultaat:** Lint- én conversiestatus behouden.

```bash
set -o pipefail
mkdir -p .tools/lint/puppet/results
bundle exec puppet-lint --no-config --config .puppet-lint.rc --json . | bundle exec puppet-lint-junit .tools/lint/puppet/results/puppet-lint-report.xml
```

`pipefail` bewaart de foutstatus van Puppet-lint en laat ook een mislukte omzetting falen. De omzetter controleert geen Puppet-code en voert de linter niet opnieuw uit. De JSON-invoer blijft intern in de pipe; het opgeslagen artifact bevat XML. Gebruik het gedeelde profiel met `--fail-on-warnings`, zodat actieve waarschuwingen zowel de job als het rapport laten falen.

Het Puppet-rapport groepeert actieve meldingen per bestand en check in één JUnit-testcase. De fouttekst bevat alle bijbehorende regels, kolommen en meldingen. Genegeerde en gecorrigeerde meldingen tellen niet als fout. Een scan zonder actieve bevindingen krijgt één geslaagde testcase voor de gehele scan; dat is geen telling van gecontroleerde manifests of functionele tests. Ontbrekende of ongeldige JSON-invoer en een scan zonder gerapporteerde bestanden leveren een rapport met `ReportError` en een foutcode op. Het opgegeven rapportbestand wordt bij iedere uitvoering vervangen; een eventuele bovenliggende map moet bestaan.

Voor Ruby-rapporten gebruik je de [native RuboCop-aanroep](../../README.md#rapporten-en-artifacts-in-je-project). De [parservalidatie](../../syntax/README.md) en [tooltests](../../README.md#gezamenlijke-tooltests) houden hun eigen rapporten.

### Rapportmap kiezen

Zie de [gezamenlijke toolinghandleiding](../../README.md#rapportmap-kiezen) voor deze procedure.

### CI van deze repository

Zie de [gezamenlijke toolinghandleiding](../../README.md#ci-van-deze-repository) voor deze procedure.

### Rapporten en artifacts in je project

Zie de [gezamenlijke toolinghandleiding](../../README.md#rapporten-en-artifacts-in-je-project) voor deze procedure.

### Controle in CI

Zie de [gezamenlijke toolinghandleiding](../../README.md#controle-in-ci) voor deze procedure.

#### Rapporten tonen in GitLab

Zie de [gezamenlijke toolinghandleiding](../../README.md#rapporten-tonen-in-gitlab) voor deze procedure.

## Importeren en distribueren

<a id="de-linter-gebruiken-in-een-ander-puppet-project"></a>

Zie de [gezamenlijke toolinghandleiding](../../README.md#importeren-en-distribueren) voor deze procedure.

### Gedeelde tooling hergebruiken

Zie de [gezamenlijke toolinghandleiding](../../README.md#gedeelde-tooling-hergebruiken) voor deze procedure.

### Benodigdheden

Zie de [gezamenlijke toolinghandleiding](../../README.md#benodigdheden) voor deze procedure.

### Aanbevolen projectstructuur

Zie de [gezamenlijke toolinghandleiding](../../README.md#aanbevolen-projectstructuur) voor deze procedure.

### Installatie in je project

Zie de [gezamenlijke toolinghandleiding](../../README.md#installatie-in-je-project) voor deze procedure.

### Eigen code controleren

Het voorbeeld hieronder controleert twee concrete manifests. Stel het modulepad in voor het opzoeken van declaraties; [metadata](../../metadata/README.md) heeft een eigen commando.

**Werkmap:** Consumerroot. **Shell:** POSIX shell met errexit. **Vereisten:** Eigen bundle, lokale configuratie en bestaande genoemde manifests/modulemappen. **Invoer:** De twee expliciet genoemde bestanden. **Wijzigt bestanden:** Geen bronbestanden. **Verwacht resultaat:** Volledige profielcontrole van deze selectie.

```sh
set -e
lint_gem="$(bundle info --path lint-project)"
export PROJECT_TOOLS_MODULEPATH="$PWD/global-modules:$PWD/modules"
test -f .puppet-lint.rc
bundle exec puppet-lint --no-config --load "$lint_gem/lib/project_lint.rb" --config "$lint_gem/config/puppet-lint.rc" --config .puppet-lint.rc environments/production/manifests/site.pp modules/profile/manifests/init.pp
```

Vervang de modulemappen en manifestpaden door bestaande paden in jouw project. De paden in `PROJECT_TOOLS_MODULEPATH` moeten absoluut zijn en dezelfde volgorde hebben als in de gekozen Puppet environment; het voorbeeld volgt de [module-installatie](../../../README.md#installatie), met `global-modules` vóór `modules`. Voeg andere gebruikte modulemappen expliciet toe. Het voorbeeld stopt met `set -e` bij een fout. `test -f` is nodig omdat de native CLI een ontbrekend optiebestand stilzwijgend overslaat. `--no-config` voorkomt dat systeem- of persoonlijke lintopties worden ingelezen. De twee `--config`-opties lezen eerst het gedeelde profiel en vervolgens je eigen bestandsuitsluitingen.

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
cd .tools/lint/puppet
gem build lint-project.gemspec --output /tmp/lint-project.gem
```

Het pakket bevat alleen `lib/`, `bin/`, `config/`, `README.md`, `docs/CODE_RULES.md`, `docs/DOCUMENTATION_RULES.md`, `docs/OPERATIONAL_RULES.md` en de licentie, inclusief `puppet-lint-junit` en een expliciete dependency op `project-tools-shared`. De [pakketprocedure](../../README.md#gebouwd-gempakket-installeren) bouwt en levert shared afzonderlijk mee. Tests, ontwikkelgems en Puppet-modules zijn geen onderdeel van de distributie. Publicatie naar RubyGems is niet nodig; je kunt het bestand via je eigen goedgekeurde distributieroute beschikbaar maken. Een ontvangend project installeert zijn eigen dependencies en bewaart zijn eigen lockfile.

Volg bij een update de [consumermigratie](../../README.md#migreren-naar-afzonderlijke-toolpakketten) voor de afzonderlijke metadata- en Ruby-tools en gewijzigde gedeelde instellingen.

Het [checkoverzicht](#beschikbare-projectchecks) vermeldt de actieve controles en verwijst naar hun detectie- en autofixvoorwaarden. Let bij de [packageguard-fix](docs/OPERATIONAL_RULES.md#gelijk-ingestelde-packageguards-samenvoegen) op de runtimevoorwaarde: de gegenereerde Puppet-code gebruikt `stdlib::ensure_packages()` uit stdlib; de linter levert die module niet mee. Conflicterende package-attributen blijven als catalogusfout zichtbaar.

Checknamen, meldingsniveaus, veilige fixresultaten, `PROJECT_TOOLS_MODULEPATH`, het entrypoint, gedeelde configuratiepaden en rapportcommando's zijn publieke interfaces; de [ontwikkelinstructies](#architectuurreview) beschrijven de review ervan. Verhoog de gemversie bij een uitgave en beschrijf wijzigingen die afnemers raken. Wijzigingen aan actieve regels en profielen kunnen bestaande projecten laten falen; laat afnemers zo’n update bewust uitvoeren met Bundler en hun eigen CI. Werk een Git-afnemer bij naar een gecontroleerde revisie en een pakketafnemer naar een gecontroleerde gemversie.

### Git-dependency uit de monorepo

Zie de [gezamenlijke toolinghandleiding](../../README.md#git-dependency-uit-de-monorepo) voor deze procedure.

### Gebouwd gempakket installeren

Zie de [gezamenlijke toolinghandleiding](../../README.md#gebouwd-gempakket-installeren) voor deze procedure.

## Linter ontwikkelen en testen

<a id="linter-ontwikkelen-en-onderhouden"></a>

Dit gedeelte beschrijft de lintarchitectuur, fixinteracties en testaanroepen. De onderhoudssecties hieronder regelen checkontwikkeling, veilige autofix en de configuratieroute, binnen [CONTRIBUTING](../../../CONTRIBUTING.md) en [TESTS](../../../TESTS.md). Gezamenlijke installatie, distributie en CI staan in de [toolinghandleiding](../../README.md). Voor een gewone Puppet-wijziging volstaan de [werkwijze](#werkwijze-bij-een-wijziging) en de relevante codeafspraken.

### Checkontwikkeling

- Begin bij de bestaande codenorm en onderscheid automatisch bewijs van handmatige review. Onderzoek eerst of een native check, geïnstalleerde plugin of projectcheck het contract al behandelt; breid die waar mogelijk uit in plaats van concurrerende detectie of correctie toe te voegen.
- Beoordeel iedere nieuwe of gewijzigde lintregel per meldingsvariant op veilige automatische correctie, ook bestaande checks zonder autofix. Implementeer een fix wanneer beschikbare informatie de correctie eenduidig bepaalt en behoud van gedrag en gegevens aantoonbaar is. Implementeer een veilige deelverzameling als slechts een deel eenduidig is. Baseer fixes nooit op onbewezen aannames of ontwerpkeuzes die gedrag of data kunnen schaden. Leg het oordeel vast onder `Autofix` en `Autofixvoorwaarden`; benoem bij ontbrekende of gedeeltelijke fixes welke informatie, handmatige beslissing of technische mogelijkheid ontbreekt.
- Volg de [native registratie en architectuur](#technische-werking-van-de-checks). Iedere manifestcheck heeft een eigen bestand onder `lib/project_lint/checks/`, genoemd naar de check zonder `project_`, met zijn `ProjectLint::Checks`-module, `PuppetLint.new_check(:project_...) { include CheckModule }`, `check` en optioneel `fix(problem)`. Voeg de gewone `require` toe aan `lib/project_lint.rb`.
- Meld oorzaak en bruikbare bronpositie zonder willekeurige bronwaarden in diagnostiek of JSON. Gebruik `[review]` wanneer analyse de gewenste eigenschap of correctie niet kan vaststellen.
- Werk de norm en het [checkregister](#beschikbare-projectchecks) samen bij, met feitelijke detectie, autofix en handmatige dekking. Pas de [gezamenlijke verplichting voor gewijzigde Puppet-conventies](../../../CONTRIBUTING.md#impact-en-inhoudelijke-review) toe.
- Test geldig en ongeldig gebruik, grenzen en analyselimieten via de echte library-ingang en native configuratie. Test bij package-, configuratie- of CLI-wijzigingen ook installatie, exitcodes, geladen regels en isolatie van persoonlijke opties in een onafhankelijk project. Gebruik tijdens ontwikkeling de [linttests](#tests-uitvoeren-en-uitbreiden) en vóór oplevering de [verplichte eindcontroles](../../../TESTS.md#controlevolgorde-en-verplichte-eindcontroles).

### Architectuurreview

- Gebruik bij voorkeur Puppet-lints native registratie, configuratie, diagnostiek, suppressions en autofix-API's. Houd eenvoudige tokenchecks vrij van onnodige AST-analyse en behoud de gedeelde analyse- en laadcontracten uit de [architectuur](#technische-werking-van-de-checks).
- Houd Ruby-helpers in `ProjectLint` met conventionele namespacegebonden require-paden. Voeg geen top-level helperconstants of bij laden vastgelegde mutable configuratie toe.
- Deel helpers voor concrete begrippen zoals resource-attributen, commentaargrenzen, variabeledependencies en modulepaden. Houd substantiële zelfstandige analyses, zoals backendherkomst of shellescaping, los van hun checks; eenvoudige checkspecifieke methoden blijven bij de check. Een grotere analyse mag binnen hetzelfde bestand worden verdeeld, bijvoorbeeld commentaaropmaak, regelbreedte en suppressions, met behoud van samenhang en RuboCopregels. Extraheer alleen bestaande gedeelde complexiteit of een substantiële zelfstandige analyse, zonder speculatieve abstracties.
- Behandel checknamen, severities, veilige fixresultaten, `PROJECT_TOOLS_MODULEPATH`, het entrypoint, gedeelde configuratiepaden en rapportcommando's als publieke interfaces. Beoordeel wijzigingen volgens het [releasebeleid](../../../CONTRIBUTING.md#compatibiliteit-en-versies) en valideer de gebouwde gem in een onafhankelijk project. Houd consumerinstallatie en CI-voorbeelden in lijn met de [ondersteunde structuur](#aanbevolen-projectstructuur); documenteer afwijkingen zonder implementaties of gedeelde profielen te kopiëren. Volg de [gemreleaseprocedure](#een-gem-bouwen-en-versie-uitbrengen) en beschrijf gevolgen voor consumers.

### Veilige autofix ontwikkelen

- Inspecteer de echte bundle met `bundle exec puppet-lint --no-config --config .puppet-lint.rc --version` en `bundle show puppet-lint`. Hergebruik native, plugin- en projectdetectie en veilige fixes. Gebruik uitsluitend het native Puppet-lintfixmechanisme, zonder formatter of eigen autofixengine.
- Iedere eigen fix moet idempotent zijn en voldoen aan de [dagelijkse correctieveiligheid](#werkwijze-bij-een-wijziging): veilig, deterministisch, afgebakend en met behoud van gedrag, relaties, dependencies en configuratie. Review de hele geraakte constructie, behoud commentaar, valideer gegenereerde Puppet-syntax en verifieer dat de opgeloste melding verdwijnt.
- Implementeer `fix(problem)` naast `check` in de geregistreerde module. Bewaar tokenobjecten en correctievoorwaarden tijdens `check`; diagnostiek verwijst per index naar die context in plaats van bronwaarden in JSON te tonen. Controleer alle voorwaarden vóór tokenmutatie; gebruik `PuppetLint::NoFix` als ze ontbreken, zodat de oorspronkelijke melding blijft.
- Gebruik native `add_token`, `remove_token` en bestaande tokeneigenschappen. Hergebruik tokens die andere checks kunnen veranderen en bereken spacing uit actuele tokeninhoud. Regel- en kolomnummers verwijzen nog naar de oorspronkelijke bron. Gebruik [TokenHelpers](lib/project_lint/token_helpers.rb) voor gebieden en witruimte, geen complete bestandsparser of -herschrijver.
- Houd rekening met eerdere fixes die tokens na detectie veranderen of verwijderen. Behoud [fixinteracties](#autofixinteracties), native `lint:ignore` en `fix(problem)`-afhandeling. Een meerregelige correctie controleert ook of zij een genegeerd gebied zou aanpassen.
- Voeg regressiedekking toe voor detectie zonder mutatie, exacte uitvoer, schone hercontrole en ongewijzigde tweede fixrun. Neem ongeschikte invoer, suppressions, commentaar, strings, meerdere problemen, nesting en interacties met actieve upstreamchecks mee. Test native CLI-schrijven en exitcodes op tijdelijke bestanden, inclusief configuratiekeuze, gedeeltelijke correcties en onveilige gevallen. Ondersteun autofix pas wanneer de gewone `--fix` aantoonbaar de bedoelde wijziging schrijft en herscannen de melding oplost. Parservalidatie van fixuitvoer hoort bij dit toolcontract; algemene modulesyntaxsuites blijven erbuiten volgens TESTS.
- Houd gewone CLI en CI check-only. Schakel `fix` uitsluitend in een expliciete correctiestap in en voeg geen tweede formatter of automatische commitstap toe.

### Linttests onderhouden

Gebruik de [bestaande testondersteuning](#tests-uitvoeren-en-uitbreiden): gewone `Minitest::Test`, native linthelper en publieke configuratie. Houd korte invoer in Ruby; gebruik fixtures voor grotere of hergebruikte scenario's wanneer dat duidelijker is. Behoud expliciete fixtureselectie en falen bij lege verzamelingen, zonder gespecialiseerde basisklassen of uit methodenamen afgeleide fixtures.

Gebruik `assert_fix(before, after, :project_check_name)` voor detectie, exacte correctie, parservalidatie, schone hercontrole en idempotentie. Test onveilige constructies met `fix: true` en ongewijzigde invoer. Behoud interactiedekking tussen checks.

Onderzoek fouten vanuit gemelde invoer en assertion. Voer tijdens ontwikkeling de betrokken test afzonderlijk uit en eindig met de volledige toolsuite. Vereis bij controle van de GitHub-uitvoervorm met `GITHUB_ACTION=synthetic_test` dezelfde diagnostische aantallen als bij gewone uitvoer.

### Technische werking van de checks

De interne gem maakt de runtime-afhankelijkheden, laadpaden en gedeelde profielen beschikbaar aan andere projecten zonder dat zij onze ontwikkelbundle hoeven te gebruiken. De gem volgt de [RubyGems-libraryconventies](https://guides.rubygems.org/make-your-own-gem/): een entrypoint, eigen code onder `ProjectLint` en runtime-afhankelijkheden in de [gemspec](lint-project.gemspec). Het root-Gemfile en Rakefile blijven verantwoordelijk voor de ontwikkeling van alle repositorytools. De [gedeelde ontwikkelinstructies](../../README.md#verantwoordelijkheden-en-integratie-reviewen) regelen het onderhoud van deze packagegrenzen. De [Bundler-documentatie](https://bundler.io/guides/git.html) beschrijft hoe dezelfde gem vanuit een checkout of Git-bron kan worden gebruikt.

```text
.tools/lint/puppet/
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
├── AGENTS.md                # Agentleesroute in de checkout.
├── README.md                # Gebruik, onderhoud, architectuur en checkregister.
└── docs/
    ├── CODE_RULES.md          # Algemene codeprincipes en aanvullende Puppet-regels.
    ├── DOCUMENTATION_RULES.md # Algemene documentatienormen en specifieke codeafspraken.
    └── OPERATIONAL_RULES.md   # Operationele normen met specifieke uitwerkingen.
```

Puppet-lint blijft de lintengine. De checks gebruiken zijn tokens, `notify`, suppressions, `PuppetLint::NoFix`, `add_token` en `remove_token`. De native CLI bepaalt opties, manifestdetectie, rapportage, foutstatus en correcties. Eenvoudige tokenchecks, zoals de controle van Puppet-URLs, hebben geen AST nodig.

[`PuppetJunit`](lib/project_lint/puppet_junit.rb) verwerkt uitsluitend de native JSON-uitvoer voor de [JUnit-rapportage](#lintrapporten-maken). Het uitvoerbare commando `puppet-lint-junit` komt uit dezelfde gem. De omzetter gebruikt `builder` voor XML-escaping, neemt alleen diagnostische velden op en wijzigt geen lintconfiguratie. De [reportertests](tests/puppet_junit/conversion_test.rb) controleren geldige en ongeldige invoer, unieke testcases en foutdetails; de [pakkettest](tests/external/junit_test.rb) controleert de volledige pipe vanuit een onafhankelijk geïnstalleerde gem.

[`JunitReport`](lib/project_lint/junit_report.rb) verwijst naar de gedeelde XML-schrijver in `project-tools-shared`. De zelfstandige [validatorgem](../../syntax/README.md) beheert parserorkestratie en de bijbehorende tests.

[`Ast`](lib/project_lint/ast.rb) voegt alleen de structurele informatie van de OpenVox-parser toe: declaraties, expressies, resources en hun omliggende scopes. De tokenindexen van Puppet-lint leveren die volledige structuur niet. Alle structurele checks delen één AST voor de huidige lintinvoer; een nieuwe scan vervangt die analyse, ook bij gelijke tekst in een ander bestand. De analyse voert geen Puppet-functies of catalogi uit. Alleen echte `Puppet::ParseError`-meldingen worden omgezet naar een syntaxfout; programmeerfouten blijven fouten. Een onbekende constructie krijgt waar nodig een reviewmelding.

Het entrypoint laadt eerst `puppet-lint` en daarna de eigen checks. Gebruik daarom `--load` zoals in de voorbeelden, of `require 'project_lint'` vanuit Ruby. Automatische registratie van manifestchecks via `lib/puppet-lint/plugins/` wordt bewust niet gebruikt: Puppet-lint laadt gemplugins met `load`, in gemvolgorde. De externe trailing-comma-plugin bewaart oorspronkelijke tokenankers die referencefixes kunnen verwijderen. Door het projectentrypoint na de engine te laden, zijn de upstream-fixes al geregistreerd en blijven beide transformaties bruikbaar. De integratietests bewaken deze laadroute en herhaald laden veroorzaakt geen dubbele registraties. De [native API](https://puppet-lint.com/developer/api/) en de onderhouden [parameterplugin](https://github.com/voxpupuli/puppet-lint-param-types) zijn het uitgangspunt voor nieuwe checks; afhankelijkheden en hun werkelijk geïnstalleerde implementatie bepalen de grenzen van autofix.

[`native_fixes.rb`](lib/project_lint/native_fixes.rb) vult de bestaande native checks voor reference-richting en pijlspaties aan en begrenst facts-conversie tot aantoonbaar schrijfbare invoer. De Puppet-URL-check weigert daarnaast de upstream-mountkeuze. Deze uitbreidingen behouden de bestaande checknamen, selectie, suppressions en fixafhandeling; zij registreren geen concurrerende checks.


[`ModuleResolver`](lib/project_lint/module_resolver.rb) leest het modulepad bij het maken van een analyse, zodat een volgende scan gewijzigde environmentinstellingen kan gebruiken. Gevonden bestanden worden alleen binnen die analyse gecachet en bij gewijzigde bestandsmetadata opnieuw gelezen. Er zijn geen modulepaden die tijdens `require` als globale constants worden vastgelegd. De regels voor vindbaarheid staan bij [Aanroepen van modules controleren](#aanroepen-van-modules-controleren).

#### Herhaalde functieaanroepen

`project_duplicate_function_calls` is standaard actief in beide profielen. Vanaf twee structureel gelijke, bewezen herhaalbare aanroepen volgt één `warning` op de tweede aanroep, met de regel van de eerste. De melding bevat geen argumentwaarden. Met `--fail-on-warnings` kan deze nieuwe check de scan laten falen; inventariseer bevindingen vóór een consumerupdate. De [norm en reviewcriteria](docs/CODE_RULES.md#herhaalde-zuivere-functieaanroepen-lokaal-hergebruiken) blijven ook buiten de automatische dekking gelden.

Het interne register in [duplicate_function_calls.rb](lib/project_lint/checks/duplicate_function_calls.rb) is beoordeeld tegen OpenVox 8.29.0 en stdlib 10.1.0 uit de checkout. De bestaande gemspecafhankelijkheden veranderen niet. Controleer bij runtime-updates opnieuw dispatches en implementaties; de [Puppet-functiereferentie](https://help.puppet.com/core/current/Content/PuppetCore/Markdown/function.htm), [conversiereferentie](https://help.puppet.com/core/current/Content/PuppetCore/typecasting.htm) en [stdlib 10.1.0-bron](https://github.com/puppetlabs/puppetlabs-stdlib/tree/v10.1.0/lib/puppet) helpen die review, maar vervangen haar niet.

Alleen onderstaande exacte namen en positionele vormen zijn ingeschakeld. `Data` betekent gewone Puppet-data: scalars, `undef`, arrays daarvan en hashes met stringkeys; `ScalarData` betekent string, getal of boolean. `Collection` is hier `Array[Data]` of `Hash[String, Data]`. Vierkante tekst tussen haakjes in de argumentkolom geeft optionele argumenten aan, geen Puppet-typesyntax. De resultaatkolom is een conservatief statisch type, geen uitvoering van de functie.

| Exacte functie | Ingeschakelde argumenten | Resultaat en begrenzing |
| --- | --- | --- |
| `String` | `Data`[, niet-lege String-opmaak] | String; geen object- of type-opmaakhash |
| `Integer` | String/Numeric/Boolean[, letterlijke radix 2/8/10/16[, Boolean absolute waarde]] | Integer; geen named options of `default`-radix |
| `Float` | String/Numeric/Boolean[, Boolean absolute waarde] | Float; geen named options |
| `Boolean` | String/Numeric/Boolean | Boolean; geen objectconversie |
| `Array` | Collection[, Boolean wrap], of Data met expliciet `true` | Array van Data; geen Iterable of iterator |
| `Hash` | Hash met stringkeys, array van stringkey/waarde-paren, of even scalaire array met statisch bewezen stringkeys | Hash met stringkeys; geen tree-conversie of objecten |
| `downcase`, `upcase`, `capitalize` | Eén String | String; geen array- of hashvorm |
| `strip`, `lstrip`, `rstrip`, `chomp`, `chop` | Eén String | String; geen meervoudige of collectie-invoer |
| `sprintf` | String-opmaak en één of meer ScalarData-argumenten | String; geen named format-hash |
| `join` | Array van Data[, String-scheidingsteken] | String |
| `split` | String, String of letterlijke Regexp | Array van strings |
| `regsubst` | String, String/Regexp-patroon, String-vervanging[, letterlijke flags] | String; stringpatroon: uitsluitend G/E/I/M; regex: leeg of G; geen vijfde encodingargument |
| `keys`, `values` | Hash met stringkeys en Data-waarden | Array van scalars respectievelijk Data; volgorde blijft relevant |
| `dig` | Collection en één of meer String/Integer-sleutels | Data; geen objectnavigatie |
| `length`, `size`, `empty` | String of Collection | Integer, Integer respectievelijk Boolean |
| `flatten` | Eén Array van Data | Array van Data; geen variadische vorm |
| `sort` | Array van uitsluitend strings of uitsluitend getallen | Array van Data; geen comparatorblok of gemengde typen |
| `unique` | Array van Data | Array van Data; geen blok of stringvorm |
| `abs`, `floor`, `ceiling`, `round` | Eén Numeric | Numeric voor abs, anders Integer; geen deprecated stringoverloads |
| `stdlib::to_json` | Eén Data | String; geen opties |
| `stdlib::to_json_pretty` | Collection[, Boolean skip_undef] | String; geen formatteringshash of expliciete undef-optie |
| `stdlib::to_yaml` | Eén Data | String; geen optieshash |
| `stdlib::merge` | Twee of meer hashes met stringkeys en Data-waarden | Hash; geen codeblok |
| `stdlib::shell_escape` | Eén String | String |
| `shell_join`, `shell_split` | Array van strings respectievelijk één String | String respectievelijk Array van strings |
| `base64` | encode/decode, String[, default/strict/urlsafe] | String; bewerking en variant moeten door hun letterlijke waarde of Enum-type vaststaan |
| `basename` | String[, String-suffix] | String; uitsluitend padtekst |
| `dirname` | Niet-lege String | String; uitsluitend padtekst |
| `stdlib::sha256` | Eén ScalarData | String; geen undef, collectie of object |
| `stdlib::seeded_rand` | Positieve Integer, String-seed | Integer; beide argumenten expliciet en veilig |

Niet genoemde overloads zijn uitgeschakeld. Met name JSON/YAML-optieshashes, named conversieopties en type-opmaakhashes zijn niet als complete veilige vorm getest; de check doet daarvoor geen veiligheidsclaim. Array/Hash-iterators en codeblokken hebben uitvoerbaar gedrag. Deprecated numerieke stringoverloads en aliassen worden niet overgenomen. `stdlib::basename` wordt bijvoorbeeld niet verzonnen. De gerichte [registertests](tests/duplicate_function/registry_test.rb) bevatten positieve varianten en uitgesloten invoer voor iedere ingeschakelde naam.

Voor stdlib vergelijkt de resolver de gekozen implementatiebestanden met de beoordeelde SHA-256-identiteiten; JSON/YAML vereisen ook de bekende `rewrap_sensitive_data`-helper. Afwijkende, ontbrekende of overschaduwde bestanden vallen buiten detectie. De resolver volgt het [modulepad](#aanroepen-van-modules-controleren), leest geen manifestfuncties in als Ruby-code en voert ze niet uit. Voor ingebouwde namen weigert hij zichtbare gelijknamige implementaties in de invoer, modulemappen of environmentfuncties. Stem het lintmodulepad af op de werkelijke environment; code die alleen elders op de server beschikbaar is kan de linter niet bewijzen.

De volledige argumentboom moet veilig zijn. `String(lookup('example::value'))` is uitgesloten, net als `Deferred`, `Sensitive`, eigen objecten, captures zoals `$1`, onbekende variabelen en dynamische aanroepen. Een eerdere eenduidige toekenning uit `lookup('example::value', Integer)` levert wel statische type-informatie: alleen herhaald gebruik van de al vastgelegde waarde wordt gedeeld. Ook ingebouwde parametertypen en eerdere gewone lokale waarden tellen mee; typealiases, gekwalificeerde variabelen en algemene datastroomanalyse blijven buiten bereik.

Structurele sleutels behouden functie, geordende argumenten, letterlijke typen en waarden, opties, regexopties, array- en hashvolgorde en bindingen. Spaties en bronposities veranderen die sleutel niet. De detectie groepeert binnen één resource-expressie en tussen zelfstandige gewone resources met dezelfde directe AST-blokouder. Iedere aanroep bewaart haar eigen resource-eigenaar. Afzonderlijke branches of scopes en andere soorten statements worden niet gecombineerd. Aanroepen onder kortsluiting, selectors, lambda's, interpolatie of heredocs worden niet verplaatst of als onvoorwaardelijke groep gemeld. Groepen van grotere gedeelde expressies gaan vóór volledig afgedekte binnenste groepen.

Autofix vereist per betrokken resource één gewone resourcebody op een veilige statementgrens. De toekenning blijft binnen de bestaande branch, na haar afhankelijkheden en direct vóór de eerste betrokken resource. Bij één eigenaar komt zij onder het volledige gewone toelichtingsblok, zonder lege regel tussen commentaar, toekenning en resource. Bij meerdere eigenaren komt zij vóór het commentaar van de eerste resource, met één lege regel ertussen. Alle resourcecommentaren blijven ongewijzigd bij hun declaratie; ook identieke teksten worden niet samengevoegd. De titel en eerdere argumenten mogen geen relevante evaluatie of mogelijk falende andere aanroep veroorzaken vóór de eerste kandidaat. Onbekende tussenliggende evaluaties en andere soorten statements tussen betrokken resources verhinderen de fix. Bij naamconflict, overerving, commentaar in de aanroep, meerregelige eerste aanroep, gewijzigde tokenankers of suppressions blijft de warning staan en weigert `PuppetLint::NoFix` vóór iedere wijziging. Alle vervangingen en de toekenning worden vooraf voorbereid. Meerregelige latere voorkomens mogen worden vervangen wanneer hun volledige tokenbereik veilig is.

Eén duidelijke bronvariabele krijgt een bewerkingssuffix, bijvoorbeeld `_string`, `_integer`, `_float`, `_boolean`, `_array`, `_hash` of `_json`. Anders gebruikt de check een vaste naam zoals `$sprintf_result`. Bestaande namen worden niet overschreven of automatisch genummerd. De fix verzint geen toelichting. Zonder gewone toelichting voor een nieuwe variabelegroep bij blokbegin blijft de warning staan. Een resourcecommentaar wordt bij gedeeld gebruik nooit als groepscommentaar geïnterpreteerd. Ook een nieuwe onafhankelijke toekenning na een al afhankelijke variabelegroep kan handmatige uitleg vereisen; daarbij tellen eerder in dezelfde fix-run ingevoegde variabelen mee. Lintmarkeringen, Puppet Strings-tags, formatteringsaanwijzingen en herkenbare beheer- of licentieheaders in het betrokken bereik verhinderen autofix. Inline commentaar blijft aan de oorspronkelijke code gebonden. Zie de [plaatsingsnorm](docs/DOCUMENTATION_RULES.md#toelichtingsblokken-van-eerdere-code-scheiden) en [groepsuitleg](docs/DOCUMENTATION_RULES.md#een-variabelegroep-bij-blokbegin-toelichten). Handmatige correctie kiest een geschikte naam en bewijst dezelfde voorwaarden, inclusief mogelijke fouten en indirecte naamafnemers.

Fragment uit Nextcloud; `$files_max_chunk_size` is daar een getypeerde Integer-parameter. Alleen de dubbele conversie wordt gedeeld. Vóór correctie:

```puppet
# Compare the string stored by config:app:set so an unchanged chunk size does not trigger another write.
docker::nextcloud_occ { "${name}_files_max_chunk_size":
  command      => [
    'config:app:set',
    'files',
    'max_chunk_size',
    '--value',
    String($files_max_chunk_size),
  ],
  compose_name => $name,
  unless       => ['config:app:get', 'files', 'max_chunk_size'],
  unless_json  => stdlib::to_json(String($files_max_chunk_size)),
}
```

Na correctie, binnen dezelfde bestaande voorwaarde:

```puppet
# Compare the string stored by config:app:set so an unchanged chunk size does not trigger another write.
$files_max_chunk_size_string = String($files_max_chunk_size)
docker::nextcloud_occ { "${name}_files_max_chunk_size":
  command      => [
    'config:app:set',
    'files',
    'max_chunk_size',
    '--value',
    $files_max_chunk_size_string,
  ],
  compose_name => $name,
  unless       => ['config:app:get', 'files', 'max_chunk_size'],
  unless_json  => stdlib::to_json($files_max_chunk_size_string),
}
```

Gebruik de [native CLI-route](#werking-van-de-controles) met `--only-checks project_duplicate_function_calls` voor inventarisatie en voeg alleen voor de gekozen bestanden `--fix` toe. Controleer daarna de diff, het volledige profiel, de native parser en een ongewijzigde tweede fixrun. De [CLI-tests](tests/cli/duplicate_function_calls_test.rb) controleren ook console/JSON/JUnit zonder argumentwaarden, scan zonder schrijven en samenwerking met opmaakchecks. De [consumertest](tests/external/duplicate_function_calls_test.rb) controleert de gebouwde gem zonder ontwikkelcheckout. Parseracceptatie bewijst geen volledige semantische gelijkheid; voer de toepasselijke functionele controles afzonderlijk uit.

#### Omvang en validatiestructuur

`project_positive_flow` meldt een `if`-tak die minder codestructuur bevat dan de bijbehorende `else`. Een opdracht telt als één onderdeel; geneste blokken, resource-instanties, attributen en elementen in arrays, hashes en selectors tellen mee. Commentaar, witruimte, de lengte van strings en gewone functieargumenten tellen niet als extra opdrachten. Naast deze algemene vergelijking controleert dezelfde check de afsluitende structuur van validaties met `fail(...)` en `warning(...)`.

De validatiecontrole herkent rechtstreekse Puppet-aanroepen van `warning()` en `fail()`, ook met een voorloop-`::`, in classes, defined types, nodeblokken en op manifest-topniveau. De dichtstbijzijnde declaratie bepaalt de grens: de body van `HostClassDefinition`, `ResourceTypeDefinition` of `NodeDefinition`; zonder zo’n declaratie geldt de body van `Program`. Andere declaraties, waaronder functiedefinities, en parameterdefaults vallen buiten de validatieanalyse. Strings, commentaar en functies zoals `example::warning()` zijn geen validatieaanroepen.

De melding hoort rechtstreeks in de uitsluitend diagnostische afsluitende `else` of laatste `default` van een bestaande `case`, eventueel met lokale voorbereiding voor de meldingen. Vanaf die keuze volgt de check alle omvattende opdrachtenblokken tot de scopegrens. Een latere opdracht in zo’n blok geeft een warning, ook na een omvattende `if`, `case` of lambda-aanroep. Een volgende `else`, andere `case`-tak of afzonderlijke declaratie is geen vervolgcode op hetzelfde pad. De positie volgt uit de AST, niet uit fysieke regelvolgorde. De check evalueert geen voorwaarden, bewijst geen inhoudelijke afhankelijkheid tussen opdrachten en volgt geen uitvoering naar andere manifests. Meerdere meldingen bij dezelfde validatiekeuze geven samen één lintmelding; de algemene takgroottecontrole voegt daar geen tweede melding aan toe.

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

### Autofixinteracties

`project_guarded_packages` gebruikt de gedeelde AST voor guards, scopes en attribuutvergelijking. De tokenanalyse bepaalt alleen de te vervangen gebieden en de concrete opmaak. De fix draait na die van de bestaande checks en leest de actuele attribuuttokens, zodat eerdere quote- en kommafixes behouden blijven. De [voorwaarden voor packagegroepen](docs/OPERATIONAL_RULES.md#pakketten-en-mappen) beschrijven wanneer het vervangingsplan wordt geweigerd. De diagnose noemt de packagenamen en geeft controltekens met escapes weer; attribuutwaarden en AST-objecten worden niet aan de melding toegevoegd.

`ArrayLayout` bepaalt één gezamenlijk plan met AST-classificatie, oorspronkelijke elementtokens en een begrensde renderlus. `ArrayLayoutCheck` integreert de meldingen met `project_layout`. `FinalArrayLayout` in `array_layout_fixes.rb` start na de native fixes één nieuwe parse en uitsluitend de arrayfixfase. Een daaropvolgende controle zonder fixes vervangt actieve meldingen door de actuele bronposities; bestaande en nieuw opgeloste meldingen blijven `fixed`. Er is geen algemene fixlus. De line-ending-integratie bewaart LF en CRLF, ook in ondoorzichtige inhoud.

Puppet-lint voert eerst alle checks uit en daarna de fixes. Tokens kunnen daardoor al gewijzigd of verwijderd zijn wanneer een latere fix begint. De parameteruitlijning vernieuwt vlak vóór haar fixes de meldingen op de bewaarde tokens via de native `run`-methode: een eerdere komma- of tabcorrectie kan de breedte van een type veranderen. De documentatiecheck leest na parameterordening en commentopmaak opnieuw de actuele commenttokens, zodat beschrijvingen en ingevoegde scheidingsregels correct meeverhuizen. De native afhandeling van `lint:ignore` en `fix(problem)` blijft daarbij actief.

De [ontwikkelinstructies](#veilige-autofix-ontwikkelen) leggen vast hoe je deze interacties bij een wijziging beoordeelt en verifieert.

### Tests uitvoeren en uitbreiden

Alle lintertests staan onder [`.tools/lint/puppet/tests/`](tests), inclusief tests voor CLI, rapportage en gebruik vanuit andere projecten. De [projectbrede testscope](../../../TESTS.md#testscope-en-plaatsing) bepaalt welk gedrag in repositorytests thuishoort.

Voer tests uit vanuit de repositoryroot, na [installatie van de ontwikkelbundle](#gems-installeren):

**Werkmap:** Repositoryroot. **Shell:** POSIX shell. **Vereisten:** Ontwikkelbundle. **Invoer:** Alle tooltests of alleen de lintertests. **Wijzigt bestanden:** Tijdelijke testinvoer; rapporten alleen bij expliciete instelling. **Verwacht resultaat:** Niet-lege selectie zonder failures, errors of onverklaarde skips.

```sh
bundle exec rake test
bundle exec rake test:lint
```

De [gezamenlijke testtaken](../../README.md#gezamenlijke-tooltests) beheren discovery, rapportbestemming en reporterlevenscyclus voor alle tools en repositorycontroles. De lint-testhelper laadt de [gedeelde bootstrap](../../shared/README.md#testondersteuning) en voegt de native lintconfiguratie toe. De [teststructuurcontrole](../../repository/tests/test_structure_test.rb) bewaakt dat `test:lint` alleen lintertests selecteert.

Een gewone checktest erft rechtstreeks van `Minitest::Test` en gebruikt [`test_helper.rb`](tests/test_helper.rb) voor de native lintaanroep. De gedeelde `findings`-helper selecteert één regel via de publieke configuratie en herstelt die configuratie na de aanroep. Er zijn geen gespecialiseerde testbasisklassen of fixtures die op de naam van de testmethode worden opgezocht.

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

`assert_fix(before, after, :project_check_name)` controleert detectie, exacte correctie, parservalidatie, een schone hercontrole en een ongewijzigde tweede fixrun. De [referencefixes](tests/reference/merging_test.rb), [documentatietests](tests/documentation/structure_test.rb) en [interactietests](tests/cross_check_autofix_test.rb) laten het gebruik zien; de [lokale testinstructies](#linttests-onderhouden) bepalen de verplichte dekking bij wijzigingen.

De `cli/*_test.rb`-bestanden controleren native bestandsuitvoer, exitcodes, configuratie en suppressions. [`external/project_test.rb`](tests/external/project_test.rb) bouwt en installeert de echte `.gem` in een tijdelijk project met een eigen bundle. [`external/isolation_test.rb`](tests/external/isolation_test.rb) controleert dat lint zonder metadata werkt, metadata niet wijzigt en geen andere zelfstandige tools installeert. De tests gebruiken reeds geïnstalleerde dependencies en `bundle install --local`; ze hebben geen netwerk, productiegegevens of beheerde hosts nodig. Grotere of hergebruikte Puppet-fragmenten staan als afzonderlijke `.pp`-fixtures bij de tests. De expliciete `fixture`-aanroep wijst naar dat bestand; `fixture_set` leest een benoemde verzameling en faalt als die leeg is. Korte invoer staat direct in Ruby. De CLI-tests hebben daarnaast synthetische Ruby-invoer voor het laden van plugins en persoonlijke configuratie.

Volg de [centrale fixtureconventie](../../../TESTS.md#fixtures-bij-de-tests-plaatsen) voor plaatsing. De helpers `fixture` en `fixture_set` gebruiken expliciete paden vanaf `tests/`, zonder de extensie `.pp`: bijvoorbeeld `fixture('array_layout/fixtures/paths_after')` voor groepsinvoer en `fixture('fixtures/resource_dependencies/before')` voor gedeelde invoer. `fixture_set` leest uitsluitend het opgegeven patroon en faalt als de verzameling leeg is.

Voor één testbestand kun je bijvoorbeeld `bundle exec ruby .tools/lint/puppet/tests/reference/merging_test.rb` gebruiken. `GITHUB_ACTION=synthetic_test bundle exec rake test` toont de GitHub-uitvoervorm. De [testscope](../../../TESTS.md#testscope-en-plaatsing) bepaalt welk gedrag in repositorytests thuishoort.

### Versies bijwerken

Zie de [gezamenlijke toolinghandleiding](../../README.md#versies-bijwerken) voor deze procedure.

### Eigen tooltests

Zie de [gezamenlijke toolinghandleiding](../../README.md#eigen-tooltests) voor deze procedure.

#### Testselectie en uitvoeropties

Zie de [gezamenlijke toolinghandleiding](../../README.md#testselectie-en-uitvoeropties) voor deze procedure.

#### JUnit-rapportage instellen

Zie de [gezamenlijke toolinghandleiding](../../README.md#junit-rapportage-instellen) voor deze procedure.

## Documentatiecontract voor maintainers

### Grenzen van de lintdocumentatie

- Houd lintnormen en publieke lintprocedures in precies vier centrale Nederlandse documenten: deze README voor gebruik, dagelijkse lintworkflow, onderhoud en het checkregister; CODE_RULES voor algemene codeprincipes en afgebakende taalregels; DOCUMENTATION_RULES voor algemene documentatienormen en aanvullende codecommentaar-, Strings- en interfaceafspraken; OPERATIONAL_RULES voor operationele normen en specifieke uitwerkingen. Volg de [gezamenlijke informatieplaatsing](docs/DOCUMENTATION_RULES.md#informatieplaatsing).
- CONTRIBUTING en TESTS zijn afzonderlijke rootdocumenten voor gezamenlijke ontwikkeling en testbeleid, naast deze vier lintdocumenten. `AGENTS.md` bevat de agentleesroute, geen vijfde normverzameling of tweede register. Maak geen afzonderlijke lintdocumenten per check, regel, kleine regelgroep, autofix, consumer, CI-platform of testonderwerp. Een extra centraal lintdocument vereist een afzonderlijke expliciete architectuurwijziging; bestandsgrootte rechtvaardigt die niet automatisch.
- Houd algemene coderegels onder CODE_RULES; voeg geen STYLE_RULES toe omdat deze afspraken ook interfaces, parameters, dependencies en resources omvatten. Gebruik REFERENCE niet voor lintnormen; module-REFERENCE-bestanden behouden hun Strings/API-functie.
- Beoordeel omvang op de taak van de lezer volgens de [README-richtlijnen](docs/DOCUMENTATION_RULES.md#readme-richtlijnen). Verplaats geen noodzakelijke inhoud uitsluitend vanwege bestandsgrootte; houd gebruik, technische naslag en onderhoud via gerichte links bereikbaar.
- Behoud bij herindeling alle eisen, uitzonderingen, waarschuwingen, detectiebeperkingen, autofixvoorwaarden, gebruiksroutes en handmatige reviewcriteria. Consolidatie behoudt iedere unieke voorwaarde en verplichting.
- Houd de README-inhoudsopgave taakgericht op lintgebruik en tooling. Link duidelijk naar alle drie regelsdocumenten en tussen relevante secties volgens de [Markdownnorm](docs/DOCUMENTATION_RULES.md#markdown); benoem cumulatieve toepasselijkheid in de leeswijzer.
- Houd repository- en consumersnelstart vóór de gedetailleerde lintreferentie en link gedeelde setup aan `../../README.md`. Het enige checkregister en de maintaineruitleg blijven hier. Link vanuit het register rechtstreeks naar de normeigenaar zonder regels of register te dupliceren.
- Het onderstaande contract bewaakt de technische volledigheid van de lintreferentie. Gebruik voor uitsluitend handmatige normen de compacte uitleg; herhaal geen velden over niet-bestaande meldingen of fixes.

### Lintdocumentatie onderhouden

Pas het [maintainercontract](#documentatiecontract-voor-maintainers) toe bij regels, checks, diagnostiek, profielen, configuratie, procedures en consumerinterfaces. Beoordeel eigenaarschap en behoud van betekenis volgens de [gezamenlijke documentatienormen](docs/DOCUMENTATION_RULES.md#afspraken-onderhouden). Noteer oude plaats, behouden betekenis, nieuwe plaats en reden van iedere inhoudelijke verplaatsing in de wijzigingsreview, zonder nieuw repositorydocument voor het migratieregister.

Verifieer inkomende links, ankers, inventarissen en uitvoeringscontracten met de documentatietests; review juistheid, helderheid en betekenisbehoud handmatig. Iedere norm en haar subheadings hebben één gezaghebbende bestemming. Houd open beleidsconflicten en ontbrekende verplichte controles zichtbaar volgens [bewijsvoering](../../../TESTS.md#isolatie-en-bewijsvoering); noem het werk niet afgerond zolang vereist bewijs ontbreekt.

#### Documentatiewijzigingen verifiëren

- Pas het onderstaande contract toe op regeluitleg, registerrijen en gebruiksprocedures. Behoud iedere onafhankelijke coderegel bij één heading en de technische informatie die voor haar controle nodig is. Handmatige normen hoeven geen automatische meldingen of fixes te beschrijven. Voeg geen tweede regelnummering toe.
- Verifieer precies één registerrij per geregistreerde projectcheck; toets ontbrekende, onbekende en dubbele namen afzonderlijk. Verifieer runtimeregistratie, beide profielactivaties, diagnostische dekking en normlinks als afzonderlijke eigenschappen. Classificeer autofix per meldingsvariant, niet enkel op aanwezigheid van een fixmethode.
- Werk bij gewijzigde checks, diagnostiek, severity, defaults, autofix, suppressions, configuratie, dependencies, reporters of consumerinterfaces de geraakte normvelden, registerrijen, procedures, implementatie en tooltests samen bij. Onderbouw geen-documentatie-impact met de werkelijk beoordeelde interfaces. Verifieer versieclaims tegen constraints en opgeloste dependencies; onderscheid verklaarde compatibiliteit, geïnstalleerde versies, geteste combinaties en ontwikkelbeleid.
- Verifieer gewijzigde configuratie-instructies tegen geïnstalleerde CLI, loader en tests. Bepaal voorrang per optietype; neem niet aan dat iedere latere waarde wint. Test gewijzigde downstreamprocedures in een onafhankelijk consumerproject met eigen Gemfile, lockfile, configuratie en manifestselectie. Valideer iedere beschreven installatieroute afzonderlijk, ook gebouwde pakketten bij distributie; pathinstallatie bewijst geen Git- of packageinstallatie. Controleer succesvolle en falende opdrachten, numerieke status en rapportproductie; geslaagde conversie mag falende lint of validatie nooit verbergen.
- Controleer juiste en onjuiste voorbeelden, iedere uitzondering en grenscategorie, exacte fixes, herscannen en ongewijzigde tweede fixrun. Volledige voorbeelden moeten onder het hele benoemde profiel slagen; handmatige normen benoemen concrete stappen en criteria. Behoud voorbeeldlabels en benodigde procedurecontext, definieer variabelen en vervangpaden vóór gebruik en licht een veranderde context opnieuw toe.
- Behoud headingankers zonder dubbele ID's en werk inkomende links bij verplaatsing bij. Noteer verplaatste, samengebrachte en gecorrigeerde verplichtingen, uitzonderingen, waarschuwingen en gebruiksroutes met oude en nieuwe plaatsen en bewijs in de review. Verander geen lintgedrag of norm alleen om een documentatieverschil op te lossen; houd norm en waargenomen gedrag gescheiden totdat de bedoelde correctie vaststaat.

### Schema voor regels en procedures

Gebruik dit contract wanneer je een regel in [CODE_RULES.md](docs/CODE_RULES.md), [DOCUMENTATION_RULES.md](docs/DOCUMENTATION_RULES.md) of [OPERATIONAL_RULES.md](docs/OPERATIONAL_RULES.md), of een checkbeschrijving of gebruiksprocedure in deze README bijwerkt. De algemene afspraken voor de inhoudsopgave en samenhang binnen ieder onderwerp staan in [DOCUMENTATION_RULES.md](docs/DOCUMENTATION_RULES.md#markdown). Het onderstaande contract onderscheidt regels met automatische detectie van normen die inhoudelijke review vragen. De algemene documentatie-, Markdown-, README- en redactionele normen in DOCUMENTATION_RULES houden hun onderwerpstructuur; zij zijn geen extra lintcoderegels. Dit onderscheid geldt ook voor de aanvullende coderegels vanaf Commentaar en documentatie.

Iedere onafhankelijke coderegel krijgt in `docs/CODE_RULES.md`, `docs/DOCUMENTATION_RULES.md` of `docs/OPERATIONAL_RULES.md` een eigen `##`- of `###`-subsectie op precies één autoritatieve locatie. Een automatisch gecontroleerde regel bevat de onderstaande niet-lege velden in deze volgorde; de [lokale onderhoudsinstructies](#documentatiewijzigingen-verifiëren) bewaken wijzigingen eraan. Een regel kan meerdere checks hebben en een check meerdere regels: verbind ze met links naar de betreffende secties in de vier documenten, zonder een tweede regelnummering. Plaats de norm bij het beslispunt waarvoor het document verantwoordelijk is en verwijs vanuit de andere regelsbestanden gericht naar die norm.

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

Een uitsluitend handmatige norm behoudt `Norm`, `Herkomst`, `Toepassingsgebied`, `Handmatige review` en `Verificatie`. Behoud daarnaast concrete uitzonderingen, grenzen en nuttige reviewscenario's wanneer zij iets toevoegen. Vermeld ondersteunende checks met hun beperkte betekenis wanneer relevant. Voor deze normen zijn er geen eigen lintmelding, severity of autofix; een lintmarkering heft de reviewverplichting nooit op. Deze gemeenschappelijke grens hoeft niet bij iedere norm te worden herhaald.

Koppen die uitsluitend regels groeperen dragen `<!-- lint-rule-group -->`; zij bevatten zelf geen tweede norm. De contracttest controleert de vereiste informatie per soort regel en wijst lege velden af. De redactionele review beoordeelt of de gekozen structuur de lezer helpt.

Formuleer toepasselijkheid en vereiste actie rechtstreeks. Behoud of bestaand beleid verplicht, verboden, aanbevolen of toegestaan is. Houd voorwaarden, toegestane uitzonderingen, analysegrenzen en weigeringen van autofix bij de betreffende norm.

`Herkomst` is `Projectregel`, `Upstreamregel`, `Projectspecificatie van upstream` of `Nog niet vastgesteld`; bij upstream hoort een bronverwijzing. De laatste waarde verwijst naar een open verificatiepunt in de oplevering. `Automatische controle` noemt de exacte checknamen of letterlijk `Geen automatische controle`. Beschrijf bij iedere meldingsvariant de trigger, werkelijke severity en variabele tekstdelen. `[review]` is een tekstlabel, geen severity.

`Autofix` is per variant `Geen`, `Voorwaardelijk` of `Alle gedocumenteerde gevallen`, onderbouwd door uitvoering. Beschrijf alle correcties en weigeringsvoorwaarden. Een gemiste detectie is geen toegestane uitzondering. Suppressions noemen naam, syntax, plaats en begrenzing of verbieden suppressie expliciet. Gebruik `Geen` of `Niet van toepassing` uitsluitend met een concrete reden; ontbrekend bewijs krijgt `Nog niet vastgesteld` en een open punt.

Beschrijf bij `Verificatie` hoe de lezer het contract controleert en welke tests dat gedrag bewaken. Bewaar concrete uitvoeringsresultaten, tijdelijke bevindingen en open beslispunten bij de betreffende wijzigingsreview of het uitvoeringsrapport, volgens de [centrale documentatieafspraken](docs/DOCUMENTATION_RULES.md#duurzame-documentatie). Houd een noodzakelijke beperking of workaround daarnaast vindbaar bij de betrokken gebruiksinstructie.

Label voorbeelden als `Fragment`, `Volledig uitvoerbaar voorbeeld` of `Handmatig reviewscenario`. Een fragment kan uitsluitend voor benoemde checks groen zijn. Volledige voorbeelden slagen onder het volledige benoemde profiel. Handmatige normen benoemen de concrete reviewstappen en beoordelingscriteria.

Het centrale projectcheckregister staat uitsluitend in deze README, tussen `<!-- BEGIN PROJECT CHECK REGISTRY -->` en `<!-- END PROJECT CHECK REGISTRY -->`. Gebruik exact de kolommen `Check`, `Actief in repositoryprofiel`, `Actief in gedeeld profiel`, `Meldingsvarianten`, `Autofix` en `Regeluitleg`. Iedere geregistreerde projectcheck heeft één rij. Fixdekking beschrijft de afzonderlijke meldingsvarianten. Gemengde fixdekking heet `Per meldingsvariant` en verwijst naar de uitwerking in `docs/CODE_RULES.md`, `docs/DOCUMENTATION_RULES.md` of `docs/OPERATIONAL_RULES.md`. Regelverwijzingen uit het register wijzen rechtstreeks naar de betreffende autoritatieve headings. Maak geen tweede register in een regelsbestand.

Maak vóór uitvoering duidelijk waar en met welke shell een procedure werkt, welke voorbereiding en invoer nodig zijn, wat zij wijzigt en welk resultaat verwacht wordt. Gebruik de bestaande contextvelden waar ze helpen; onderhoud gedeelde context eenmaal en licht afwijkingen bij de betrokken stap toe. Definieer variabelen en vervangbare paden vooraf.

De [inventaristest](tests/guide/inventory_test.rb) bewaakt de vier centrale documenten en de afzonderlijke lokale ontwikkelinstructie. De [structuurtest](tests/guide/structure_test.rb) controleert unieke normeigenaars, navigatie en de documentverantwoordelijkheden uit de [lokale onderhoudsafspraken](#grenzen-van-de-lintdocumentatie). De [documentatiecontracttest](tests/guide/contract_test.rb) controleert daarnaast registratie, regelverwijzingen en verplichte velden. Deze tests beoordelen het contract zonder documentatie te wijzigen. De [onderhoudsinstructies](#documentatiewijzigingen-verifiëren) verbinden wijzigingen aan documentatie, implementatie, profielen en regressietests.

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
