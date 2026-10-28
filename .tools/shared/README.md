# Gedeelde toolingbibliotheek

`project-tools-shared` levert het technische fundament voor `lint-project`, `project-tools-secrets`, `project-tools-metadata`, `project-tools-syntax` en `project-tools-module`. Gebruik de [gezamenlijke installatiehandleiding](../README.md#installatie) om de gembron en bundle in te richten.

Voor links buiten deze gem lees je de handleiding in de bijbehorende repositorycheckout.

## Inhoudsopgave

- [Inhoudsopgave](#inhoudsopgave)
- [Runtimecontracten](#runtimecontracten)
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
