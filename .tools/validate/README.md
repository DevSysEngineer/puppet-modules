# Zelfstandige Puppet-parservalidatie

`project-tools-validate` levert `validate-junit`: native OpenVox-syntaxvalidatie met JUnit per manifest. De gem gebruikt `project-tools-shared` voor de XML-opbouw en kan zonder linter, lintplugins, RuboCop of dependencytool worden geïnstalleerd. De [gezamenlijke toolinghandleiding](../README.md#installatie-in-je-project) beschrijft installatie, packagekeuze en consumermigratie.

Voor links buiten deze gem lees je de handleiding in de bijbehorende repositorycheckout. Voor onderhoud aan deze tool volg je daar de [lokale ontwikkelinstructies](AGENTS.md).

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

Voer vanuit de repositoryroot de volledige selectie zonder rapport uit:

**Werkmap:** Repositoryroot. **Shell:** POSIX shell. **Vereisten:** Ontwikkelbundle. **Invoer:** Alle eigen manifests via validate:puppet. **Wijzigt bestanden:** Geen bronbestanden of rapporten. **Verwacht resultaat:** Alle geselecteerde manifests gevalideerd met status 0.

```sh
bundle exec rake validate:puppet
```

De taak selecteert alle eigen `.pp`-bestanden recursief, inclusief `examples/` en nieuwe manifests. De vendored submodules `concat`, `debconf`, `reboot` en `stdlib`, geïnstalleerde gems onder `vendor/` en toolfixtures onder `.tools/` vallen buiten deze selectie. De taak staat los van `rake test` en is geen afhankelijkheid van die testtaak.

Zonder taakargument geeft `validate:puppet` de geselecteerde bestanden rechtstreeks aan `puppet parser validate` uit de actieve bundle, zonder kleurcodes. De taak maakt geen rapporten of rapportmappen en laat bestaande rapporten ongemoeid. Een lege selectie geeft een fout, zodat de parser niet terugvalt op stdin of een standaardmanifest. De parser controleert syntax zonder een catalogus te compileren of resources toe te passen; lintregels, functiegedrag en de werking op een host vallen buiten deze controle.

Geef voor CI en de eindcontrole het rapportpad expliciet mee als `junit`-taakargument. Zet de volledige taakaanroep tussen quotes, zodat de shell de vierkante haken niet als bestandsselectie verwerkt:

**Werkmap:** Repositoryroot. **Shell:** POSIX shell. **Vereisten:** Ontwikkelbundle. **Invoer:** Dezelfde volledige manifestselectie. **Wijzigt bestanden:** Het opgegeven parser-JUnit. **Verwacht resultaat:** Dezelfde parserstatus met een rapport per manifest.

```sh
bundle exec rake 'validate:puppet[.tools/validate/results/validate-report.xml]'
```

Met dit argument roept de taak `validate-junit` aan. Dit commando voert voor ieder bestand afzonderlijk de native parser uit. Een fout stopt de controle van de overige bestanden niet. De reporter volgt het [centrale logcontract](../README.md#joblogs): start met de unieke manifestselectie, direct zichtbare native bevindingen en een eindresultaat met afzonderlijke failures en uitvoeringsproblemen. Lange native subprocessen krijgen een activiteitsmelding zonder verzonnen tussenresultaten. Ontbrekende of niet-beoordeelde manifests tellen niet als gecontroleerd. De native route zonder rapport geeft geen gestructureerde resultaten per bestand; bij een niet-nul status verwijst de taak naar de oorspronkelijke diagnose en vermeldt zij de status als ongeclassificeerd. Beide uitvoervormen geven een foutstatus bij ongeldige syntax of een lege selectie; een aangevraagd maar onschrijfbaar rapport geeft eveneens een foutstatus.

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
  desc 'Validate own Puppet manifests, optionally writing JUnit to the supplied path'
  task :puppet, [:junit] do |_task, args|
    manifests = FileList['**/*.pp'].exclude('.tools/**/*', 'global-modules/**/*', 'vendor/**/*')
    if args[:junit]
      sh 'bundle', 'exec', 'validate-junit', args[:junit], *manifests, verbose: false do |ok, status|
        raise SignalException, status.termsig if status.signaled?

        exit status.exitstatus unless ok
      end
    else
      require 'project_tools/shared/console'
      console = ProjectTools::Shared::Console.new('Puppet validation', scope: "#{manifests.size} files selected")
      console.during do
        abort 'No Puppet manifests selected.' if manifests.empty?
        sh 'bundle', 'exec', 'puppet', 'parser', 'validate', '--color=false', *manifests, verbose: false do |ok, status|
          console.finish(status: ok ? 'PASSED' : 'Result not classified', execution: ok ? 'complete' : 'unknown',
                         facts: ["Original exit status: #{status}", 'Native parser diagnostics are shown above.'])
          raise SignalException, status.termsig if status.signaled?

          exit status.exitstatus unless ok
        end
      end
    end
  end
end
```

Pas de uitsluitingen aan de dependencylocaties van je project aan. Deze selectie neemt nieuwe eigen manifests en uitvoerbare voorbeelden mee en sluit toolfixtures uit. De taak gebruikt de native parser of de rapportagegem; je kopieert geen validator of rapportimplementatie. Gebruik lokaal `bundle exec rake validate:puppet` voor console-uitvoer. Vraag in de validatiejob het rapport expliciet aan met `bundle exec rake "validate:puppet[$PROJECT_REPORT_DIR/validate-report.xml]"`. Alleen het instellen van `PROJECT_REPORT_DIR` schakelt rapportage niet in. Houd de taak los van `test` en eventuele standaardtaken voor tooltests. Het [CI-voorbeeld](../README.md#controle-in-ci) gebruikt de rechtstreekse aanroep met twee concrete manifests; vervang die door je volledige bestandsselectie of de Rake-aanroep met rapportargument.

Voor het onderzoeken van één fout blijft de native opdracht `bundle exec puppet parser validate pad/naar/manifest.pp` beschikbaar. Parservalidatie compileert geen catalogus en vervangt de [eigen gedragsvalidatie](../lint/README.md#aanvullende-tests) niet.

## Exitcodes van validate-junit

| Geval | Exitcode | Stdout | Stderr | Rapportgedrag |
| --- | --- | --- | --- | --- |
| Alle manifests syntactisch geldig | 0 | Compact `PASSED` met manifest- en resultaattellingen | Leeg | Eén geslaagde testcase per uniek pad |
| Native waarschuwing zonder niet-nul parserstatus | 0 | Native uitvoer bij resultaat | Leeg | Geslaagde testcase met system-out; geen eigen warningseverity |
| Parser eindigt niet-nul | 1 | `failure`, native diagnostic, telling | Native stderr is samengevoegd in resultaat | Failure; resterende bestanden worden ook gecontroleerd |
| Ontbrekend bestand, directory of verkeerde extensie | 1 | `error` en `Expected an existing .pp file: {pad}` | Leeg | Error per ongeldig pad |
| Geen manifests na geldig rapportargument | 1 | `No Puppet manifests selected.` in resultaat | Leeg | Error voor Manifest selection |
| Rapportargument ontbreekt of eindigt niet op `.xml` | 1 | `ERROR`, niet uitgevoerd | Usage | Geen nieuw rapport |
| Validator kan niet starten of eindigt door signaal | 1 | Error met start-/procesdiagnose | In resultaatafhandeling | XML-error als rapport schrijven mogelijk is |
| Rapportmap of bestand niet schrijfbaar | 1 | `ERROR`, reeds bekende bevindingen en onvolledige dekking | `Cannot write Puppet validation JUnit report: {fout}` | Geen bruikbaar nieuw rapport |

Deze reporter heeft geen lintconfiguratie; het modulepad en `.puppet-lint.rc` zijn daarom niet van toepassing op zijn selectie. De native parser controleert syntax, geen catalogus. Een ontbrekende gem of executable kan al vóór de reporter met een Ruby-/Bundlerfout stoppen; dan is er geen rapport.

## Runtime en packagegrenzen

`require 'project_tools/validate'` levert `ProjectTools::Validate.run(arguments, console:, errors:)`. De [implementatie](lib/project_tools/validate.rb) start voor ieder uniek manifest de native parser uit de actieve bundle met `RbConfig.ruby` en `Gem.bin_path('openvox', 'puppet')`. Bestandspaden gaan als afzonderlijke procesargumenten mee; er is geen shellinterpretatie of eigen syntaxparser. De API en CLI gebruiken dezelfde resultaatverzameling en exitstatus.

De [gemspec](project-tools-validate.gemspec) beheert de vereiste versies van shared, OpenVox, JSON en syslog. Het [pakketoverzicht](../README.md#pakketten-en-commandos) beschrijft de dependencies per tool; de [lockfile](../../Gemfile.lock) legt de ontwikkelbundle vast. De gem bevat uitsluitend eigen runtimecode, executable, README en licentie. Testhulp en ontwikkelgems blijven buiten het pakket. Voor een validatie zijn geen rootmetadata, `VERSION`, lintprofielen of `PROJECT_LINT_*`-instellingen vereist.

`validate-junit` heeft precies één eigenaar: deze gem. `lint-project` gebruikt OpenVox voor zijn eigen AST-analyse, maar installeert de validatorgem niet. De [migratie-instructies](../README.md#migreren-naar-afzonderlijke-toolpakketten) beschrijven hoe bestaande afnemers hun bundle aanvullen. De repositorytaak en CI-rapportlocaties staan in de [gezamenlijke CI-uitleg](../README.md#ci-van-deze-repository).

## Ontwikkelen en testen

Voer vanuit de repositoryroot `bundle exec rake test:validate` uit voor de tooltests en `bundle exec rake test` voor alle tools. Tests en eventuele fixtures staan uitsluitend onder `tests/`; de gedeelde bootstrap en packagehulp komen uit `project-tools-shared`-testondersteuning in de checkout en zijn geen runtime-dependency.

De [reportertests](tests/validate_test.rb) controleren lege selecties, ongeldige bestanden, ontdubbeling, bijzondere padnamen, schrijfproblemen en bronbehoud. De [distributietests](tests/external_validate_test.rb) bouwen en installeren de gem in een zelfstandige consumerbundle. Zij controleren native succes en syntaxfouten, het doorgaan na een fout, rapportvervanging, pakketinhoud en een path-installatie zonder lint of projectmetadata. De gezamenlijke Git-consumertest controleert de afzonderlijke gembronnen via de [gedocumenteerde local override](../README.md#git-dependency-uit-de-monorepo), inclusief de native parser zonder rapport.

Deze synthetische tests controleren het gereedschap. De volledige first-party parservalidatie met `bundle exec rake validate:puppet` blijft een aparte taak en is geen afhankelijkheid van tooltests. Volg voor de eindcontrole de [gezamenlijke validatie](../README.md#gezamenlijke-tooltests).
