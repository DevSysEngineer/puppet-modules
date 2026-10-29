# Gedeelde toolingbibliotheek

`project-tools-shared` levert het technische fundament voor `lint-project`, `project-tools-secrets`, `project-tools-metadata`, `project-tools-syntax` en `project-tools-module`. Gebruik de [gezamenlijke installatiehandleiding](../README.md#installatie) om de gembron en bundle in te richten.

Voor links buiten deze gem lees je de handleiding in de bijbehorende repositorycheckout.

## Inhoudsopgave

- [Inhoudsopgave](#inhoudsopgave)
- [Runtimecontracten](#runtimecontracten)
- [Puppet-runtime selecteren](#puppet-runtime-selecteren)
- [Afhankelijkheden en onderhoud](#afhankelijkheden-en-onderhoud)
- [Testondersteuning](#testondersteuning)

## Runtimecontracten

`require 'project_tools/shared/junit_report'` levert `ProjectTools::Shared::JunitReport.write(output, name:, **counts) { |xml| ... }`. De schrijver maakt de XML-declaratie, `testsuites` en `testsuite`; de producer levert tellingen, testcases, failures, errors en eventuele rapporttekst. Builder verzorgt escaping. Lint, secretcontrole, metadata, parser en dependencyreporter gebruiken dezelfde implementatie, maar behouden ieder hun eigen succescriterium en exitstatus.

`require 'project_tools/shared/modulepath'` levert `ProjectTools::Shared::Modulepath.parse(value)`. Deze functie splitst met `File::PATH_SEPARATOR`, weigert lege of ongeldige onderdelen en vereist absolute bestaande directories. Het resultaat bevat bevroren, gecanonicaliseerde paden in oorspronkelijke volgorde, inclusief duplicaten. Ongeldige invoer geeft `ArgumentError`; bestandsysteemfouten behouden hun Ruby-fouttype. De linter en dependencytool gebruiken deze validatie.

De aanroeper bepaalt of een ontbrekende modulepath een terugval activeert of een configuratiefout oplevert. Shared selecteert geen modules, metadata, manifests of toegestane bronbestanden. De linter behoudt zijn eigen symlink- en bronleesgrenzen; dependencycontrole volgt native Puppet-selectie. De package voert bij laden geen scans uit, initialiseert geen Puppet-instellingen of Minitest, registreert geen lintchecks en wijzigt geen rapporten.

`require 'project_tools/shared/console'` levert `ProjectTools::Shared::Console` vanaf shared 0.1.1. Maak een instantie met een controlenaam, `output:` en eventueel `scope:`. `during { ... }` beheert de activiteitsthread en stopt die ook bij exceptions en afhandelbare signalen. `advance(unit:, total: nil)` registreert één afgeronde eenheid; `finding(message, output:)` toont een bevinding direct. `finish(status:, execution:, facts: [], details: [], report: nil)` schrijft het primaire eindresultaat. De aanroeper levert status en volledigheid; shared leidt geen oordeel af uit exitcodes of severitynamen. Geef `report:` uitsluitend na succesvol schrijven en sluiten van de gevraagde uitvoer.

`diagnostic(message, output:)` is ook als classmethode beschikbaar voor converters zonder eigen uitvoeringscyclus. Zij springt regels in en vlakt terminalcontroltekens af; XML blijft bij de JUnit-writer. De console schrijft geen bestanden, platformcommando’s of annotaties. Bij een onverwacht afgebroken `during` blijven verzamelde bevindingen zichtbaar in een onvolledige foutafsluiting, waarna de oorspronkelijke exception of het signaal doorgaat. Het [centrale logcontract](../README.md#joblogs) bepaalt de gebruikerspresentatie en de grens met native CI-stappen.

Gebruik `finding` voor een beknopte identiteit en het probleemtype; deze methode toont maximaal de eerste twee regels. Geef een volledige meerregelige diagnose daarom afzonderlijk aan `diagnostic`, dat alle regels behoudt en terminalcontroltekens veilig weergeeft. Succesdetails zoals gecompileerde resources of definities zijn geen bevinding: bewaar ze bij het toolresultaat voor JUnit. Shared beslist niet of een warning of ontbrekende dekking het toolbeleid schendt.

Dit kleine voorbeeld presenteert reeds door de tool beoordeelde resultaten. `status`, `execution` en `written_report` komen van de aanroeper; de rapportvariabele is alleen gevuld na geslaagde publicatie:

```ruby
console = ProjectTools::Shared::Console.new('Example check', scope: "#{results.size} checks selected")
console.during do
  results.each do |result|
    if result[:problem]
      console.finding("#{result[:name]} | #{result[:problem]}")
      console.diagnostic(result[:diagnostic])
    end
    console.advance(unit: 'checks', total: results.size)
  end
  console.finish(status: status, execution: execution,
                 facts: ["Checks: #{results.size} processed"],
                 details: ['See any findings and diagnostics above.'], report: written_report)
end
```

Handel verwachte uitvoerings- en rapportagefouten binnen `during` af en roep daarna eenmaal `finish` aan met het juiste tooloordeel. Een rescue buiten `during` komt pas na de automatische onvolledige afsluiting en mag geen tweede primaire status schrijven. Herhaal volledig getoonde diagnoses niet via `finish(details:)`; verwijs ernaar bij de bekende tellingen. De automatische afsluiting bij een onverwachte exception is een vangnet, geen vervanging voor de toolspecifieke foutafhandeling en resultaatadministratie.

`project_lint/junit_report` blijft in de lintgem beschikbaar als compatibility-shim. `ProjectLint::JunitReport` verwijst naar dezelfde shared-module, met dezelfde signatuur. Er is geen tweede XML-implementatie of fallback naar een naastgelegen checkout.

## Puppet-runtime selecteren

`require 'project_tools/shared/puppet_runtime'` laadt uitsluitend de gedeelde voorziening. `PuppetRuntime.detect` selecteert precies één geactiveerde gem uit `Gem.loaded_specs`: `puppet` of `openvox`. Bundler activeert de gem uit de eigen bundle; buiten Bundler moet de caller haar vooraf activeren. Geïnstalleerde alternatieven en `PATH` zijn geen selectiebron. Geen actieve runtime, beide gems tegelijk of overschaduwde Puppet-kerncode buiten de gekozen gem geeft `PuppetRuntime::Error`. `name`, `version` en `to_s` komen uit de geselecteerde gemspec. De herkomstcontrole beoordeelt `puppet.rb` en bestanden die in de geselecteerde runtime bestaan; module-eigen uitbreidingen onder `lib/puppet/` blijven toegestaan.

`PuppetRuntime.load!(feature = 'puppet')` laadt de vereiste interface en controleert herkomst en overeenstemming tussen gemversie en `Puppet.version`. Dit is een consistentiecontrole tussen twee dynamische waarden, geen lijst toegestane releases. `detect.executable` kiest met RubyGems de executable van precies die gem en versie en controleert de herkomst. Start haar met de actieve `RbConfig.ruby`; zoek niet zelfstandig naar een executable of tweede runtime.

`PuppetRuntime.parser` oefent parsing, AST-traversal, declaraties, literalwaarden en bronposities met synthetische invoer voordat de parser wordt teruggegeven. Een ontbrekende of afwijkende interface geeft een gerichte fout. De gedeelde voorziening garandeert geen volledige compatibiliteit van compiler, functies of interne API's. Functiespecifieke adapters blijven bij hun tool, zoals de [literal-evaluator](../lint/puppet/lib/project_lint/literal_evaluator.rb), die waarden en het signaal voor onbekende expressies controleert, en de [deprecationadapter](../catalog/README.md#native-deprecations-afkeuren). Ontwikkel adapters op benodigd gedrag: gebruik stabiele interfaces waar mogelijk, oefen noodzakelijke interne contracten en rapporteer onbekende of onvolledige analyse als fout. Voeg een verschiladapter alleen toe voor een aangetoond gedragsverschil; kies niet uitsluitend op een majorversie.

`Console.software(tool, runtime: false, version: nil, output: $stderr)` toont eenmaal per aanroep de toolversie uit de geactiveerde gemspec, de runtime-identiteit en `RUBY_VERSION`. Checkouttools geven hun bestaande versiebron expliciet mee. `runtime: true` detecteert de actieve runtime; `false` toont `Puppet runtime: not required`. Een uitvoeringsconsole kan dezelfde informatie met `software: { tool: ..., runtime: ... }` bij haar start tonen. Een native CLI gebruikt rechtstreeks `software`; voeg geen tweede header toe in CI. `Console.with_software` houdt voor de secrets-tool bij of daadwerkelijk een Puppet-interface is gevraagd, ook bij een laadfout, en schrijft de header bij afsluiting. Algemene tekstscans activeren geen runtime.

De [simulatietests](tests/puppet_runtime_test.rb) gebruiken tijdelijke gemspecs en een vervangende executable-resolver voor Puppet 8, OpenVox 8, OpenVox 9 en een onbekende toekomstige major. Ze testen selectie, conflicten, herkomst, versielogs en ontbrekende of gewijzigde API's zonder runtime-installaties. Ze bewijzen onze beslislogica, geen werking van die externe releases. De integratietests gebruiken uitsluitend de reeds geselecteerde lokale runtime; raadpleeg de [centrale bewijsgrenzen](../README.md#runtimekeuze-en-compatibiliteit).

## Afhankelijkheden en onderhoud

Volg bij onderhoud ook de [gezamenlijke ontwikkelwerkwijze](../../CONTRIBUTING.md), het [testbeleid](../../TESTS.md) en het [gedeelde toolingonderhoud](../README.md#gedeeld-toolingonderhoud).

- Voeg shared-code alleen toe wanneer concrete consumers hetzelfde technische gedrag nodig hebben. Houd metadataherstel, selectiebeleid, lintchecks, parserorkestratie en dependencybevindingen bij hun tools volgens de packagegrenzen hieronder.
- Identificeer bij gewijzigde [runtimeinterfaces](#runtimecontracten) alle geraakte aanroepers, lees hun README-contracten en verifieer hun CLI en ondersteunde distributieroutes. Agents lezen ook hun lokale instructies. Behoud selectie-, resultaat- en exitsemantiek bij de caller, isolatie bij laden en de lint-JUnit-compatibility-shim.
- Houd [testondersteuning](#testondersteuning) buiten de runtimegem. Verifieer eenmalige bootstrap en reporterinitialisatie, opt-in JUnit, behoud van andere rapporten en foutstatus bij rapportschrijffouten. Lintconfiguratie en verwachtingen blijven in de linthelper.
- Onderhoud package-testhelpers tegen de bestaande offline consumerroute met gescheiden stdout, stderr en processtatus. Gebruik shared-tests voor library- en bootstrapcontracten; navigatie, workflow en testindeling horen bij repositorycontroles.

De [shared-gemspec](project-tools-shared.gemspec) declareert Builder als runtime-dependency. Iedere afnemende tool beheert zijn vereiste shared-versie in de eigen gemspec; zie het [pakketoverzicht](../README.md#pakketten-en-commandos). Shared gebruikt geen tool en krijgt geen OpenVox-specifieke JSON-grens. De gem bevat uitsluitend eigen `lib/`, deze README en de licentie, zonder executable, tests, fixtures of rapporten.

## Testondersteuning

Repository-testhulp staat in `test_support/` en wordt niet verpakt. `bootstrap.rb` initialiseert Minitest en `TestConsoleReporter` eenmaal via Ruby `require`. De adapter gebruikt de runtimeconsole voor presentatie en de native Minitest JUnit-reporter voor dezelfde testcase-identiteiten. De bekende native testselectie levert het totaal; bij een exclude-filter levert het framework geen betrouwbaar totaal en vermeldt de adapter dat de volledigheid onbekend is. Skips blijven zichtbaar. De primaire afsluiting volgt na de aangevraagde JUnit-schrijfhandeling, zodat een schrijffout geen geslaagd eindresultaat krijgt. Alleen wanneer de aanroeper `MINITEST_REPORTERS_REPORTS_DIR` instelt, wordt ook JUnit geschreven. Zonder die instelling geven zowel Rake-taken als rechtstreeks gestarte testbestanden alleen console-uitvoer. De bootstrap kent geen vaste resultaatmap en laadt geen lintconfiguratie. De [gezamenlijke testinrichting](../README.md#gezamenlijke-tooltests) beschrijft de lokale aanroep en expliciete CI-instelling.

`packages.rb` deelt tijdelijke consumeromgevingen, subprocess-uitvoering met afzonderlijke stdout/stderr/status en het bouwen en installeren van afzonderlijke gems. De linthelper voegt alleen zijn eigen configuratie en verwachtingen toe. Validator- en dependencydistributietests gebruiken dezelfde packagehulp zonder lintbeleid. Package-tests werken offline met beschikbare externe gems, eigen Gemfiles en lockfiles; ze publiceren niets.

Voer vanuit de repositoryroot `bundle exec rake test:shared` uit voor deze library en `bundle exec rake test` voor alle tools. De bootstraptests bewaken eenmalige initialisatie en behoud van andere rapportbestanden. Documentatielinks, workflow- en testindeling horen bij de [repositorycontroles](../repository/README.md). De [projectbrede testscope](../../TESTS.md#testscope-en-plaatsing) en [gezamenlijke testinrichting](../README.md#gezamenlijke-tooltests) blijven leidend.
