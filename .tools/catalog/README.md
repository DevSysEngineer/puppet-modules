# Cataloguscompilatie

Deze repositorycontrole compileert de volledige `basic_settings`-class met de echte modules uit de checkout. Zij vindt onder meer dubbele resourcedeclaraties en ontbrekende classes die een afzonderlijke syntaxcontrole niet vindt. De controle past geen resources toe en levert geen zelfstandige gem. Gebruik de [syntaxcontrole](../syntax/README.md) voor de native parser en het [testbeleid](../../TESTS.md) voor de vereiste aanvullende validatie.

## Inhoudsopgave

- [Inhoudsopgave](#inhoudsopgave)
- [Uitvoeren](#uitvoeren)
- [Vaste scenario’s](#vaste-scenarios)
- [Uitvoering en resultaten](#uitvoering-en-resultaten)
- [Onderhoud](#onderhoud)

## Uitvoeren

**Werkmap:** Repositoryroot. **Shell:** POSIX shell. **Vereisten:** [Ontwikkelbundle](../README.md#installatie) en de volledige moduleset inclusief submodules. **Invoer:** De vaste manifests en facts hieronder. **Wijzigt bestanden:** Alleen tijdelijke Puppet-instellingen; geen bronbestanden of beheerde resources. **Verwacht resultaat:** Vier geslaagde compilaties, exitstatus 0.

```sh
bundle exec rake secrets:puppet
bundle exec rake catalog:compile
```

Voer eerst de [Puppet-secretsgate](../secrets/README.md#puppet-manifesten-in-standaardtests-en-ci) uit en beoordeel haar status voordat je compileert. Die gate selecteert ook de scenario-manifests. In CI is zij een verplichte jobdependency. De taak staat naast `syntax:puppet` en `rake test`; tooltests starten deze werkelijke catalogusmatrix niet.

Vraag voor CI en de eindcontrole het JUnit-rapport expliciet aan:

**Werkmap:** Repositoryroot. **Shell:** POSIX shell. **Vereisten:** Dezelfde bundle en moduleset. **Invoer:** Dezelfde vier scenario’s. **Wijzigt bestanden:** Het opgegeven XML-rapport en zo nodig zijn bovenliggende map. **Verwacht resultaat:** Een testcase per scenario en een foutstatus zodra een scenario of rapportschrijfactie faalt.

```sh
bundle exec rake 'catalog:compile[.tools/catalog/results/catalog-report.xml]'
```

De interne CLI `bundle exec ruby .tools/catalog/compile.rb [--junit REPORT.xml]` gebruikt dezelfde runner. Net als de Rake-taak veronderstelt zij dat de Puppet-secretscontrole al is geslaagd. Gebruik normaal de Rake-taak. Zonder rapportargument maakt de runner geen rapporten en laat hij bestaande rapporten ongemoeid. De [CI-configuratie](../README.md#ci-van-deze-repository) publiceert uitsluitend het expliciet aangevraagde rapport.

## Vaste scenario’s

| Facts | Defaultconfiguratie | Monitoring ingeschakeld |
| --- | --- | --- |
| [Debian 13](facts/debian-13.json) | [default.pp](manifests/default.pp) | [monitoring.pp](manifests/monitoring.pp) |
| [Ubuntu 24.04](facts/ubuntu-noble.json) | [default.pp](manifests/default.pp) | [monitoring.pp](manifests/monitoring.pp) |

Beide manifests laden de publieke hoofdclass `basic_settings`, inclusief development. Het defaultscenario gebruikt de standaardinstellingen zonder monitoringbackend. Het monitoringscenario stelt `monitoring_package` van `basic_settings` in op `openitcockpit`, waardoor onder meer de NCSC-check en zijn Python-afhankelijkheid worden meegenomen. De dubbele declaratie van `Package['python3']` blokkeert hierdoor de monitoringcompilaties.

De facts zijn synthetisch: een Linux-VM met amd64, twee processors en acht GiB geheugen. Zij worden niet van de ontwikkelmachine verzameld. De runner bepaalt de vier combinaties expliciet; een ontbrekend manifest of factsbestand wordt een fout en verkleint de matrix niet stilzwijgend.

Deze vaste matrix draait bij iedere wijziging. Voeg geen scenario toe enkel omdat een nieuwe wijziging wordt gedaan. Breid de matrix uit wanneer een ondersteunde configuratie of een wezenlijk andere combinatie dat vereist. Specifieke resourcewaarden, standaloneclasses en declaratievolgorden vragen zo nodig aanvullende tijdelijke regressiecontroles volgens [TESTS.md](../../TESTS.md#scenarios-kiezen).

## Uitvoering en resultaten

De [runner](lib/catalog.rb) start voor ieder scenario met de actieve Ruby en bundle een afzonderlijke [worker](lib/worker.rb). Die gebruikt de native `Puppet::Parser::Compiler`, het repositorypad als modulepad en een tijdelijke map voor Puppet-instellingen, Hiera-configuratie en runtimebestanden. De scenario’s gebruiken geen productie-Hiera, Facter-inventaris of beheerde servers. Puppet-functies en templates worden wel tijdens compilatie uitgevoerd; alleen gecontroleerde repositorycode hoort in deze selectie.

| Uitkomst | Exitstatus runner | JUnit | Dekking |
| --- | --- | --- | --- |
| Alle scenario’s compileren | 0 | Geslaagde testcase per scenario | Volledig voor deze matrix |
| Native compilatiefout | 1 | `failure` met compilerdiagnose | Overige scenario’s worden ook uitgevoerd |
| Ontbrekende invoer, ongeldige facts of onderbroken compiler | 1 | `error` | Onvolledige controle; overige scenario’s worden ook uitgevoerd |
| Lege selectie | 1 | `error` voor de selectie | Geen compilaties |
| Ongeldig rapportpad of rapportschrijffout | 1 | Geen bruikbaar nieuw rapport gegarandeerd | Log behoudt reeds bekende resultaten |

De suite en testcase-classname heten `catalog`. De testcase noemt het factsbestand en scenario, bijvoorbeeld `debian-13/monitoring`. Het log volgt het [gedeelde logcontract](../README.md#joblogs) met selectie, voortgang, diagnoses en afzonderlijke aantallen failures en errors. Het rapport bevat geen volledige catalogi.

Een geslaagde compilatie bewijst dat deze classcombinatie met deze facts compileert. Zij bewijst geen installatie op een host, werkende services of monitoringchecks, alle parametercombinaties of ondersteuning van iedere Puppet-versie. De ontwikkelbundle bepaalt de compiler; modulemetadata houdt haar eigen ondersteunde runtimecontract.

## Onderhoud

Volg de [ontwikkelwerkwijze](../../CONTRIBUTING.md), het [testbeleid](../../TESTS.md) en het [gedeelde toolingonderhoud](../README.md#gedeeld-toolingonderhoud). Houd de werkelijke compilatiematrix gescheiden van de synthetische tests van de runner.

Voer `bundle exec rake test:catalog` uit voor selectie, native compilatie, procesisolatie, foutafhandeling, doorgaan na fouten, bronbehoud en optionele JUnit-rapportage. Deze tooltests gebruiken tijdelijke synthetische modules. Voer daarnaast `bundle exec rake catalog:compile` uit voor de echte vier scenario’s en volg de [gezamenlijke eindcontroles](../../TESTS.md#controlevolgorde-en-verplichte-eindcontroles).

Werk bij een matrixwijziging facts, manifests, de expliciete selectie en deze tabel samen bij. Bij wijzigingen aan Rake of CI horen ook de [repositorycontroles](../repository-checks/README.md#onderhoud). Houd deze controle in de repository; een consumerproject gebruikt eigen facts, Hiera en classcombinaties voor zijn cataloguscontroles.
