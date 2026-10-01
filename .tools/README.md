# Gedeelde projecttooling

Gebruik één ontwikkelbundle met afzonderlijke tools voor Puppet-lint, Ruby-lint, metadata, parservalidatie en moduledependencies. Iedere tool heeft een eigen commando en resultaat. Kies voor je eigen project alleen de benodigde pakketten; geen van deze controles past catalogi toe.

## Inhoudsopgave

- [Inhoudsopgave](#inhoudsopgave)
- [Pakketten en commando’s](#pakketten-en-commandos)
- [Verantwoordelijkheden gescheiden houden](#verantwoordelijkheden-gescheiden-houden)
  - [CLI en rapportage](#cli-en-rapportage)
- [Snelstart in deze repository](#snelstart-in-deze-repository)
- [Installatie en compatibiliteit](#installatie-en-compatibiliteit)
  - [Benodigde omgeving](#benodigde-omgeving)
  - [Installatie](#installatie)
  - [Ruby op macOS](#ruby-op-macos)
  - [Gems installeren](#gems-installeren)
- [Gedeeld modulepad](#gedeeld-modulepad)
- [Rapporten en CI](#rapporten-en-ci)
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
  - [Git-dependency uit de monorepo](#git-dependency-uit-de-monorepo)
  - [Gebouwd gempakket installeren](#gebouwd-gempakket-installeren)
  - [Migreren naar de zes pakketten](#migreren-naar-de-zes-pakketten)
- [Gezamenlijke tooltests](#gezamenlijke-tooltests)
  - [Versies bijwerken](#versies-bijwerken)
  - [Eigen tooltests](#eigen-tooltests)
    - [Testselectie en uitvoeropties](#testselectie-en-uitvoeropties)
    - [JUnit-rapportage instellen](#junit-rapportage-instellen)

## Pakketten en commando’s

| Pakket | Eigenaar | Publieke commando’s |
| --- | --- | --- |
| `project-tools-metadata 0.1.0` | [Metadata](metadata/README.md) | `project-tools-metadata [--fix] [--ignore-paths GLOBS] [--junit REPORT.xml]` |
| `project-tools-module-dependencies 0.1.0` | [Dependencycontrole](module-dependencies/README.md) | `project-tools-module-dependencies [--junit REPORT.xml]` |
| `project-tools-validate 0.1.0` | [Parservalidatie](validate/README.md) | Native `puppet parser validate MANIFEST.pp`; met rapport `validate-junit REPORT.xml MANIFEST.pp [MANIFEST.pp ...]` |
| `lint-project 0.2.0` | [Lint](lint/README.md) | `puppet-lint`, `puppet-lint-junit` |
| `project-tools-ruby-lint 0.1.0` | [Ruby-lint](ruby-lint/README.md) | Native `rubocop` met eigen JUnit-formatter |
| `project-tools-shared 0.1.0` | [Gedeelde library](shared/README.md) | Geen eigen executable |

De validatorgem gebruikt shared, OpenVox, JSON en syslog; de dependencygem gebruikt daarnaast semantic_puppet. OpenVox heeft syslog op de gebruikte Ruby 4-runtime nodig; alle drie OpenVox-gebruikers declareren die dependency zelf. Validator en dependencytool installeren geen Puppet-lint, lintplugins of RuboCop. Shared gebruikt geen van de tools en initialiseert geen Puppet-runtime. Metadata gebruikt JSON en shared, zonder Puppet-runtime. Ruby-lint gebruikt alleen RuboCop. Lint gebruikt OpenVox voor zijn eigen AST-analyse. [Repositorycontroles](repository-checks/README.md) bewaken uitsluitend deze ontwikkelcheckout en vormen geen runtimegem.

## Verantwoordelijkheden gescheiden houden

Houd iedere onafhankelijke controle bij haar eigen tool: CLI, runtime-dependencies, configuratie, correcties, rapport en gedragstests. Puppet-lint corrigeert Puppet-invoer; metadatawijzigingen vereisen het metadatacommando. Ruby-lint gebruikt de native RuboCop-CLI en formatter. Een gezamenlijke bundle of CI-setup maakt deze tools niet afhankelijk van elkaar.

Shared bevat alleen technisch gedrag dat meerdere tools daadwerkelijk delen, zoals XML en modulepadvalidatie. Repositorydocumentatie, workflowconfiguratie, distributie-integratie en testindeling worden door [repositorycontroles](repository-checks/README.md) bewaakt. Houd gedeelde instellingen, taken en rapportlocaties neutraal benoemd; leg toolspecifieke instellingen bij hun eigenaar vast. Pas bij een verplaatsing ook consumerinstallatie, CI, rapporten en documentatie samen aan.

### CLI en rapportage

Een controle of herstelhandeling moet lokaal uitvoerbaar zijn met console-uitvoer en een passende exitstatus, zonder verplicht rapportbestand. Geef een zelfstandig controlecommando een naam die zijn taak beschrijft. Gebruik bij onze eigen controle-CLI’s `--junit REPORT.xml` voor optionele JUnit-uitvoer. Zonder deze optie worden geen rapporten of rapportmappen aangemaakt of bijgewerkt; een bestaande rapportmap is geen vereiste voor controle of herstel. CI vraagt het rapport expliciet aan.

Dit geldt ook voor Rake-taken, standaardtaken en voorbeeldhelpers: laat die rapportage niet impliciet inschakelen of een rapportpad invullen. Voor Minitest vraagt de aanroeper rapportage aan via de bestaande instelling `MINITEST_REPORTERS_REPORTS_DIR`. Een gewone `rake test`, gerichte testtaak of standaardtaak behoudt zonder die instelling uitsluitend console-uitvoer en de teststatus.

Gebruik bestaande native commando’s en hun uitvoeropties wanneer die de controle al aanbieden. Puppet-lint en RuboCop hebben hun eigen CLI en correctieopties; `puppet parser validate` biedt syntaxvalidatie zonder rapport. Voeg daarvoor geen gelijknamige projectwrapper of uniforme set opties toe. Een aparte converter of rapportagevariant mag een uitvoerformaat in zijn naam en een verplicht rapportpad hebben: `puppet-lint-junit` zet bestaande JSON-uitvoer om, terwijl `validate-junit` native parserresultaten per manifest verzamelt. Documenteer bij zo’n variant ook het gewone commando zonder rapport.

Controle en rapportage gebruiken dezelfde bevindingen. Het aanvragen van een rapport verandert het oordeel niet; een fout bij het schrijven van een gevraagd rapport blijft wel een uitvoerfout. Leg dit vast in gedragstests bij de tool: geslaagde en afgekeurde controles met en zonder rapport, herstel zonder rapport indien ondersteund, geen rapportwijzigingen zonder verzoek en behoud van de foutstatus bij rapportageproblemen. Controleer daarnaast de geïnstalleerde CLI en werk voorbeelden, CI en consumermigratie samen bij wanneer het commando verandert.

## Snelstart in deze repository

**Werkmap:** Repositoryroot. **Shell:** POSIX shell. **Vereisten:** [Ontwikkelbundle](#installatie) en volledige submodules. **Invoer:** Eigen code en de lokale moduleset. **Wijzigt bestanden:** Alleen rapporten en caches. **Verwacht resultaat:** Elke controle heeft zijn eigen status; dependencyconflicten blijven fouten.

```sh
export PROJECT_METADATA_MODULES_PATH=.
export PROJECT_TOOLS_MODULEPATH="$PWD"
bundle exec project-tools-metadata
bundle exec project-tools-module-dependencies
bundle exec rake validate:puppet
bundle exec puppet-lint --no-config --config .puppet-lint.rc .
bundle exec rubocop --config .rubocop.yml
bundle exec rake test
```

Voer de opdrachten afzonderlijk uit en beoordeel iedere exitstatus. De [project-README](../README.md#ondersteuning-en-compatibiliteit) beschrijft de gebruikte dependencies en hun compatibiliteitsgrenzen. Pas ranges of gitlinks alleen aan na inhoudelijk compatibiliteitsonderzoek.

## Installatie en compatibiliteit

### Benodigde omgeving

Je hebt Git, de nieuwste stabiele Ruby en de nieuwste stabiele Bundler nodig. Werk in een volledige checkout van deze repository, inclusief de verborgen bestanden en Git-submodules. De installatie hieronder haalt de submodules op en installeert de gems die de controles gebruiken.

Voer de commando's voor deze repository uit vanuit de hoofdmap. Het ontwikkelgereedschap staat onder `.tools`, apart van de Puppet-modules. De ontwikkelomgeving bepaalt niet welke Puppet- of OpenVox-versies op beheerde servers worden ondersteund; daarvoor gelden de modulemetadata en de [project-README](../README.md#ondersteuning-en-compatibiliteit).

De controles passen geen catalogi toe en hebben geen productiegeheimen of verbindingen met beheerde servers nodig. De [testhandleiding](#gezamenlijke-tooltests) beschrijft welke controles bij de tooltests horen en hoe je synthetische testinvoer gebruikt.

### Installatie

Gebruik de nieuwste stabiele Ruby en Bundler. Pin hun versies niet in setupcommando’s of runtimeconfiguratie. Richt op macOS eerst Ruby in met de onderstaande stappen. Heb je de nieuwste stabiele Ruby al actief, ga dan door met [de gems installeren](#gems-installeren).

### Ruby op macOS

De Ruby die macOS meelevert is te oud voor deze ontwikkelomgeving. De stappen hieronder gebruiken de nieuwste stabiele Ruby uit de [Homebrew-formule `ruby`](https://formulae.brew.sh/formula/ruby) en gaan uit van zsh. Gebruik je een Ruby-versiebeheerder zoals rbenv of mise, installeer en activeer de nieuwste stabiele Ruby daarmee en ga door naar [Gems installeren](#gems-installeren).

Controleer de [macOS-vereisten van Homebrew](https://docs.brew.sh/Installation#macos-requirements), waaronder de benodigde Command Line Tools voor Xcode. Installeer [Homebrew](https://brew.sh/) als `brew` nog niet beschikbaar is en volg ook de aanwijzingen voor de shellconfiguratie. Voer daarna dit blok uit in je huidige terminal:

**Werkmap:** Willekeurige werkmap op macOS. **Shell:** zsh. **Vereisten:** Homebrew en de genoemde macOS-vereisten. **Invoer:** Homebrew-formule ruby. **Wijzigt bestanden:** Ruby-installatie en PATH in deze shell. **Verwacht resultaat:** Homebrew-Ruby actief.

```sh
brew install ruby
export PATH="$(brew --prefix ruby)/bin:$PATH"
export PATH="$(ruby -r rubygems -e 'print Gem.bindir'):$PATH"
ruby --version
command -v ruby
```

De eerste `export` kiest Homebrew-Ruby. De tweede vraagt die Ruby waar gemcommando's worden geïnstalleerd en voegt ook die map aan PATH toe. Zo zijn de commando's beschikbaar die je straks met `gem install` installeert. Met `brew --prefix ruby` hoef je het installatiepad niet vast te leggen op Apple Silicon of Intel; de beschikbaarheid van Ruby voor jouw macOS-versie en architectuur volgt uit de Homebrew-formule.

Controleer in de uitvoer welke Ruby-versie actief is. `command -v ruby` moet naar Homebrew wijzen en niet naar `/usr/bin/ruby`.

Voor nieuwe zsh-terminals zet je dezelfde twee `export PATH=...`-regels, in dezelfde volgorde, in `~/.zshrc`. Plaats ze na eventuele Homebrew-initialisatie en behoud de `$(...)`-expressies letterlijk, zodat iedere nieuwe terminal de paden opnieuw bepaalt. Open daarna een nieuwe terminal en herhaal `ruby --version` en `command -v ruby`.

### Gems installeren

Voer dit uit vanuit de repositoryroot met de juiste Ruby actief. Haal ook de Git-submodules op, zodat de moduleverzameling compleet is.

**Werkmap:** Repositoryroot. **Shell:** POSIX shell. **Vereisten:** Nieuwste stabiele Ruby, Git en netwerktoegang voor de bestaande dependencies. **Invoer:** Bestaande submodules, Gemfile en lockfile. **Wijzigt bestanden:** Submodulecheckouts en geminstallatie. **Verwacht resultaat:** Bundle met de gelockte dependencies geïnstalleerd.

```sh
git submodule sync --recursive
git submodule update --init --recursive
gem install bundler
export BUNDLE_VERSION=system
bundle install
```

`gem install bundler` installeert de nieuwste stabiele Bundler. Met `BUNDLE_VERSION=system` gebruik je de geïnstalleerde versie, ook wanneer `BUNDLED WITH` in de lockfile een oudere versie noemt. Zet deze variabele ook in een nieuwe terminal voordat je de bundle gebruikt.

De [Gemfile](../Gemfile) bevat geen vaste gemversies. [`Gemfile.lock`](../Gemfile.lock) bewaart wel de geteste combinatie, zodat `bundle install` lokaal en in CI dezelfde gems installeert. Het ophalen van nieuwere versies staat apart onder [Versies bijwerken](#versies-bijwerken).

Krijg je een Bundler-fout met `/System/Library/Frameworks/Ruby.framework` of `/usr/bin/bundle` in de melding, dan gebruikt je terminal nog de macOS-installatie. Controleer eerst `ruby --version`, `command -v ruby` en `command -v bundle` en herstel de PATH-instelling hierboven. Bundler installeren met de oude systeem-Ruby of `sudo gem install` lost die versieverschillen niet op.

De root-Gemfile wijst iedere toolgem expliciet aan via zijn eigen map. Lint, metadata, validator en dependencycontrole gebruiken shared (`>= 0.1.0, < 0.2.0`); Ruby-lint gebruikt uitsluitend RuboCop. Ontwikkeldependencies blijven in de rootbundle.

## Gedeeld modulepad

`PROJECT_TOOLS_MODULEPATH` is de geordende, met `File::PATH_SEPARATOR` gescheiden lijst van absolute bestaande modulemappen. Lege onderdelen zijn ongeldig. Op macOS en Linux is het scheidingsteken `:`; spaties in paden zijn toegestaan, een `:` in een mapnaam niet. De shared-library valideert paden; iedere tool bepaalt zijn eigen selectie. De linter behoudt zijn terugval naar de werkmap en bronleesgrenzen. De dependencytool verlangt een expliciete niet-lege waarde en volgt native Puppet-selectie, inclusief legitieme module-symlinks.

`PROJECT_METADATA_MODULES_PATH` selecteert uitsluitend eigen metadata voor `project-tools-metadata`; `PROJECT_METADATA_PREFIX` is diens naamgevingsinstelling. Ze bepalen geen dependencies of modulepadvolgorde. De rootmetadata van metadata- en dependencycontrole staan in de werkmap, nooit automatisch bij de geïnstalleerde gem.

## Rapporten en CI

### Rapportmap kiezen

Kies een eigen map voor gegenereerde rapporten binnen je project, bijvoorbeeld `.tools/quality/results/`, `.tools/checks/results/` of `build/reports/`. De naam `lint` en de locatie onder `.tools/` zijn voor afnemende projecten niet verplicht. Deze repository gebruikt de [rapportlocaties per tool](#ci-van-deze-repository), geen vast uitvoerpad van de gedeelde gems. Gebruik een aparte uitvoermap, houd die buiten versiebeheer en schrijf niet naar `global-modules` of de geïnstalleerde gem.

De voorbeelden hieronder gebruiken `PROJECT_REPORT_DIR` om die projectkeuze door te geven. Stel de variabele in vanuit je eigen projectroot voordat je de rapportcommando's uitvoert:

**Werkmap:** Consumerroot. **Shell:** POSIX shell. **Vereisten:** Eigen rapportkeuze. **Invoer:** Het concrete voorbeeldpad. **Wijzigt bestanden:** Alleen shellomgeving. **Verwacht resultaat:** PROJECT_REPORT_DIR beschikbaar voor de volgende procedures.

```sh
export PROJECT_REPORT_DIR=".tools/quality/results"
```

Dit is een afspraak in de voorbeeldconfiguratie van het afnemende project, geen automatisch ingelezen geminstelling. De shellcommando's geven het pad expliciet mee. De voorbeeldtaak voor parserrapportage leest de variabele zelf en gebruikt `.tools/quality/results` wanneer die ontbreekt. Voor testrapportage geeft de aanroeper het gekozen pad expliciet door via `MINITEST_REPORTERS_REPORTS_DIR`. Geef een niet-leeg pad op, relatief aan de eigen projectroot. De voorbeelden plaatsen ook de CI-artifacts binnen die checkout.

Gebruik dezelfde waarde lokaal en in CI. In het [GitHub-voorbeeld](#controle-in-ci) stel je die eenmaal onder `env` in; in het [GitLab-fragment](#rapporten-tonen-in-gitlab) onder `variables`. De uitvoercommando's, uploadpaden en testsamenvatting verwijzen naar die instelling. Pas daarnaast de eigen `.gitignore` aan het concrete pad aan: Git vervangt daar geen omgevingsvariabelen. De [rapportafspraken](#rapporten-en-artifacts-in-je-project) tonen per controle het bestand binnen deze map.

### CI van deze repository

Onderhoud metadata, dependencycontrole, parservalidatie, Puppet-linting, Ruby-linting en tooltests als onafhankelijke CI-jobs. Genereer alle gepubliceerde validatie-, lint- en testrapporten tijdens de betreffende uitvoering als JUnit XML. Publiceer iedere soort als afzonderlijk artifact na succes of een gewone controlefout en behoud de oorspronkelijke exitstatus. Bewaar gegenereerde rapporten in een genegeerde results-map onder `.tools/` en documenteer commando’s en locaties hier. Sluit het geslaagde validatiepad van iedere job af met `git diff --exit-code HEAD --`; de [projectworkflow](../AGENTS.md#ci-jobs-and-reports) verbiedt herstel om die controle te laten slagen.

[GitHub Actions](../.github/workflows/checks.yml) voert zes onafhankelijke jobs uit. Iedere job haalt de repository met submodules op en roept daarna [setup-tooling](../.github/actions/setup-tooling/action.yml) aan voor dezelfde Ruby-, Bundler- en frozen-bundle-installatie. Daarna volgt de eigen controle. De Ruby-job controleert de Ruby-code van alle tools. De testjob voert alle suites uit, inclusief repositorycontroles. Een fout in één controle houdt de andere jobs niet tegen.

Houd in de workflow, controleoverzichten en CI-voorbeelden de onderstaande volgorde aan: eerst projectmetadata en de gedeclareerde dependencies, daarna Puppet-syntax en de twee linters, en ten slotte het gedrag van de tools via hun tests. Dit is de leesvolgorde. De jobs kunnen parallel starten; hun start- en eindvolgorde liggen niet vast. Voeg geen `needs`-relaties of afzonderlijke stages toe om deze indeling als uitvoervolgorde af te dwingen.

| Job | Controle | Downloadbaar artifact | Inhoud |
| --- | --- | --- | --- |
| `Metadata` | Root- en modulemetadata, versiebron en naamgeving | `Metadata-report` | `.tools/metadata/results/metadata-report.xml` |
| `Puppet dependencies` | Native module- en rootdependencycontrole | `Project-tools-module-dependencies-report` | `.tools/module-dependencies/results/project-tools-module-dependencies-report.xml` |
| `Validate` | `bundle exec rake validate:puppet` met JUnit per manifest | `Validate-report` | `.tools/validate/results/validate-report.xml` |
| `Puppet lint` | De volledige Puppet-lintscan met JUnit-omzetting | `Puppet-lint-report` | `.tools/lint/results/puppet-lint-report.xml` |
| `Ruby lint` | RuboCop met console- en JUnit-uitvoer | `Ruby-lint-report` | `.tools/ruby-lint/results/rubocop-report.xml` |
| `Tool tests` | `bundle exec rake test` met expliciet `MINITEST_REPORTERS_REPORTS_DIR=.tools/results/tests` | `Test-results` | `.tools/results/tests/TEST-*.xml` |

De validatiejob gebruikt de [parsertaak](validate/README.md#puppet-manifests-valideren), de lintjobs gebruiken de [rapportaanroepen](#rapporten-en-artifacts-in-je-project) en de testjob gebruikt de gewone [roottaak](#gezamenlijke-tooltests). Iedere controle draait eenmaal en behoudt zijn eigen foutstatus. De tests omvatten pluginloading, autofixinteracties en het bouwen en installeren van de gem in een tijdelijk afnemend project. Dat controleert het ontwikkelgereedschap; het bewijst geen correct modulegedrag of ondersteuning van alle platforms.

Open de workflowrun onder **Actions** om de zes uitslagen en de artifacts te bekijken. De testjob publiceert zijn JUnit-resultaten in het overzicht. De dependencyjob publiceert hetzelfde dependency-JUnit-bestand als artifact en als summary met `show: fail` en `folded: false`. Een ontbrekend rapport laat de upload expliciet falen; de summary vereist een bestaand bestand. Controleer na menselijke publicatie zowel een failure als een error in de daadwerkelijke GitHub-weergave. XML-tests alleen bewijzen die presentatie niet. De upload- en samenvattingsstappen gebruiken `!cancelled()`, zodat al gemaakte rapporten na een gewone validatie-, lint- of testfout beschikbaar blijven. Wanneer de installatie of het laden van de tests al mislukt, is er mogelijk nog geen bruikbaar rapport. Een geannuleerde run hoeft evenmin rapporten op te leveren.

Puppet-lint schrijft onder `.tools/lint/results/`, Ruby-lint onder `.tools/ruby-lint/results/` en tooltests onder `.tools/results/tests/`. De metadata-, parser- en dependencyreporters maken hun eigen bovenliggende rapportmap aan. De uploads gebruiken `include-hidden-files: true`, omdat `.tools` een verborgen map is. Iedere artifactselectie wijst uitsluitend naar het eigen lint- of validatierapport of naar `TEST-*.xml`; de testsamenvatting leest dezelfde testselectie.

Iedere job voert na zijn geslaagde controle rechtstreeks `git diff --exit-code HEAD --` uit. Dit vindt wijzigingen die installatie of controles in gevolgde bestanden hebben achtergelaten ten opzichte van de uitgecheckte commit. Nieuwe, niet-gevolgde bestanden vallen erbuiten. De opdracht vergelijkt geen twee commits en vervangt de lokale whitespacecontrole met `git diff --check` niet. Voer deze CI-controle uit vanuit een schone checkout; lokale ontwikkelwijzigingen geven eveneens een verschil.

De workflow gebruikt de nieuwste stabiele Ruby en installeert Bundler zonder versiepin. `BUNDLE_FROZEN=true` bewaakt de lockfile; `BUNDLE_IGNORE_CONFIG=1` voorkomt afhankelijkheid van persoonlijke Bundler-instellingen. Gems worden binnen de checkout geïnstalleerd via `BUNDLE_PATH=vendor/bundle`. De metadatajob stelt `PROJECT_METADATA_MODULES_PATH=.` in; de overige jobs hebben die instelling niet nodig. De jobs gebruiken Bash met `pipefail`, zodat ook de Puppet-lintaanroep met JUnit-omzetting zijn foutstatus behoudt. Beide linters controleren alleen; de workflow maakt geen commits en publiceert geen gem.

De artifacts en het testoverzicht vereisen geen extra schrijfrechten op de repository; `contents: read` blijft voldoende. De samenvatting schrijft geen pull-requestcomments of afzonderlijke check runs. Gebruikt de repository verplichte statuschecks, selecteer dan alle zes de jobnamen uit de tabel. Voor afnemende projecten staat hieronder een [voorbeeld met dezelfde CLI](#controle-in-ci).

### Rapporten en artifacts in je project

Gebruik JUnit XML voor alle gepubliceerde validatie-, lint- en testrapporten en schrijf ze naar de [eigen rapportmap](#rapportmap-kiezen). De voorbeelden gebruiken daarvoor `PROJECT_REPORT_DIR`; de projectroot blijft vrij van losse rapportbestanden. De uitvoermap bevat alleen gegenereerde resultaten; de lintercode en gedeelde profielen komen uit de gem in `global-modules` of je andere gembron.

Bewaar bij voorkeur de resultaten van iedere controle in een afzonderlijk artifact van de job die de controle uitvoert. Daardoor vind je een lintbevinding of testfout direct bij de bijbehorende uitslag. De JUnit-bestanden van één testuitvoering vormen samen één testartifact.

| Job | Bestand binnen de gekozen rapportmap | Artifactnaam | Voorwaarde |
| --- | --- | --- | --- |
| `Metadata` | `metadata-report.xml` | `Metadata-report` | Eigen VERSION, rootmetadata en expliciete modulelocatie. |
| `Puppet dependencies` | `project-tools-module-dependencies-report.xml` | `Project-tools-module-dependencies-report` | Eigen rootmetadata en expliciete modulepath met alle dependencies. |
| `Validate` | `validate-report.xml` | `Validate-report` | De eigen Puppet-manifests zijn geselecteerd. |
| `Puppet lint` | `puppet-lint-report.xml` | `Puppet-lint-report` | De eigen Puppet-manifests en lintconfiguratie zijn aanwezig. |
| `Ruby lint` | `rubocop-report.xml` | `Ruby-lint-report` | De eigen Ruby-code en RuboCop-configuratie zijn aanwezig. |
| `Tool tests` | `TEST-*.xml` | `Test-results` | Het project heeft een eigen testsuite en [JUnit-rapportage](#junit-rapportage-instellen). |

De voorbeelden gebruiken de zes pakketten volgens [Installatie in je project](#installatie-in-je-project). Bewaar de gekozen submodulerevisie en eigen lockfile en volg bij updates de [consumermigratie](#migreren-naar-de-zes-pakketten). De commando's zijn onderdeel van de gem; je kopieert geen converter of validator naar je eigen project.

Stel eerst `PROJECT_REPORT_DIR` in volgens [Rapportmap kiezen](#rapportmap-kiezen).

Voor metadata gebruik je de [eigen modulelocatie en naamprefix](metadata/README.md#gebruik-in-een-ander-project). De opdracht schrijft ook bij metadatafouten een eigen rapport:

**Werkmap:** Consumerroot. **Shell:** POSIX shell. **Vereisten:** Eigen bundle, VERSION, rootmetadata, modules-map en ingestelde PROJECT_REPORT_DIR. **Invoer:** Eigen metadata. **Wijzigt bestanden:** Metadata-JUnit. **Verwacht resultaat:** Exitcode 0 bij geldige metadata, anders een foutstatus.

```sh
export PROJECT_METADATA_MODULES_PATH=modules
export PROJECT_METADATA_PREFIX=example
bundle exec project-tools-metadata --junit "$PROJECT_REPORT_DIR/metadata-report.xml"
```

De [dependencycontrole](module-dependencies/README.md#een-controle-uitvoeren) schrijft haar rapport bij de expliciete `--junit`-aanroep. Het validatierapport ontstaat tijdens de [parseraanroep](validate/README.md#eigen-manifests-valideren).

Maak het Puppet-lintrapport vanuit de projectroot met dezelfde configuratie en bronselectie als de [gewone controle](lint/README.md#eigen-code-controleren):

**Werkmap:** Consumerroot. **Shell:** Bash met errexit en pipefail. **Vereisten:** Eigen bundle, [configuratie](lint/README.md#eigen-lintconfiguratie), [rapportmap](#rapportmap-kiezen) en genoemde manifests/modules. **Invoer:** De twee genoemde eigen manifests. **Wijzigt bestanden:** Puppet-lint-JUnit. **Verwacht resultaat:** Lint- en conversiefouten blijven jobfouten.

```bash
set -eo pipefail
mkdir -p "$PROJECT_REPORT_DIR"
lint_gem="$(bundle info --path lint-project)"
export PROJECT_TOOLS_MODULEPATH="$PWD/global-modules:$PWD/modules"
test -f .puppet-lint.rc
bundle exec puppet-lint --no-config --load "$lint_gem/lib/project_lint.rb" --config "$lint_gem/config/puppet-lint.rc" --config .puppet-lint.rc --json environments/production/manifests/site.pp modules/profile/manifests/init.pp | bundle exec puppet-lint-junit "$PROJECT_REPORT_DIR/puppet-lint-report.xml"
```

Pas modulemappen en manifestpaden aan je project aan. Bash `pipefail` behoudt de foutstatus van Puppet-lint tijdens de omzetting en laat de opdracht ook bij een conversiefout falen. De configuratie, bestandsselectie en controle op waarschuwingen blijven gelijk aan de gewone scan. De [uitleg over de rapportinhoud](lint/README.md#lintrapporten-maken) beschrijft hoe lintmeldingen in JUnit worden weergegeven.

Voor Ruby gebruik je afzonderlijk de volgende aanroep. De [eigen `.rubocop.yml`](ruby-lint/README.md#ruby-controleren-in-een-ander-project) bepaalt welke bestanden worden gecontroleerd:

**Werkmap:** Consumerroot. **Shell:** POSIX shell. **Vereisten:** Eigen bundle, .rubocop.yml en [rapportmap](#rapportmap-kiezen). **Invoer:** Eigen Ruby-selectie. **Wijzigt bestanden:** RuboCop-JUnit en cache. **Verwacht resultaat:** Console en XML met dezelfde foutstatus.

```sh
mkdir -p "$PROJECT_REPORT_DIR"
bundle exec rubocop --config .rubocop.yml --format progress --format junit --out "$PROJECT_REPORT_DIR/rubocop-report.xml"
```

De testtaak uit [JUnit-rapportage instellen](#junit-rapportage-instellen) maakt zijn eigen rapporten bij `MINITEST_REPORTERS_REPORTS_DIR="$PROJECT_REPORT_DIR" bundle exec rake test`. Iedere controle draait eenmaal. Alle artifacts bevatten JUnit XML; houd parservalidatie, lintresultaten en tooltests als afzonderlijke suites en artifacts herkenbaar.

Neem de hele gekozen uitvoermap met zijn concrete pad op in de eigen `.gitignore`. Voor de voorbeeldwaarde `.tools/quality/results` is dat:

```gitignore
/.tools/quality/results/
```

Het [GitHub Actions-voorbeeld](#controle-in-ci) bewaart elk rapport als downloadbaar artifact en toont tooltests en dependencybevindingen ook in het workflowoverzicht. Voor het testoverzicht van GitLab voeg je de [JUnit-registratie](#rapporten-tonen-in-gitlab) toe aan iedere producerende job. Downloaden en weergeven gebruiken dezelfde rapportbestanden.

Gebruik voor het testartifact en de testsamenvatting uitsluitend `TEST-*.xml` binnen de gekozen testmap. Een selectie van de hele map of `*.xml` neemt ook de lint- en validatierapporten mee. Verander je een rapportbestandsnaam, pas dan de bijbehorende upload en JUnit-registratie samen aan. GitHub Actions vereist [`include-hidden-files: true`](https://github.com/actions/upload-artifact#uploading-hidden-files) wanneer de gekozen map onder een verborgen pad zoals `.tools` staat; de onderstaande voorbeelden beperken de upload tot de bedoelde rapportbestanden.

### Controle in CI

Gebruik de eigen `VERSION` en rootmetadata en leg de modulelocatie en naamprefix vast volgens [Modulemetadata controleren](metadata/README.md#modulemetadata-controleren). De onderstaande GitHub- en GitLab-voorbeelden gebruiken `example` als synthetische eigenaar; vervang die door de vastgelegde eigenaar van je project.

Gebruik dezelfde Gemfile, lockfile, configuratie en CLI-aanroepen als lokaal. Het onderstaande GitHub Actions-voorbeeld hoort bij een project met `global-modules`, eigen Ruby-code en een Minitest-suite met de [reporterconfiguratie voor eigen tooltests](#junit-rapportage-instellen). Bewaar het als `.github/workflows/checks.yml` in je eigen project en stel `env.PROJECT_REPORT_DIR` in op de eigen rapportmap. De commando's, uploads en testsamenvatting gebruiken die waarde. Gebruik de jobs die bij je project horen: voor alleen dependencycontrole volstaat `puppet_dependencies`; zonder eigen testsuite laat je `tool_tests` weg. Heeft het project geen eigen Ruby-code, Gemfile, Rakefile of Ruby-tooling om te controleren, laat dan ook `ruby_lint` weg; kopieer geen tests of Ruby-code uit de gedeelde gem om een lege job te vullen.

Iedere job haalt `global-modules` met zijn submodules op en installeert de eigen ontwikkelbundle. De voorbeelden volgen de [vaste leesvolgorde](#ci-van-deze-repository). De jobs draaien onafhankelijk, zonder `needs` tussen controles, en bewaren ieder hun [eigen artifact](#rapporten-en-artifacts-in-je-project). Gebruik je een andere gembron of aanvullende Puppet-modules, voeg dan in iedere betrokken job de benodigde installatiestappen toe vóór de controle. De bronselectie en het modulepad volgen de inrichting van je eigen Puppet environment.

```yaml
name: Puppet checks

on:
  pull_request:
  push:

permissions:
  contents: read

env:
  BUNDLE_IGNORE_CONFIG: '1'
  BUNDLE_VERSION: system
  BUNDLE_FROZEN: 'true'
  BUNDLE_PATH: vendor/bundle
  PROJECT_REPORT_DIR: .tools/quality/results

defaults:
  run:
    shell: bash

jobs:
  metadata:
    name: Metadata
    runs-on: ubuntu-24.04
    env:
      PROJECT_METADATA_MODULES_PATH: modules
      PROJECT_METADATA_PREFIX: example
    steps:
      - name: Checkout repository
        uses: actions/checkout@v7
        with:
          submodules: recursive
          persist-credentials: false
      - name: Set up Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: ruby
          bundler: none
      - name: Install the latest stable Bundler
        run: gem install bundler
      - name: Install the project bundle
        run: bundle install
      - name: Check project and module metadata
        run: bundle exec project-tools-metadata --junit "$PROJECT_REPORT_DIR/metadata-report.xml"
      - name: Check for changes
        run: git diff --exit-code HEAD --
      - name: Upload metadata report
        if: ${{ !cancelled() }}
        uses: actions/upload-artifact@v7
        with:
          name: Metadata-report
          include-hidden-files: true
          path: ${{ env.PROJECT_REPORT_DIR }}/metadata-report.xml

  puppet_dependencies:
    name: Puppet dependencies
    runs-on: ubuntu-24.04
    steps:
      - name: Checkout repository
        uses: actions/checkout@v7
        with:
          submodules: recursive
          persist-credentials: false
      - name: Set up Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: ruby
          bundler: none
      - name: Install the latest stable Bundler
        run: gem install bundler
      - name: Install the project bundle
        run: bundle install
      - name: Check Puppet module dependencies
        run: |
          export PROJECT_TOOLS_MODULEPATH="$GITHUB_WORKSPACE/global-modules:$GITHUB_WORKSPACE/modules"
          bundle exec project-tools-module-dependencies --junit "$PROJECT_REPORT_DIR/project-tools-module-dependencies-report.xml"
      - name: Check for changes
        run: git diff --exit-code HEAD --
      - name: Upload Puppet dependency report
        if: ${{ !cancelled() }}
        uses: actions/upload-artifact@v7
        with:
          name: Project-tools-module-dependencies-report
          include-hidden-files: true
          if-no-files-found: error
          path: ${{ env.PROJECT_REPORT_DIR }}/project-tools-module-dependencies-report.xml
      - name: Publish dependency summary
        if: ${{ !cancelled() && hashFiles(format('{0}/project-tools-module-dependencies-report.xml', env.PROJECT_REPORT_DIR)) != '' }}
        uses: test-summary/action@v2
        with:
          paths: ${{ env.PROJECT_REPORT_DIR }}/project-tools-module-dependencies-report.xml
          show: fail
          folded: false

  validate:
    name: Validate
    runs-on: ubuntu-24.04
    steps:
      - name: Checkout repository
        uses: actions/checkout@v7
        with:
          submodules: recursive
          persist-credentials: false
      - name: Set up Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: ruby
          bundler: none
      - name: Install the latest stable Bundler
        run: gem install bundler
      - name: Install the project bundle
        run: bundle install
      - name: Validate own Puppet manifests
        run: bundle exec validate-junit "$PROJECT_REPORT_DIR/validate-report.xml" environments/production/manifests/site.pp modules/profile/manifests/init.pp
      - name: Check for changes
        run: git diff --exit-code HEAD --
      - name: Upload Puppet validation report
        if: ${{ !cancelled() }}
        uses: actions/upload-artifact@v7
        with:
          name: Validate-report
          include-hidden-files: true
          path: ${{ env.PROJECT_REPORT_DIR }}/validate-report.xml

  puppet_lint:
    name: Puppet lint
    runs-on: ubuntu-24.04
    steps:
      - name: Checkout repository
        uses: actions/checkout@v7
        with:
          submodules: recursive
          persist-credentials: false
      - name: Set up Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: ruby
          bundler: none
      - name: Install the latest stable Bundler
        run: gem install bundler
      - name: Install the project bundle
        run: bundle install
      - name: Check own Puppet manifests
        run: |
          mkdir -p "$PROJECT_REPORT_DIR"
          test -f .puppet-lint.rc
          lint_gem="$(bundle info --path lint-project)"
          export PROJECT_TOOLS_MODULEPATH="$GITHUB_WORKSPACE/global-modules:$GITHUB_WORKSPACE/modules"
          bundle exec puppet-lint --no-config --load "$lint_gem/lib/project_lint.rb" --config "$lint_gem/config/puppet-lint.rc" --config .puppet-lint.rc --json environments/production/manifests/site.pp modules/profile/manifests/init.pp | bundle exec puppet-lint-junit "$PROJECT_REPORT_DIR/puppet-lint-report.xml"
      - name: Check for changes
        run: git diff --exit-code HEAD --
      - name: Upload Puppet lint report
        if: ${{ !cancelled() }}
        uses: actions/upload-artifact@v7
        with:
          name: Puppet-lint-report
          include-hidden-files: true
          path: ${{ env.PROJECT_REPORT_DIR }}/puppet-lint-report.xml

  ruby_lint:
    name: Ruby lint
    runs-on: ubuntu-24.04
    steps:
      - name: Checkout repository
        uses: actions/checkout@v7
        with:
          submodules: recursive
          persist-credentials: false
      - name: Set up Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: ruby
          bundler: none
      - name: Install the latest stable Bundler
        run: gem install bundler
      - name: Install the project bundle
        run: bundle install
      - name: Check own Ruby code
        run: |
          mkdir -p "$PROJECT_REPORT_DIR"
          bundle exec rubocop --config .rubocop.yml --format progress --format junit --out "$PROJECT_REPORT_DIR/rubocop-report.xml"
      - name: Check for changes
        run: git diff --exit-code HEAD --
      - name: Upload Ruby lint report
        if: ${{ !cancelled() }}
        uses: actions/upload-artifact@v7
        with:
          name: Ruby-lint-report
          include-hidden-files: true
          path: ${{ env.PROJECT_REPORT_DIR }}/rubocop-report.xml

  # Include this job when the project has its own tool tests and JUnit reporter.
  tool_tests:
    name: Tool tests
    runs-on: ubuntu-24.04
    steps:
      - name: Checkout repository
        uses: actions/checkout@v7
        with:
          submodules: recursive
          persist-credentials: false
      - name: Set up Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: ruby
          bundler: none
      - name: Install the latest stable Bundler
        run: gem install bundler
      - name: Install the project bundle
        run: bundle install
      - name: Run own tool tests
        env:
          MINITEST_REPORTERS_REPORTS_DIR: ${{ env.PROJECT_REPORT_DIR }}
        run: bundle exec rake test
      - name: Check for changes
        run: git diff --exit-code HEAD --
      - name: Upload test results
        if: ${{ !cancelled() }}
        uses: actions/upload-artifact@v7
        with:
          name: Test-results
          include-hidden-files: true
          path: ${{ env.PROJECT_REPORT_DIR }}/TEST-*.xml
      - name: Publish test summary
        if: ${{ !cancelled() }}
        uses: test-summary/action@v2
        with:
          paths: ${{ env.PROJECT_REPORT_DIR }}/TEST-*.xml
```

De publicatiestappen gebruiken `!cancelled()`: ook na een gewone validatie-, lint- of testfout bewaren ze de gemaakte rapporten, terwijl de producerende job zijn foutstatus behoudt. Na een installatie- of opstartfout is er mogelijk nog geen rapport. Een geannuleerde uitvoering hoeft geen artifacts op te leveren. Laat fouten zichtbaar; gebruik geen autofix of foutonderdrukking in CI.

Iedere job controleert na zijn geslaagde opdracht met `git diff --exit-code HEAD --` of installatie of uitvoering gevolgde bestanden verandert. Hiervoor is een schone checkout nodig. Nieuwe, niet-gevolgde bestanden vallen buiten deze controle; herstel bestanden niet om de stap te laten slagen. `git diff --check` blijft de afzonderlijke lokale whitespacecontrole.

Open in GitHub **Actions** en kies de workflowrun. Daar download je `Metadata-report`, `Project-tools-module-dependencies-report`, `Validate-report`, `Puppet-lint-report`, `Ruby-lint-report` en, wanneer de testjob aanwezig is, `Test-results`. Het workflowoverzicht toont daarnaast de JUnit-samenvattingen van de tooltests en dependencycontrole. De configuratie gebruikt alleen `contents: read`; de samenvatting schrijft geen pull-requestcomments en vraagt geen extra repositoryschrijfrechten. Een beheerder kan de nieuwe job bij branchbeveiliging als verplichte statuscheck instellen; de tooling wijzigt die instelling niet.

De Ruby-job gebruikt de [.rubocop.yml van je project](ruby-lint/README.md#ruby-controleren-in-een-ander-project); de gem levert het bijbehorende commando. Houd rapportpaden, de eigen `.gitignore` en artifactinstellingen gelijk aan de [rapportafspraken](#rapporten-en-artifacts-in-je-project). Bewaar credentials voor een interne gembron in de daarvoor bedoelde CI-instellingen; zet ze niet in deze configuratie. De tests van `global-modules` draaien in de [CI van deze repository](#ci-van-deze-repository); de testjob van het afnemende project voert uitsluitend zijn eigen tests uit.

#### Rapporten tonen in GitLab

De [GitLab-testweergave](https://docs.gitlab.com/ci/testing/unit_test_reports/) leest JUnit XML via `artifacts:reports:junit`. Een bestand onder alleen `artifacts:paths` is downloadbaar, maar verschijnt daarmee niet in het testoverzicht. Gebruik in je bestaande GitLab-jobs dezelfde installatie, configuratie en rapportcommando's als hierboven; de Puppet-pipe vereist Bash met `set -eo pipefail`.

Voeg de onderstaande rapportmap en artifactinstellingen toe aan de bijbehorende configuratie in `.gitlab-ci.yml`. Voeg `PROJECT_REPORT_DIR` toe aan de bestaande `variables` en kies daar het eigen pad. Zo gebruiken de scripts en uploads dezelfde [CI/CD-variabele](https://docs.gitlab.com/ci/variables/where_variables_can_be_used/); alleen een `export` binnen het script stelt die variabele niet voor de artifactupload in. Dit voorbeeld bevat zes onafhankelijke jobs in dezelfde stage. Gebruik een runner die deze image met Bash uitvoert; `set -eo pipefail` is een Bash-prerequisite. In bestaande jobs kun je alleen de artifactinstellingen overnemen en de eigen installatie en controlecommando’s behouden. Laat `tool_tests` weg wanneer je project geen eigen testsuite heeft.

```yaml
stages:
  - checks

variables:
  PROJECT_REPORT_DIR: .tools/quality/results
  BUNDLE_IGNORE_CONFIG: '1'
  BUNDLE_VERSION: system
  BUNDLE_FROZEN: 'true'
  BUNDLE_PATH: vendor/bundle
  GIT_SUBMODULE_STRATEGY: recursive

.check_setup:
  stage: checks
  image: ruby:latest
  before_script:
    - set -eo pipefail
    - gem install bundler
    - bundle install

metadata:
  extends: .check_setup
  variables:
    PROJECT_METADATA_MODULES_PATH: modules
    PROJECT_METADATA_PREFIX: example
  script:
    - bundle exec project-tools-metadata --junit "$PROJECT_REPORT_DIR/metadata-report.xml"
    - git diff --exit-code HEAD --
  artifacts:
    name: Metadata-report
    when: always
    paths:
      - "$PROJECT_REPORT_DIR/metadata-report.xml"
    reports:
      junit: "$PROJECT_REPORT_DIR/metadata-report.xml"

puppet_dependencies:
  extends: .check_setup
  script:
    - export PROJECT_TOOLS_MODULEPATH="$CI_PROJECT_DIR/global-modules:$CI_PROJECT_DIR/modules"
    - bundle exec project-tools-module-dependencies --junit "$PROJECT_REPORT_DIR/project-tools-module-dependencies-report.xml"
    - git diff --exit-code HEAD --
  artifacts:
    name: Project-tools-module-dependencies-report
    when: always
    paths:
      - "$PROJECT_REPORT_DIR/project-tools-module-dependencies-report.xml"
    reports:
      junit: "$PROJECT_REPORT_DIR/project-tools-module-dependencies-report.xml"

validate:
  extends: .check_setup
  script:
    - bundle exec validate-junit "$PROJECT_REPORT_DIR/validate-report.xml" environments/production/manifests/site.pp modules/profile/manifests/init.pp
    - git diff --exit-code HEAD --
  artifacts:
    name: Validate-report
    when: always
    paths:
      - "$PROJECT_REPORT_DIR/validate-report.xml"
    reports:
      junit: "$PROJECT_REPORT_DIR/validate-report.xml"

puppet_lint:
  extends: .check_setup
  script:
    - mkdir -p "$PROJECT_REPORT_DIR"
    - test -f .puppet-lint.rc
    - lint_gem="$(bundle info --path lint-project)"
    - export PROJECT_TOOLS_MODULEPATH="$CI_PROJECT_DIR/global-modules:$CI_PROJECT_DIR/modules"
    - bundle exec puppet-lint --no-config --load "$lint_gem/lib/project_lint.rb" --config "$lint_gem/config/puppet-lint.rc" --config .puppet-lint.rc --json environments/production/manifests/site.pp modules/profile/manifests/init.pp | bundle exec puppet-lint-junit "$PROJECT_REPORT_DIR/puppet-lint-report.xml"
    - git diff --exit-code HEAD --
  artifacts:
    name: Puppet-lint-report
    when: always
    paths:
      - "$PROJECT_REPORT_DIR/puppet-lint-report.xml"
    reports:
      junit: "$PROJECT_REPORT_DIR/puppet-lint-report.xml"

ruby_lint:
  extends: .check_setup
  script:
    - mkdir -p "$PROJECT_REPORT_DIR"
    - bundle exec rubocop --config .rubocop.yml --format progress --format junit --out "$PROJECT_REPORT_DIR/rubocop-report.xml"
    - git diff --exit-code HEAD --
  artifacts:
    name: Ruby-lint-report
    when: always
    paths:
      - "$PROJECT_REPORT_DIR/rubocop-report.xml"
    reports:
      junit: "$PROJECT_REPORT_DIR/rubocop-report.xml"

tool_tests:
  extends: .check_setup
  script:
    - MINITEST_REPORTERS_REPORTS_DIR="$PROJECT_REPORT_DIR" bundle exec rake test
    - git diff --exit-code HEAD --
  artifacts:
    name: Test-results
    when: always
    paths:
      - "$PROJECT_REPORT_DIR/TEST-*.xml"
    reports:
      junit: "$PROJECT_REPORT_DIR/TEST-*.xml"
```

`when: always` bewaart beschikbare rapporten ook na een gewone validatie-, lint- of testfout. De CLI-foutcode bepaalt of de job faalt; JUnit-publicatie verandert die status niet. Bekijk de resultaten onder **Tests** in de pipeline en in de testsamenvatting van de merge request. Parservalidatie en lintchecks blijven herkenbaar aan hun eigen suite en artifact. De repository zelf gebruikt de [GitHub Actions-workflow](#ci-van-deze-repository).

## Importeren en distribueren

<a id="de-linter-gebruiken-in-een-ander-puppet-project"></a>

Kies de tools die je project nodig heeft en voeg hun gems met shared toe aan de eigen ontwikkelbundle. Je project bepaalt de te controleren bestanden, modulepaden en rapportlocaties. Een checkout van Puppet-modules is alleen nodig voor controles die hun code of metadata lezen.

Voor een project met `global-modules` richt je eerst de [eigen bundle](#installatie-in-je-project) en de configuratie voor [Puppet-lint](lint/README.md#eigen-lintconfiguratie) en [RuboCop](ruby-lint/README.md#ruby-controleren-in-een-ander-project) in. Voeg daarnaast de [parservalidatie van eigen manifests](validate/README.md#eigen-manifests-valideren) toe. Heeft je project eigen gereedschap met tests, voeg dan de [testtaak en JUnit-rapportage](#eigen-tooltests) toe. De [rapportafspraken](#rapporten-en-artifacts-in-je-project) en het [CI-voorbeeld](#controle-in-ci) laten zien hoe je de resultaten per controle afzonderlijk bewaart en publiceert.

### Gedeelde tooling hergebruiken

Kies de gems voor de benodigde controles volgens [Pakketten en commando’s](#pakketten-en-commandos). De gems leveren checks, profielen en rapportcommando’s; je hoeft daarvoor geen validator, lintregels of XML-omzetter te schrijven. Je eigen configuratie bepaalt welke bestanden en modulepaden relevant zijn en waar de rapporten terechtkomen.

| Controle | Dit gebruik je uit de gem | Dit stelt je eigen project in |
| --- | --- | --- |
| Metadata | `project-tools-metadata` controleert metadata, herstelt bekende velden met `--fix` en schrijft optioneel JUnit met `--junit`. | Eigen VERSION, rootmetadata, modulelocatie, naamprefix, uitsluitingen en eventueel een rapportpad volgens de [metadatagids](metadata/README.md). |
| Puppet-dependencies | `project-tools-module-dependencies` gebruikt native OpenVox; `--junit` schrijft dezelfde uitslag ook als XML. | Expliciete modulepath, rootmetadata en eventueel een rapportpad. |
| Puppet-syntax | `validate-junit` voert de meegeleverde native Puppet-parser uit en schrijft JUnit XML per manifest. | De manifestselectie en het rapportpad. De [optionele Rake-taak](validate/README.md#eigen-manifests-valideren) verzamelt alleen de eigen bestanden en roept dit commando aan. |
| Puppet-lint | De projectchecks, het gedeelde `config/puppet-lint.rc` en `puppet-lint-junit`. | De eigen bestandsuitsluitingen, het Puppet-modulepad en het rapportpad. Gebruik de [native CLI met het gem-entrypoint](lint/README.md#eigen-code-controleren). |
| Ruby-lint | RuboCop en het gedeelde `config/rubocop.yml`. De native JUnit-formatter schrijft het rapport. | De eigen `.rubocop.yml` met `inherit_gem`, bestandsselectie en het rapportpad. |
| Eigen tooltests | De [voorbeelden voor testselectie en rapportage](#eigen-tooltests). | De eigen tests en testdependencies. De reporter van het eigen testframework schrijft JUnit XML. |

Installeer de gekozen gems eenmaal per ontwikkelomgeving of CI-job via de eigen Gemfile en lockfile. Roep vervolgens de gedeelde commando's met `bundle exec` aan. Kopieer geen implementatie, gedeelde profielen of gemtests uit `global-modules` en laad zijn Gemfile of Rakefile niet vanuit je eigen project. Het Rakefile van deze repository selecteert onze bestanden; de gemcommando's werken met jouw selectie.

De [CI-voorbeelden](#controle-in-ci) zijn configuratievoorbeelden voor het afnemende project, geen automatisch geïnstalleerde pipeline. Neem de benodigde jobs over en pas alleen de eigen installatie, bestandsselectie, modulepaden en rapportmap aan. Gedeelde verbeteringen komen via de gekozen gemversie of submodulerevisie binnen; een eigen kopie van de implementatie bijhouden is niet nodig. Controleer een update met de eigen lint-, validatie- en testjobs.

### Benodigdheden

Gebruik de nieuwste stabiele Ruby en Bundler en een eigen Gemfile. Voor het controleren van aanroepen moeten de betreffende Puppet-modules lokaal vindbaar zijn. De linter haalt geen modules, catalogi, Hiera of productie-instellingen op.

### Aanbevolen projectstructuur

Gebruik voor nieuwe projecten die deze moduleverzameling als `global-modules` opnemen de onderstaande indeling als voorbeeld. Die sluit aan op de [installatie van de Puppet-modules](../README.md#installatie). De mapnamen voor eigen gereedschap en rapporten zijn projectkeuzes; `lint-project` vereist geen lokale map met de naam `lint`.

```text
Puppet/
├── VERSION                         # De eigen projectversie.
├── metadata.json                   # Beschrijft het eigen hoofdproject.
├── Gemfile
├── Gemfile.lock
├── .puppet-lint.rc
├── .rubocop.yml
├── AGENTS.md
├── README.md
├── Rakefile                         # Alleen nodig voor eigen taken of tooltests.
├── .tools/                          # Eigen gereedschap en gegenereerde rapporten.
│   ├── quality/results/             # Voorbeeldrapportmap; kies een eigen pad.
│   └── <tool-name>/
│       ├── bin/                     # Uitvoerbare ingangen, indien nodig.
│       ├── lib/                     # Ruby-code van deze tool, indien nodig.
│       ├── tests/
│       │   ├── <behavior>_test.rb
│       │   ├── test_helper.rb       # Alleen voor werkelijk gedeelde testhulp.
│       │   └── fixtures/            # Alleen voor benodigde synthetische invoer.
│       └── README.md
├── global-modules/                  # Deze repository als Git-submodule.
│   ├── VERSION                     # De versie van het gedeelde project.
│   ├── metadata.json
│   └── .tools/
│       ├── README.md
│       ├── shared/project-tools-shared.gemspec
│       ├── module-dependencies/project-tools-module-dependencies.gemspec
│       ├── metadata/project-tools-metadata.gemspec
│       ├── ruby-lint/project-tools-ruby-lint.gemspec
│       ├── validate/project-tools-validate.gemspec
│       └── lint/
│           ├── README.md
│           ├── docs/
│           │   ├── CODE_RULES.md
│           │   ├── DOCUMENTATION_RULES.md
│           │   └── OPERATIONAL_RULES.md
│           └── lint-project.gemspec
├── modules/
│   └── profile/
│       ├── metadata.json
│       └── manifests/init.pp
└── environments/
    └── production/
        ├── environment.conf
        └── manifests/site.pp
```

De namen `profile`, `production` en `quality/results` zijn voorbeelden. Voeg de modules en environments toe die jouw project gebruikt en kies een [rapportmap die bij je indeling past](#rapportmap-kiezen). Maak mappen voor eigen gereedschap en een Rakefile pas aan wanneer je zulke tools of taken nodig hebt. Voor het gebruiken van `lint-project` volstaan de dependency en de configuratiebestanden in de projectroot; de [rapportcommando's](#rapporten-en-artifacts-in-je-project) schrijven naar de gekozen uitvoermap.

| Onderdeel | Afspraak |
| --- | --- |
| `Gemfile` en `Gemfile.lock` | Eén ontwikkelbundle in de projectroot voor lokaal werk en CI. Voeg alleen de toolgems toe die het eigen project gebruikt. |
| `.puppet-lint.rc` en `.rubocop.yml` | Bewaar hier de eigen bestandsselectie en laad de gedeelde profielen volgens [Eigen lintconfiguratie](lint/README.md#eigen-lintconfiguratie) en [Ruby controleren in een ander project](ruby-lint/README.md#ruby-controleren-in-een-ander-project). |
| `global-modules/` | Beheer deze dependency via de Git-submodule en de gekozen revisie. Gebruik de gem uit die checkout; voer de controles vanuit de eigen projectroot uit. |
| Eigen rapportmap, bijvoorbeeld `.tools/quality/results/` | Gegenereerde validatie-, lint- en testrapporten van het eigen project. Kies de locatie zelf, bewaar de map buiten versiebeheer en schrijf niet naar de submodule. |
| `.tools/<tool-name>/` | Eén map per eigen tool, met een concrete naam. Gebruik `bin/` voor uitvoerbare ingangen en `lib/` voor Ruby-librarycode wanneer die nodig zijn; een klein zelfstandig script mag rechtstreeks in de toolmap staan. |
| `.tools/<tool-name>/tests/` | Houd gedragstests, helpers en fixtures bij de tool die ze controleren. De [testindeling en uitvoering](#eigen-tooltests) beschrijven ook bestaande testmappen. |
| `Rakefile` | Houd eigen taken in de projectroot. Ontdek tooltests recursief onder `.tools/*/tests/**/*_test.rb` en voeg alleen bestaande tools toe als `test:<tool-name>`. |

Houd eigen taken voor deze controles beperkt tot de projectspecifieke selectie en het aanroepen van de [gedeelde tooling](#gedeelde-tooling-hergebruiken). Verbeteringen aan de checks, validators en rapportcommando's die voor alle afnemers gelden, horen in de gedeelde gem.

Leg de gekozen eigen toolingindeling en rapportmap vast in de eigen `AGENTS.md` en README. Verwijs voor gedeelde tooling naar deze handleiding onder `global-modules/.tools/README.md` en voor de algemene lintregels en reviewcriteria naar `global-modules/.tools/lint/docs/CODE_RULES.md`. Verwijs voor commentaar, Puppet Strings en interface-documentatie aanvullend naar `global-modules/.tools/lint/docs/DOCUMENTATION_RULES.md` en voor operationele wijzigingen naar `global-modules/.tools/lint/docs/OPERATIONAL_RULES.md`. Beide aanvullende regelsbestanden kunnen tegelijk van toepassing zijn. Zo wordt iedere uitleg op haar eigen plek onderhouden. De `AGENTS.md` in de submodule beschrijft het werk aan die repository; afnemers leggen de afspraken voor hun eigen project expliciet vast.

Een bestaand project met een andere indeling hoeft daarvoor geen Puppet-modules of environments te verplaatsen. Beschrijf de afwijkende paden in de eigen README en houd Gemfile, bestandsselectie, modulepad en CI daarmee in overeenstemming. Voor de manifestanalyse is de indeling een aanbevolen werkwijze. Stel voor de [metadatacontrole](metadata/README.md#modulemetadata-controleren) `PROJECT_METADATA_MODULES_PATH` in op de gekozen map met eigen modules; de naam `modules` is alleen een voorbeeld. Gebruik je een los gempakket, dan vervalt `global-modules/` als installatievereiste en blijven de afspraken voor de eigen tooling hetzelfde.

### Installatie in je project

Gebruik voor een checkout als `global-modules` expliciete bronnen voor alle gekozen gems:

```ruby
source 'https://rubygems.org'

gem 'project-tools-shared', path: 'global-modules/.tools/shared', require: false
gem 'lint-project', path: 'global-modules/.tools/lint', require: false
gem 'project-tools-module-dependencies', path: 'global-modules/.tools/module-dependencies', require: false
gem 'project-tools-validate', path: 'global-modules/.tools/validate', require: false
gem 'project-tools-ruby-lint', path: 'global-modules/.tools/ruby-lint', require: false
gem 'project-tools-metadata', path: 'global-modules/.tools/metadata', require: false
```

Voor alleen parservalidatie kies je shared en `project-tools-validate`; voor alleen dependencycontrole kies je shared en `project-tools-module-dependencies`. Voor alleen metadata kies je shared en `project-tools-metadata`; voor alleen Ruby-lint volstaat `project-tools-ruby-lint`, zonder shared. Laat de overige toolgems weg. De Git-submodule legt de bronrevisie vast en je eigen lockfile legt de volledige oplossing vast. Voer `bundle install` vanuit de consumerroot uit. De gems installeren geen Puppet-modules; haal die afzonderlijk op. Kopieer geen Ruby-implementatie of rapportomzetter en laad niet de root-Gemfile of het Rakefile van `global-modules`.

### Git-dependency uit de monorepo

Alle interne gems komen uit dezelfde gekozen revisie. Vervang `<repository-url>` door de Git-URL van je goedgekeurde repository. `TOOLS_REVISION` hieronder is een shellinstelling van de consumer met een overeengekomen onveranderlijke revisie die de zes gemspecs bevat; de tools lezen deze variabele niet tijdens scans.

```ruby
source 'https://rubygems.org'

git '<repository-url>',
    ref: ENV.fetch('TOOLS_REVISION'),
    glob: '.tools/*/*.gemspec' do
  gem 'project-tools-shared', require: false
  gem 'lint-project', require: false
  gem 'project-tools-module-dependencies', require: false
  gem 'project-tools-validate', require: false
  gem 'project-tools-ruby-lint', require: false
  gem 'project-tools-metadata', require: false
end
```

Voer `bundle install` vanuit de eigen projectroot uit. Bewaar de gekozen revisie en lockfile. Bij een update gebruik je een gecontroleerde revisie en `bundle update lint-project project-tools-shared project-tools-module-dependencies project-tools-validate project-tools-ruby-lint project-tools-metadata`, gevolgd door de eigen kwaliteitscontroles. Zonder de multi-gemglob vindt Bundler niet alle geneste gemspecs. Zet geen credentials in Gemfile of URL. Een Puppet-modulecheckout blijft afzonderlijk nodig voor de moduleset die je beoordeelt.

De installatietest gebruikt een tijdelijke Git-checkout met een Bundler-local-override voor de huidige werkbestanden, zonder commits te maken. Dat controleert de multi-gembron, glob, lokale packagegrenzen en consumercommando’s. Een installatie van de uiteindelijke gepubliceerde revisie zonder local override blijft een controle na de menselijke commit; de test bewijst evenmin bereikbaarheid of toegangsrechten van de externe server.

### Gebouwd gempakket installeren

Bouw ieder pakket vanuit zijn eigen map. Runtimecode gebruikt gewone `require`-paden; er is geen fallback naar siblingbroncode als shared ontbreekt. Iedere gem bevat uitsluitend eigen runtimecode, bedoelde executables, licentie en documentatie. Shared bevat geen tests of testbootstrap. Resultaten, caches, fixtures, rootlockfile en Puppet-modules blijven buiten de pakketten.

De meegeleverde Markdown blijft gelijk aan de documentatie in de checkout en volgt de [afspraken voor documentatielinks](../AGENTS.md#markdown). Links naar meegeleverde bestanden werken ook binnen de geïnstalleerde gem. Open de documentatie in de bijbehorende checkout voor verwijzingen naar andere tools, repository-instructies, tests of Puppet-modules; die bestanden zitten niet in het pakket.

**Werkmap:** Repositoryroot. **Shell:** POSIX shell. **Vereisten:** Gevalideerde bronnen en RubyGems. **Invoer:** Zes gemspecs. **Wijzigt bestanden:** Alleen /tmp-gempakketten. **Verwacht resultaat:** Zes zelfstandig installeerbare pakketten.

```sh
(cd .tools/shared && gem build project-tools-shared.gemspec --output /tmp/project-tools-shared.gem)
(cd .tools/lint && gem build lint-project.gemspec --output /tmp/lint-project.gem)
(cd .tools/module-dependencies && gem build project-tools-module-dependencies.gemspec --output /tmp/project-tools-module-dependencies.gem)
(cd .tools/validate && gem build project-tools-validate.gemspec --output /tmp/project-tools-validate.gem)
(cd .tools/ruby-lint && gem build project-tools-ruby-lint.gemspec --output /tmp/project-tools-ruby-lint.gem)
(cd .tools/metadata && gem build project-tools-metadata.gemspec --output /tmp/project-tools-metadata.gem)
```

Installeer shared vóór de gekozen tools, zodat een ongepubliceerde shared-gem niet van RubyGems hoeft te komen. De externe dependencies komen uit je goedgekeurde gembron. Deze procedure publiceert niets en veronderstelt geen eigendom van de nieuwe gemnamen op RubyGems.

**Werkmap:** Consumerroot. **Shell:** POSIX shell. **Vereisten:** De bovenstaande pakketten, nieuwste stabiele Ruby/Bundler en toegang tot de externe gemdependencies. **Invoer:** Gebouwde gems. **Wijzigt bestanden:** Geminstallatie en eigen lockfile. **Verwacht resultaat:** Dezelfde publieke commando’s buiten de checkout.

```sh
gem install /tmp/project-tools-shared.gem
gem install /tmp/lint-project.gem
gem install /tmp/project-tools-module-dependencies.gem
gem install /tmp/project-tools-validate.gem
gem install /tmp/project-tools-ruby-lint.gem
gem install /tmp/project-tools-metadata.gem
bundle install
```

De eigen Gemfile selecteert de geïnstalleerde pakketten:

```ruby
source 'https://rubygems.org'

gem 'project-tools-shared', '= 0.1.0', require: false
gem 'lint-project', '= 0.2.0', require: false
gem 'project-tools-module-dependencies', '= 0.1.0', require: false
gem 'project-tools-validate', '= 0.1.0', require: false
gem 'project-tools-ruby-lint', '= 0.1.0', require: false
gem 'project-tools-metadata', '= 0.1.0', require: false
```

Installeer uitsluitend shared en de gekozen tools. Voor parservalidatie en dependencycontrole is `lint-project` niet nodig. Richt per gekozen tool het [lintprofiel](lint/README.md#eigen-lintconfiguratie), [Ruby-profiel](ruby-lint/README.md#ruby-controleren-in-een-ander-project) en de [eigen metadataconfiguratie](metadata/README.md) in. Controleer pakketupdates met de eigen volledige lintscan, parservalidatie, dependencycontrole en toepasselijke Ruby- en tooltests. `bundle info --path` toont de werkelijk gebruikte gem; bronbestanden buiten het pakket zijn geen vervanging voor ontbrekende distributie-inhoud. De tijdelijke `.gem`-bestanden mogen na installatie weg; bewaar uitgaven via een goedgekeurde distributieroute.

### Migreren naar de zes pakketten

<a id="migreren-naar-de-vier-packages"></a>

Voeg voor Ruby `project-tools-ruby-lint` toe en wijzig `inherit_gem` in `.rubocop.yml` van `lint-project` naar `project-tools-ruby-lint`. Het commando blijft `bundle exec rubocop`; lint installeert RuboCop niet meer.

Voeg voor metadata `project-tools-metadata` toe. Vervang `PROJECT_LINT_MODULES_PATH` door `PROJECT_METADATA_MODULES_PATH` en `PROJECT_LINT_METADATA_PREFIX` door `PROJECT_METADATA_PREFIX` in de metadata-aanroep en CI-job. Neem benodigde uitsluitingen uit `.puppet-lint.rc` expliciet over als `--ignore-paths` van het metadatacommando. Vervang `puppet-lint --only-checks=project_metadata --fix` door `project-tools-metadata --fix`. Verwijder oude `project_metadata`-selecties of uitschakelopties uit lintconfiguratie; de check is geen lintplugin meer. Voeg ook de metadatajob met `--junit REPORT.xml` zonder `--fix` toe: Puppet-lint controleert en synchroniseert metadata niet meer.

Vervang eerdere aanroepen van `project-tools-metadata-junit [--fix] REPORT.xml` door `project-tools-metadata [--fix] --junit REPORT.xml` en van `project-tools-module-dependencies-junit REPORT.xml` door `project-tools-module-dependencies --junit REPORT.xml`. Laat voor uitsluitend console-uitvoer het hele `--junit REPORT.xml`-argument weg. Een los rapportpad wordt afgewezen. Werk ook eigen scripts en CI-aanroepen bij en voer `bundle install` uit om de nieuwe executables beschikbaar te maken. De pakketnamen en rapportbestandsnamen blijven gelijk; de vervangen executables krijgen geen compatibiliteitsalias.

Verwijder automatische rapportinstellingen uit eigen Rakefiles en testhelpers. Gebruik de [optionele reporterinitialisatie](#junit-rapportage-instellen) en geef in CI `MINITEST_REPORTERS_REPORTS_DIR` expliciet mee met dezelfde map als de testartifactselectie. Zonder die instelling laten `rake test`, gerichte taken en de standaardtaak bestaande rapporten ongemoeid; een lokaal oud rapport hoort dus bij de eerdere uitvoering.

Vervang `PROJECT_LINT_MODULEPATH` door `PROJECT_TOOLS_MODULEPATH` bij lint en dependencycontrole. De padvolgorde en validatie blijven gelijk. Gebruik voor gezamenlijke testresultaten `.tools/results/tests/TEST-*.xml`, voor Ruby `.tools/ruby-lint/results/rubocop-report.xml` en voor metadata `.tools/metadata/results/metadata-report.xml`; werk uploads en ignorepatronen tegelijk bij. Hernoem de workflow naar `checks.yml` en voeg `Metadata` toe aan verplichte statuschecks waar je project die gebruikt. Deze repository gebruikt geen compatibiliteitsaliassen voor de vervangen instellingen.

`lint-project 0.2.0` vereist een extra shared-gembron. Een bestaande path- of Git-consumer met alleen `lint-project` kan de ongepubliceerde shared-gem niet vanzelf vinden. Voeg de [shared-pathbron](#installatie-in-je-project) toe, gebruik de [multi-gem-Gitbron](#git-dependency-uit-de-monorepo), of lever het [shared-pakket](#gebouwd-gempakket-installeren) mee. Selecteer alle interne gems uit dezelfde gecontroleerde checkout of revisie, werk de eigen lockfile bij en voer de bestaande kwaliteitscontroles uit.

Voeg `project-tools-validate` expliciet toe voor parservalidatie; `lint-project` levert of installeert deze executable niet. Vervang `project-tools-puppet-validate` door `project-tools-validate` in de eigen Gemfile en wijzig een pathbron naar `global-modules/.tools/validate`. Vervang aanroepen van `puppet-validate-junit` door `validate-junit` en werk de eigen lockfile bij. De CLI-argumenten en exitstatus blijven gelijk. Bij rechtstreeks Ruby-gebruik laad je `project_tools/validate` en roep je `ProjectTools::Validate` aan.

Gebruik `validate-report.xml` voor het parserrapport en pas artifactpaden en JUnit-registraties samen aan. De suite en testcase-classname heten `validate`; de artifactnaam is `Validate-report`. De CI-job heet `Validate` met sleutel `validate`; pas een verplichte statuscheck met de oude naam `Puppet validate` ook aan. In deze repository staan het rapport onder `.tools/validate/results/` en de tooltests onder `.tools/validate/tests/`; de gerichte testtaak is `test:validate`. De volledige Puppet-selectie blijft beschikbaar via `validate:puppet`.

Voeg `project-tools-module-dependencies` en zijn afzonderlijke CI-job toe wanneer je dependencycontrole gebruikt. Werk bestaande Gemfile-verwijzingen, buildcommando’s en CI-aanroepen voor de dependencytool bij naar de volledige naam `project-tools-module-dependencies` en executable `project-tools-module-dependencies`. Gebruik de rapportnamen uit [Rapporten en artifacts](#rapporten-en-artifacts-in-je-project).

Dit is een brekende wijziging van de gedocumenteerde toolingintegratie. De al gekozen projectversie `3.0.0` blijft behouden: de laatste gepubliceerde release is `v2.0.0`, en de verzamelde wijzigingen vereisen al een majorrelease. Root- en first-party-modulemetadata volgen `VERSION`; externe modules en Ruby-gems behouden hun eigen versies. `lint-project` gaat naar `0.2.0`, de overige gems beginnen bij `0.1.0`. De afzonderlijke validator, metadata- en Ruby-tools, gewijzigde commando’s, optionele rapportage bij testtaken en gedeelde instellingen passen binnen deze al gekozen majorrelease; een verdere versieophoging is niet nodig. Er worden geen tags of releases automatisch gemaakt.

De uniforme leesvolgorde van CI-jobs en controleoverzichten behoudt alle jobnamen, commando’s en statuscontracten. Deze indelingscorrectie is compatibel en past eveneens binnen de al gekozen projectversie `3.0.0`.

Puppet-lint en parservalidatie behouden hun statuscontracten na installatie en aanpassing van de parseraanroep. `puppet-lint-junit` blijft een converter: geldige conversie kan status 0 geven terwijl de XML failures bevat; de lintpipe blijft `pipefail` vereisen. `validate-junit` blijft ieder geselecteerd manifest native valideren. De nieuwe dependencytool gebruikt zijn eigen [exitcodes en rapportlevenscyclus](module-dependencies/README.md#exitcodes-en-rapporten).

## Gezamenlijke tooltests

Tests blijven bij hun eigenaar onder `.tools/<tool>/tests/`: `lint`, `shared`, `validate`, `module-dependencies`, `metadata`, `ruby-lint` en `repository-checks`. Generieke repository-testhulp staat in `.tools/shared/test_support/`, buiten de runtimegem. Lintfixtures, checks en verwachtingen blijven bij lint. De [testscope](../AGENTS.md#test-scope) beperkt deze tests tot gereedschap; een echte dependencycontrole van de checkout is een afzonderlijke taak.

**Werkmap:** Repositoryroot. **Shell:** POSIX shell. **Vereisten:** Ontwikkelbundle. **Invoer:** Synthetische toolcontracten. **Wijzigt bestanden:** Tijdelijke testinvoer; zonder rapportinstelling geen rapportbestanden. **Verwacht resultaat:** Niet-lege selectie zonder failures, errors of onverklaarde skips.

```sh
bundle exec rake test
bundle exec rake test:lint
bundle exec rake test:shared
bundle exec rake test:module_dependencies
bundle exec rake test:validate
bundle exec rake test:metadata
bundle exec rake test:ruby_lint
bundle exec rake test:repository_checks
```

De root-Rake-taak ontdekt `.tools/*/tests/**/*_test.rb` recursief. `bundle exec rake` voert dezelfde selectie uit als `bundle exec rake test`; de gerichte taken kiezen één eigenaar. Zonder `MINITEST_REPORTERS_REPORTS_DIR` geven al deze routes en rechtstreeks uitgevoerde testbestanden uitsluitend console-uitvoer. Bestaande rapportbestanden blijven ongewijzigd en er wordt geen rapportmap aangemaakt. De eenmalige bootstrap registreert autorun en reporters slechts één keer.

Vraag JUnit aan met een niet-leeg rapportpad, relatief aan de werkmap of absoluut. De CI-testjob gebruikt onderstaande instelling; je kunt die ook lokaal bij iedere testtaak meegeven:

**Werkmap:** Repositoryroot. **Shell:** POSIX shell. **Vereisten:** Ontwikkelbundle. **Invoer:** Alle tooltests. **Wijzigt bestanden:** Test-JUnit in de opgegeven map. **Verwacht resultaat:** Dezelfde teststatus met console-uitvoer en JUnit.

```sh
MINITEST_REPORTERS_REPORTS_DIR=.tools/results/tests bundle exec rake test
```

De reporter maakt de opgegeven map aan en vervangt alleen `TEST-*.xml`; andere rapporten blijven staan. Testklassen hebben unieke namen, zodat bestanden niet worden overschreven. Een mislukte test houdt zijn foutstatus, met of zonder rapport. Een fout bij het schrijven van een gevraagd rapport geeft eveneens een foutstatus.

De shared-tests controleren paden, XML, laadbijwerkingen en de gedeelde testbootstrap. Repositorycontroles bewaken documentatienavigatie, CI, package-integratie en testindeling. Metadata- en Ruby-tests bewaken hun eigen CLI, correcties, rapporten en onafhankelijke installatie. De linkcontrole verifieert lokale doelen en ankers en meldt vaste repository-URL’s in Markdown volgens de [documentatieafspraken](../AGENTS.md#markdown). Dependencytests controleren synthetische selectie, rootvoorwaarden, runtime-isolatie, presentatie, package-inhoud en afzonderlijke installatie. Validatortests controleren native parseruitvoering, selectie, foutstatus, bronbehoud en afzonderlijke installatie. Linttests bewaren de bestaande lint-CLI-, autofix- en packagecontracten. Controleer aantallen en gerichte taken: een geslaagde run met nul tests is onvoldoende. [Lintontwikkeling](lint/README.md#tests-uitvoeren-en-uitbreiden) houdt zijn eigen instructies.

### Versies bijwerken

Bij de eerste installatie gebruikt Bundler de versies uit de lockfile. Wil je die combinatie bijwerken, voer dan het volgende uit vanuit de hoofdmap van deze repository, met de nieuwste stabiele Ruby actief:

**Werkmap:** Repositoryroot. **Shell:** POSIX shell. **Vereisten:** Nieuwste stabiele Ruby en bewuste opdracht tot dependencyupdate. **Invoer:** Eigen Gemfile en bestaande lockfile. **Wijzigt bestanden:** Bundlerinstallatie, gems, Gemfile.lock en rapporten. **Verwacht resultaat:** Bijgewerkte combinatie gecontroleerd; diff van lockfile ter review.

```sh
export PROJECT_METADATA_MODULES_PATH=.
gem install bundler
BUNDLE_VERSION=system bundle update --all
bundle exec puppet-lint --no-config --config .puppet-lint.rc .
bundle exec project-tools-metadata --junit .tools/metadata/results/metadata-report.xml
bundle exec rubocop --config .rubocop.yml
bundle exec rake test
git diff -- Gemfile.lock
```

[`bundle update --all`](https://bundler.io/man/bundle-update.1.html) kiest de nieuwste stabiele gems die onderling en met de ingestelde Ruby-versie passen. Gems kunnen zelf beperkingen aan hun afhankelijkheden stellen. Gebruik geen prereleases voor de gewone ontwikkelomgeving.

Controleer de gewijzigde lockfile en eventuele codeaanpassingen in de review. `bundle install` gebruikt daarna steeds die geteste combinatie.

Werk op macOS Ruby bij met `brew update` en `brew upgrade ruby`. Open daarna een nieuwe terminal, zodat ook het pad voor gemcommando's opnieuw wordt bepaald, en volg opnieuw [Gems installeren](#gems-installeren). Draai na een Ruby-update de volledige lintscan en testsuite.

### Eigen tooltests

Test eigen gereedschap onder `.tools/<tool-name>/tests/`, met bestandsnamen die eindigen op `_test.rb`. Zet gedeelde voorbereiding in `test_helper.rb` wanneer meerdere tests die nodig hebben en bewaar grotere synthetische invoer onder `tests/fixtures/`. Fixtures mogen zo nodig per gedrag worden gegroepeerd. Gebruik korte invoer direct in de test en los paden op vanaf het testbestand, zodat de uitvoering niet afhangt van de huidige werkmap.

De tests staan bij de tool die ze controleren; er is geen afzonderlijke centrale `.tools/test/` of `.tools/tests/`. Houd require-paden, fixtures, taken, CI en documentatie in overeenstemming met die indeling en behoud de testdekking. Module- en catalogustests horen bij de eigen validatie van het afnemende project en staan buiten `.tools/`.

Gebruik voor Ruby-tooltests Minitest en Rake uit de eigen ontwikkelbundle. Voeg deze dependencies alleen toe als je zulke tests hebt:

```ruby
gem 'minitest'
gem 'rake'
```

Voer daarna `bundle install` uit. In een project met alleen tooltests kan de root-Rakefile de selectie als volgt vastleggen:

```ruby
# frozen_string_literal: true

require 'rake/testtask'

Rake::TestTask.new(:test) do |task|
  task.pattern = '.tools/*/tests/**/*_test.rb'
  task.warning = false
end

task default: :test
```

Voer vanuit de projectroot `bundle exec rake test` uit, lokaal en in CI. Controleer het aantal uitgevoerde tests; een geslaagde taak met nul tests bewijst niets. Een aanvullende `test:<tool-name>`-taak selecteert alleen `.tools/<tool-name>/tests/**/*_test.rb`. Heeft het project al een verzameltaak voor andere tests, voeg de toolselectie dan als afzonderlijke taak toe en behoud de bestaande dekking en het standaardgedrag.

Laat de selectie alleen de eigen tools doorlopen. De tests onder `global-modules/.tools/*/tests/` horen bij de ontwikkeling van de gedeelde gem en draaien in de CI van die repository. Het afnemende project hoeft die suite niet te kopiëren of via zijn eigen Rakefile te laden. Wie alleen de linters gebruikt, heeft daarvoor geen eigen testmap of testtaak nodig.

#### Testselectie en uitvoeropties

De roottaak hierboven ondersteunt de standaardopties van Rake en Minitest. In deze voorbeelden is `inventory` een eigen tool; vervang de paden en testnamen door die van jouw project.

| Doel | Commando |
| --- | --- |
| Alle eigen tooltests uitvoeren | `bundle exec rake test` |
| Eén testbestand uitvoeren | `bundle exec rake test TEST=.tools/inventory/tests/inventory_test.rb` |
| Testnamen tonen | `bundle exec rake test TESTOPTS='--verbose'` |
| Eén testnaam of patroon selecteren | `bundle exec rake test TESTOPTS='--name=/inventory/'` |
| De testvolgorde reproduceerbaar maken | `bundle exec rake test TESTOPTS='--seed=12345'` |

Geef optiewaarden binnen `TESTOPTS` mee met `=`, zoals `--name=/inventory/`; de testloader van Rake behandelt een losse waarde als bestandsnaam. Gebruik een gerichte selectie tijdens het onderzoeken van een fout. CI voert de volledige bedoelde testtaak uit.

Testmethoden behouden hun gebruikelijke `test_...`-namen; namen, aantallen en skips blijven herkenbaar in de console en de rapporten.

#### JUnit-rapportage instellen

Gebruik standaard console-uitvoer en vraag JUnit expliciet aan wanneer je een rapport nodig hebt. Beide uitvoervormen komen dan uit dezelfde testuitvoering. Voeg voor de Minitest-suite `gem 'minitest-reporters'` toe aan de eigen root-Gemfile naast Minitest en Rake, voer `bundle install` uit en neem de lockfile op in versiebeheer. De reporter is een dependency van je eigen ontwikkelbundle; `lint-project` installeert hem niet voor afnemers.

Configureer de reporters in de eigen `.tools/<tool-name>/tests/test_helper.rb`. Het onderstaande voorbeeld schakelt JUnit uitsluitend in wanneer de aanroeper een rapportmap opgeeft:

```ruby
# frozen_string_literal: true

require 'minitest/autorun'
require 'minitest/reporters'

reporters = [Minitest::Reporters::DefaultReporter.new]
if ENV['MINITEST_REPORTERS_REPORTS_DIR']
  reporters << Minitest::Reporters::JUnitReporter.new(ENV.fetch('MINITEST_REPORTERS_REPORTS_DIR'))
end
Minitest::Reporters.use!(reporters)
```

Laat de testbestanden deze helper laden met `require_relative 'test_helper'` en behoud de voorbereiding en assertions die de eigen tests nodig hebben. Eén uitvoering configureert de reporters eenmaal. Gebruikt de roottaak tests van meerdere eigen tools, laat hun helpers dezelfde reporterinitialisatie laden uit de gedeelde testhulp die dat project daarvoor gebruikt; herinitialiseer de reporters niet per tool.

`bundle exec rake test` toont zonder rapportinstelling alleen de testuitslag. Gebruik vanuit de consumerroot `MINITEST_REPORTERS_REPORTS_DIR="$PROJECT_REPORT_DIR" bundle exec rake test` om daarnaast per testklasse een `TEST-*.xml`-bestand in de [gekozen rapportmap](#rapportmap-kiezen) te schrijven. Geef een niet-leeg relatief of absoluut pad op. De reporter maakt de map zo nodig aan en vervangt alleen die testbestanden, zodat een gerichte testselectie een beperkt rapport oplevert en de lint- en validatierapporten behouden blijven. De rapportmap hoeft niet naast de helper of in een map met de naam `lint` te staan.

`MINITEST_REPORTERS_REPORTS_DIR` geldt uitsluitend voor de tests en verandert de lint- en validatierapportpaden niet. Laat het testartifact en de testsamenvatting naar dezelfde expliciet gekozen map wijzen. `PROJECT_REPORT_DIR` alleen schakelt de testreporter niet in. Mislukte tests behouden hun foutcode; een JUnit-bestand maakt een mislukte uitvoering niet succesvol.

Gebruikt je project een ander testframework, behoud dan de eigen testtaak en gebruik de JUnit-reporter van dat framework. Pas het rapportpad in de [CI-configuratie](#controle-in-ci) daarop aan.
