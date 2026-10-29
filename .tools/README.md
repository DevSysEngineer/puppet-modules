# Gedeelde projecttooling

Gebruik één ontwikkelbundle met afzonderlijke tools voor lokale secretcontrole, Puppet-lint, Ruby-lint, metadata, syntax, cataloguscompilatie en moduledependencies. Iedere controle heeft een eigen uitvoerinterface en resultaat. Kies voor je eigen project alleen de benodigde pakketten; geen van deze controles past catalogi toe.

Voor onderhoud aan tools of hun integratie begin je bij de [gedeelde onderhoudsafspraken](#gedeeld-toolingonderhoud), met de index naar ieder component. Installatie en gebruik staan in deze handleiding.

## Inhoudsopgave

- [Inhoudsopgave](#inhoudsopgave)
- [Pakketten en commando’s](#pakketten-en-commandos)
- [Snelstart in deze repository](#snelstart-in-deze-repository)
- [Installatie en compatibiliteit](#installatie-en-compatibiliteit)
  - [Benodigde omgeving](#benodigde-omgeving)
  - [Installatie](#installatie)
  - [Ruby op macOS](#ruby-op-macos)
  - [Gems installeren](#gems-installeren)
- [Runtimekeuze en compatibiliteit](#runtimekeuze-en-compatibiliteit)
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
  - [Migreren naar afzonderlijke toolpakketten](#migreren-naar-afzonderlijke-toolpakketten)
- [Verantwoordelijkheden gescheiden houden](#verantwoordelijkheden-gescheiden-houden)
  - [CLI en rapportage](#cli-en-rapportage)
  - [Joblogs](#joblogs)
- [Gedeeld toolingonderhoud](#gedeeld-toolingonderhoud)
  - [Componentstructuur](#componentstructuur)
  - [Verantwoordelijkheden en integratie reviewen](#verantwoordelijkheden-en-integratie-reviewen)
  - [Toolteststructuur onderhouden](#toolteststructuur-onderhouden)
  - [CI en rapporten onderhouden](#ci-en-rapporten-onderhouden)
  - [Toolingdocumentatie onderhouden](#toolingdocumentatie-onderhouden)
- [Gezamenlijke tooltests](#gezamenlijke-tooltests)
  - [Versies bijwerken](#versies-bijwerken)
  - [Eigen tooltests](#eigen-tooltests)
    - [Testselectie en uitvoeropties](#testselectie-en-uitvoeropties)
    - [JUnit-rapportage instellen](#junit-rapportage-instellen)

## Pakketten en commando’s

| Pakket | Eigenaar | Publieke commando’s |
| --- | --- | --- |
| [`project-tools-metadata`](metadata/project-tools-metadata.gemspec) | [Metadata](metadata/README.md) | `project-tools-metadata [--fix] [--ignore-paths GLOBS] [--junit REPORT.xml]` |
| [`project-tools-dependencies`](dependencies/project-tools-dependencies.gemspec) | [Dependencycontrole](dependencies/README.md) | `project-tools-dependencies [--junit REPORT.xml]` |
| [`project-tools-syntax`](syntax/project-tools-syntax.gemspec) | [Parservalidatie](syntax/README.md) | Native `puppet parser validate MANIFEST.pp`; met rapport `syntax-junit REPORT.xml MANIFEST.pp [MANIFEST.pp ...]` |
| [`lint-project`](lint/puppet/lint-project.gemspec) | [Lint](lint/puppet/README.md) | `puppet-lint`, `puppet-lint-junit` |
| [`project-tools-ruby-lint`](lint/ruby/project-tools-ruby-lint.gemspec) | [Ruby-lint](lint/ruby/README.md) | Native `rubocop` met eigen JUnit-formatter |
| [`project-tools-secrets`](secrets/project-tools-secrets.gemspec) | [Lokale secretcontrole](secrets/README.md) | `project-tools-secrets [--json] [--junit NEW_FILE] PATH ...`; subcommando's `prepare`, `write`, `run`, `diff`, `close` en overige bewerkingen |
| [`project-tools-shared`](shared/project-tools-shared.gemspec) | [Gedeelde library](shared/README.md) | Geen eigen executable |

Controleer bestanden vóór AI-analyse of externe inzage met de [lokale secretcontrole](secrets/README.md). De handleiding beschrijft de volgorde van scannen, rapport beoordelen en afzonderlijke kopieën maskeren, inclusief de beperkingen bij zoekuitvoer en diffs. Deze voorcontrole draait lokaal vóór openbaarmaking; een CI-scan achteraf vervangt haar niet.

De pakketlinks verwijzen naar de gemspecs die de pakketversies en dependencygrenzen beheren. De [lockfile](../Gemfile.lock) legt de gekozen versies van de ontwikkelbundle vast; afnemende projecten beheren hun eigen lockfile.

De toolgems kiezen geen Puppet-runtime voor de afnemer. Syntax, modulecontrole, lint en cataloguscompilatie gebruiken Puppet of OpenVox uit de actieve bundle; secrets gebruikt die alleen voor Puppet-invoer. De [gedeelde runtimevoorziening](shared/README.md#puppet-runtime-selecteren) verzorgt selectie en executable. Metadata, Ruby-lint en algemene tekstscans werken zonder Puppet-runtime. Ruby-lint gebruikt RuboCop en shared voor uniforme versie-informatie. Shared heeft geen dependency op Puppet, OpenVox of andere tools. Validator en dependencycontrole installeren geen linter. [Repositorycontroles](repository/README.md) blijven uitsluitend voor deze ontwikkelcheckout.

De secrets-gem levert één executable: `project-tools-secrets`. De subcommando's `prepare`, `write`, `run`, `diff` en `close` bedienen de analysewerkwijze. De [taakindeling en migratie](secrets/README.md#taakingangen-en-migratie) beschrijven ook markerregistratie, diagnostiek, afsluiten en herstel. Gebruik voor bewerkingen met beschermde waarden de [voorbereide analysebestanden](secrets/README.md#ontwikkelen-met-een-analysewerkboom), met eigen lokale selectie, Hiera-context en private ID-koppelingen. Scanner, voorbereiding, writer, diagnostiek en gecontroleerde vergelijking delen hetzelfde pakket en werken zonder Git-repository of agentlauncher. De [gezamenlijke Git-afspraken](../CONTRIBUTING.md#git-inspectie) verplichten tot voorcontrole; de [praktische Git-werkwijze](secrets/README.md#git-versies-lokaal-controleren-en-vergelijken) beschrijft hoe je volledige versies lokaal aanbiedt. Ruim eerder ingerichte koppelingen op volgens de [migratie-instructies](secrets/README.md#oude-integraties-opruimen).

De [cataloguscontrole](catalog/README.md) is repositorygebonden en heeft geen eigen gem. Zij ontdekt scenario’s onder `<module>/tests/` en compileert ze met de OpenVox-runtime uit de actieve bundle. De [consumerroute](catalog/README.md#vanuit-een-ander-project-uitvoeren) ondersteunt geïmporteerde checkouts en eigen modulepaden. Gewone waarschuwingen blijven toegestaan; [native deprecations](catalog/README.md#native-deprecations-afkeuren) laten dezelfde cataloguscontrole lokaal en in CI falen. De centrale adapter bepaalt welke runtime voor deze detectie is geverifieerd.

## Snelstart in deze repository

**Werkmap:** Repositoryroot. **Shell:** POSIX shell. **Vereisten:** [Ontwikkelbundle](#installatie) en volledige submodules. **Invoer:** Eigen code en de lokale moduleset. **Wijzigt bestanden:** Caches en tijdelijke testinvoer; rapporten alleen bij een expliciete rapportinstelling. **Verwacht resultaat:** Elke controle heeft zijn eigen status; dependencyconflicten blijven fouten.

```sh
export PROJECT_METADATA_MODULES_PATH=.
export PROJECT_TOOLS_MODULEPATH="$PWD"
bundle exec rake secrets:puppet
bundle exec project-tools-metadata
bundle exec rake syntax:puppet
bundle exec project-tools-dependencies
bundle exec puppet-lint --no-config --config .puppet-lint.rc .
bundle exec rubocop --config .rubocop.yml
bundle exec rake test:tools
bundle exec rake catalog:compile
```

Volg de [verplichte controlevolgorde](../TESTS.md#controlevolgorde-en-verplichte-eindcontroles): de Puppet-secretscontrole moet slagen vóór bronhoudende diagnostiek. Voer de opdrachten afzonderlijk uit en beoordeel iedere exitstatus. De [project-README](../README.md#ondersteuning-en-compatibiliteit) beschrijft de gebruikte dependencies en hun compatibiliteitsgrenzen. Pas ranges of gitlinks alleen aan na inhoudelijk compatibiliteitsonderzoek.

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

De root-Gemfile wijst iedere toolgem expliciet aan via zijn eigen map. Lint, metadata, validator en dependencycontrole gebruiken shared volgens de [dependencygrenzen in hun gemspecs](#pakketten-en-commandos); Ruby-lint gebruikt RuboCop en shared. Ontwikkeldependencies blijven in de rootbundle.

## Runtimekeuze en compatibiliteit

Het afnemende project selecteert in zijn Gemfile **één** runtime, `gem 'openvox', require: false` of `gem 'puppet', require: false`. Declareer nooit beide. Toolgems bevatten geen directe runtime-dependency en sluiten toekomstige majors niet met een pessimistische runtimegrens uit. Bundler en de eigen lockfile leggen de volledige reproduceerbare combinatie vast. Verander de runtime alleen als bewuste dependencyupdate; detectie installeert of wisselt niets.

Voor de huidige ontwikkelcombinatie staan `json < 3` en `syslog ~> 0.4` in de root-Gemfile. De onderzochte runtime gebruikt `JSON::PRETTY_STATE_PROTOTYPE`; syslog is op de gebruikte Ruby geen gebundelde library meer. Die runtimegebonden keuzes horen bij het project, niet in iedere toolgem. De syslog-declaratie is begrensd tot Bundlers `ruby`-platform; behoud bij een ander platform of andere runtime uitsluitend aantoonbaar benodigde dependencies. De toolgems houden hun eigen JSON-, parser-, lint- en shared-interfacegrenzen. Kopieer bij gebruik van de huidige runtime deze ondersteunende dependencies naar de eigen Gemfile en lockfile; toets ze opnieuw bij een runtime-upgrade.

| Combinatie | Bewijs en grens |
| --- | --- |
| OpenVox 8.29.0, Ruby 4.0.9 | Aanwezige ontwikkelruntime; echte integratietests en functionele probes worden hiermee uitgevoerd. |
| Puppet 8, OpenVox 8/9, onbekende toekomstige major | Gesimuleerde gemselectie, versie- en executableverwerking, logging en foutpaden. Geen uitgevoerde integratie met iedere genoemde release. |
| Andere runtime met dezelfde interfaces | Architectuur kan haar selecteren; functionaliteit vereist geslaagde gedragsprobes en eigen integratievalidatie. Geen algemene ondersteuningsclaim. |

Exacte versiegelijkheid is geen algemene toegangspoort voor functionaliteit. Een methode die bestaat, kan nog ander gedrag hebben. Gebruik de [gedeelde detectie en parserprobe](shared/README.md#puppet-runtime-selecteren) en toolgebonden gedragsprobes voor noodzakelijke interne API's. Onbekende of onvolledige controles moeten afkeuren; stil overslaan en vervolgens groen melden is verboden. De [Ruby-lintregel](lint/ruby/README.md#runtimekoppelingen-controleren) bewaakt nieuwe directe runtimekeuze en onverklaarde versiegrenzen in de normale CI-scan.

Bij migratie van een consumer die OpenVox via een toolgem verkreeg: voeg de runtime expliciet toe aan de eigen Gemfile, neem benodigde ondersteunende gems over en laat Bundler de eigen lockfile bijwerken. Leg de gekozen runtime en goedgekeurde toolingrevisie samen vast. Voor deze ontwikkeling worden geen extra Puppet/OpenVox-versies geïnstalleerd en wordt de bestaande rootlockfile niet automatisch gewijzigd. Simulatietests vragen geen nieuwe CI-matrix; ze bewijzen de eigen detectielogica, geen gewijzigde externe API.

## Gedeeld modulepad

`PROJECT_TOOLS_MODULEPATH` is de geordende, met `File::PATH_SEPARATOR` gescheiden lijst van absolute bestaande modulemappen. Lege onderdelen zijn ongeldig. Op macOS en Linux is het scheidingsteken `:`; spaties in paden zijn toegestaan, een `:` in een mapnaam niet. De shared-library valideert paden; iedere tool bepaalt zijn eigen selectie. De linter behoudt zijn terugval naar de werkmap en bronleesgrenzen. De dependencytool verlangt een expliciete niet-lege waarde en volgt native Puppet-selectie, inclusief legitieme module-symlinks. Cataloguscompilatie gebruikt dit pad voor ontdekking en compilatie; zonder instelling kiest zij de eigen checkout, volgens haar [selectiecontract](catalog/README.md#modulepad-en-ontdekking).

`PROJECT_METADATA_MODULES_PATH` selecteert uitsluitend eigen metadata voor `project-tools-metadata`; `PROJECT_METADATA_PREFIX` is diens naamgevingsinstelling. Ze bepalen geen dependencies of modulepadvolgorde. De rootmetadata van metadata- en dependencycontrole staan in de werkmap, nooit automatisch bij de geïnstalleerde gem.

## Rapporten en CI

### Rapportmap kiezen

Kies een eigen map voor gegenereerde rapporten binnen je project, bijvoorbeeld `.tools/quality/results/`, `.tools/checks/results/` of `build/reports/`. De naam `lint` en de locatie onder `.tools/` zijn voor afnemende projecten niet verplicht. Deze repository gebruikt de [rapportlocaties per tool](#ci-van-deze-repository), geen vast uitvoerpad van de gedeelde gems. Gebruik een aparte uitvoermap, houd die buiten versiebeheer en schrijf niet naar `global-modules` of de geïnstalleerde gem.

De voorbeelden hieronder gebruiken `PROJECT_REPORT_DIR` om die projectkeuze door te geven. Stel de variabele in vanuit je eigen projectroot voordat je de rapportcommando's uitvoert:

**Werkmap:** Consumerroot. **Shell:** POSIX shell. **Vereisten:** Eigen rapportkeuze. **Invoer:** Het concrete voorbeeldpad. **Wijzigt bestanden:** Alleen shellomgeving. **Verwacht resultaat:** PROJECT_REPORT_DIR beschikbaar voor de volgende procedures.

```sh
export PROJECT_REPORT_DIR=".tools/quality/results"
```

Dit is een afspraak in de voorbeeldconfiguratie van het afnemende project, geen automatisch ingelezen geminstelling. De shellcommando's geven het pad expliciet mee, ook als taakargument bij de [voorbeeldtaak voor parservalidatie](syntax/README.md#eigen-manifests-valideren). Alleen het instellen van `PROJECT_REPORT_DIR` schakelt geen rapportage in. Voor testrapportage geeft de aanroeper het gekozen pad expliciet door via `MINITEST_REPORTERS_REPORTS_DIR`. Geef een niet-leeg pad op, relatief aan de eigen projectroot. De voorbeelden plaatsen ook de CI-artifacts binnen die checkout.

Gebruik dezelfde waarde lokaal en in CI. In het [GitHub-voorbeeld](#controle-in-ci) stel je die eenmaal onder `env` in; in het [GitLab-fragment](#rapporten-tonen-in-gitlab) onder `variables`. De uitvoercommando's, uploadpaden en testsamenvatting verwijzen naar die instelling. Pas daarnaast de eigen `.gitignore` aan het concrete pad aan: Git vervangt daar geen omgevingsvariabelen. De [rapportafspraken](#rapporten-en-artifacts-in-je-project) tonen per controle het bestand binnen deze map.

### CI van deze repository

De CI van deze library voert acht controles in vijf kwaliteitsfases uit. Een volgende fase start pas wanneer alle toepasselijke controles in de vorige fase geslaagd zijn. Binnen één fase mogen jobs parallel draaien. De fysieke YAML-volgorde en jobnamen bepalen alleen de leesvolgorde: GitHub dwingt de uitvoering af met `needs`; de [GitLab-consumervoorbeelden](#rapporten-tonen-in-gitlab) gebruiken `stages`.

| Fase | Technische job-ID | Zichtbare GitHub-naam | Directe GitHub-`needs` |
| --- | --- | --- | --- |
| 01 | `puppet_secrets` | `Puppet secrets` | Geen |
| 02 | `puppet_metadata` | `Puppet metadata` | `[puppet_secrets]` |
| 02 | `puppet_syntax` | `Puppet syntax` | `[puppet_secrets]` |
| 03 | `puppet_dependencies` | `Puppet dependencies` | `[puppet_metadata, puppet_syntax]` |
| 03 | `puppet_lint` | `Puppet lint` | `[puppet_metadata, puppet_syntax]` |
| 03 | `ruby_lint` | `Ruby lint` | `[puppet_metadata, puppet_syntax]` |
| 04 | `tool_tests` | `Tool tests` | `[puppet_dependencies, puppet_lint, ruby_lint]` |
| 05 | `puppet_catalog` | `Puppet catalogs` | `[tool_tests]` |

De [workflow](../.github/workflows/checks.yml) voert bij `push`, `pull_request` en `merge_group` precies één projectbrede Puppet-secrets-scan uit, in `puppet_secrets`. De bestaande selectie van `rake secrets:puppet` blijft leidend, inclusief haar bewuste uitsluitingen; het modulepad breidt die selectie niet uit. Een afgekeurde, onvolledige of overgeslagen eerste job blokkeert alle volgende fases. Een fout in metadata of syntax blokkeert fases 03–05; een fout in dependencies of een linter blokkeert tooltests en catalogi; mislukte tooltests blokkeren catalogi. Gebruik geen jobvoorwaarden of foutonderdrukking die deze grenzen omzeilen. Zie [GitHub-jobafhankelijkheden](https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-jobs).

Iedere job haalt de repository met alle submodules op en gebruikt [setup-tooling](../.github/actions/setup-tooling/action.yml) voor dezelfde Ruby-, Bundler- en frozen-bundle-installatie. Iedere kwaliteitsjob voert daarna uitsluitend haar eigen controle uit. De zelfstandige `test:tools` draait dezelfde gehele toolsuite en reporter als de lokale verzameltaak `test`, maar zonder projectscan. Lokaal voert `test` eerst `rake secrets:puppet` en daarna eenmaal `test:tools` uit; `bundle exec rake` kiest diezelfde beschermde route. `catalog:compile` heeft geen secrets-prerequisite en de runner scant niet zelf. Voer vóór een losse lokale catalogusaanroep zelf de toepasselijke voorcontrole uit.

Synthetische tests van de scanner blijven onderdeel van de toolsuite. Zij controleren herkenning, maskering en foutafhandeling met fictieve fixtures en zijn geen tweede scan van echte projectbestanden. Gebruik geen skipvariabele, scanstatuscache of vrijgaveartifact: de faseafhankelijkheden verzorgen de vrijgave in CI.

| Job | Controle of commando | Downloadbaar artifact | Inhoud |
| --- | --- | --- | --- |
| `Puppet secrets` | `bundle exec rake secrets:puppet` | Geen | Veilige scanmetadata in het joblog |
| `Puppet metadata` | `bundle exec project-tools-metadata --junit .tools/metadata/results/metadata-report.xml` met `PROJECT_METADATA_MODULES_PATH=.` | `Metadata-report` | `.tools/metadata/results/metadata-report.xml` |
| `Puppet syntax` | `bundle exec rake 'syntax:puppet[.tools/syntax/results/syntax-report.xml]'` | `Syntax-report` | `.tools/syntax/results/syntax-report.xml` |
| `Puppet dependencies` | `bundle exec project-tools-dependencies --junit .tools/dependencies/results/project-tools-dependencies-report.xml` met het expliciete projectmodulepad | `Project-tools-dependencies-report` | `.tools/dependencies/results/project-tools-dependencies-report.xml` |
| `Puppet lint` | Volledige lintscan met JUnit-omzetting volgens de workflow | `Puppet-lint-report` | `.tools/lint/puppet/results/puppet-lint-report.xml` |
| `Ruby lint` | RuboCop met console en JUnit volgens de workflow | `Ruby-lint-report` | `.tools/lint/ruby/results/rubocop-report.xml` |
| `Tool tests` | `MINITEST_REPORTERS_REPORTS_DIR=.tools/results/tests bundle exec rake test:tools` | `Test-results` | `.tools/results/tests/TEST-*.xml` |
| `Puppet catalogs` | `bundle exec rake 'catalog:compile[.tools/catalog/results/catalog-report.xml]'` | `Catalog-report` | `.tools/catalog/results/catalog-report.xml` |

De metadatajob controleert zowel root- als modulemetadata, inclusief naamgeving en versieconsistentie. De syntaxjob gebruikt de [parsertaak](syntax/README.md#puppet-manifests-valideren); de catalogusjob ontdekt de [moduletests](catalog/README.md#tests-bij-een-module-plaatsen). Tooltests bewijzen gereedschapsgedrag en blijven afzonderlijk van compilatie met de echte moduleset. Iedere controle behoudt haar selectie, drempels, exitstatus en JUnit-formaat. Publiceer beschikbare rapporten ook na een gewone controlefout, zonder de oorspronkelijke fout te verbergen.

Open de workflowrun onder **Actions** om de afzonderlijke uitslagen en de artifacts te bekijken. De testjob publiceert zijn JUnit-resultaten in het overzicht. De dependencyjob publiceert hetzelfde dependency-JUnit-bestand als artifact en als summary met `show: fail` en `folded: false`. Een ontbrekend rapport laat de upload expliciet falen; de summary vereist een bestaand bestand. Controleer na menselijke publicatie zowel een failure als een error in de daadwerkelijke GitHub-weergave. XML-tests alleen bewijzen die presentatie niet. De upload- en samenvattingsstappen gebruiken `!cancelled()`, zodat al gemaakte rapporten na een gewone validatie-, lint- of testfout beschikbaar blijven. Wanneer de installatie of het laden van de tests al mislukt, is er mogelijk nog geen bruikbaar rapport. Een geannuleerde run hoeft evenmin rapporten op te leveren.

Puppet-lint schrijft onder `.tools/lint/puppet/results/`, Ruby-lint onder `.tools/lint/ruby/results/` en tooltests onder `.tools/results/tests/`. De metadata-, syntax-, catalogus- en dependencyreporters maken hun eigen bovenliggende rapportmap aan. De uploads gebruiken `include-hidden-files: true`, omdat `.tools` een verborgen map is. Iedere artifactselectie wijst uitsluitend naar het eigen lint- of validatierapport of naar `TEST-*.xml`; de testsamenvatting leest dezelfde testselectie.

De scanner sluit de secrets-controle af met veilige metadata; de overige controles gebruiken de Bash-presentatie; iedere job voert daarna op het geslaagde pad rechtstreeks `git diff --quiet HEAD --` uit. Dit vindt wijzigingen die installatie of controles in gevolgde bestanden hebben achtergelaten ten opzichte van de uitgecheckte commit. Nieuwe, niet-gevolgde bestanden vallen erbuiten. De opdracht vergelijkt geen twee commits en vervangt de [voorwaardelijke lokale whitespacecontrole](../TESTS.md#controlevolgorde-en-verplichte-eindcontroles) niet. Voer deze CI-controle uit vanuit een schone checkout; lokale ontwikkelwijzigingen geven eveneens een verschil.

De workflow gebruikt de nieuwste stabiele Ruby en installeert Bundler zonder versiepin. `BUNDLE_FROZEN=true` bewaakt de lockfile; `BUNDLE_IGNORE_CONFIG=1` voorkomt afhankelijkheid van persoonlijke Bundler-instellingen. Gems worden binnen de checkout geïnstalleerd via `BUNDLE_PATH=vendor/bundle`. De metadatajob stelt `PROJECT_METADATA_MODULES_PATH=.` in; de overige jobs hebben die instelling niet nodig. De jobs gebruiken Bash met `pipefail`, zodat ook de Puppet-lintaanroep met JUnit-omzetting zijn foutstatus behoudt. Beide linters controleren alleen; de workflow maakt geen commits en publiceert geen gem.

De artifacts en het testoverzicht vereisen geen extra schrijfrechten op de repository; `contents: read` blijft voldoende. De samenvatting schrijft geen pull-requestcomments of afzonderlijke check runs. Gebruikt de repository verplichte statuschecks, selecteer dan alle toepasselijke zichtbare jobnamen uit de fasetabel, niet alleen `Puppet catalogs`. Een overgeslagen afhankelijke job kan anders als acceptabele status gelden; zie [vereiste statuschecks](https://docs.github.com/en/pull-requests/how-tos/merge-and-close-pull-requests/troubleshooting-required-status-checks). Controleer branch protection, rulesets en externe verwijzingen op de werkelijk gepubliceerde checknamen. Controleer na publicatie een volledige geslaagde run en een geïsoleerde synthetische fout, inclusief de geblokkeerde vervolgfases en artifacts. Voor afnemende projecten staat hieronder een [voorbeeld met dezelfde CLI](#controle-in-ci).

### Rapporten en artifacts in je project

Gebruik JUnit XML voor alle gepubliceerde validatie-, lint- en testrapporten en schrijf ze naar de [eigen rapportmap](#rapportmap-kiezen). De voorbeelden gebruiken daarvoor `PROJECT_REPORT_DIR`; de projectroot blijft vrij van losse rapportbestanden. De uitvoermap bevat alleen gegenereerde resultaten; de lintercode en gedeelde profielen komen uit de gem in `global-modules` of je andere gembron.

Bewaar bij voorkeur de resultaten van iedere controle in een afzonderlijk artifact van de job die de controle uitvoert. Daardoor vind je een lintbevinding of testfout direct bij de bijbehorende uitslag. De JUnit-bestanden van één testuitvoering vormen samen één testartifact.

| Job | Bestand binnen de gekozen rapportmap | Artifactnaam | Voorwaarde |
| --- | --- | --- | --- |
| `Puppet metadata` | `metadata-report.xml` | `Metadata-report` | Eigen VERSION, rootmetadata en expliciete modulelocatie. |
| `Puppet syntax` | `syntax-report.xml` | `Syntax-report` | De eigen Puppet-manifests zijn geselecteerd. |
| `Puppet dependencies` | `project-tools-dependencies-report.xml` | `Project-tools-dependencies-report` | Eigen rootmetadata en expliciete modulepath met alle dependencies. |
| `Puppet lint` | `puppet-lint-report.xml` | `Puppet-lint-report` | De eigen Puppet-manifests en lintconfiguratie zijn aanwezig. |
| `Ruby lint` | `rubocop-report.xml` | `Ruby-lint-report` | De eigen Ruby-code en RuboCop-configuratie zijn aanwezig. |
| `Tool tests` | `TEST-*.xml` | `Test-results` | Het project heeft een eigen testsuite en [JUnit-rapportage](#junit-rapportage-instellen). |
| `Puppet catalogs` | `catalog-report.xml` | `Catalog-report` | Module-eigen scenario’s en het expliciete modulepad. |

De voorbeelden gebruiken de pakketten volgens [Installatie in je project](#installatie-in-je-project). Bewaar de gekozen submodulerevisie en eigen lockfile en volg bij updates de [consumermigratie](#migreren-naar-afzonderlijke-toolpakketten). De commando's zijn onderdeel van de gem; je kopieert geen converter of validator naar je eigen project.

Stel eerst `PROJECT_REPORT_DIR` in volgens [Rapportmap kiezen](#rapportmap-kiezen).

Voor metadata gebruik je de [eigen modulelocatie en naamprefix](metadata/README.md#gebruik-in-een-ander-project). De opdracht schrijft ook bij metadatafouten een eigen rapport:

**Werkmap:** Consumerroot. **Shell:** POSIX shell. **Vereisten:** Eigen bundle, VERSION, rootmetadata, modules-map en ingestelde PROJECT_REPORT_DIR. **Invoer:** Eigen metadata. **Wijzigt bestanden:** Metadata-JUnit. **Verwacht resultaat:** Exitcode 0 bij geldige metadata, anders een foutstatus.

```sh
export PROJECT_METADATA_MODULES_PATH=modules
export PROJECT_METADATA_PREFIX=example
bundle exec project-tools-metadata --junit "$PROJECT_REPORT_DIR/metadata-report.xml"
```

De [dependencycontrole](dependencies/README.md#een-controle-uitvoeren) schrijft haar rapport bij de expliciete `--junit`-aanroep. Het validatierapport ontstaat tijdens de [parseraanroep](syntax/README.md#eigen-manifests-valideren).

Maak het Puppet-lintrapport vanuit de projectroot met dezelfde configuratie en bronselectie als de [gewone controle](lint/puppet/README.md#eigen-code-controleren):

**Werkmap:** Consumerroot. **Shell:** Bash met errexit en pipefail. **Vereisten:** Eigen bundle, [configuratie](lint/puppet/README.md#eigen-lintconfiguratie), [rapportmap](#rapportmap-kiezen) en genoemde manifests/modules. **Invoer:** De twee genoemde eigen manifests. **Wijzigt bestanden:** Puppet-lint-JUnit. **Verwacht resultaat:** Lint- en conversiefouten blijven jobfouten.

```bash
set -eo pipefail
mkdir -p "$PROJECT_REPORT_DIR"
lint_gem="$(bundle info --path lint-project)"
export PROJECT_TOOLS_MODULEPATH="$PWD/global-modules:$PWD/modules"
test -f .puppet-lint.rc
bundle exec puppet-lint --no-config --load "$lint_gem/lib/project_lint.rb" --config "$lint_gem/config/puppet-lint.rc" --config .puppet-lint.rc --json environments/production/manifests/site.pp modules/profile/manifests/init.pp | bundle exec puppet-lint-junit "$PROJECT_REPORT_DIR/puppet-lint-report.xml"
```

Pas modulemappen en manifestpaden aan je project aan. Bash `pipefail` behoudt de foutstatus van Puppet-lint tijdens de omzetting en laat de opdracht ook bij een conversiefout falen. De configuratie, bestandsselectie en controle op waarschuwingen blijven gelijk aan de gewone scan. De [uitleg over de rapportinhoud](lint/puppet/README.md#lintrapporten-maken) beschrijft hoe lintmeldingen in JUnit worden weergegeven.

Voor Ruby gebruik je afzonderlijk de volgende aanroep. De [eigen `.rubocop.yml`](lint/ruby/README.md#ruby-controleren-in-een-ander-project) bepaalt welke bestanden worden gecontroleerd:

**Werkmap:** Consumerroot. **Shell:** POSIX shell. **Vereisten:** Eigen bundle, .rubocop.yml en [rapportmap](#rapportmap-kiezen). **Invoer:** Eigen Ruby-selectie. **Wijzigt bestanden:** RuboCop-JUnit en cache. **Verwacht resultaat:** Console en XML met dezelfde foutstatus.

```sh
mkdir -p "$PROJECT_REPORT_DIR"
bundle exec rubocop --config .rubocop.yml --stderr --format progress --format junit --out "$PROJECT_REPORT_DIR/rubocop-report.xml"
```

De testtaak uit [JUnit-rapportage instellen](#junit-rapportage-instellen) maakt zijn eigen rapporten bij `MINITEST_REPORTERS_REPORTS_DIR="$PROJECT_REPORT_DIR" bundle exec rake test:tools`. Iedere controle draait eenmaal. Alle artifacts bevatten JUnit XML; houd parservalidatie, lintresultaten en tooltests als afzonderlijke suites en artifacts herkenbaar.

Neem de hele gekozen uitvoermap met zijn concrete pad op in de eigen `.gitignore`. Voor de voorbeeldwaarde `.tools/quality/results` is dat:

```gitignore
/.tools/quality/results/
```

Het [GitHub Actions-voorbeeld](#controle-in-ci) bewaart elk rapport als downloadbaar artifact en toont tooltests en dependencybevindingen ook in het workflowoverzicht. Voor het testoverzicht van GitLab voeg je de [JUnit-registratie](#rapporten-tonen-in-gitlab) toe aan iedere producerende job. Downloaden en weergeven gebruiken dezelfde rapportbestanden.

Gebruik voor het testartifact en de testsamenvatting uitsluitend `TEST-*.xml` binnen de gekozen testmap. Een selectie van de hele map of `*.xml` neemt ook de lint- en validatierapporten mee. Verander je een rapportbestandsnaam, pas dan de bijbehorende upload en JUnit-registratie samen aan. GitHub Actions vereist [`include-hidden-files: true`](https://github.com/actions/upload-artifact#uploading-hidden-files) wanneer de gekozen map onder een verborgen pad zoals `.tools` staat; de onderstaande voorbeelden beperken de upload tot de bedoelde rapportbestanden.

### Controle in CI

Volg lokaal de [verplichte voorcontrole](../CONTRIBUTING.md#lokale-inspectie-vóór-inzage) en de [Git-werkwijze](secrets/README.md#git-versies-lokaal-controleren-en-vergelijken); een CI-run begint pas na verzending. Publiceer geen analysewerkbomen, mappings, staging of ruwe herstelgegevens als artifact. De zelfstandige Puppet-secretsgate en de bestaande CI-inrichting blijven hiervan afzonderlijk functioneren.

Gebruik de eigen `VERSION` en rootmetadata en leg de modulelocatie en naamprefix vast volgens [Modulemetadata controleren](metadata/README.md#modulemetadata-controleren). De onderstaande GitHub- en GitLab-voorbeelden gebruiken `example` als synthetische eigenaar; vervang die door de vastgelegde eigenaar van je project.

De library ontwikkelen en de library gebruiken zijn verschillende taken. Een update van `global-modules` wijzigt nooit de CI of eigen Rake-taken van een consumer. Gebruik de publieke CLI’s en Rake-integraties uit de gekozen revisie; kopieer geen scanner, catalogusrunner, lintimplementatie, reporter of interne runner-unit-tests.

De twee volledige basisvoorbeelden hieronder horen bij eigen Puppet-modules met catalogusscenario’s, zonder eigen Ruby-code of toolsuite. Ze bevatten precies zes jobs: secrets, metadata, syntax, dependencies, Puppet-lint en catalogi. Fase 04 heeft geen job; catalogi wachten direct op beide fase-03-jobs. Een consumer zonder catalogusscenario’s laat ook de catalogusjob weg. Maak geen lege succesjobs en verwijs nooit naar een afwezige job.

Richt eerst de [eigen bundle](#installatie-in-je-project) en [Puppet-lintconfiguratie](lint/puppet/README.md#eigen-lintconfiguratie) in. Voor dit profiel selecteer je shared, secrets, metadata, dependencies, syntax en lint; Ruby-lint en Minitest zijn niet nodig. Selecteer daarnaast één runtime en haar vereiste ondersteunende gems volgens [runtimekeuze](#runtimekeuze-en-compatibiliteit). Haal `global-modules` recursief op, voer lokaal `bundle install` uit en leg de eigen Gemfile, lockfile en gekozen submodulerevisie vast. Iedere CI-job gebruikt diezelfde bundle met `BUNDLE_FROZEN=true`.

Secrets, syntax en lint richten zich op de bestaande expliciete selectie eigen code en toepasselijke voorbeelden. Pas de voorbeeldpaden aan die selectie aan; deze inrichting vraagt geen uitbreiding naar imports. `--puppet` controleert uitsluitend Puppet-manifests en vervangt de algemene inspectie van YAML, templates of andere bronnen niet. `PROJECT_METADATA_MODULES_PATH=modules` en `PROJECT_METADATA_PREFIX=example` horen bij de eigen root- en modulemetadata en het eigen `VERSION`-bestand. Neem upstream-eigenaar, modulelocatie of versie niet blind over.

`PROJECT_TOOLS_MODULEPATH` bepaalt de beschikbare modules voor dependencies en cataloguscompilatie, inclusief imports en de [modulepadvoorrang](catalog/README.md#modulepad-en-ontdekking). Dit pad bepaalt niet automatisch de secrets-bestandsselectie. De voorbeelden behouden hun bestaande volgorde `global-modules:modules`; zet eigen modules eerst wanneer die bewust voorrang moeten krijgen. Houd de volgorde consistent voor alle betrokken controles. Bewust niet gescande imports blijven buiten het bewijs van de Puppet-secretsjob; beoordeel hun herkomst en mogelijke diagnostiek afzonderlijk.

Bewaar het GitHub-voorbeeld als `.github/workflows/checks.yml` en kies `env.PROJECT_REPORT_DIR`. Checkout, submodules, Ruby, Bundler, controlecommando’s en rapportuploads zijn inbegrepen. De normale `needs`-relaties verzorgen alle fasegrenzen. Laat een eigen `catalog:compile` uitsluitend de gedeelde runner aanroepen, zonder `catalog:secrets` of `rake secrets:puppet` als directe of indirecte prerequisite. Voor een lokale losse catalogusaanroep voer je zelf vooraf de toepasselijke controle uit.

```yaml
name: Puppet checks

on:
  pull_request:
  push:
  merge_group:

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
  puppet_secrets:
    name: "Puppet secrets"
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
        run: |
          source global-modules/.github/actions/setup-tooling/log.sh
          ci_begin 'Install Bundler' details
          if gem install bundler; then
              ci_end 0 PASSED complete
          else
              ci_end "$?" ERROR incomplete
          fi
      - name: Install the project bundle
        run: |
          source global-modules/.github/actions/setup-tooling/log.sh
          ci_begin 'Install locked bundle' details
          if bundle install; then
              ci_end 0 PASSED complete
          else
              ci_end "$?" ERROR incomplete
          fi
      - name: Reject hardcoded Puppet secrets
        run: bundle exec project-tools-secrets --puppet environments/ modules/
      - name: Check for changes without source output
        run: git diff --quiet HEAD --

  puppet_metadata:
    name: "Puppet metadata"
    needs: [puppet_secrets]
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
        run: |
          source global-modules/.github/actions/setup-tooling/log.sh
          ci_begin 'Install Bundler' details
          if gem install bundler; then
              ci_end 0 PASSED complete
          else
              ci_end "$?" ERROR incomplete
          fi
      - name: Install the project bundle
        run: |
          source global-modules/.github/actions/setup-tooling/log.sh
          ci_begin 'Install locked bundle' details
          if bundle install; then
              ci_end 0 PASSED complete
          else
              ci_end "$?" ERROR incomplete
          fi
      - name: Check project and module metadata
        run: bundle exec project-tools-metadata --junit "$PROJECT_REPORT_DIR/metadata-report.xml"
      - name: Check for changes
        run: |
          source global-modules/.github/actions/setup-tooling/log.sh
          ci_begin 'Checkout changes'
          if git diff --quiet HEAD --; then
              ci_end 0 PASSED complete
          else
              CHECKOUT_STATUS=$?
              if [ "$CHECKOUT_STATUS" -eq 1 ]; then
                  ci_end "$CHECKOUT_STATUS" FAILED complete 'Tracked files differ from the checked-out commit.'
              else
                  ci_end "$CHECKOUT_STATUS" ERROR incomplete 'Git could not check the working tree; inspect the native diagnostic above.'
              fi
          fi
      - name: Upload metadata report
        if: ${{ !cancelled() }}
        uses: actions/upload-artifact@v7
        with:
          name: Metadata-report
          include-hidden-files: true
          path: ${{ env.PROJECT_REPORT_DIR }}/metadata-report.xml

  puppet_syntax:
    name: "Puppet syntax"
    needs: [puppet_secrets]
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
        run: |
          source global-modules/.github/actions/setup-tooling/log.sh
          ci_begin 'Install Bundler' details
          if gem install bundler; then
              ci_end 0 PASSED complete
          else
              ci_end "$?" ERROR incomplete
          fi
      - name: Install the project bundle
        run: |
          source global-modules/.github/actions/setup-tooling/log.sh
          ci_begin 'Install locked bundle' details
          if bundle install; then
              ci_end 0 PASSED complete
          else
              ci_end "$?" ERROR incomplete
          fi
      - name: Check own Puppet syntax
        run: bundle exec syntax-junit "$PROJECT_REPORT_DIR/syntax-report.xml" environments/production/manifests/site.pp modules/profile/manifests/init.pp
      - name: Check for changes
        run: |
          source global-modules/.github/actions/setup-tooling/log.sh
          ci_begin 'Checkout changes'
          if git diff --quiet HEAD --; then
              ci_end 0 PASSED complete
          else
              CHECKOUT_STATUS=$?
              if [ "$CHECKOUT_STATUS" -eq 1 ]; then
                  ci_end "$CHECKOUT_STATUS" FAILED complete 'Tracked files differ from the checked-out commit.'
              else
                  ci_end "$CHECKOUT_STATUS" ERROR incomplete 'Git could not check the working tree; inspect the native diagnostic above.'
              fi
          fi
      - name: Upload Puppet syntax report
        if: ${{ !cancelled() }}
        uses: actions/upload-artifact@v7
        with:
          name: Syntax-report
          include-hidden-files: true
          path: ${{ env.PROJECT_REPORT_DIR }}/syntax-report.xml

  puppet_dependencies:
    name: "Puppet dependencies"
    needs: [puppet_metadata, puppet_syntax]
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
        run: |
          source global-modules/.github/actions/setup-tooling/log.sh
          ci_begin 'Install Bundler' details
          if gem install bundler; then
              ci_end 0 PASSED complete
          else
              ci_end "$?" ERROR incomplete
          fi
      - name: Install the project bundle
        run: |
          source global-modules/.github/actions/setup-tooling/log.sh
          ci_begin 'Install locked bundle' details
          if bundle install; then
              ci_end 0 PASSED complete
          else
              ci_end "$?" ERROR incomplete
          fi
      - name: Check Puppet module dependencies
        run: |
          export PROJECT_TOOLS_MODULEPATH="$GITHUB_WORKSPACE/global-modules:$GITHUB_WORKSPACE/modules"
          bundle exec project-tools-dependencies --junit "$PROJECT_REPORT_DIR/project-tools-dependencies-report.xml"
      - name: Check for changes
        run: |
          source global-modules/.github/actions/setup-tooling/log.sh
          ci_begin 'Checkout changes'
          if git diff --quiet HEAD --; then
              ci_end 0 PASSED complete
          else
              CHECKOUT_STATUS=$?
              if [ "$CHECKOUT_STATUS" -eq 1 ]; then
                  ci_end "$CHECKOUT_STATUS" FAILED complete 'Tracked files differ from the checked-out commit.'
              else
                  ci_end "$CHECKOUT_STATUS" ERROR incomplete 'Git could not check the working tree; inspect the native diagnostic above.'
              fi
          fi
      - name: Upload Puppet dependency report
        if: ${{ !cancelled() }}
        uses: actions/upload-artifact@v7
        with:
          name: Project-tools-dependencies-report
          include-hidden-files: true
          if-no-files-found: error
          path: ${{ env.PROJECT_REPORT_DIR }}/project-tools-dependencies-report.xml
      - name: Publish dependency summary
        if: ${{ !cancelled() && hashFiles(format('{0}/project-tools-dependencies-report.xml', env.PROJECT_REPORT_DIR)) != '' }}
        uses: test-summary/action@v2
        with:
          paths: ${{ env.PROJECT_REPORT_DIR }}/project-tools-dependencies-report.xml
          show: fail
          folded: false

  puppet_lint:
    name: "Puppet lint"
    needs: [puppet_metadata, puppet_syntax]
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
        run: |
          source global-modules/.github/actions/setup-tooling/log.sh
          ci_begin 'Install Bundler' details
          if gem install bundler; then
              ci_end 0 PASSED complete
          else
              ci_end "$?" ERROR incomplete
          fi
      - name: Install the project bundle
        run: |
          source global-modules/.github/actions/setup-tooling/log.sh
          ci_begin 'Install locked bundle' details
          if bundle install; then
              ci_end 0 PASSED complete
          else
              ci_end "$?" ERROR incomplete
          fi
      - name: Check own Puppet manifests
        run: |
          source global-modules/.github/actions/setup-tooling/log.sh
          ci_begin 'Puppet lint'
          mkdir -p "$PROJECT_REPORT_DIR"
          test -f .puppet-lint.rc
          lint_gem="$(bundle info --path lint-project)"
          export PROJECT_TOOLS_MODULEPATH="$GITHUB_WORKSPACE/global-modules:$GITHUB_WORKSPACE/modules"
          set +e
          bundle exec puppet-lint --no-config --load "$lint_gem/lib/project_lint.rb" --config "$lint_gem/config/puppet-lint.rc" --config .puppet-lint.rc --json environments/production/manifests/site.pp modules/profile/manifests/init.pp | bundle exec puppet-lint-junit --result-status "$PROJECT_REPORT_DIR/puppet-lint-report.xml"
          LINT_STATUS=("${PIPESTATUS[@]}")
          LINT_RESULT_STATUS=${LINT_STATUS[1]}
          if [ "$LINT_RESULT_STATUS" -eq 10 ]; then LINT_STATUS[1]=0; fi
          set -e
          printf 'Native scan exit status: %s | Converter exit status: %s\n' "${LINT_STATUS[0]}" "${LINT_STATUS[1]}"
          if [ "${LINT_STATUS[1]}" -ne 0 ]; then
              ci_end "${LINT_STATUS[1]}" ERROR incomplete 'The lint report could not be completed; inspect the converter diagnostic above.'
          elif [ "${LINT_STATUS[0]}" -ne 0 ]; then
              if [ "${LINT_STATUS[0]}" -eq 1 ] && [ "$LINT_RESULT_STATUS" -eq 10 ]; then
                  ci_end 1 FAILED complete 'Lint findings exceed the configured threshold; --fail-on-warnings also rejects warnings.'
              else
                  ci_end "${LINT_STATUS[0]}" ERROR incomplete 'Puppet-lint did not return a confirmed lint outcome; inspect the native diagnostic above.'
              fi
          else
              ci_end 0 PASSED complete
          fi
      - name: Check for changes
        run: |
          source global-modules/.github/actions/setup-tooling/log.sh
          ci_begin 'Checkout changes'
          if git diff --quiet HEAD --; then
              ci_end 0 PASSED complete
          else
              CHECKOUT_STATUS=$?
              if [ "$CHECKOUT_STATUS" -eq 1 ]; then
                  ci_end "$CHECKOUT_STATUS" FAILED complete 'Tracked files differ from the checked-out commit.'
              else
                  ci_end "$CHECKOUT_STATUS" ERROR incomplete 'Git could not check the working tree; inspect the native diagnostic above.'
              fi
          fi
      - name: Upload Puppet lint report
        if: ${{ !cancelled() }}
        uses: actions/upload-artifact@v7
        with:
          name: Puppet-lint-report
          include-hidden-files: true
          path: ${{ env.PROJECT_REPORT_DIR }}/puppet-lint-report.xml

  puppet_catalog:
    name: "Puppet catalogs"
    needs: [puppet_dependencies, puppet_lint]
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
        run: |
          source global-modules/.github/actions/setup-tooling/log.sh
          ci_begin 'Install Bundler' details
          if gem install bundler; then
              ci_end 0 PASSED complete
          else
              ci_end "$?" ERROR incomplete
          fi
      - name: Install the project bundle
        run: |
          source global-modules/.github/actions/setup-tooling/log.sh
          ci_begin 'Install locked bundle' details
          if bundle install; then
              ci_end 0 PASSED complete
          else
              ci_end "$?" ERROR incomplete
          fi
      - name: Check own Puppet catalogs
        run: |
          export PROJECT_TOOLS_MODULEPATH="$GITHUB_WORKSPACE/global-modules:$GITHUB_WORKSPACE/modules"
          bundle exec global-modules/.tools/catalog/bin/project-tools-catalog --junit "$PROJECT_REPORT_DIR/catalog-report.xml"
      - name: Check for changes
        run: |
          source global-modules/.github/actions/setup-tooling/log.sh
          ci_begin 'Checkout changes'
          if git diff --quiet HEAD --; then
              ci_end 0 PASSED complete
          else
              CHECKOUT_STATUS=$?
              if [ "$CHECKOUT_STATUS" -eq 1 ]; then
                  ci_end "$CHECKOUT_STATUS" FAILED complete 'Tracked files differ from the checked-out commit.'
              else
                  ci_end "$CHECKOUT_STATUS" ERROR incomplete 'Git could not check the working tree; inspect the native diagnostic above.'
              fi
          fi
      - name: Upload Puppet catalogs report
        if: ${{ !cancelled() }}
        uses: actions/upload-artifact@v7
        with:
          name: Catalog-report
          include-hidden-files: true
          path: ${{ env.PROJECT_REPORT_DIR }}/catalog-report.xml
```

De publicatiestappen gebruiken `!cancelled()`: ook na een gewone validatie-, lint- of testfout bewaren ze de gemaakte rapporten, terwijl de producerende job zijn foutstatus behoudt. Na een installatie- of opstartfout is er mogelijk nog geen rapport. Een geannuleerde uitvoering hoeft geen artifacts op te leveren. Laat fouten zichtbaar; gebruik geen autofix of foutonderdrukking in CI.

Iedere job controleert na zijn geslaagde opdracht met `git diff --quiet HEAD --` of installatie of uitvoering gevolgde bestanden verandert. Hiervoor is een schone checkout nodig. Nieuwe, niet-gevolgde bestanden vallen buiten deze controle; herstel bestanden niet om de stap te laten slagen. Voor de lokale whitespacecontrole met `git diff --check` gelden de [voorcontrole en beperkingen](../CONTRIBUTING.md#git-inspectie).

Open in GitHub **Actions** en kies de workflowrun. Daar download je `Metadata-report`, `Syntax-report`, `Project-tools-dependencies-report`, `Puppet-lint-report` en `Catalog-report`. Het workflowoverzicht toont daarnaast de JUnit-samenvatting van de dependencycontrole. De configuratie gebruikt alleen `contents: read`; de samenvatting schrijft geen pull-requestcomments en vraagt geen extra repositoryschrijfrechten. Een beheerder kan de nieuwe job bij branchbeveiliging als verplichte statuscheck instellen; de tooling wijzigt die instelling niet.

Als eigen Ruby-code van toepassing wordt, voeg je `ruby_lint` met naam `"Ruby lint"` toe aan fase 03, met `needs: [puppet_metadata, puppet_syntax]`. Gebruik de [Ruby-rapportaanroep](#rapporten-en-artifacts-in-je-project), de eigen `.rubocop.yml`, artifact `Ruby-lint-report` en `rubocop-report.xml`. Zonder toolsuite voeg je `ruby_lint` tevens toe aan de `needs` van catalogi.

Bij een echte eigen toolsuite voeg je `tool_tests` met naam `"Tool tests"` toe aan fase 04. Laat die wachten op alle aanwezige fase-03-jobs en laat catalogi daarna op `tool_tests` wachten. De opdracht is `MINITEST_REPORTERS_REPORTS_DIR="$PROJECT_REPORT_DIR" bundle exec rake test:tools`, met de [eigen testtaak en reporter](#eigen-tooltests), artifact `Test-results`, uploadselectie `TEST-*.xml` en een `test-summary/action@v2`-stap met dezelfde `paths`. Behoud `if: ${{ !cancelled() }}` bij uploads en samenvattingen. Gebruik een bestaande lokale `test`-verzameltaak met secretsvoorcontrole uitsluitend lokaal. De tooltests van `global-modules` horen bij de ontwikkeling van de library en worden niet de consumer-suite.

Houd rapportpaden, de eigen `.gitignore` en artifactinstellingen gelijk aan de [rapportafspraken](#rapporten-en-artifacts-in-je-project). Bewaar credentials voor een interne gembron in de daarvoor bedoelde CI-instellingen.

#### Rapporten tonen in GitLab

Vereis voor de doelbranch een geslaagde pipeline en behoud de eerste secrets-stage uit dit voorbeeld. De [lokale inspectie vóór openbaarmaking](../CONTRIBUTING.md#lokale-inspectie-vóór-inzage) voorkomt dat ongecontroleerde inhoud wordt gedeeld; de pipeline vervangt die voorcontrole niet. Bewaar private herstelstate nooit als CI-artifact.

De [GitLab-testweergave](https://docs.gitlab.com/ci/testing/unit_test_reports/) leest JUnit XML via `artifacts:reports:junit`. Een bestand onder alleen `artifacts:paths` is downloadbaar, maar verschijnt daarmee niet in het testoverzicht. Gebruik in je bestaande GitLab-jobs dezelfde installatie, configuratie en rapportcommando's als hierboven; de Puppet-pipe vereist Bash met `set -eo pipefail`.

Voeg de onderstaande rapportmap en artifactinstellingen toe aan de bijbehorende configuratie in `.gitlab-ci.yml`. Voeg `PROJECT_REPORT_DIR` toe aan de bestaande `variables` en kies daar het eigen pad. Zo gebruiken de scripts en uploads dezelfde [CI/CD-variabele](https://docs.gitlab.com/ci/variables/where_variables_can_be_used/); alleen een `export` binnen het script stelt die variabele niet voor de artifactupload in. Dit voorbeeld gebruikt de vijf stages `secrets`, `basic_validation`, `static_checks`, `tool_tests` en `catalogs`, zonder `needs`. De lege stage `tool_tests` krijgt geen job en wordt niet getoond. Met `allow_failure: false` en `when: on_success` start iedere volgende aanwezige stage pas na succes van alle eerdere jobs. Gebruik een runner die deze image met Bash uitvoert; `set -eo pipefail` is een Bash-prerequisite. In bestaande jobs kun je alleen de artifactinstellingen overnemen en de eigen installatie en controlecommando’s behouden. Voeg bij eigen Ruby-code `ruby_lint` aan `static_checks` toe en bij een eigen toolsuite `tool_tests` aan de gelijknamige stage, met de gerichte taak en rapporten hierboven. Registreer ook dan hetzelfde rapport via `artifacts:paths` en `artifacts:reports:junit`, met `artifacts:when: always`.

```yaml
stages:
  - secrets
  - basic_validation
  - static_checks
  - tool_tests
  - catalogs

variables:
  PROJECT_REPORT_DIR: .tools/quality/results
  BUNDLE_IGNORE_CONFIG: '1'
  BUNDLE_VERSION: system
  BUNDLE_FROZEN: 'true'
  BUNDLE_PATH: vendor/bundle
  GIT_SUBMODULE_STRATEGY: recursive

.check_setup:
  allow_failure: false
  when: on_success
  image: ruby:latest
  before_script:
    - set -eo pipefail
    - source global-modules/.github/actions/setup-tooling/log.sh
    - |
      ci_begin 'Install Bundler' details
      if gem install bundler; then
          ci_end 0 PASSED complete
      else
          ci_end "$?" ERROR incomplete
      fi
    - |
      ci_begin 'Install locked bundle' details
      if bundle install; then
          ci_end 0 PASSED complete
      else
          ci_end "$?" ERROR incomplete
      fi

puppet_secrets:
  extends: .check_setup
  stage: secrets
  script:
    - bundle exec project-tools-secrets --puppet environments/ modules/
    - git diff --quiet HEAD --

puppet_metadata:
  extends: .check_setup
  stage: basic_validation
  variables:
    PROJECT_METADATA_MODULES_PATH: modules
    PROJECT_METADATA_PREFIX: example
  script:
    - bundle exec project-tools-metadata --junit "$PROJECT_REPORT_DIR/metadata-report.xml"
    - |
      ci_begin 'Checkout changes'
      if git diff --quiet HEAD --; then
          ci_end 0 PASSED complete
      else
          CHECKOUT_STATUS=$?
          if [ "$CHECKOUT_STATUS" -eq 1 ]; then
              ci_end "$CHECKOUT_STATUS" FAILED complete 'Tracked files differ from the checked-out commit.'
          else
              ci_end "$CHECKOUT_STATUS" ERROR incomplete 'Git could not check the working tree; inspect the native diagnostic above.'
          fi
      fi
  artifacts:
    name: Metadata-report
    when: always
    paths:
      - "$PROJECT_REPORT_DIR/metadata-report.xml"
    reports:
      junit: "$PROJECT_REPORT_DIR/metadata-report.xml"

puppet_syntax:
  extends: .check_setup
  stage: basic_validation
  script:
    - bundle exec syntax-junit "$PROJECT_REPORT_DIR/syntax-report.xml" environments/production/manifests/site.pp modules/profile/manifests/init.pp
    - |
      ci_begin 'Checkout changes'
      if git diff --quiet HEAD --; then
          ci_end 0 PASSED complete
      else
          CHECKOUT_STATUS=$?
          if [ "$CHECKOUT_STATUS" -eq 1 ]; then
              ci_end "$CHECKOUT_STATUS" FAILED complete 'Tracked files differ from the checked-out commit.'
          else
              ci_end "$CHECKOUT_STATUS" ERROR incomplete 'Git could not check the working tree; inspect the native diagnostic above.'
          fi
      fi
  artifacts:
    name: Syntax-report
    when: always
    paths:
      - "$PROJECT_REPORT_DIR/syntax-report.xml"
    reports:
      junit: "$PROJECT_REPORT_DIR/syntax-report.xml"

puppet_dependencies:
  extends: .check_setup
  stage: static_checks
  script:
    - export PROJECT_TOOLS_MODULEPATH="$CI_PROJECT_DIR/global-modules:$CI_PROJECT_DIR/modules"
    - bundle exec project-tools-dependencies --junit "$PROJECT_REPORT_DIR/project-tools-dependencies-report.xml"
    - |
      ci_begin 'Checkout changes'
      if git diff --quiet HEAD --; then
          ci_end 0 PASSED complete
      else
          CHECKOUT_STATUS=$?
          if [ "$CHECKOUT_STATUS" -eq 1 ]; then
              ci_end "$CHECKOUT_STATUS" FAILED complete 'Tracked files differ from the checked-out commit.'
          else
              ci_end "$CHECKOUT_STATUS" ERROR incomplete 'Git could not check the working tree; inspect the native diagnostic above.'
          fi
      fi
  artifacts:
    name: Project-tools-dependencies-report
    when: always
    paths:
      - "$PROJECT_REPORT_DIR/project-tools-dependencies-report.xml"
    reports:
      junit: "$PROJECT_REPORT_DIR/project-tools-dependencies-report.xml"

puppet_lint:
  extends: .check_setup
  stage: static_checks
  script:
    - |
      ci_begin 'Puppet lint'
      mkdir -p "$PROJECT_REPORT_DIR"
    - test -f .puppet-lint.rc
    - lint_gem="$(bundle info --path lint-project)"
    - export PROJECT_TOOLS_MODULEPATH="$CI_PROJECT_DIR/global-modules:$CI_PROJECT_DIR/modules"
    - |
      set +e
      bundle exec puppet-lint --no-config --load "$lint_gem/lib/project_lint.rb" --config "$lint_gem/config/puppet-lint.rc" --config .puppet-lint.rc --json environments/production/manifests/site.pp modules/profile/manifests/init.pp | bundle exec puppet-lint-junit --result-status "$PROJECT_REPORT_DIR/puppet-lint-report.xml"
      LINT_STATUS=("${PIPESTATUS[@]}")
      LINT_RESULT_STATUS=${LINT_STATUS[1]}
      if [ "$LINT_RESULT_STATUS" -eq 10 ]; then LINT_STATUS[1]=0; fi
      set -e
      printf 'Native scan exit status: %s | Converter exit status: %s\n' "${LINT_STATUS[0]}" "${LINT_STATUS[1]}"
      if [ "${LINT_STATUS[1]}" -ne 0 ]; then
          ci_end "${LINT_STATUS[1]}" ERROR incomplete 'The lint report could not be completed; inspect the converter diagnostic above.'
      elif [ "${LINT_STATUS[0]}" -ne 0 ]; then
          if [ "${LINT_STATUS[0]}" -eq 1 ] && [ "$LINT_RESULT_STATUS" -eq 10 ]; then
              ci_end 1 FAILED complete 'Lint findings exceed the configured threshold; --fail-on-warnings also rejects warnings.'
          else
              ci_end "${LINT_STATUS[0]}" ERROR incomplete 'Puppet-lint did not return a confirmed lint outcome; inspect the native diagnostic above.'
          fi
      else
          ci_end 0 PASSED complete
      fi
    - |
      ci_begin 'Checkout changes'
      if git diff --quiet HEAD --; then
          ci_end 0 PASSED complete
      else
          CHECKOUT_STATUS=$?
          if [ "$CHECKOUT_STATUS" -eq 1 ]; then
              ci_end "$CHECKOUT_STATUS" FAILED complete 'Tracked files differ from the checked-out commit.'
          else
              ci_end "$CHECKOUT_STATUS" ERROR incomplete 'Git could not check the working tree; inspect the native diagnostic above.'
          fi
      fi
  artifacts:
    name: Puppet-lint-report
    when: always
    paths:
      - "$PROJECT_REPORT_DIR/puppet-lint-report.xml"
    reports:
      junit: "$PROJECT_REPORT_DIR/puppet-lint-report.xml"

puppet_catalog:
  extends: .check_setup
  stage: catalogs
  script:
    - export PROJECT_TOOLS_MODULEPATH="$CI_PROJECT_DIR/global-modules:$CI_PROJECT_DIR/modules"
    - bundle exec global-modules/.tools/catalog/bin/project-tools-catalog --junit "$PROJECT_REPORT_DIR/catalog-report.xml"
    - |
      ci_begin 'Checkout changes'
      if git diff --quiet HEAD --; then
          ci_end 0 PASSED complete
      else
          CHECKOUT_STATUS=$?
          if [ "$CHECKOUT_STATUS" -eq 1 ]; then
              ci_end "$CHECKOUT_STATUS" FAILED complete 'Tracked files differ from the checked-out commit.'
          else
              ci_end "$CHECKOUT_STATUS" ERROR incomplete 'Git could not check the working tree; inspect the native diagnostic above.'
          fi
      fi
  artifacts:
    name: Catalog-report
    when: always
    paths:
      - "$PROJECT_REPORT_DIR/catalog-report.xml"
    reports:
      junit: "$PROJECT_REPORT_DIR/catalog-report.xml"
```

`when: always` bewaart beschikbare rapporten ook na een gewone validatie-, lint- of testfout. De CLI-foutcode bepaalt of de job faalt; JUnit-publicatie verandert die status niet. Bekijk de resultaten onder **Tests** in de pipeline en in de testsamenvatting van de merge request. Parservalidatie en lintchecks blijven herkenbaar aan hun eigen suite en artifact. De repository zelf gebruikt de [GitHub Actions-workflow](#ci-van-deze-repository). De jobkey is in GitLab ook de zichtbare naam; gebruik dezelfde technische IDs als bij GitHub. De volgorde in de YAML-bron dwingt uitvoering niet af: dat doen hier de [stages](https://docs.gitlab.com/ci/yaml/#stages). Voeg geen `needs` toe die deze grenzen kan passeren. Jobs binnen één stage kunnen volgens de interface alfabetisch gesorteerd worden. Een exacte schermvolgorde is geen reden voor kunstmatige afhankelijkheden. Controleer na publicatie de aanwezige stagekolommen, een volledige geslaagde pipeline en een geïsoleerde synthetische fout met geblokkeerde vervolgstages; repositorytests bewijzen geen gehoste uitvoering.

## Importeren en distribueren

<a id="de-linter-gebruiken-in-een-ander-puppet-project"></a>

Kies de tools die je project nodig heeft en voeg hun gems met shared toe aan de eigen ontwikkelbundle. Je project bepaalt de te controleren bestanden, modulepaden en rapportlocaties. Een checkout van Puppet-modules is alleen nodig voor controles die hun code of metadata lezen.

Voor een project met `global-modules` begin je met de [secrets-scanner in je eigen project](secrets/README.md#gebruik-in-een-ander-project): die handleiding verbindt de eigen bundle, voorcontrole vóór AI-gebruik, Rake-prerequisite en CI-gate. Richt daarna de configuratie voor [Puppet-lint](lint/puppet/README.md#eigen-lintconfiguratie) en [RuboCop](lint/ruby/README.md#ruby-controleren-in-een-ander-project) in via de [eigen bundle](#installatie-in-je-project). Voeg daarnaast de [parservalidatie van eigen manifests](syntax/README.md#eigen-manifests-valideren) toe. Heeft je project eigen gereedschap met tests, voeg dan de [testtaak en JUnit-rapportage](#eigen-tooltests) toe. De [rapportafspraken](#rapporten-en-artifacts-in-je-project) en het [CI-voorbeeld](#controle-in-ci) laten zien hoe je de resultaten per controle afzonderlijk bewaart en publiceert.

### Gedeelde tooling hergebruiken

Kies de gems voor de benodigde controles volgens [Pakketten en commando’s](#pakketten-en-commandos). De gems leveren checks, profielen en rapportcommando’s; je hoeft daarvoor geen validator, lintregels of XML-omzetter te schrijven. Je eigen configuratie bepaalt welke bestanden en modulepaden relevant zijn en waar de rapporten terechtkomen.

| Controle | Dit gebruik je uit de gem | Dit stelt je eigen project in |
| --- | --- | --- |
| Metadata | `project-tools-metadata` controleert metadata, herstelt bekende velden met `--fix` en schrijft optioneel JUnit met `--junit`. | Eigen VERSION, rootmetadata, modulelocatie, naamprefix, uitsluitingen en eventueel een rapportpad volgens de [metadatagids](metadata/README.md). |
| Puppet-dependencies | `project-tools-dependencies` gebruikt native OpenVox; `--junit` schrijft dezelfde uitslag ook als XML. | Expliciete modulepath, rootmetadata en eventueel een rapportpad. |
| Puppet-syntax | `syntax-junit` voert de meegeleverde native Puppet-parser uit en schrijft JUnit XML per manifest. | De manifestselectie en het rapportpad. De [optionele Rake-taak](syntax/README.md#eigen-manifests-valideren) verzamelt alleen de eigen bestanden en roept dit commando aan. |
| Puppet-lint | De projectchecks, het gedeelde `config/puppet-lint.rc` en `puppet-lint-junit`. | De eigen bestandsuitsluitingen, het Puppet-modulepad en het rapportpad. Gebruik de [native CLI met het gem-entrypoint](lint/puppet/README.md#eigen-code-controleren). |
| Ruby-lint | RuboCop en het gedeelde `config/rubocop.yml`. De native JUnit-formatter schrijft het rapport. | De eigen `.rubocop.yml` met `inherit_gem`, bestandsselectie en het rapportpad. |
| Lokale secretcontrole | `project-tools-secrets` scant lokaal; `prepare` maakt de analysewerkboom voor inzage en wijzigingen. | Eigen bronselectie, voorcontrole, Puppet-gate en eventueel reviewbeleid volgens de [inrichtingsstappen](secrets/README.md#gebruik-in-een-ander-project). |
| Eigen tooltests | De [voorbeelden voor testselectie en rapportage](#eigen-tooltests). | De eigen tests en testdependencies. De reporter van het eigen testframework schrijft JUnit XML. |

Installeer de gekozen gems eenmaal per ontwikkelomgeving of CI-job via de eigen Gemfile en lockfile. Roep vervolgens de gedeelde commando's met `bundle exec` aan. Kopieer geen implementatie, gedeelde profielen of gemtests uit `global-modules` en laad zijn Gemfile of algemene testtaak niet vanuit je eigen project. Gebruik voor moduletests de afzonderlijke [catalog-ingang voor consumers](catalog/README.md#vanuit-een-ander-project-uitvoeren); die ondersteunt zowel de CLI als de gerichte Rake-taak met de eigen bundle. De gemcommando's werken met jouw selectie.

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
│       │   └── fixtures/            # Invoer voor meerdere groepen of tests zonder groep.
│       └── README.md
├── global-modules/                  # Deze repository als Git-submodule.
│   ├── VERSION                     # De versie van het gedeelde project.
│   ├── metadata.json
│   └── .tools/
│       ├── README.md
│       ├── secrets/project-tools-secrets.gemspec
│       ├── shared/project-tools-shared.gemspec
│       ├── dependencies/project-tools-dependencies.gemspec
│       ├── metadata/project-tools-metadata.gemspec
│       ├── syntax/project-tools-syntax.gemspec
│       └── lint/
│           ├── puppet/
│           │   ├── README.md
│           │   ├── docs/
│           │   │   ├── CODE_RULES.md
│           │   │   ├── DOCUMENTATION_RULES.md
│           │   │   └── OPERATIONAL_RULES.md
│           │   └── lint-project.gemspec
│           └── ruby/
│               ├── README.md
│               └── project-tools-ruby-lint.gemspec
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
| `.puppet-lint.rc` en `.rubocop.yml` | Bewaar hier de eigen bestandsselectie en laad de gedeelde profielen volgens [Eigen lintconfiguratie](lint/puppet/README.md#eigen-lintconfiguratie) en [Ruby controleren in een ander project](lint/ruby/README.md#ruby-controleren-in-een-ander-project). |
| `global-modules/` | Beheer deze dependency via de Git-submodule en de gekozen revisie. Gebruik de gem uit die checkout; voer de controles vanuit de eigen projectroot uit. |
| Eigen rapportmap, bijvoorbeeld `.tools/quality/results/` | Gegenereerde validatie-, lint- en testrapporten van het eigen project. Kies de locatie zelf, bewaar de map buiten versiebeheer en schrijf niet naar de submodule. |
| `.tools/<tool-name>/` | Eén map per eigen tool, met een concrete naam. Volg de [componentstructuur](#componentstructuur): de verantwoordelijkheid bepaalt welke ingangen, implementatie en tests nodig zijn. |
| `.tools/<tool-name>/tests/` | Houd gedragstests, helpers en fixtures bij de tool die ze controleren. De [testindeling en uitvoering](#eigen-tooltests) beschrijven ook bestaande testmappen. |
| `Rakefile` | Houd eigen taken in de projectroot. Ontdek tooltests recursief onder `.tools/**/tests/**/*_test.rb` en voeg alleen bestaande tools toe als `test:<tool-name>`. |

Houd eigen taken voor deze controles beperkt tot de projectspecifieke selectie en het aanroepen van de [gedeelde tooling](#gedeelde-tooling-hergebruiken). Verbeteringen aan de checks, validators en rapportcommando's die voor alle afnemers gelden, horen in de gedeelde gem.

Leg de gekozen toolingindeling en rapportmap vast in de eigen gebruikshandleiding. Leg de gezamenlijke ontwikkel- en testafspraken vast in de eigen ontwikkeldocumentatie en verwijs daarnaar vanuit de eigen `AGENTS.md`. Verwijs voor gedeelde tooling naar deze handleiding onder `global-modules/.tools/README.md` en voor algemene codeprincipes, toepasselijke Puppet-regels en reviewcriteria naar `global-modules/.tools/lint/puppet/docs/CODE_RULES.md`. Verwijs voor commentaar, Puppet Strings en interface-documentatie aanvullend naar `global-modules/.tools/lint/puppet/docs/DOCUMENTATION_RULES.md` en voor operationele wijzigingen naar `global-modules/.tools/lint/puppet/docs/OPERATIONAL_RULES.md`. Beide aanvullende regelsbestanden kunnen tegelijk van toepassing zijn. Zo wordt iedere uitleg op haar eigen plek onderhouden. De root-`CONTRIBUTING.md` en `TESTS.md` in de submodule beschrijven het werk aan die repository; haar `AGENTS.md` routeert agents naar diezelfde bronnen. Afnemers leggen de afspraken voor hun eigen project expliciet vast.

Een bestaand project met een andere indeling hoeft daarvoor geen Puppet-modules of environments te verplaatsen. Beschrijf de afwijkende paden in de eigen README en houd Gemfile, bestandsselectie, modulepad en CI daarmee in overeenstemming. Voor de manifestanalyse is de indeling een aanbevolen werkwijze. Stel voor de [metadatacontrole](metadata/README.md#modulemetadata-controleren) `PROJECT_METADATA_MODULES_PATH` in op de gekozen map met eigen modules; de naam `modules` is alleen een voorbeeld. Gebruik je een los gempakket, dan vervalt `global-modules/` als installatievereiste en blijven de afspraken voor de eigen tooling hetzelfde.

### Installatie in je project

Gebruik voor een checkout als `global-modules` expliciete bronnen voor alle gekozen gems:

```ruby
source 'https://rubygems.org'

# Choose one runtime; replace openvox with puppet when appropriate.
gem 'openvox', require: false
gem 'json', '< 3', require: false
gem 'syslog', '~> 0.4', platforms: :ruby, require: false

gem 'project-tools-shared', path: 'global-modules/.tools/shared', require: false
gem 'lint-project', path: 'global-modules/.tools/lint/puppet', require: false
gem 'project-tools-dependencies', path: 'global-modules/.tools/dependencies', require: false
gem 'project-tools-syntax', path: 'global-modules/.tools/syntax', require: false
gem 'project-tools-ruby-lint', path: 'global-modules/.tools/lint/ruby', require: false
gem 'project-tools-metadata', path: 'global-modules/.tools/metadata', require: false
gem 'project-tools-secrets', path: 'global-modules/.tools/secrets', require: false
```

Voor algemene secretcontrole kies je shared en `project-tools-secrets`; de Puppet-modus gebruikt aanvullend de gekozen Puppet-runtime; leg ook de [voorcontrole voor AI en externe analyse](secrets/README.md#gebruik-in-een-ander-project) vast in je eigen instructies. Voor alleen parservalidatie kies je shared en `project-tools-syntax`; voor alleen dependencycontrole kies je shared en `project-tools-dependencies`. Voor alleen metadata kies je shared en `project-tools-metadata`; voor alleen Ruby-lint kies je `project-tools-ruby-lint` en shared, zonder Puppet-runtime. Laat de overige toolgems weg. De Git-submodule legt de bronrevisie vast en je eigen lockfile legt de volledige oplossing vast. Voer `bundle install` vanuit de consumerroot uit. De gems installeren geen Puppet-modules; haal die afzonderlijk op. Kopieer geen Ruby-implementatie of rapportomzetter en laad niet de root-Gemfile of algemene testtaak van `global-modules`. Voor moduletests geldt de afzonderlijke [catalog-ingang](catalog/README.md#vanuit-een-ander-project-uitvoeren).

### Git-dependency uit de monorepo

Alle interne gems komen uit dezelfde gekozen revisie. Vervang `<repository-url>` door de Git-URL van je goedgekeurde repository. `TOOLS_REVISION` hieronder is een shellinstelling van de consumer met een overeengekomen onveranderlijke revisie die de gemspecs van de gekozen tools bevat; de tools lezen deze variabele niet tijdens scans.

```ruby
source 'https://rubygems.org'

# Choose one runtime; replace openvox with puppet when appropriate.
gem 'openvox', require: false
gem 'json', '< 3', require: false
gem 'syslog', '~> 0.4', platforms: :ruby, require: false

git '<repository-url>',
    ref: ENV.fetch('TOOLS_REVISION'),
    glob: '.tools/**/*.gemspec' do
  gem 'project-tools-shared', require: false
  gem 'lint-project', require: false
  gem 'project-tools-dependencies', require: false
  gem 'project-tools-syntax', require: false
  gem 'project-tools-ruby-lint', require: false
  gem 'project-tools-metadata', require: false
  gem 'project-tools-secrets', require: false
end
```

Voer `bundle install` vanuit de eigen projectroot uit. Bewaar de gekozen revisie en lockfile. Bij een update gebruik je een gecontroleerde revisie en `bundle update lint-project project-tools-shared project-tools-dependencies project-tools-syntax project-tools-ruby-lint project-tools-metadata project-tools-secrets`, gevolgd door de eigen kwaliteitscontroles. Zonder de multi-gemglob vindt Bundler niet alle geneste gemspecs. Zet geen credentials in Gemfile of URL. Een Puppet-modulecheckout blijft afzonderlijk nodig voor de moduleset die je beoordeelt.

De installatietest gebruikt een tijdelijke Git-checkout met een Bundler-local-override voor de huidige werkbestanden, zonder commits te maken. Dat controleert de multi-gembron, glob, lokale packagegrenzen en consumercommando’s. Een installatie van de uiteindelijke gepubliceerde revisie zonder local override blijft een controle na de menselijke commit; de test bewijst evenmin bereikbaarheid of toegangsrechten van de externe server.

### Gebouwd gempakket installeren

Bouw ieder pakket vanuit zijn eigen map. Runtimecode gebruikt gewone `require`-paden; er is geen fallback naar siblingbroncode als shared ontbreekt. Iedere gem bevat uitsluitend eigen runtimecode, bedoelde executables, licentie en documentatie. Shared bevat geen tests of testbootstrap. Resultaten, caches, fixtures, rootlockfile en Puppet-modules blijven buiten de pakketten.

De meegeleverde Markdown blijft gelijk aan de documentatie in de checkout en volgt de [afspraken voor documentatielinks](lint/puppet/docs/DOCUMENTATION_RULES.md#markdown). Links naar meegeleverde bestanden werken ook binnen de geïnstalleerde gem. Open de documentatie in de bijbehorende checkout voor verwijzingen naar CONTRIBUTING, TESTS, andere tools, agentroutes, tests of Puppet-modules; die bestanden zitten niet in het pakket.

**Werkmap:** Repositoryroot. **Shell:** POSIX shell. **Vereisten:** Gevalideerde bronnen en RubyGems. **Invoer:** De gemspecs van de gekozen tools. **Wijzigt bestanden:** Alleen /tmp-gempakketten. **Verwacht resultaat:** Zelfstandig installeerbare pakketten.

```sh
(cd .tools/shared && gem build project-tools-shared.gemspec --output /tmp/project-tools-shared.gem)
(cd .tools/lint/puppet && gem build lint-project.gemspec --output /tmp/lint-project.gem)
(cd .tools/dependencies && gem build project-tools-dependencies.gemspec --output /tmp/project-tools-dependencies.gem)
(cd .tools/syntax && gem build project-tools-syntax.gemspec --output /tmp/project-tools-syntax.gem)
(cd .tools/lint/ruby && gem build project-tools-ruby-lint.gemspec --output /tmp/project-tools-ruby-lint.gem)
(cd .tools/metadata && gem build project-tools-metadata.gemspec --output /tmp/project-tools-metadata.gem)
(cd .tools/secrets && gem build project-tools-secrets.gemspec --output /tmp/project-tools-secrets.gem)
```

Installeer shared vóór de gekozen tools, zodat een ongepubliceerde shared-gem niet van RubyGems hoeft te komen. De externe dependencies komen uit je goedgekeurde gembron. Deze procedure publiceert niets en veronderstelt geen eigendom van de nieuwe gemnamen op RubyGems.

**Werkmap:** Consumerroot. **Shell:** POSIX shell. **Vereisten:** De bovenstaande pakketten, nieuwste stabiele Ruby/Bundler en toegang tot de externe gemdependencies. **Invoer:** Gebouwde gems. **Wijzigt bestanden:** Geminstallatie en eigen lockfile. **Verwacht resultaat:** Dezelfde publieke commando’s buiten de checkout.

```sh
gem install /tmp/project-tools-shared.gem
gem install /tmp/lint-project.gem
gem install /tmp/project-tools-dependencies.gem
gem install /tmp/project-tools-syntax.gem
gem install /tmp/project-tools-ruby-lint.gem
gem install /tmp/project-tools-metadata.gem
gem install /tmp/project-tools-secrets.gem
bundle install
```

De eigen Gemfile selecteert de geïnstalleerde pakketten. Onderstaande vaste versies zijn een illustratief voorbeeld; neem per pakket de versie uit de gemspec van je gekozen uitgave over en behoud de expliciete pin:

```ruby
source 'https://rubygems.org'

# Choose one runtime; replace openvox with puppet when appropriate.
gem 'openvox', require: false
gem 'json', '< 3', require: false
gem 'syslog', '~> 0.4', platforms: :ruby, require: false

gem 'project-tools-shared', '= 0.1.1', require: false
gem 'lint-project', '= 0.2.0', require: false
gem 'project-tools-dependencies', '= 0.1.0', require: false
gem 'project-tools-syntax', '= 0.1.0', require: false
gem 'project-tools-ruby-lint', '= 0.1.0', require: false
gem 'project-tools-metadata', '= 0.1.0', require: false
gem 'project-tools-secrets', '= 0.4.0', require: false
```

Installeer uitsluitend shared en de gekozen tools. Voor parservalidatie en dependencycontrole is `lint-project` niet nodig. Richt per gekozen tool het [lintprofiel](lint/puppet/README.md#eigen-lintconfiguratie), [Ruby-profiel](lint/ruby/README.md#ruby-controleren-in-een-ander-project) en de [eigen metadataconfiguratie](metadata/README.md) in. Controleer pakketupdates met de eigen volledige lintscan, parservalidatie, dependencycontrole en toepasselijke Ruby- en tooltests. `bundle info --path` toont de werkelijk gebruikte gem; bronbestanden buiten het pakket zijn geen vervanging voor ontbrekende distributie-inhoud. De tijdelijke `.gem`-bestanden mogen na installatie weg; bewaar uitgaven via een goedgekeurde distributieroute.

### Migreren naar afzonderlijke toolpakketten

<a id="migreren-naar-de-vier-packages"></a>
<a id="migreren-naar-de-zes-pakketten"></a>

Deze stappen beschrijven de overstap naar de afzonderlijke toolingintegratie vanaf projectversie `3.0.0`. Pas ze toe voor de tools, instellingen en eerdere aanroepen die je project gebruikt.

Voeg voor Ruby `project-tools-ruby-lint` toe en wijzig `inherit_gem` in `.rubocop.yml` van `lint-project` naar `project-tools-ruby-lint`. Het commando blijft `bundle exec rubocop`; lint installeert RuboCop niet meer.

Voeg voor metadata `project-tools-metadata` toe. Vervang `PROJECT_LINT_MODULES_PATH` door `PROJECT_METADATA_MODULES_PATH` en `PROJECT_LINT_METADATA_PREFIX` door `PROJECT_METADATA_PREFIX` in de metadata-aanroep en CI-job. Neem benodigde uitsluitingen uit `.puppet-lint.rc` expliciet over als `--ignore-paths` van het metadatacommando. Vervang `puppet-lint --only-checks=project_metadata --fix` door `project-tools-metadata --fix`. Verwijder oude `project_metadata`-selecties of uitschakelopties uit lintconfiguratie; de check is geen lintplugin meer. Voeg ook de metadatajob met `--junit REPORT.xml` zonder `--fix` toe: Puppet-lint controleert en synchroniseert metadata niet meer.

Vervang eerdere aanroepen van `project-tools-metadata-junit [--fix] REPORT.xml` door `project-tools-metadata [--fix] --junit REPORT.xml` en van `project-tools-module-dependencies-junit REPORT.xml` door `project-tools-dependencies --junit REPORT.xml`. Laat voor uitsluitend console-uitvoer het hele `--junit REPORT.xml`-argument weg. Een los rapportpad wordt afgewezen. Werk ook eigen scripts en CI-aanroepen bij en voer `bundle install` uit om de nieuwe executables beschikbaar te maken. De vervangen executables krijgen geen compatibiliteitsalias.

Verwijder automatische rapportinstellingen uit eigen Rakefiles en testhelpers. Gebruik de [optionele reporterinitialisatie](#junit-rapportage-instellen) en geef in CI `MINITEST_REPORTERS_REPORTS_DIR` expliciet mee met dezelfde map als de testartifactselectie. Zonder die instelling laten `rake test`, gerichte taken en de standaardtaak bestaande rapporten ongemoeid; een lokaal oud rapport hoort dus bij de eerdere uitvoering.

Vervang `PROJECT_LINT_MODULEPATH` door `PROJECT_TOOLS_MODULEPATH` bij lint en dependencycontrole. De padvolgorde en validatie blijven gelijk. Stem rapportpaden, uploads en ignorepatronen samen af volgens [Rapporten en artifacts](#rapporten-en-artifacts-in-je-project). Als je de workflow van deze repository overneemt, gebruik je `checks.yml` en voeg je `Puppet metadata` toe aan verplichte statuschecks waar je project die gebruikt. Een eigen workflownaam of rapportmap hoeft daarvoor niet te veranderen. Deze repository gebruikt geen compatibiliteitsaliassen voor de vervangen instellingen.

`lint-project 0.2.0` vereist een extra shared-gembron. Een bestaande path- of Git-consumer met alleen `lint-project` kan de ongepubliceerde shared-gem niet vanzelf vinden. Voeg de [shared-pathbron](#installatie-in-je-project) toe, gebruik de [multi-gem-Gitbron](#git-dependency-uit-de-monorepo), of lever het [shared-pakket](#gebouwd-gempakket-installeren) mee. Selecteer alle interne gems uit dezelfde gecontroleerde checkout of revisie, werk de eigen lockfile bij en voer de bestaande kwaliteitscontroles uit.

Gebruik `project-tools-syntax` voor syntaxcontrole. Vervang `project-tools-validate` (of de oudere naam `project-tools-puppet-validate`) in de eigen Gemfile en wijzig de pathbron van `global-modules/.tools/validate` naar `global-modules/.tools/syntax`. Vervang `validate-junit` of `puppet-validate-junit` door `syntax-junit`, werk de eigen lockfile bij en voer `bundle install` uit. Bij rechtstreeks Ruby-gebruik veranderen `project_tools/validate` en `ProjectTools::Validate` naar `project_tools/syntax` en `ProjectTools::Syntax`. Er zijn geen compatibiliteitsaliassen. Het native commando `puppet parser validate` blijft ongewijzigd.

Hernoem eigen `validate:puppet`-taken naar `syntax:puppet`. Gebruik `syntax-report.xml`, suite en testcase-classname `syntax`, artifact `Syntax-report` en CI-job `Puppet syntax` met sleutel `puppet_syntax`. Pas rapportpaden, uploads, ignorepatronen en verplichte statuschecks met de oude naam `Validate` of `Puppet validate` samen aan. In deze repository worden `.tools/validate/` en `test:validate` vervangen door `.tools/syntax/` en `test:syntax`. De afzonderlijke job `Puppet catalogs` ontdekt en compileert de [module-eigen scenario’s](catalog/README.md); voeg die job ook toe aan verplichte statuschecks als die zijn ingesteld. De consumer-CI-voorbeelden blijven gericht op eigen manifests. Voor cataloguscontroles gebruikt een consumer de [centrale runner](catalog/README.md#vanuit-een-ander-project-uitvoeren), die zowel geïmporteerde als eigen moduletests op het gekozen modulepad ontdekt.

Werk eigen parser-Rake-taken bij volgens het [voorbeeld met optionele rapportage](syntax/README.md#eigen-manifests-valideren). `bundle exec rake syntax:puppet` valideert zonder rapport. Vervang de aanroep in CI door `bundle exec rake "syntax:puppet[$PROJECT_REPORT_DIR/syntax-report.xml]"` met de ingestelde rapportmap. De taak heeft geen standaardrapportpad en leest `PROJECT_REPORT_DIR` niet zelf; bestaande rapporten blijven zonder rapportargument ongewijzigd.

Voeg `project-tools-dependencies` en zijn afzonderlijke CI-job toe wanneer je dependencycontrole gebruikt. Werk bestaande Gemfile-verwijzingen, buildcommando’s en CI-aanroepen voor de dependencytool bij naar de volledige naam `project-tools-dependencies` en executable `project-tools-dependencies`. Gebruik de rapportnamen uit [Rapporten en artifacts](#rapporten-en-artifacts-in-je-project).

De gedeelde console voor [joblogs](#joblogs) is beschikbaar vanaf `project-tools-shared 0.1.1`. Werk bij een update van de afnemende tools ook shared en de eigen lockfile bij volgens hun gemspecs. Mensgerichte tekst is geen parser-API; gebruik voor automatische verwerking de bestaande JSON- en XML-formaten.

Puppet-lint en parservalidatie behouden hun statuscontracten na installatie en aanpassing van de parseraanroep. `puppet-lint-junit` blijft een converter: geldige conversie kan status 0 geven terwijl de XML failures bevat; de lintpipe blijft `pipefail` vereisen. `syntax-junit` blijft ieder geselecteerd manifest native valideren. De nieuwe dependencytool gebruikt zijn eigen [exitcodes en rapportlevenscyclus](dependencies/README.md#exitcodes-en-rapporten).

## Verantwoordelijkheden gescheiden houden

De [algemene ontwerpregels](lint/puppet/docs/CODE_RULES.md#algemene-ontwerpregels) gelden ook voor alle code onder `.tools/`. Hieronder staat hoe de bestaande toolpakketten die verantwoordelijkheden verdelen.

Een tool met een eigen CLI biedt één executable met expliciete subcommando's voor haar verschillende taken. De executable draagt de verwerking over aan de library van de betreffende tool. De commandolaag verwerkt de CLI-aanroep en vertaalt het resultaat naar uitvoer en exitstatus. De toollibrary bevat de taakverwerking; `project-tools-shared` levert de gedeelde technische voorzieningen.

Houd iedere onafhankelijke controle bij haar eigen tool: CLI, runtime-dependencies, configuratie, correcties, rapport en gedragstests. Puppet-lint corrigeert Puppet-invoer; metadatawijzigingen vereisen het metadatacommando. Ruby-lint gebruikt de native RuboCop-CLI en formatter. Een gezamenlijke bundle of CI-setup maakt deze tools niet afhankelijk van elkaar.

Shared bevat alleen technisch gedrag dat meerdere tools daadwerkelijk delen, zoals XML, modulepadvalidatie en consolepresentatie. Repositorydocumentatie, workflowconfiguratie, distributie-integratie en testindeling worden door [repositorycontroles](repository/README.md) bewaakt. De [ontwikkelinstructies](#verantwoordelijkheden-en-integratie-reviewen) regelen review en onderhoud over deze grenzen heen.

### CLI en rapportage

Iedere eigen executable, ook een converter of rapportagevariant, ondersteunt `-h` en `--help`. Beide tonen dezelfde gebruiksuitleg met de ondersteunde opties op stdout en eindigen met status 0 en lege stderr. Help voert geen controle of herstel uit, leest geen verwerkingsinvoer en maakt of wijzigt geen bestanden; start-, voortgangs- en resultaatmeldingen horen daar niet bij. Onbekende opties geven een niet-nul status en een diagnose, zonder als bestandsnamen te worden verwerkt. Behoud de gedocumenteerde toolspecifieke foutcodes en beveiligde diagnostiek. Gebruik de bestaande Ruby-optieparser voor de eigen CLI's; externe commando's houden hun native interface.

Een controle of herstelhandeling moet lokaal uitvoerbaar zijn met console-uitvoer en een passende exitstatus, zonder verplicht rapportbestand. Geef een zelfstandig controlecommando een naam die zijn taak beschrijft. Gebruik bij onze eigen controle-CLI’s `--junit REPORT.xml` voor optionele JUnit-uitvoer. Zonder deze optie worden geen rapporten of rapportmappen aangemaakt of bijgewerkt; een bestaande rapportmap is geen vereiste voor controle of herstel. CI vraagt het rapport expliciet aan.

Dit geldt ook voor Rake-taken, standaardtaken en voorbeeldhelpers: laat die rapportage niet impliciet inschakelen of een rapportpad invullen. Voor Minitest vraagt de aanroeper rapportage aan via de bestaande instelling `MINITEST_REPORTERS_REPORTS_DIR`. Een gewone `rake test`, gerichte testtaak of standaardtaak behoudt zonder die instelling uitsluitend console-uitvoer en de teststatus.

Gebruik bestaande native commando’s en hun uitvoeropties wanneer die de controle al aanbieden. Puppet-lint en RuboCop hebben hun eigen CLI en correctieopties; `puppet parser validate` biedt syntaxvalidatie zonder rapport. Voeg daarvoor geen gelijknamige projectwrapper of uniforme set opties toe. Een aparte converter of rapportagevariant mag een uitvoerformaat in zijn naam en een verplicht rapportpad hebben: `puppet-lint-junit` zet bestaande JSON-uitvoer om, terwijl `syntax-junit` native parserresultaten per manifest verzamelt. Documenteer bij zo’n variant ook het gewone commando zonder rapport.

Controle en rapportage gebruiken dezelfde bevindingen. Het aanvragen van een rapport verandert het oordeel niet; een fout bij het schrijven van een gevraagd rapport blijft wel een uitvoerfout. De [ontwikkelinstructies](#verantwoordelijkheden-en-integratie-reviewen) bepalen welke gedragstests en integratiecontroles dit contract bij wijzigingen bewaken.

### Joblogs

Nieuwe en gewijzigde CI-aanroepen volgen één leesvolgorde: start en bereik, beperkte voortgang, bevindingen en een zelfstandig leesbaar eindresultaat. Dit geldt ook voor installatie, rapportpublicatie en de checkoutcontrole. Houd de bestaande jobs, selecties, waarschuwingdrempels en exitcodes aan. Laat dezelfde controle maar eenmaal uitvoeren en wijs één laag aan die haar primaire eindresultaat schrijft.

Alle eigen Ruby-tools moeten het bestaande [gedeelde consolecontract](shared/README.md#runtimecontracten) gebruiken voor hun mensgerichte controle-uitvoer. Zij tonen gewone, direct geflushte regels. Bij langer werk verschijnt ongeveer iedere vijftien seconden een voortgangsregel. Alleen afgeronde onderdelen verhogen de teller; zonder nieuwe resultaten verschijnt `Still running` met de verstreken tijd. Die melding toont activiteit en bewijst geen inhoudelijke voortgang. Korte controles hebben aan start en eindresultaat voldoende. Normale succesvolle individuele controles blijven standaard stil; gedetailleerde succesinformatie hoort in het expliciet aangevraagde rapport. Relevante bevindingen, waarschuwingen, correcties, beperkingen en native diagnostiek blijven zichtbaar.

Houd consolepresentatie, controlesemantiek en rapportage afzonderlijk. De tool bepaalt selectie, tellingen en oordeel; shared presenteert die gegevens. Gebruik gestructureerde resultaten om bevindingen van succesdetails te onderscheiden, zonder menselijke logregels als protocol te parsen. Iedere controle schrijft maximaal één primaire afsluiting, ook bij een rapportagefout of afhandelbare onderbreking. Rond noodzakelijke rapportage af vóór die afsluiting.

| Afsluiting | Betekenis |
| --- | --- |
| `PASSED` | Voldoet volgens het bestaande toolbeleid; waarschuwingen kunnen aanwezig zijn. |
| `FAILED` | Inhoudelijke afkeuring volgens dat beleid. |
| `ERROR` | Uitvoering of noodzakelijke afronding is niet betrouwbaar voltooid. |
| `SKIPPED` | Bewust overgeslagen volgens bestaande configuratie of beleid. |

Volledigheid staat afzonderlijk bij `Execution`: `complete`, `incomplete`, `not executed` of `unknown`. Een bevinding blijft ook bij een latere uitvoerfout zichtbaar. Niet-afgeronde onderdelen tellen niet als geslaagd of bewust overgeslagen. Een lege selectie volgt het bestaande toolbeleid. Tellingen benoemen hun eenheid: bronnen, manifests, modules, testgevallen en bevindingen zijn verschillende aantallen. Een onbekende telling wordt weggelaten of als onbekend aangeduid, nooit als nul. De [toolhandleidingen](#pakketten-en-commandos) leggen hun concrete tellingen vast.

Het eindresultaat bevat de bekende tellingen en relevante diagnostiek, voorspelbaar gesorteerd op bron en positie waar die beschikbaar zijn. Reeds volledig getoonde bevindingen en diagnoses worden niet opnieuw afgedrukt: het compacte einde verwijst er expliciet naar en blijft zelfstandig leesbaar met status, volledigheid, tellingen en duur. Kort geen bevindingen stilzwijgend af. Een rapportverwijzing verschijnt pas na een geslaagde schrijfhandeling voor deze uitvoering; een bestaand oud bestand is geen bewijs. Zonder rapportverzoek blijven bestaande rapporten ongemoeid. Een latere verplichte upload of checkoutcontrole kan de job alsnog laten falen.

Nieuwe en gewijzigde eigen Ruby-tools moeten dit contract met gedragstests bij de betreffende tool bewaken, volgens het [testbeleid voor console en rapportage](../TESTS.md#interfaces-dependencies-en-gegenereerde-inhoud). De bestaande automatische `test:tools`-selectie voert deze regressies ook in de CI-gate uit. Shared-tests bewaken uitsluitend gedeeld presentatiegedrag; alleen de gedeelde console aanroepen is onvoldoende bewijs van correct toolgedrag.

JSON en XML blijven vrij van startregels, voortgang en platformmarkeringen. Voeg geen `2>&1` toe aan de lintpipe: native stdout blijft JSON, native stderr houdt zijn diagnoses. Puppet-lint schakelt zijn native annotaties bij JSON-uitvoer uit; de gewone native tekstaanroep behoudt die mogelijkheid. De converter toont de gestructureerde bevindingen en maakt JUnit; hij bepaalt geen lintdrempel. De CI-aanroep vraagt met `--result-status` een afzonderlijk signaal voor actieve bevindingen na geslaagde conversie. De Bash-aanroep bewaart beide `PIPESTATUS`-waarden onmiddellijk en normaliseert uitsluitend dat bevindingensignaal naar conversiestatus 0. Native lintstatus 1 met dat signaal geeft `FAILED`, met de ingestelde warningdrempel als reden. Een andere niet-nul lintstatus, lintstatus 1 zonder bevestigde bevindingen of een conversiefout geeft `ERROR`. De oorspronkelijke processtatussen en de prioriteit van de laatste niet-nul status blijven behouden; een converterbevinding maakt een native nulstatus niet alsnog afkeurend. De [converterinterface](lint/puppet/README.md#exitcodes-van-puppet-lint-junit) beschrijft de codes en het verschil met gewone conversie.

Native lokale commando’s houden hun eigen uitvoer en opties. In CI levert de bestaande Bash-stap waar nodig start, activiteit en afsluiting via [log.sh](../.github/actions/setup-tooling/log.sh). Deze kleine, gesourcete presentatiehulp voert zelf geen controlecommando uit en werkt ook vóór de bundle-installatie. `ci_begin NAME [details|native]` start de presentatie; `ci_end CODE STATUS COMPLETENESS [REASON]` sluit haar af en retourneert de oorspronkelijke code. `native` laat voortgang aan de native formatter en start geen tweede activiteitsproces. RuboCop gebruikt in deze CI-aanroepen `--stderr` voor direct zichtbare native voortgang; alleen de mensgerichte uitvoer verhuist, het aangevraagde JUnit-bestand blijft apart. De aanroep bepaalt de toolspecifieke statusbetekenis. Een opgegeven `REASON` staat bij het eindresultaat en legt uit waarom de controle faalt. De EXIT-afhandeling meldt een onverwachte fout als `ERROR` met `Execution: incomplete`, benoemt dat geen resultaat kon worden bevestigd en bewaart de oorspronkelijke code. INT en TERM sluiten activiteit en een geopende sectie af; harde beëindiging kan afsluiting en rapportage onmogelijk maken.

`details` groepeert uitgebreide voorbereiding met [GitHub-groepen](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-commands#grouping-log-lines) of [ingeklapte GitLab-secties](https://docs.gitlab.com/ci/jobs/job_logs/#collapse-sections-by-default). Het resultaat staat buiten de groep. Lokaal verschijnen geen platformmarkeringen. Platformacties voor checkout, Ruby-setup, uploads en summaries behouden hun native logs en foutafhandeling. RuboCop houdt zijn native voortgang, broninformatie, JUnit-formatter en eventuele GitHub-annotaties. De bestaande publicatieacties blijven eigenaar van de GitHub-summaries; er komt geen tweede samenvatting of annotatie bij.

De consumer-voorbeelden sourcen de hulp uit hun vastgelegde `global-modules`-checkout; kopieer het script niet naar het eigen project. Wie uitsluitend geïnstalleerde gems gebruikt, behoudt de eigen CI-aanroeplaag en past daar dit presentatiecontract toe. De Ruby-gems vereisen geen CI-script of ontwikkelcheckout. Een Ruby-lintinstallatie gebruikt shared voor de versieheader en heeft geen Puppet-runtime nodig.

Elke tooluitvoering toont dynamisch `Tool: <naam> <versie>`, `Runtime: Puppet/OpenVox <versie>` en `Ruby: <versie>`. Zonder runtimegebruik staat er `Puppet runtime: not required`; een ontbrekende vereiste runtime wordt als unavailable vermeld en de controle faalt. Help blijft zonder versieheader. De gedeelde console levert dezelfde informatie lokaal, in GitLab CI en GitHub Actions. Native RuboCop, Puppet-lint en converters schrijven de header op stderr, zodat JSON/XML en JUnit ongewijzigd blijven. De secrets-tool meldt bij afsluiting welke runtime zij werkelijk heeft gevraagd. De catalogusrunner gebruikt root-`VERSION`; gemtools gebruiken hun geactiveerde gemspec. CI voegt geen tweede header toe.

## Gedeeld toolingonderhoud

Volg bij onderhoud de [gezamenlijke ontwikkelwerkwijze](../CONTRIBUTING.md) en het [repositorybrede testbeleid](../TESTS.md). Deze onderhoudsroute geldt ook voor integratie in de root-Gemfile, het Rakefile, `.github/` en consumervoorbeelden. Lees daarna de README van ieder geraakt component; bij een gedeelde interface ook de contracten van de werkelijke afnemers. De [algemene ontwerpregels](lint/puppet/docs/CODE_RULES.md#algemene-ontwerpregels) gelden voor ieder component.

| Component | Onderhoud en verificatie |
| --- | --- |
| Lint | [Checks, architectuur, veilige autofix en documentatie](lint/puppet/README.md#linter-ontwikkelen-en-testen). |
| Metadata | [Selectie, versiebron, herstel en rapporten](metadata/README.md#onderhoud-en-verificatie). |
| Moduledependencies | [Native selectie, runtimegrenzen en distributie](dependencies/README.md#ontwikkelen-en-testen). |
| Repositorycontroles | [Documentatie, instructieroutes, CI, distributie-integratie en testindeling](repository/README.md#onderhoud). |
| Ruby-lint | [Native RuboCop, profiel en consumerintegratie](lint/ruby/README.md#onderhoud-en-tests). |
| Secrets | [Detectie, analysekopieën, herstel en veilige review](secrets/README.md#ontwikkelen-en-testen). |
| Shared | [Gedeelde runtime en testondersteuning](shared/README.md#afhankelijkheden-en-onderhoud). |
| Cataloguscontrole | [Moduletestontdekking en runner](catalog/README.md#onderhoud). |
| Syntax | [Native parser, selectie en rapporten](syntax/README.md#ontwikkelen-en-testen). |

### Componentstructuur

Bepaal de structuur vanuit de verantwoordelijkheid van het component. Maak geen lege mappen, startbestanden of wrappers om alle componenten dezelfde indeling te geven.

| Soort component | Vereiste structuur |
| --- | --- |
| Tool met eigen CLI | Eén eigen executable onder `bin/`, met een Ruby-shebang en modus `0755`. Houd de implementatie in `lib/` gescheiden van het startbestand en laad haar onafhankelijk van de werkmap. |
| Ruby-gem met executable | Dezelfde CLI-indeling, met `bindir = 'bin'` en de geleverde executables geregistreerd in de `.gemspec`. |
| Gedeelde bibliotheek | Librarycode zonder verplichte `bin/` wanneer er geen zelfstandig commando is. |
| Configuratie voor externe tooling | Configuratie voor het bestaande externe commando, zonder overbodige wrapper. |
| Repositorytests | Tests via de bestaande root-Rake-infrastructuur, zonder eigen CLI. |

Daarom heeft `catalog` een [eigen startbestand](catalog/bin/project-tools-catalog), terwijl `shared` alleen een bibliotheek levert, `lint/ruby` de native RuboCop-CLI gebruikt en `repository` via Rake draait. Die laatste drie hebben geen eigen `bin/` nodig. Houd bij ieder component de eigen `README.md`, `AGENTS.md` en toepasselijke tests onder `tests/` bij, volgens de [testscope](../TESTS.md#testscope-en-plaatsing) en [testinrichting](#gezamenlijke-tooltests). Documenteer gebruik en onderhoud bij de eigenaar en verbind de agentroute met die uitleg.

Leg bij een nieuwe tool meteen de uitvoerinterface en de bijbehorende structuurtest vast. De bestaande [structuurcontrole](repository/tests/test_structure_test.rb) leidt gem-executables af uit hun gemspecs en componenten uit gemspecs, Rake-testselecties en aanwezige CLI-startbestanden. Een CLI zonder gemregistratie, zoals catalog, krijgt een expliciete verwachting in die test. Alleen aanwezige `bin/`-bestanden ontdekken kan een ontbrekende, nergens geregistreerde CLI niet aantonen. Houd ook de Ruby-lintselectie, gerichte testtaak en werkelijk benodigde Rake-, CI- en consumerintegraties in overeenstemming; voeg geen tweede toolregister of testsysteem toe.

### Verantwoordelijkheden en integratie reviewen

- Lees vóór een toolwijziging het [centrale logcontract](#joblogs), controleer de [bestaande shared-implementatie](shared/lib/project_tools/shared/console.rb) en vergelijk relevante aanroepers bij andere tools. Onderhoud de toepasselijke console- en rapportageregressies bij de tool en werk de bijbehorende gebruiks- en ontwikkeluitleg bij. Native externe tools, waaronder RuboCop, behouden hun eigen formatter, diagnostiek en resultaatbeleid; bouw hun uitvoer niet om naar een tweede formatter. Voeg geen Bash-presentatie om een Ruby-runner toe die zelf zijn primaire afsluiting schrijft.

- Pas de [hergebruikreview](../CONTRIBUTING.md#hergebruik-en-samenhang) en algemene ontwerpcriteria toe over de geraakte tools en hun echte consumers. Beoordeel executable, commandolaag, toolverwerking en gedeelde runtime tegen de [verantwoordelijkheidsgrenzen](#verantwoordelijkheden-gescheiden-houden) en het [CLI-contract](#cli-en-rapportage), ook voor zelfstandige installatie en consumerprojecten.
- Beoordeel bij iedere nieuwe of gewijzigde CLI-optie, standaardinstelling, uitvoerconventie of foutafhandeling alle eigen CLI's op hetzelfde gebruikerscontract. Pas algemeen gedrag in dezelfde wijziging toe bij alle toepasselijke tools en onderhoud de gezamenlijke gedragstest in de bestaande [repositorystructuurcontrole](repository/tests/test_structure_test.rb). Leid de selectie af uit de componentstructuur; verzwak de gezamenlijke assertions niet met toolspecifieke uitzonderingen. Houd noodzakelijke verschillen bij hun eigenaar, met reden en gerichte tests; voeg taakgebonden functies niet toe aan tools waarvoor zij geen betekenis hebben. Verifieer gewijzigde libraries en geïnstalleerde consumerinterfaces naast de gezamenlijke CLI-test.
- Verifieer bij taakingangen dat iedere afzonderlijke gebruikstaak een duidelijk subcommando binnen de ene executable heeft en de inhoudelijke verwerking aan de eigen library overdraagt. Pas bij vervanging de consolidatieafspraak toe: consumers migreren in plaats van parallelle routes te behouden. Werk geïnstalleerde executables, lintdekking, integraties en consumermigratie samen bij, zonder een tweede implementatie achter een nieuw commando.
- Review packagegrenzen tegen het [pakketcontract](#pakketten-en-commandos): CLI, runtime-dependencies, configuratie, correcties, rapporten en gedragstests blijven bij hun onafhankelijke controle. Een gedeelde ontwikkelbundle rechtvaardigt geen afhankelijkheden tussen onafhankelijke tools of een runtimepakket voor repositorycontroles.
- Houd ontwikkeldependencies en orkestratie in root-Gemfile en Rakefile. Gebruik lokaal en in CI dezelfde Bundler-, Rake- en native CLI-routes; voeg geen tweede ontwikkelbundle binnen een toolgem toe.
- Werk bij verplaatsing consumerinstallatie, CI, rapporten en documentatie samen bij. Benoem gedeelde instellingen, taken en rapportlocaties neutraal en behoud toolspecifieke instellingen bij hun eigenaar.
- Verifieer het CLI- en rapportcontract met gedragstests: geslaagde en afgekeurde controles met en zonder rapport, herstel zonder rapport waar ondersteund, geen rapportwijziging zonder verzoek en behoud van foutstatus bij rapportagefouten. Controleer de geïnstalleerde CLI en wijzig bij een commandowijziging voorbeelden, CI en consumermigratie tegelijk.

### Toolteststructuur onderhouden

Volg bij toevoegen en verplaatsen de [centrale groeperingsconventie](../TESTS.md#testbestanden-groeperen), de [testlocaties en taken](#gezamenlijke-tooltests), de [repositorybrede testscope](../TESTS.md#testscope-en-plaatsing) en [scenarioselectie](../TESTS.md#scenarios-kiezen).

- Verplaats verkeerd geplaatste tests naar hun eigenaar; verbreed discovery niet en documenteer geen uitzondering alleen om de bestaande plaats te behouden.
- Gebruik fixtures en ondersteuning uitsluitend om een toolcontract te toetsen. Houd toolspecifieke helpers en fixtures bij hun tests; deel testhulp alleen als meerdere tools haar werkelijk nodig hebben.
- Werk bij structuurwijzigingen discovery, padresolutie, taken, CI en documentatie samen bij. Verwijder na migratie vervangen testmappen, dubbele bestanden, ongebruikte ondersteuningsdata, verouderde taken en verwijzingen.
- Behoud regressiedekking en rapporteer bewust verwijderde tests. Verifieer dat de verwachte tests daadwerkelijk worden ontdekt en uitgevoerd: succes zonder toepasselijke tests bewijst niets.

### CI en rapporten onderhouden

Pas de [CI- en rapportprocedures](#ci-van-deze-repository) toe bij tooling- of pipelinewijzigingen. Behoud de eenmalige secrets-gate en alle vijf fasegrenzen vóór vervolgdiagnostiek en de selecties, drempels, exitcodes en publicatiecontracten.

Beoordeel gewijzigde reporters en CI-aanroepen tegen het [joblogcontract](#joblogs). Inspecteer representatieve uitvoer voor een schone run, één bevinding tussen veel schone invoer, meerdere bevindingen binnen en over invoer, en onvolledige uitvoering met bevindingen en meerdere uitvoerfouten. Bewaar die gevallen in de gedragstests van de eigenaar en noteer de handmatige leesbaarheidsreview. Alleen gebruik van de gedeelde console bewijst geen naleving. Houd uitvoering en presentatie gescheiden en valideer betrokken tool- en repositoryintegratietests.

### Toolingdocumentatie onderhouden

Houd algemene codeprincipes bij CODE_RULES en verwijs daarnaar zonder herhaling. Publieke installatie, gebruik, configuratie, concrete architectuur, interfaces, exitcodes, rapporten, voorbeelden, ondersteunde integraties en onderhoud staan in de kleinste passende README. De gedeelde gids en de README's van shared, metadata, Ruby-lint, repositorycontroles, validator en dependencies bezitten hun eigen interfaces en procedures en dupliceren geen lintnormen. Volg voor de vier centrale lintdocumenten hun [onderhoudsafspraken en grenzen](lint/puppet/README.md#lintdocumentatie-onderhouden).

Houd toolspecifieke testinstructies in de eigen handleiding en maak geen losse test-README's. Controleer bij verplaatsing ook verpakte documentatielinks. Normaal gebruik moet begrijpelijk blijven vanuit de meegeleverde README en regelsdocumenten; aanvullende ontwikkeldocumentatie buiten de gem vereist de bijbehorende checkout. Wijzig geminhoud alleen wanneer een ondersteunde distributieroute dat vereist, met behoud van packagegrenzen en licenties.

## Gezamenlijke tooltests

Tests blijven bij hun eigenaar onder `.tools/<tool>/tests/`: `lint/puppet`, `lint/ruby`, `shared`, `syntax`, `catalog`, `dependencies`, `metadata`, `secrets` en `repository`. Generieke repository-testhulp staat in `.tools/shared/test_support/`, buiten de runtimegem. Lintfixtures, checks en verwachtingen blijven bij lint. De [testscope](../TESTS.md#testscope-en-plaatsing) beperkt deze tests tot gereedschap; een echte dependencycontrole van de checkout is een afzonderlijke taak.

**Werkmap:** Repositoryroot. **Shell:** POSIX shell. **Vereisten:** Ontwikkelbundle. **Invoer:** Eigen Puppet-manifesten voor de secrets-gate en synthetische toolcontracten. **Wijzigt bestanden:** Tijdelijke testinvoer; zonder rapportinstelling geen rapportbestanden. **Verwacht resultaat:** Niet-lege selectie zonder failures, errors of onverklaarde skips.

```sh
bundle exec rake test
bundle exec rake test:lint
bundle exec rake test:shared
bundle exec rake test:dependencies
bundle exec rake test:syntax
bundle exec rake test:catalog
bundle exec rake test:metadata
bundle exec rake test:ruby_lint
bundle exec rake test:repository
bundle exec rake test:secrets
```

De lokale standaardtaak voert eerst `rake secrets:puppet` uit volgens de [scannerhandleiding](secrets/README.md#puppet-manifesten-in-standaardtests-en-ci). Daarna voert `test` eenmaal `test:tools` uit; die taak ontdekt `.tools/**/tests/**/*_test.rb` recursief. `bundle exec rake` voert dezelfde selectie uit als `bundle exec rake test`; `test:tools` kiest dezelfde gehele suite zonder projectscan; de overige gerichte taken kiezen één eigenaar. Zonder `MINITEST_REPORTERS_REPORTS_DIR` geven al deze routes en rechtstreeks uitgevoerde testbestanden uitsluitend console-uitvoer. Bestaande rapportbestanden blijven ongewijzigd en er wordt geen rapportmap aangemaakt. De eenmalige bootstrap registreert autorun en de [testreporter](shared/README.md#testondersteuning) slechts één keer. Die toont afgeronde testgevallen, fouten en skips volgens het centrale logcontract; `TESTOPTS='--verbose'` behoudt de native detailuitvoer.

De automatische testselectie slaat `fixtures/`-mappen op ieder niveau over.

Vraag JUnit aan met een niet-leeg rapportpad, relatief aan de werkmap of absoluut. De CI-testjob gebruikt onderstaande instelling; je kunt die ook lokaal bij iedere testtaak meegeven:

**Werkmap:** Repositoryroot. **Shell:** POSIX shell. **Vereisten:** Ontwikkelbundle. **Invoer:** Alle tooltests. **Wijzigt bestanden:** Test-JUnit in de opgegeven map. **Verwacht resultaat:** Dezelfde teststatus met console-uitvoer en JUnit.

```sh
MINITEST_REPORTERS_REPORTS_DIR=.tools/results/tests bundle exec rake test:tools
```

De reporter maakt de opgegeven map aan en vervangt alleen `TEST-*.xml`; andere rapporten blijven staan. Testklassen hebben unieke namen, zodat bestanden niet worden overschreven. Een mislukte test houdt zijn foutstatus, met of zonder rapport. Een fout bij het schrijven van een gevraagd rapport geeft eveneens een foutstatus.

De shared-tests controleren paden, XML, laadbijwerkingen en de gedeelde testbootstrap. Repositorycontroles bewaken documentatienavigatie, CI, package-integratie en testindeling. Metadata- en Ruby-tests bewaken hun eigen CLI, correcties, rapporten en onafhankelijke installatie. De linkcontrole verifieert lokale doelen en ankers en meldt vaste repository-URL’s in Markdown volgens de [documentatieafspraken](lint/puppet/docs/DOCUMENTATION_RULES.md#markdown). Dependencytests controleren synthetische selectie, rootvoorwaarden, runtime-isolatie, presentatie, package-inhoud en afzonderlijke installatie. Catalogus-runnertests controleren compilatie, procesisolatie en rapportage met synthetische modules; de werkelijke moduletests blijven een aparte controle. Syntaxtests controleren native parseruitvoering, selectie, foutstatus, bronbehoud en afzonderlijke installatie. Linttests bewaren de bestaande lint-CLI-, autofix- en packagecontracten. Het [testonderhoud](#toolteststructuur-onderhouden) bewaakt plaatsing, discovery en dekking; de [lintgids](lint/puppet/README.md#tests-uitvoeren-en-uitbreiden) beschrijft zijn eigen testaanroepen.

### Versies bijwerken

Bij de eerste installatie gebruikt Bundler de versies uit de lockfile. Wil je die combinatie bijwerken, voer dan het volgende uit vanuit de hoofdmap van deze repository, met de nieuwste stabiele Ruby actief:

**Werkmap:** Repositoryroot. **Shell:** POSIX shell. **Vereisten:** Nieuwste stabiele Ruby en bewuste opdracht tot dependencyupdate. **Invoer:** Eigen Gemfile en bestaande lockfile. **Wijzigt bestanden:** Bundlerinstallatie, gems, Gemfile.lock en rapporten. **Verwacht resultaat:** Bijgewerkte combinatie gecontroleerd; diff van lockfile ter review.

```sh
export PROJECT_METADATA_MODULES_PATH=.
gem install bundler
BUNDLE_VERSION=system bundle update --all
bundle exec rake secrets:puppet
bundle exec puppet-lint --no-config --config .puppet-lint.rc .
bundle exec project-tools-metadata --junit .tools/metadata/results/metadata-report.xml
bundle exec rubocop --config .rubocop.yml
bundle exec rake test
```

[`bundle update --all`](https://bundler.io/man/bundle-update.1.html) kiest de nieuwste stabiele gems die onderling en met de ingestelde Ruby-versie passen. Gems kunnen zelf beperkingen aan hun afhankelijkheden stellen. Gebruik geen prereleases voor de gewone ontwikkelomgeving.

Controleer de gewijzigde lockfile en eventuele codeaanpassingen via de [veilige Git-inspectie](../CONTRIBUTING.md#git-inspectie) in de review. `bundle install` gebruikt daarna steeds die geteste combinatie.

Werk op macOS Ruby bij met `brew update` en `brew upgrade ruby`. Open daarna een nieuwe terminal, zodat ook het pad voor gemcommando's opnieuw wordt bepaald, en volg opnieuw [Gems installeren](#gems-installeren). Draai na een Ruby-update de volledige lintscan en testsuite.

### Eigen tooltests

Test eigen gereedschap onder `.tools/<tool-name>/tests/`, met bestandsnamen die eindigen op `_test.rb`. Zet gedeelde voorbereiding in `test_helper.rb` wanneer meerdere tests die nodig hebben en plaats grotere synthetische invoer volgens de [centrale fixtureconventie](../TESTS.md#fixtures-bij-de-tests-plaatsen) bij haar gebruikers. Gebruik korte invoer direct in de test en los paden op vanaf het testbestand, zodat de uitvoering niet afhangt van de huidige werkmap.

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

Rake::TestTask.new('test:tools') do |task|
  task.test_files = Rake::FileList['.tools/**/tests/**/*_test.rb'].exclude(%r{(?:\A|/)fixtures/})
  task.warning = false
end

task test: 'test:tools'
task default: :test
```

Voer vanuit de projectroot `bundle exec rake test:tools` uit in CI. Voor projecten met Puppet-code koppelt de [secrets-inrichting](secrets/README.md#koppel-de-puppet-controle-aan-eigen-taken) de lokale verzameltaak `test` eerst aan de projectscan en daarna aan `test:tools`. De gerichte taak heeft zelf geen secrets-prerequisite. Controleer het aantal uitgevoerde tests; een geslaagde taak met nul tests bewijst niets. Een aanvullende `test:<tool-name>`-taak selecteert alleen `.tools/<tool-name>/tests/**/*_test.rb`, met dezelfde uitsluiting van `fixtures/` op ieder niveau. Heeft het project al een verzameltaak voor andere tests, voeg de toolselectie dan als afzonderlijke taak toe en behoud de bestaande dekking en het standaardgedrag.

Laat de selectie alleen de eigen tools doorlopen. De tests onder `global-modules/.tools/**/tests/` horen bij de ontwikkeling van de gedeelde gem en draaien in de CI van die repository. Het afnemende project hoeft die suite niet te kopiëren of via zijn eigen Rakefile te laden. Wie alleen de linters gebruikt, heeft daarvoor geen eigen testmap of testtaak nodig.

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

$stdout.sync = true
reporters = [Minitest::Reporters::DefaultReporter.new]
if ENV['MINITEST_REPORTERS_REPORTS_DIR']
  reporters << Minitest::Reporters::JUnitReporter.new(ENV.fetch('MINITEST_REPORTERS_REPORTS_DIR'))
end
Minitest::Reporters.use!(reporters)
```

Laat de testbestanden deze helper laden met `require_relative 'test_helper'` en behoud de voorbereiding en assertions die de eigen tests nodig hebben. Eén uitvoering configureert de reporters eenmaal. Gebruikt de roottaak tests van meerdere eigen tools, laat hun helpers dezelfde reporterinitialisatie laden uit de gedeelde testhulp die dat project daarvoor gebruikt; herinitialiseer de reporters niet per tool.

`bundle exec rake test` toont zonder rapportinstelling alleen de testuitslag. Gebruik vanuit de consumerroot `MINITEST_REPORTERS_REPORTS_DIR="$PROJECT_REPORT_DIR" bundle exec rake test:tools` om daarnaast per testklasse een `TEST-*.xml`-bestand in de [gekozen rapportmap](#rapportmap-kiezen) te schrijven. Geef een niet-leeg relatief of absoluut pad op. De reporter maakt de map zo nodig aan en vervangt alleen die testbestanden, zodat een gerichte testselectie een beperkt rapport oplevert en de lint- en validatierapporten behouden blijven. De rapportmap hoeft niet naast de helper of in een map met de naam `lint` te staan.

`MINITEST_REPORTERS_REPORTS_DIR` geldt uitsluitend voor de tests en verandert de lint- en validatierapportpaden niet. Laat het testartifact en de testsamenvatting naar dezelfde expliciet gekozen map wijzen. `PROJECT_REPORT_DIR` alleen schakelt de testreporter niet in. Mislukte tests behouden hun foutcode; een JUnit-bestand maakt een mislukte uitvoering niet succesvol.

Gebruikt je project een ander testframework, behoud dan de eigen testtaak en gebruik de JUnit-reporter van dat framework. Pas het rapportpad in de [CI-configuratie](#controle-in-ci) daarop aan.
