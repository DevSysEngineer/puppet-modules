# Cataloguscompilatie

`catalog` ontdekt en compileert de scenario’s die modules in hun eigen `tests/`-directory onderhouden. De controle vindt onder meer dubbele resourcedeclaraties en ontbrekende classes die een afzonderlijke syntaxcontrole niet vindt. Zij past geen resources toe. Gebruik de [syntaxcontrole](../syntax/README.md) voor de native parser en het [testbeleid](../../TESTS.md) voor aanvullende validatie.

## Inhoudsopgave

- [Inhoudsopgave](#inhoudsopgave)
- [Uitvoeren](#uitvoeren)
- [Tests bij een module plaatsen](#tests-bij-een-module-plaatsen)
  - [Voorbeeld: nginx alleen en samen](#voorbeeld-nginx-alleen-en-samen)
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

De CLI `bundle exec ruby .tools/catalog/compile.rb [--junit REPORT.xml]` gebruikt dezelfde runner. Beide ingangen veronderstellen een geslaagde voorcontrole. Zonder rapportargument maakt de runner geen rapporten en laat hij bestaande rapporten ongemoeid. Relatieve rapportpaden volgen de werkmap van de aanroeper. De [CI-configuratie](../README.md#ci-van-deze-repository) publiceert uitsluitend het aangevraagde rapport.

## Tests bij een module plaatsen

Plaats de scenario’s en hun synthetische facts bij de module die hun compilatiegedrag onderhoudt. Begin met de kleinste bruikbare selectie volgens het [beleid voor eenvoudige moduletests](../../TESTS.md#moduletests-eenvoudig-houden):

```text
<module>/
  manifests/
  tests/
    facts/
      platform.json
    manifests/
      standalone.pp
```

Ieder `.pp`-bestand onder `tests/manifests/` is een zelfstandig compilatiescenario. Ieder `.json`-bestand onder `tests/facts/` bevat één JSON-object met facts. De runner combineert binnen dezelfde module ieder manifest met ieder factsbestand, ook in subdirectories. Elk bestand wordt eenmaal geselecteerd; iedere manifest/facts-combinatie wordt eenmaal uitgevoerd. Kies daarom facts waarvoor alle scenario’s van die module bedoeld zijn. Namen van bestanden en subdirectories ten opzichte van `tests/manifests/` respectievelijk `tests/facts/` vormen de testcase-identiteit. Daardoor blijven gelijknamige manifests in verschillende submappen onderscheidbaar.

Volg voor de namen en eventuele groepen de [centrale testindeling](../../TESTS.md#testbestanden-groeperen). De ontdekking doorloopt `tests/manifests/` recursief en vindt zowel rechtstreeks geplaatste manifests als manifests in functionele submappen daarvan. Mappen met de naam `fixtures` worden op ieder niveau overgeslagen; hun inhoud is testinvoer volgens de [fixtureconventie](../../TESTS.md#fixtures-bij-de-tests-plaatsen). `facts/` bevat de gedeelde invoer van de module.

Er is geen centrale lijst van modules, bestandsnamen of scenario’s. Een nieuwe module met deze structuur doet bij de volgende aanroep automatisch mee. Modules zonder `tests/` worden overgeslagen; hun aantal staat in het log. Een aanwezige `tests/` vereist minstens één manifest onder `manifests/` en één factsbestand onder `facts/`. Een lege, onleesbare of onvolledige selectie wordt een fout. Gebruik gewone bestanden en directories voor scenario-invoer; symlinks daarbinnen worden geweigerd om onduidelijke selectie en recursielussen te voorkomen. Een module zelf mag een symlink zijn.

De [basic_settings-scenario’s](../../basic_settings/tests/README.md) onderhouden hun eigen configuratiematrix en toelichting. Houd configuraties en modulekennis bij zulke moduletests; de centrale runner bevat uitsluitend ontdekking, compilatie en rapportage. De [nginx-scenario’s](../../nginx/tests/README.md) geven een compact voorbeeld met twee verschillende classcombinaties.

### Voorbeeld: nginx alleen en samen

Een standalone compilatiescenario laadt alleen de publieke class van de te controleren module. Voor nginx volstaat [standalone.pp](../../nginx/tests/manifests/standalone.pp):

```puppet
include nginx
```

Een scenario met meerdere modules declareert de benodigde classes in de volgorde die hun publieke contract voorschrijft. In [with_basic_settings.pp](../../nginx/tests/manifests/with_basic_settings.pp) staat de serverbasis daarom vóór nginx:

```puppet
include basic_settings
include nginx
```

Beide manifests gebruiken hetzelfde [synthetische Debian-factsbestand](../../nginx/tests/facts/debian-13.json). De combinatie heeft ook facts voor de serverbasis nodig. De modulecode en haar dependencies blijven beschikbaar op het modulepad; standalone betekent hier dat het manifest de hoofdclass `basic_settings` niet declareert. Er worden geen dependencies nagebootst en geen configuratievarianten gegenereerd.

De manifests staan rechtstreeks onder `nginx/tests/manifests/`; hun invoer staat onder `nginx/tests/facts/`. Bij de bestaande opdracht `bundle exec rake catalog:compile` vindt de runner deze module automatisch en combineert de twee manifests met het ene factsbestand: twee compilaties, elk in een eigen proces. Een compilatiefout wordt via het bestaande log, optionele JUnit-rapport en de exitcode teruggegeven. De aanroep vanuit CI of een consumer gebruikt dezelfde ontdekking.

De standalone test controleert de ingang zonder serverbasis; de combinatietest controleert de samenwerking met die basis. Een extra scenario is zinvol wanneer bijvoorbeeld een ondersteunde combinatie een andere resource-declaratie activeert en daardoor een nog niet afgedekt compilatieconflict kan blootleggen. Een tweede naam voor dezelfde classcombinatie voegt niets toe. Beoordeel uitbreiding met de [criteria in het testbeleid](../../TESTS.md#moduletests-eenvoudig-houden) en houd de toelichting bij de betreffende module.

## Modulepad en ontdekking

Zonder `PROJECT_TOOLS_MODULEPATH` gebruikt de runner de checkout waarin zijn code staat, onafhankelijk van de huidige werkmap. Met deze variabele gebruikt hij uitsluitend het opgegeven [gedeelde modulepad](../README.md#gedeeld-modulepad): absolute bestaande directories, in volgorde en gescheiden door `File::PATH_SEPARATOR` (`:` op Linux en macOS). Een lege of ongeldige waarde geeft een fout; er is dan geen terugval.

De runner zoekt de directe moduledirectories op ieder modulepad met de native Puppet-regel voor modulenamen. Bij dezelfde modulenaam wint de eerste directory, ook als die module geen tests heeft. Dezelfde module wordt niet nogmaals getest bij een herhaald pad. Ontdekking en compilatie gebruiken dezelfde padvolgorde, zodat de gevonden tests bij de werkelijk geladen module horen. Een module mag andere modules gebruiken als dependency; haar tests en facts hoeven niet in die andere module te staan.

Alle gevonden modules met tests doen mee, inclusief geïmporteerde modules op het gekozen modulepad. Er worden geen willekeurige scripts of Ruby-tests uit `tests/` gestart: deze controle ondersteunt de hierboven beschreven Puppet-manifests en facts. Een selectie zonder compilaties én zonder andere ontdekkingsfouten geeft een selectiefout; een groene uitslag vereist uitgevoerde scenario’s.

## Vanuit een ander project uitvoeren

De runner wordt met de moduleset als checkout of submodule geïmporteerd, bijvoorbeeld onder `global-modules`. Hij heeft geen eigen gem. Gebruik een actieve consumerbundle met `openvox` vanaf 8.29 binnen major 8, `json` onder versie 3, `syslog` binnen 0.4 en `project-tools-shared` vanaf 0.1.1 binnen 0.1; Rake-aanroepen vereisen bovendien `rake`. De [bundle-installatie voor consumers](../README.md#installatie-in-je-project) beschrijft de gedeelde packages. Een installatie van uitsluitend gems bevat deze runner en de moduletests niet.

**Werkmap:** Consumerroot. **Shell:** POSIX shell. **Vereisten:** De genoemde bundle, de volledige checkout onder `global-modules` en een geslaagde secretsvoorcontrole van de geselecteerde modules en scenario’s. **Invoer:** Tests uit de geïmporteerde checkout. **Wijzigt bestanden:** Het gevraagde rapport binnen het consumerproject. **Verwacht resultaat:** Dezelfde selectie en exitcodes als vanuit de libraryroot.

```sh
bundle exec ruby global-modules/.tools/catalog/compile.rb --junit build/reports/catalog.xml
```

Wil je eigen modules en hun tests meenemen, geef dan het volledige modulepad op. In dit voorbeeld staan eigen modules vóór de geïmporteerde modules; beide directories moeten bestaan. De voorcontrole moet dezelfde geselecteerde code dekken voordat je compileert.

**Werkmap:** Consumerroot. **Shell:** POSIX shell. **Vereisten:** Dezelfde bundle en gecontroleerde invoer, plus eigen modules onder `modules`. **Invoer:** Beide modulemappen in de opgegeven volgorde. **Wijzigt bestanden:** Het gevraagde rapport. **Verwacht resultaat:** Automatische uitvoering van eigen en geïmporteerde moduletests, met voorrang voor eigen modules met dezelfde naam.

```sh
export PROJECT_TOOLS_MODULEPATH="$PWD/modules:$PWD/global-modules"
bundle exec ruby global-modules/.tools/catalog/compile.rb --junit build/reports/catalog.xml
```

De bestaande Rake-ingang blijft bruikbaar met `bundle exec rake -f global-modules/Rakefile 'catalog:compile[build/reports/catalog.xml]'`. Vanuit een andere directory geef je absolute paden naar de CLI of het Rakefile en selecteer je de consumerbundle via `BUNDLE_GEMFILE`. Het modulepad blijft onafhankelijk van die directory; een relatief rapportpad volgt wel de aanroeper.

## Uitvoering en resultaten

De [runner](lib/catalog.rb) start voor ieder scenario met de actieve Ruby en bundle een afzonderlijke [worker](lib/worker.rb). Die gebruikt de native `Puppet::Parser::Compiler`, het geselecteerde modulepad en tijdelijke Puppet-instellingen. De scenario’s gebruiken geen productie-Hiera, Facter-inventaris of beheerde servers. Puppet-functies en templates worden wel tijdens compilatie uitgevoerd; alleen gecontroleerde code hoort in deze selectie.

| Uitkomst | Exitstatus runner | JUnit | Dekking |
| --- | --- | --- | --- |
| Alle scenario’s compileren | 0 | Geslaagde testcase per scenario | Volledig voor de ontdekte selectie |
| Native compilatiefout | 1 | `failure` met compilerdiagnose | Overige scenario’s worden ook uitgevoerd |
| Ontbrekende invoer, ongeldige facts of onderbroken compiler | 1 | `error` | Onvolledige controle; overige scenario’s worden ook uitgevoerd |
| Onvolledige testmap of mislukte ontdekking | 1 | `error` per getroffen selectie | Andere leesbare modules blijven meedoen |
| Ongeldig modulepad of lege totale selectie | 1 | `error` voor de selectie | Geen compilaties |
| Ongeldig rapportpad of rapportschrijffout | 1 | Geen bruikbaar nieuw rapport gegarandeerd | Log behoudt reeds bekende resultaten |

De suite en testcase-classname heten `catalog`. De testcase noemt module, manifest en facts, bijvoorbeeld `basic_settings/monitoring [debian-13]`. Subdirectorynamen blijven onderdeel van de identiteit. Het log volgt het [gedeelde logcontract](../README.md#joblogs) met selectie, voortgang, diagnoses en afzonderlijke aantallen failures en errors. Het rapport bevat geen volledige catalogi.

Een geslaagde compilatie bewijst dat deze classcombinatie met deze facts compileert. Zij bewijst geen installatie op een host, werkende services of monitoringchecks, alle parametercombinaties of ondersteuning van iedere Puppet-versie. De actieve bundle bepaalt de compiler; modulemetadata houdt haar eigen ondersteunde runtimecontract.

## Onderhoud

Volg de [ontwikkelwerkwijze](../../CONTRIBUTING.md), het [testbeleid](../../TESTS.md) en het [gedeelde toolingonderhoud](../README.md#gedeeld-toolingonderhoud). Onderhoud de echte scenario’s bij hun module; de synthetische tests van de runner blijven onder `.tools/catalog/tests/`.

Voer `bundle exec rake test:catalog` uit voor ontdekking, padvolgorde, native compilatie, procesisolatie, foutafhandeling, doorgaan na fouten en optionele JUnit-rapportage. Voer daarnaast `bundle exec rake test:repository` uit voor de Rake- en CLI-aanroep vanuit een consumer met eigen bundle en afwijkende werkmap, CI-configuratie en documentatie. Gebruik `bundle exec rake catalog:compile` voor de echte moduletests en volg de [gezamenlijke eindcontroles](../../TESTS.md#controlevolgorde-en-verplichte-eindcontroles).

Controleer bij wijzigingen aan ontdekking ook nieuwe modules zonder centrale registratie, modules zonder tests, onvolledige selecties, conflicterende modulenamen en gemengde successen en fouten. Behoud bestaande aanroepen, optionele rapportage en afkeurende exitcodes in CI. Lokale integratietests voeren de hosted CI-pipeline zelf niet uit.
