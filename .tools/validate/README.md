# Zelfstandige Puppet-parservalidatie

`project-tools-validate` levert `validate-junit`: native OpenVox-syntaxvalidatie met JUnit per manifest. De gem gebruikt `project-tools-shared` voor de XML-opbouw en kan zonder linter, lintplugins, RuboCop of dependencytool worden geïnstalleerd. De [gezamenlijke toolinghandleiding](../README.md#installatie-in-je-project) beschrijft installatie, packagekeuze en consumermigratie.

Voor links buiten deze gem lees je de handleiding in de bijbehorende repositorycheckout.

## Inhoudsopgave

- [Inhoudsopgave](#inhoudsopgave)
- [Puppet-manifests valideren](#puppet-manifests-valideren)
- [Eigen manifests valideren](#eigen-manifests-valideren)
- [Exitcodes van validate-junit](#exitcodes-van-validate-junit)
- [Runtime en packagegrenzen](#runtime-en-packagegrenzen)
- [Ontwikkelen en testen](#ontwikkelen-en-testen)

## Puppet-manifests valideren

Controleer ieder gewijzigd Puppet-manifest afzonderlijk met de native parser, zonder rapportbestand of rapportmap. Gebruik `validate-junit` wanneer je daarnaast een rapport per manifest nodig hebt, volgens het [CLI- en rapportagecontract](../README.md#cli-en-rapportage). Vervang het voorbeeldpad door het gewijzigde bestand:

**Werkmap:** Repositoryroot. **Shell:** POSIX shell. **Vereisten:** Ontwikkelbundle. **Invoer:** examples/site.pp; kies voor werkelijk werk het gewijzigde manifest. **Wijzigt bestanden:** Geen bronbestanden. **Verwacht resultaat:** Parserstatus 0 bij geldige syntax.

```sh
bundle exec puppet parser validate examples/site.pp
```

Voer vanuit de repositoryroot de volledige selectie met JUnit-rapportage uit:

**Werkmap:** Repositoryroot. **Shell:** POSIX shell. **Vereisten:** Ontwikkelbundle. **Invoer:** Alle eigen manifests via validate:puppet. **Wijzigt bestanden:** Parser-JUnit in .tools/validate/results. **Verwacht resultaat:** Alle geselecteerde manifests gevalideerd met status 0.

```sh
bundle exec rake validate:puppet
```

De taak selecteert alle eigen `.pp`-bestanden recursief, inclusief `examples/` en nieuwe manifests. De vendored submodules `concat`, `debconf`, `reboot` en `stdlib`, geïnstalleerde gems onder `vendor/` en toolfixtures onder `.tools/` vallen buiten deze selectie. De taak staat los van `rake test` en is geen afhankelijkheid van die testtaak.

`validate:puppet` geeft de geselecteerde bestanden aan `validate-junit` uit de actieve bundle. Dit commando voert voor ieder bestand afzonderlijk de native `puppet parser validate` uit, zonder kleurcodes. Een fout stopt de controle van de overige bestanden niet. De parser controleert syntax zonder een catalogus te compileren of resources toe te passen; lintregels, functiegedrag en de werking op een host vallen buiten deze controle.

Het rapport staat in `.tools/validate/results/validate-report.xml`, met suite `validate` en één testcase per uniek manifestpad. Een niet-nul exitcode van de validator geeft een `failure` met de native foutmelding. Ontbrekende bestanden en ongeschikte bestandstypen krijgen een `error`, net als een validator die niet kan starten of door een signaal eindigt. Een lege selectie levert een foutcase op en slaagt dus niet stilzwijgend. De opdracht eindigt met een foutcode zodra een controle of het schrijven van het rapport mislukt.

Voor een gerichte selectie met rapportage gebruik je:

**Werkmap:** Repositoryroot. **Shell:** POSIX shell. **Vereisten:** Ontwikkelbundle. **Invoer:** examples/site.pp en examples/web.pp. **Wijzigt bestanden:** Het opgegeven XML-rapport. **Verwacht resultaat:** Gerichte parserresultaten; geen volledige eindselectie.

```sh
bundle exec validate-junit .tools/validate/results/validate-report.xml examples/site.pp examples/web.pp
```

Het eerste argument is het rapportpad met extensie `.xml`; daarna volgen concrete `.pp`-bestanden, geen directories. Zet paden met spaties tussen quotes. De opdracht maakt de rapportmap zo nodig aan en vervangt bij iedere uitvoering alleen zijn eigen rapportbestand. Een gerichte run bevat alleen die selectie; gebruik voor de eindcontrole de volledige Rake-taak. Afnemende projecten bepalen hun [eigen manifestselectie](#eigen-manifests-valideren).

## Eigen manifests valideren

Stel eerst de [rapportmap](../README.md#rapportmap-kiezen) in en voer parservalidatie als afzonderlijke controle uit vanuit je eigen projectroot. Installeer `project-tools-validate` en shared in je eigen bundle volgens de [pakketkeuze](../README.md#installatie-in-je-project):

**Werkmap:** Consumerroot. **Shell:** POSIX shell. **Vereisten:** [Eigen installatie](../README.md#installatie-in-je-project), bestaande genoemde manifests en [rapportmapinstelling](../README.md#rapportmap-kiezen). **Invoer:** De twee genoemde eigen manifests. **Wijzigt bestanden:** XML in de eigen rapportmap. **Verwacht resultaat:** Parserresultaat per geselecteerd manifest.

```sh
bundle exec validate-junit "$PROJECT_REPORT_DIR/validate-report.xml" environments/production/manifests/site.pp modules/profile/manifests/init.pp
```

Vervang de manifestpaden door alle eigen `.pp`-bestanden die je wilt controleren. Het commando accepteert concrete bestanden; directories worden als fout gerapporteerd. De [werking en rapportinhoud](#puppet-manifests-valideren) zijn gelijk aan die in deze repository. De uitvoermap staat in je eigen project en wordt automatisch aangemaakt. Bestanden uit `global-modules` en andere dependencies horen niet bij deze eigen selectie. `.puppet-lint.rc` en `PROJECT_TOOLS_MODULEPATH` bepalen deze parserselectie niet.

Voor een recursieve projectselectie voeg je `gem 'rake'` toe aan je eigen Gemfile als Rake nog ontbreekt, voer je `bundle install` uit en plaats je de volgende taak in je eigen root-Rakefile. Behoud eventuele bestaande taken:

```ruby
namespace :validate do
  desc 'Validate own Puppet manifests and write a JUnit report'
  task :puppet do
    manifests = FileList['**/*.pp'].exclude('.tools/**/*', 'global-modules/**/*', 'vendor/**/*')
    report_dir = ENV.fetch('PROJECT_REPORT_DIR', '.tools/quality/results')
    sh 'bundle', 'exec', 'validate-junit', File.join(report_dir, 'validate-report.xml'), *manifests
  end
end
```

Pas de uitsluitingen aan de dependencylocaties van je project aan. Deze selectie neemt nieuwe eigen manifests en uitvoerbare voorbeelden mee en sluit toolfixtures uit. De taak roept de gem aan; je kopieert geen validator of rapportimplementatie. Gebruik `bundle exec rake validate:puppet` lokaal en in de validatiejob zodra je deze taak gebruikt. Houd de taak los van `test` en eventuele standaardtaken voor tooltests. Het [CI-voorbeeld](../README.md#controle-in-ci) gebruikt de rechtstreekse aanroep met twee concrete manifests; vervang die door je volledige bestandsselectie of deze Rake-taak.

Voor het onderzoeken van één fout blijft de native opdracht `bundle exec puppet parser validate pad/naar/manifest.pp` beschikbaar. Parservalidatie compileert geen catalogus en vervangt de [eigen gedragsvalidatie](../lint/README.md#aanvullende-tests) niet.

## Exitcodes van validate-junit

| Geval | Exitcode | Stdout | Stderr | Rapportgedrag |
| --- | --- | --- | --- | --- |
| Alle manifests syntactisch geldig | 0 | `passed` per pad en resultaattelling | Leeg | Eén geslaagde testcase per uniek pad |
| Native waarschuwing zonder niet-nul parserstatus | 0 | Native uitvoer bij resultaat | Leeg | Geslaagde testcase met system-out; geen eigen warningseverity |
| Parser eindigt niet-nul | 1 | `failure`, native diagnostic, telling | Native stderr is samengevoegd in resultaat | Failure; resterende bestanden worden ook gecontroleerd |
| Ontbrekend bestand, directory of verkeerde extensie | 1 | `error` en `Expected an existing .pp file: {pad}` | Leeg | Error per ongeldig pad |
| Geen manifests na geldig rapportargument | 1 | `No Puppet manifests selected.` in resultaat | Leeg | Error voor Manifest selection |
| Rapportargument ontbreekt of eindigt niet op `.xml` | 1 | Leeg | Usage | Geen nieuw rapport |
| Validator kan niet starten of eindigt door signaal | 1 | Error met start-/procesdiagnose | In resultaatafhandeling | XML-error als rapport schrijven mogelijk is |
| Rapportmap of bestand niet schrijfbaar | 1 | Geen complete resultaatreeks | `Cannot write Puppet validation JUnit report: {fout}` | Geen bruikbaar nieuw rapport |

Deze reporter heeft geen lintconfiguratie; het modulepad en `.puppet-lint.rc` zijn daarom niet van toepassing op zijn selectie. De native parser controleert syntax, geen catalogus. Een ontbrekende gem of executable kan al vóór de reporter met een Ruby-/Bundlerfout stoppen; dan is er geen rapport.

## Runtime en packagegrenzen

`require 'project_tools/validate'` levert `ProjectTools::Validate.run(arguments, console:, errors:)`. De [implementatie](lib/project_tools/validate.rb) start voor ieder uniek manifest de native parser uit de actieve bundle met `RbConfig.ruby` en `Gem.bin_path('openvox', 'puppet')`. Bestandspaden gaan als afzonderlijke procesargumenten mee; er is geen shellinterpretatie of eigen syntaxparser. De API en CLI gebruiken dezelfde resultaatverzameling en exitstatus.

De gem declareert shared `>= 0.1.0, < 0.2.0`, OpenVox `~> 8.29`, JSON `< 3` en syslog `~> 0.4`. Het [pakketoverzicht](../README.md#pakketten-en-commandos) beschrijft de dependencies per tool; de [lockfile](../../Gemfile.lock) legt de ontwikkelbundle vast. De gem bevat uitsluitend eigen runtimecode, executable, README en licentie. Testhulp en ontwikkelgems blijven buiten het pakket. Voor een validatie zijn geen rootmetadata, `VERSION`, lintprofielen of `PROJECT_LINT_*`-instellingen vereist.

`validate-junit` heeft precies één eigenaar: deze gem. `lint-project` gebruikt OpenVox voor zijn eigen AST-analyse, maar installeert de validatorgem niet. De [migratie-instructies](../README.md#migreren-naar-de-vier-packages) beschrijven hoe bestaande afnemers hun bundle aanvullen. De repositorytaak en CI-rapportlocaties staan in de [gezamenlijke CI-uitleg](../README.md#ci-van-deze-repository).

## Ontwikkelen en testen

Voer vanuit de repositoryroot `bundle exec rake test:validate` uit voor de tooltests en `bundle exec rake test` voor alle tools. Tests en eventuele fixtures staan uitsluitend onder `tests/`; de gedeelde bootstrap en packagehulp komen uit `project-tools-shared`-testondersteuning in de checkout en zijn geen runtime-dependency.

De [reportertests](tests/validate_test.rb) controleren lege selecties, ongeldige bestanden, ontdubbeling, bijzondere padnamen, schrijfproblemen en bronbehoud. De [distributietests](tests/external_validate_test.rb) bouwen en installeren de gem in een zelfstandige consumerbundle. Zij controleren native succes en syntaxfouten, het doorgaan na een fout, rapportvervanging, pakketinhoud en een path-installatie zonder lint of projectmetadata. De gezamenlijke Git-consumertest controleert de zes gembronnen via de [gedocumenteerde local override](../README.md#git-dependency-uit-de-monorepo), inclusief de native parser zonder rapport.

Deze synthetische tests controleren het gereedschap. De volledige first-party parservalidatie met `bundle exec rake validate:puppet` blijft een aparte taak en is geen afhankelijkheid van tooltests. Volg voor de eindcontrole de [gezamenlijke validatie](../README.md#gezamenlijke-tooltests).
