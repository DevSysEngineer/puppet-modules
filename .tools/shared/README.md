# Gedeelde toolingbibliotheek

`project-tools-shared` levert het technische fundament voor `lint-project`, `project-tools-metadata`, `project-tools-validate` en `project-tools-module-dependencies`. Gebruik de [gezamenlijke installatiehandleiding](../README.md#installatie) om de gembron en bundle in te richten.

Voor links buiten deze gem lees je de handleiding in de bijbehorende repositorycheckout.

## Inhoudsopgave

- [Inhoudsopgave](#inhoudsopgave)
- [Runtimecontracten](#runtimecontracten)
- [Afhankelijkheden en onderhoud](#afhankelijkheden-en-onderhoud)
- [Testondersteuning](#testondersteuning)

## Runtimecontracten

`require 'project_tools/shared/junit_report'` levert `ProjectTools::Shared::JunitReport.write(output, name:, **counts) { |xml| ... }`. De schrijver maakt de XML-declaratie, `testsuites` en `testsuite`; de producer levert tellingen, testcases, failures, errors en eventuele rapporttekst. Builder verzorgt escaping. Lint, metadata, parser en dependencyreporter gebruiken dezelfde implementatie, maar behouden ieder hun eigen succescriterium en exitstatus.

`require 'project_tools/shared/modulepath'` levert `ProjectTools::Shared::Modulepath.parse(value)`. Deze functie splitst met `File::PATH_SEPARATOR`, weigert lege of ongeldige onderdelen en vereist absolute bestaande directories. Het resultaat bevat bevroren, gecanonicaliseerde paden in oorspronkelijke volgorde, inclusief duplicaten. Ongeldige invoer geeft `ArgumentError`; bestandsysteemfouten behouden hun Ruby-fouttype. De linter en dependencytool gebruiken deze validatie.

De aanroeper bepaalt of een ontbrekende modulepath een terugval activeert of een configuratiefout oplevert. Shared selecteert geen modules, metadata, manifests of toegestane bronbestanden. De linter behoudt zijn eigen symlink- en bronleesgrenzen; dependencycontrole volgt native Puppet-selectie. De package voert bij laden geen scans uit, initialiseert geen Puppet-instellingen of Minitest, registreert geen lintchecks en wijzigt geen rapporten.

`project_lint/junit_report` blijft in de lintgem beschikbaar als compatibility-shim. `ProjectLint::JunitReport` verwijst naar dezelfde shared-module, met dezelfde signatuur. Er is geen tweede XML-implementatie of fallback naar een naastgelegen checkout.

## Afhankelijkheden en onderhoud

Shared declareert Builder als runtime-dependency. De vier tools declareren hun geteste shared-range `>= 0.1.0, < 0.2.0`. Shared gebruikt geen tool en krijgt geen OpenVox-specifieke JSON-grens. De gem bevat uitsluitend eigen `lib/`, deze README en de licentie, zonder executable, tests, fixtures of rapporten.

Voeg alleen code toe als concrete afnemers hetzelfde technische gedrag nodig hebben. Metadata-autofix, selectiebeleid, Puppet-lintchecks, parserorkestratie en dependencybevindingen blijven bij hun tool. Een wijziging aan een gedeeld contract vereist controle van alle betrokken CLI’s en distributieroutes volgens de [gezamenlijke validatie](../README.md#gezamenlijke-tooltests).

## Testondersteuning

Repository-testhulp staat in `test_support/` en wordt niet verpakt. `bootstrap.rb` initialiseert Minitest en de reporters eenmaal via Ruby `require`. Alleen wanneer de aanroeper `MINITEST_REPORTERS_REPORTS_DIR` instelt, wordt ook JUnit geschreven. Zonder die instelling geven zowel Rake-taken als rechtstreeks gestarte testbestanden alleen console-uitvoer. De bootstrap kent geen vaste resultaatmap en laadt geen lintconfiguratie. De [gezamenlijke testinrichting](../README.md#gezamenlijke-tooltests) beschrijft de lokale aanroep en expliciete CI-instelling.

`packages.rb` deelt tijdelijke consumeromgevingen, subprocess-uitvoering met afzonderlijke stdout/stderr/status en het bouwen en installeren van afzonderlijke gems. De linthelper voegt alleen zijn eigen configuratie en verwachtingen toe. Validator- en dependencydistributietests gebruiken dezelfde packagehulp zonder lintbeleid. Package-tests werken offline met beschikbare externe gems, eigen Gemfiles en lockfiles; ze publiceren niets.

Voer vanuit de repositoryroot `bundle exec rake test:shared` uit voor deze library en `bundle exec rake test` voor alle tools. De bootstraptests bewaken eenmalige initialisatie en behoud van andere rapportbestanden. Documentatielinks, workflow- en testindeling horen bij de [repositorycontroles](../repository-checks/README.md). De [projectbrede testscope](../../AGENTS.md#test-scope) en [gezamenlijke testinrichting](../README.md#gezamenlijke-tooltests) blijven leidend.
