# Cataloguscompilatie

`catalog` ontdekt en compileert de scenario’s die modules in hun eigen `tests/`-directory onderhouden. De controle vindt onder meer dubbele resourcedeclaraties en ontbrekende classes die een afzonderlijke syntaxcontrole niet vindt. Zij past geen resources toe. Gebruik de [syntaxcontrole](../syntax/README.md) voor de native parser en het [testbeleid](../../TESTS.md) voor aanvullende validatie.

## Inhoudsopgave

- [Inhoudsopgave](#inhoudsopgave)
- [Uitvoeren](#uitvoeren)
- [Tests bij een module plaatsen](#tests-bij-een-module-plaatsen)
  - [Optionele Hiera-testdata](#optionele-hiera-testdata)
  - [Voorbeeld: nginx alleen en samen](#voorbeeld-nginx-alleen-en-samen)
- [Class- en define-dekking controleren](#class--en-define-dekking-controleren)
- [Modulepad en ontdekking](#modulepad-en-ontdekking)
- [Vanuit een ander project uitvoeren](#vanuit-een-ander-project-uitvoeren)
- [Uitvoering en resultaten](#uitvoering-en-resultaten)
- [Onderhoud](#onderhoud)

## Uitvoeren

**Werkmap:** Repositoryroot. **Shell:** POSIX shell. **Vereisten:** [Ontwikkelbundle](../README.md#installatie) en de volledige moduleset inclusief submodules. **Invoer:** De ontdekte moduletests. **Wijzigt bestanden:** Alleen tijdelijke Puppet-instellingen; geen bronbestanden of beheerde resources. **Verwacht resultaat:** Alle ontdekte scenario’s compileren, exitstatus 0.

```sh
bundle exec rake secrets:puppet
bundle exec rake catalog:compile
```

Voer eerst de [Puppet-secretsgate](../secrets/README.md#puppet-manifesten-in-standaardtests-en-ci) uit en beoordeel haar status voordat je compileert. Die gate selecteert ook de scenario-manifests onder de eigen modules. In CI is zij een verplichte jobdependency. Cataloguscompilatie staat naast `syntax:puppet` en `rake test`; de tooltests starten uitsluitend synthetische compilaties.

Vraag voor CI en de eindcontrole het JUnit-rapport expliciet aan:

**Werkmap:** Repositoryroot. **Shell:** POSIX shell. **Vereisten:** Dezelfde bundle en moduleset. **Invoer:** Dezelfde ontdekte scenario’s. **Wijzigt bestanden:** Het opgegeven XML-rapport en zo nodig zijn bovenliggende map. **Verwacht resultaat:** Een testcase per scenario en een foutstatus zodra een scenario, ontdekking of rapportschrijfactie faalt.

```sh
bundle exec rake 'catalog:compile[.tools/catalog/results/catalog-report.xml]'
```

De CLI `bundle exec .tools/catalog/bin/project-tools-catalog [--junit REPORT.xml]` gebruikt dezelfde runner. Beide ingangen veronderstellen een geslaagde voorcontrole. Zonder rapportargument maakt de runner geen rapporten en laat hij bestaande rapporten ongemoeid. Relatieve rapportpaden volgen de werkmap van de aanroeper. De [CI-configuratie](../README.md#ci-van-deze-repository) publiceert uitsluitend het aangevraagde rapport.

## Tests bij een module plaatsen

Plaats de scenario’s en hun synthetische invoer bij de module die hun compilatiegedrag onderhoudt. Begin met de kleinste bruikbare selectie volgens het [beleid voor eenvoudige moduletests](../../TESTS.md#moduletests-eenvoudig-houden):

```text
<module>/
  manifests/
  tests/
    facts/
      platform.json
    hiera/                 # Optional, only when the module needs lookup data.
      hiera.yaml
      data/
        common.yaml
    manifests/
      standalone.pp
      with_basic_settings.pp
```

Ieder `.pp`-bestand onder `tests/manifests/` is een zelfstandig compilatiescenario. Ieder `.json`-bestand onder `tests/facts/` bevat één JSON-object met facts. De runner combineert binnen dezelfde module ieder manifest met ieder factsbestand, ook in subdirectories. Elk bestand wordt eenmaal geselecteerd; iedere manifest/facts-combinatie wordt eenmaal uitgevoerd. Kies daarom facts waarvoor alle scenario’s van die module bedoeld zijn. Namen van bestanden en subdirectories ten opzichte van `tests/manifests/` respectievelijk `tests/facts/` vormen de testcase-identiteit. Daardoor blijven gelijknamige manifests in verschillende submappen onderscheidbaar.

Volg voor de namen en eventuele groepen de [centrale testindeling](../../TESTS.md#testbestanden-groeperen). De ontdekking doorloopt `tests/manifests/` recursief en vindt zowel rechtstreeks geplaatste manifests als manifests in functionele submappen daarvan. Mappen met de naam `fixtures` worden op ieder niveau overgeslagen; hun inhoud is testinvoer volgens de [fixtureconventie](../../TESTS.md#fixtures-bij-de-tests-plaatsen). `facts/` bevat de synthetische JSON-facts van de module.

Er is geen centrale lijst van modules, bestandsnamen of scenario’s. Een nieuwe module met deze structuur doet bij de volgende aanroep automatisch mee. Modules zonder `tests/` worden overgeslagen; hun aantal staat in het log. Dat ondersteunt externe dependencies zonder dit testcontract; de [verplichte basisdekking voor eigen modules](../../TESTS.md#moduletests-eenvoudig-houden) blijft gelden. Een aanwezige `tests/` vereist minstens één manifest onder `manifests/` en één factsbestand onder `facts/`. Een lege, onleesbare of onvolledige selectie wordt een fout. Gebruik gewone bestanden en directories voor scenario-invoer; symlinks daarbinnen worden geweigerd om onduidelijke selectie en recursielussen te voorkomen. Een module zelf mag een symlink zijn.

De [basic_settings-scenario’s](../../basic_settings/tests/README.md) onderhouden hun eigen configuratie en platformkeuzes. Houd configuraties en modulekennis bij zulke moduletests; de centrale runner bevat uitsluitend ontdekking, compilatie en rapportage. De [nginx-scenario’s](../../nginx/tests/README.md) geven een compact voorbeeld met twee verschillende classcombinaties.

### Optionele Hiera-testdata

Heeft een module Hiera-data nodig om te compileren, plaats dan één lokale Hiera 5-hiërarchie onder `<module>/tests/hiera/`. Die fixture geldt voor alle bestaande manifest/facts-combinaties van de module. Hiera-bestanden worden geen afzonderlijke scenario’s en vergroten de testmatrix niet. Maak deze map alleen aan waar lookups haar nodig hebben; behoud facts als die voldoende invoer leveren. Het [eenvoudige compiletestbeleid](../../TESTS.md#moduletests-eenvoudig-houden) blijft gelden en de productie-interface wordt niet uitsluitend voor een compiletest aangepast.

Dit volledige voorbeeld gebruikt een fictieve module `catalog_fixture`. Vul bij een echte module haar bestaande lookup-sleutels in, inclusief sleutels die haar echte dependencies nodig hebben.

**Bestand:** `<module>/tests/hiera/hiera.yaml`.

```yaml
version: 5

defaults:
  datadir: data
  data_hash: yaml_data

hierarchy:
  - name: 'Testdata'
    path: common.yaml
```

**Bestand:** `<module>/tests/hiera/data/common.yaml`.

```yaml
lookup_options:
  catalog_fixture::password:
    convert_to: Sensitive

catalog_fixture::password: 'synthetic-catalog-test-only'
```

Plaats `lookup_options` in de databron, zoals `common.yaml`, en niet in `hiera.yaml`. De native compiler verwerkt expliciete `lookup()`-aanroepen, automatische classparameteropzoeking, mergeopties, typecontrole en `convert_to: Sensitive`. Een YAML-string kan zo rechtstreeks een `Sensitive[String]`-parameter vullen. De runner voegt geen ontbrekende waarden of algemene testdefaults toe. Gebruik uitsluitend herkenbaar fictieve gegevens: `Sensitive` schermt ondersteunde uitvoer af, maar versleutelt opgeslagen YAML niet.

De runner kopieert de fixture met behoud van relatieve paden naar de environmentlaag van iedere tijdelijke compilatieomgeving. De globale laag gebruikt een bestaand bestand met `version: 5` en `hierarchy: []`. Project- en hosthiërarchieën leveren geen aanvullende data. Gewone moduledata en moduledefaults uit de geselecteerde moduleset blijven beschikbaar met de normale Hiera-prioriteit. Iedere manifest/facts-combinatie krijgt een vers workerproces en eigen tijdelijke bestanden; ook na fouten worden die bestanden opgeruimd.

Het fixturecontract ondersteunt de ingebouwde `yaml_data`-backend met `path`, `paths`, `glob` of `globs` en een optionele `datadir`, globaal onder `defaults` of per hiërarchie-entry. Relatieve paden volgen de locatie van `hiera.yaml`, onafhankelijk van de werkmap. Paden mogen factverwijzingen zoals `%{facts.os.name}` bevatten; andere scopevariabelen en interpolatiefuncties vallen buiten dit fixturecontract. De runner controleert ook de door Hiera geïnterpoleerde paden vóór compilatie. Absolute paden, URI-bronnen, externe backends, `mapped_paths`, planhiërarchieën en verwijzingen buiten de fixturemap zijn ongeldig. Globs mogen geen `..`-segmenten bevatten. Gebruik gewone bestanden en directories; symlinks binnen de fixture of voor de fixturemap zelf worden geweigerd, net als bij scenario-invoer. Module-symlinks blijven toegestaan.

Een aanwezige fixturemap vereist een leesbare `hiera.yaml` met een expliciete `version: 5` en `hierarchy`-array. Een ontbrekende, lege, misvormde of niet-ondersteunde configuratie wordt ook zonder lookup afgekeurd; er is geen stilzwijgende terugval. Ontdekkings- en configuratieproblemen zijn `error`, met de module of waar mogelijk het scenario en de oorzaak in log en optioneel JUnit. Een ontbrekende verplichte lookupwaarde of een ongeldig datatype blijft een native compilatie-`failure`. Geldige lookup- en classdefaults en ontbrekende optionele databestanden behouden het normale Hiera-gedrag. Beide foutsoorten geven een falende opdracht, terwijl onafhankelijke modules en scenario’s blijven meedoen. Volledige datasets en catalogi worden niet aan de uitvoer toegevoegd.

Alleen de fixture van de volgens [modulepadvoorrang](#modulepad-en-ontdekking) geselecteerde module wordt gebruikt. Fixtures van dependencies en overschaduwde modules worden niet samengevoegd. Zonder `tests/hiera/` blijven selectie, testcase-identiteit en compilatie ongewijzigd. De fixture richt gecontroleerde compilatie-invoer in; Puppet-functies en templates worden normaal uitgevoerd en dit is geen algemene sandbox voor modulecode.

### Voorbeeld: nginx alleen en samen

De [nginx-scenario’s](../../nginx/tests/README.md) laden de class `nginx` en instantiëren zowel `nginx::server` als `nginx::monitoring_cert`. De hoofdclass alleen zou beide defines missen. Het [standalone manifest](../../nginx/tests/manifests/standalone.pp) declareert geen hoofdclass `basic_settings`; het [combinatiemanifest](../../nginx/tests/manifests/with_basic_settings.pp) laadt die serverbasis eerst en gebruikt verder dezelfde kleine configuratie.

Beide manifests gebruiken hetzelfde [synthetische Debian-factsbestand](../../nginx/tests/facts/debian-13.json). De modulecode en haar echte dependencies blijven op het modulepad beschikbaar. Standalone betekent dat de hoofdclass `basic_settings` niet wordt gedeclareerd; benodigde deelclasses en gedeelde defines zijn wel toegestaan.

De bestaande opdracht `bundle exec rake catalog:compile` ontdekt de twee manifests en combineert ieder met het ene factsbestand: twee compilaties, elk in een eigen proces. De aanroep vanuit CI of een consumer gebruikt dezelfde ontdekking. Een compilatiefout verschijnt in het log, het optionele JUnit-rapport en de exitcode.

## Class- en define-dekking controleren

Na iedere geslaagde compilatie vergelijkt de runner de class- en defined-type-declaraties uit alle `manifests/**/*.pp` van de betreffende module met de resources in de werkelijk gecompileerde catalogus. De inventaris gebruikt de native Puppet-parser. Indirect geladen classes en defines tellen mee; niet-gerealiseerde virtuele resources tellen niet mee. De vergelijking betreft de module die het scenario bezit, niet iedere meegecompileerde dependency.

Het log en `system-out` van de JUnit-testcase bevatten `Definition coverage`, de gecompileerde namen onder `Compiled definitions` en eventueel `Missing definitions (review required)`. Daardoor blijft zichtbaar welke interne of nieuw toegevoegde onderdelen buiten de compilatie vallen. Functies en typealiassen vallen buiten deze telling.

Beoordeel deze uitvoer bij iedere wijziging van een module of haar tests volgens het [testbeleid](../../TESTS.md#moduletests-eenvoudig-houden). Vul ontbrekende declaraties met geldige minimale configuratie aan in de bestaande scenario’s. Als conflicterende configuraties afzonderlijke manifests vereisen, vergelijk dan de gezamenlijke namen binnen zowel de standalone- als de combinatiegroep. Onderbouw een technische uitzondering in de module-eigen README; verwijs daarbij naar de betrokken broncode en beschrijf welke dekking wel mogelijk is.

De dekkingsmelding verandert de compile-exitcode niet en kent geen centrale uitzonderingslijst. Een geslaagde testcase bewijst dus niet automatisch volledige class- en define-dekking: ontbrekende namen vereisen expliciete review. Bestaande consumeraanroepen blijven werken en tonen dezelfde aanvullende dekkingsinformatie.

## Modulepad en ontdekking

Zonder `PROJECT_TOOLS_MODULEPATH` gebruikt de runner de checkout waarin zijn code staat, onafhankelijk van de huidige werkmap. Met deze variabele gebruikt hij uitsluitend het opgegeven [gedeelde modulepad](../README.md#gedeeld-modulepad): absolute bestaande directories, in volgorde en gescheiden door `File::PATH_SEPARATOR` (`:` op Linux en macOS). Een lege of ongeldige waarde geeft een fout; er is dan geen terugval.

De runner zoekt de directe moduledirectories op ieder modulepad met de native Puppet-regel voor modulenamen. Bij dezelfde modulenaam wint de eerste directory, ook als die module geen tests heeft. Dezelfde module wordt niet nogmaals getest bij een herhaald pad. Ontdekking en compilatie gebruiken dezelfde padvolgorde, zodat de gevonden tests bij de werkelijk geladen module horen. Een module mag andere modules gebruiken als dependency; haar tests en facts hoeven niet in die andere module te staan.

Alle gevonden modules met tests doen mee, inclusief geïmporteerde modules op het gekozen modulepad. Er worden geen willekeurige scripts of Ruby-tests uit `tests/` gestart: deze controle ondersteunt de hierboven beschreven Puppet-manifests, JSON-facts en optionele Hiera-YAML. Een selectie zonder compilaties én zonder andere ontdekkingsfouten geeft een selectiefout; een groene uitslag vereist uitgevoerde scenario’s.

## Vanuit een ander project uitvoeren

De runner wordt met de moduleset als checkout of submodule geïmporteerd, bijvoorbeeld onder `global-modules`. Hij heeft geen eigen gem. Gebruik een actieve consumerbundle met `openvox` vanaf 8.29 binnen major 8, `json` onder versie 3, `syslog` binnen 0.4 en `project-tools-shared` vanaf 0.1.1 binnen 0.1; Rake-aanroepen vereisen bovendien `rake`. De [bundle-installatie voor consumers](../README.md#installatie-in-je-project) beschrijft de gedeelde packages. Een installatie van uitsluitend gems bevat deze runner en de moduletests niet.

**Werkmap:** Consumerroot. **Shell:** POSIX shell. **Vereisten:** De genoemde bundle, de volledige checkout onder `global-modules` en een geslaagde secretsvoorcontrole van de geselecteerde modules en scenario’s. **Invoer:** Tests uit de geïmporteerde checkout. **Wijzigt bestanden:** Het gevraagde rapport binnen het consumerproject. **Verwacht resultaat:** Dezelfde selectie en exitcodes als vanuit de libraryroot.

```sh
bundle exec global-modules/.tools/catalog/bin/project-tools-catalog --junit build/reports/catalog.xml
```

Wil je eigen modules en hun tests meenemen, geef dan het volledige modulepad op. In dit voorbeeld staan eigen modules vóór de geïmporteerde modules; beide directories moeten bestaan. De voorcontrole moet dezelfde geselecteerde code dekken voordat je compileert.

**Werkmap:** Consumerroot. **Shell:** POSIX shell. **Vereisten:** Dezelfde bundle en gecontroleerde invoer, plus eigen modules onder `modules`. **Invoer:** Beide modulemappen in de opgegeven volgorde. **Wijzigt bestanden:** Het gevraagde rapport. **Verwacht resultaat:** Automatische uitvoering van eigen en geïmporteerde moduletests, met voorrang voor eigen modules met dezelfde naam.

```sh
export PROJECT_TOOLS_MODULEPATH="$PWD/modules:$PWD/global-modules"
bundle exec global-modules/.tools/catalog/bin/project-tools-catalog --junit build/reports/catalog.xml
```

De bestaande Rake-ingang blijft bruikbaar met `bundle exec rake -f global-modules/Rakefile 'catalog:compile[build/reports/catalog.xml]'`. Vanuit een andere directory geef je absolute paden naar de CLI of het Rakefile en selecteer je de consumerbundle via `BUNDLE_GEMFILE`. Het modulepad blijft onafhankelijk van die directory; een relatief rapportpad volgt wel de aanroeper. Eigen modules kunnen dezelfde optionele `tests/hiera/`-structuur gebruiken. Hun relatieve Hiera-paden blijven modulegebonden en vereisen geen consumerconfiguratie of extra CLI-optie.

## Uitvoering en resultaten

De [runner](lib/catalog.rb) start voor ieder scenario met de actieve Ruby en bundle een afzonderlijke [worker](lib/worker.rb). Die gebruikt de native `Puppet::Parser::Compiler`, het geselecteerde modulepad en tijdelijke Puppet-instellingen. De scenario’s gebruiken geen productie-Hiera, Facter-inventaris of beheerde servers. Puppet-functies en templates worden wel tijdens compilatie uitgevoerd; alleen gecontroleerde code hoort in deze selectie.

| Uitkomst | Exitstatus runner | JUnit | Dekking |
| --- | --- | --- | --- |
| Alle scenario’s compileren | 0 | Geslaagde testcase per scenario | Alle ontdekte compilaties uitgevoerd; beoordeel daarnaast de definitiedekking |
| Native compilatiefout | 1 | `failure` met compilerdiagnose | Overige scenario’s worden ook uitgevoerd |
| Ontbrekende invoer, ongeldige facts of onderbroken compiler | 1 | `error` | Onvolledige controle; overige scenario’s worden ook uitgevoerd |
| Onvolledige testmap of mislukte ontdekking | 1 | `error` per getroffen selectie | Andere leesbare modules blijven meedoen |
| Ongeldig modulepad of lege totale selectie | 1 | `error` voor de selectie | Geen compilaties |
| Ongeldig rapportpad of rapportschrijffout | 1 | Geen bruikbaar nieuw rapport gegarandeerd | Log behoudt reeds bekende resultaten |

De suite en testcase-classname heten `catalog`. De testcase noemt module, manifest en facts, bijvoorbeeld `basic_settings/standalone [debian-13]`. Subdirectorynamen blijven onderdeel van de identiteit. Het log volgt het [gedeelde logcontract](../README.md#joblogs) met selectie, voortgang, diagnoses en afzonderlijke aantallen failures en errors. Het rapport bevat geen volledige catalogi.

Een geslaagde compilatie bewijst dat deze classcombinatie met deze facts compileert. Zij bewijst geen installatie op een host, werkende services of monitoringchecks, alle parametercombinaties of ondersteuning van iedere Puppet-versie. De actieve bundle bepaalt de compiler; modulemetadata houdt haar eigen ondersteunde runtimecontract.

## Onderhoud

Volg de [ontwikkelwerkwijze](../../CONTRIBUTING.md), het [testbeleid](../../TESTS.md) en het [gedeelde toolingonderhoud](../README.md#gedeeld-toolingonderhoud). Onderhoud de echte scenario’s bij hun module; de synthetische tests van de runner blijven onder `.tools/catalog/tests/`.

Voer `bundle exec rake test:catalog` uit voor ontdekking, padvolgorde, native compilatie, class- en define-dekking, procesisolatie, Hiera-conversie en merge, fixturegrenzen, foutafhandeling, doorgaan na fouten en optionele JUnit-rapportage. Voer daarnaast `bundle exec rake test:repository` uit voor de Rake- en CLI-aanroep met Hiera vanuit een consumer met eigen bundle en afwijkende werkmap, CI-configuratie en documentatie. Gebruik `bundle exec rake catalog:compile` voor de echte moduletests en volg de [gezamenlijke eindcontroles](../../TESTS.md#controlevolgorde-en-verplichte-eindcontroles).

Controleer bij wijzigingen aan ontdekking ook nieuwe modules zonder centrale registratie, modules zonder tests, onvolledige selecties, conflicterende modulenamen en gemengde successen en fouten. Behoud bestaande aanroepen, optionele rapportage en afkeurende exitcodes in CI. Lokale integratietests voeren de hosted CI-pipeline zelf niet uit.
