# Projectmetadata controleren

`project-tools-metadata` controleert root- en modulemetadata en synchroniseert bekende velden met `--fix`. Het pakket gebruikt JSON (`>= 2.21, < 4`) en `project-tools-shared` voor rapportage en installeert geen Puppet of RuboCop. Gebruik de [gezamenlijke installatiehandleiding](../README.md#importeren-en-distribueren) voor de gekozen gembron.

Voor links buiten deze gem lees je de handleiding in de bijbehorende repositorycheckout.

## Inhoudsopgave

- [Inhoudsopgave](#inhoudsopgave)
- [Gebruik in een ander project](#gebruik-in-een-ander-project)
- [Exitcodes en tests](#exitcodes-en-tests)
- [Modulemetadata controleren](#modulemetadata-controleren)
- [Metadata in modulemappen](#metadata-in-modulemappen)
- [Metadata in de projectroot](#metadata-in-de-projectroot)
- [Versiebron en rapportage](#versiebron-en-rapportage)
- [Metadata automatisch herstellen](#metadata-automatisch-herstellen)
- [Aanvullende validatie](#aanvullende-validatie)

## Gebruik in een ander project

Voeg `project-tools-metadata` en shared toe aan je eigen bundle volgens de [installatievoorbeelden](../README.md#installatie-in-je-project). Maak de hieronder beschreven eigen `VERSION` en rootmetadata. Kies de map met eigen modules; geef ook zonder modules een bestaande, lege map op. Stel bij eigen modules bovendien de eigenaar in met letters en cijfers.

**Werkmap:** Consumerroot. **Shell:** POSIX shell. **Vereisten:** Eigen bundle, VERSION, rootmetadata en bestaande modules-map. **Invoer:** Eigen root- en modulemetadata. **Wijzigt bestanden:** Geen. **Verwacht resultaat:** Bevindingen in de console; exitcode 0 bij geldige metadata.

```sh
export PROJECT_METADATA_MODULES_PATH=modules
export PROJECT_METADATA_PREFIX=example
bundle exec project-tools-metadata
```

Gebruik in deze repository `PROJECT_METADATA_MODULES_PATH=.`; de eigenaar ligt hier vast. De tool leest geen lintconfiguratie. Geef benodigde uitsluitingen rechtstreeks mee, bijvoorbeeld `--ignore-paths='modules/external/*'`. Herhaalde `--ignore-paths` vervangt de eerdere lijst. Manifestpaden en losse rapportpaden zijn geen CLI-argumenten.

Zonder `--junit` verschijnt de uitslag alleen in de console en worden geen rapportbestanden of rapportmappen aangemaakt of bijgewerkt. Voeg voor CI of een bewaard resultaat `--junit .tools/quality/results/metadata-report.xml` toe. Dat pad is relatief aan de werkmap of absoluut; alleen dan maakt de tool de bovenliggende rapportmap aan. Dezelfde optie werkt samen met `--fix`.

| Instelling | Contract |
| --- | --- |
| `PROJECT_METADATA_MODULES_PATH` | Verplicht niet-leeg relatief pad naar een bestaande map met eigen modulemappen; geen standaardwaarde. |
| `PROJECT_METADATA_PREFIX` | Verplichte eigenaar bij geselecteerde consumermodules, uitsluitend letters/cijfers; geen consumerdefault. |
| `--fix` | Standaard uit; synchroniseert uitsluitend de hieronder beschreven bekende velden. |
| `--ignore-paths GLOBS` | Standaard leeg; kommagescheiden patronen voor metadatapaden relatief aan de projectroot. |
| `--junit REPORT.xml` | Optioneel niet-leeg rapportpad; dezelfde bevindingen ook als JUnit opslaan. |

## Exitcodes en tests

Exitcode 0 betekent dat geen metadataproblemen overblijven, ook na correcties. Exitcode 1 betekent onvolledige of ongeldige metadata, een ongeldige versiebron of moduleconfiguratie. Deze uitslag is gelijk met en zonder rapport. Exitcode 2 betekent ongeldige CLI-argumenten of een uitvoerings- of schrijffout; daarbij is mogelijk geen rapport beschikbaar. Een gevraagd maar onschrijfbaar rapport blijft dus een fout. CI gebruikt `--junit` zonder `--fix` in een eigen job en publiceert het rapport volgens de [rapportafspraken](../README.md#rapporten-en-artifacts-in-je-project).

Voer vanuit de repositoryroot `bundle exec rake test:metadata` uit voor de eigen synthetische CLI-, herstel-, rapportage- en pakkettests. `bundle exec rake test` controleert alle tools. De tests bewaken ook dat een geïnstalleerde metadatagem geen Puppet-lint, OpenVox of RuboCop nodig heeft.

## Modulemetadata controleren

Start `project-tools-metadata` vanuit de root van het project dat je controleert. De werkmap bepaalt `metadata.json`, `VERSION` en de basis voor de eigen modulelocatie. De installatiemap van de gem en `PROJECT_TOOLS_MODULEPATH` bepalen die projectroot niet. Puppet-lint voert deze controle niet uit.

De rootcontrole is verplicht in beide projectindelingen, ook zonder eigen modules of manifests. De modulecontrole beoordeelt daarnaast iedere eigen module één keer, ook als de module geen manifests bevat.

## Metadata in modulemappen

Stel `PROJECT_METADATA_MODULES_PATH` expliciet in op de map die de eigen modulemappen bevat. Het pad is relatief aan de projectroot van waaruit je metadata controleert. De instelling heeft geen standaardwaarde: een ontbrekende of lege waarde, een absoluut pad, een niet-bestaand pad of een gewoon bestand geeft een configuratiefout. Ook zonder eigen modules geef je een bestaande, lege modulemap op. De check kiest nooit zelf `modules/`, de projectroot of een map uit `PROJECT_TOOLS_MODULEPATH`.

| Expliciete waarde | Gecontroleerde modulemappen |
| --- | --- |
| `modules` | Direct onder `<projectroot>/modules/`. |
| `site-modules` | Direct onder `<projectroot>/site-modules/`. |
| `.` | Direct onder de projectroot; deze repository gebruikt deze instelling. |

Leg de waarde vast in je metadata-aanroep of shellomgeving en in de metadatajob van je eigen CI. De [consumer-aanroep](#gebruik-in-een-ander-project) laat dat zien. `PROJECT_METADATA_MODULES_PATH` selecteert metadata van eigen modules; `PROJECT_TOOLS_MODULEPATH` blijft de afzonderlijke zoeklijst voor declaraties uit eigen modules en dependencies. Geen van beide bepaalt de locatie van het rootbestand: dat blijft `<projectroot>/metadata.json` en wordt ook gecontroleerd wanneer de modulelocatie ongeldig is.

De aanwezigheid van `.tools/metadata/project-tools-metadata.gemspec` in de projectroot bepaalt de bestaande naamgeving en repository-uitsluitingen, niet de modulelocatie:

| Project | Verwachte `name` van een module |
| --- | --- |
| Deze repository, ook wanneer de checkout `global-modules` heet | `puppetmodules-{mapnaam}` |
| Een inladend project | `{PROJECT_METADATA_PREFIX}-{mapnaam}` |

De check selecteert uitsluitend directe modulemappen onder het ingestelde pad. Verborgen mappen en directorysymlinks worden overgeslagen; een symlink maakt een dependency dus geen eigen module. In deze repository vallen ook `examples`, `vendor`, `concat`, `debconf`, `reboot` en `stdlib` buiten de metadatacontrole. De eigen `--ignore-paths`-patronen van dit commando gelden voor het metadatapad relatief aan de projectroot, bijvoorbeeld `site-modules/dependency/metadata.json`. Sluit daarmee dependencies en mappen zonder eigen modules uit. Bij `.` in een inladend project vallen bijvoorbeeld `global-modules/` en een losse `manifests/`-map onder die eigen uitsluitingen. De selectie hangt niet af van aanwezige `.pp`-bestanden of metadata; submappen binnen een module worden niet als afzonderlijke modules geselecteerd. Een eigen `VERSION`, `.git` of `.tools/metadata/project-tools-metadata.gemspec` markeert een afzonderlijk project: zulke modulemappen worden overgeslagen. Wijst de ingestelde modulelocatie binnen een ander project, dan volgt een configuratiefout. Controleer dat project vanuit zijn eigen root.

Iedere geselecteerde module bevat een leesbaar `metadata.json` met een JSON-object. Naast naam en versie vereist de controle niet-lege strings voor `author`, `summary`, `license` en `source`, en een `dependencies`-array waarvan ieder object een niet-lege `name` en `version_requirement` bevat. Daarmee blijft een automatisch aangemaakt basisbestand zichtbaar onvolledig totdat de verplichte inhoud is ingevuld. De eigenschappen `name` en `version` zijn strings met exact de verwachte waarden. De naam volgt de mapnaam en de hierboven aangegeven eigenaar. Leg bij een inladend project de eigen eigenaar vast via `PROJECT_METADATA_PREFIX`, met alleen letters en cijfers, en gebruik diezelfde instelling lokaal en in CI. Een ontbrekende of ongeldige instelling geeft een fout; de check neemt nooit automatisch `puppetmodules` over voor eigen modules van een inladend project.

**Fragment:** Met `PROJECT_METADATA_MODULES_PATH=modules` zijn voor de module `modules/profile/` in een synthetisch project met `7.4.0` in `VERSION` en `PROJECT_METADATA_PREFIX=example` de verwachte eigenschappen:

```json
{
  "name": "example-profile",
  "version": "7.4.0"
}
```

Dit fragment toont alleen de afleidbare identiteit en versie; het is nog geen volledige modulemetadata. Vul de overige verplichte metadata per module in. Beoordeel of omschrijving en bronverwijzingen bij de module passen, of dependencies volledig zijn en met hun versiegrenzen aansluiten op de gebruikte interfaces, en of de opgegeven besturingssystemen en Puppet-versies door implementatie en validatie worden ondersteund. Neem die waarden niet blind over uit een andere module. De aanvullende [schema-validatie](#aanvullende-validatie) vervangt deze inhoudelijke beoordeling niet.

## Metadata in de projectroot

Maak `metadata.json` direct in de eigen projectroot. Dit bestand beschrijft het hoofdproject: gebruik de projectnaam, projectomschrijving en verwijzingen naar de projectrepository. Voor deze repository is de naam `puppet-modules`; de naam van de checkout mag anders zijn. Voor een inladend project leg je de eigen projectnaam vast. De moduleprefix wordt niet op de projectnaam toegepast en de check leidt die naam niet af uit een directorynaam of uit de gedeelde tooling.

De rootcontrole vereist de volgende volledige structuur:

| Eigenschappen | Vereiste structuur |
| --- | --- |
| `name`, `version`, `author`, `summary`, `license`, `source`, `project_page`, `issues_url` | Niet-lege strings. De versie volgt de hieronder beschreven projectversiebron. |
| `dependencies`, `requirements` | Arrays met objecten die ieder niet-lege strings `name` en `version_requirement` bevatten. |
| `operatingsystem_support` | Array met objecten die ieder een niet-lege string `operatingsystem` en een array `operatingsystemrelease` met niet-lege strings bevatten. |
| `tags` | Array met niet-lege strings. |

Een array mag leeg zijn als het project voor die eigenschap geen waarden heeft. De check meldt ontbrekende velden en onjuiste typen met de eigenschapsnaam, ook binnen arrays, bijvoorbeeld `dependencies[0].version_requirement`. De projectvelden `project_page`, `issues_url`, `operatingsystem_support`, `requirements` en `tags` zijn verplicht in het rootbestand. Voor modules geldt de hierboven beschreven basisstructuur.

**Volledig JSON-voorbeeld:** Rootmetadata voor een synthetisch project met `7.4.0` in het eigen `VERSION`-bestand. Pas alle waarden aan het betreffende project aan, inclusief de versie, dependencies en platformen. Kopieer hiervoor niet de metadata van `global-modules` of een losse module.

```json
{
  "name": "example-control",
  "version": "7.4.0",
  "author": "Synthetic maintainers",
  "summary": "Synthetic infrastructure project",
  "license": "Apache-2.0",
  "source": "https://example.org/control",
  "project_page": "https://example.org/control",
  "issues_url": "https://example.org/control/issues",
  "dependencies": [],
  "operatingsystem_support": [
    {
      "operatingsystem": "Debian",
      "operatingsystemrelease": ["12"]
    }
  ],
  "requirements": [
    {
      "name": "puppet",
      "version_requirement": ">= 8.0.0 < 9.0.0"
    }
  ],
  "tags": ["infrastructure"]
}
```

Voor een inladend project is de inrichting concreet: maak dit bestand in de eigen projectroot, neem de versie over uit het eigen `VERSION`-bestand en voer de [metadata-aanroep](#gebruik-in-een-ander-project) vanuit diezelfde root uit. De modulelocatie is verplicht; de naamprefix blijft alleen nodig als die locatie eigen modules bevat. Deze route werkt met een path-dependency naar `global-modules/.tools/metadata` en met een geïnstalleerd gempakket; er is geen aanvullende rootoptie of gekopieerde check nodig. Een ontbrekend eigen rootbestand is een fout, ook wanneer naast de gedeelde tooling geldige metadata staan.

Beoordeel de inhoud naast de automatische structuurcontrole. Naam, omschrijving en repositoryverwijzingen moeten het hoofdproject beschrijven; afhankelijkheden en platformclaims moeten overeenkomen met de daadwerkelijke samenstelling en beschikbare validatie. De [rootmetadata van deze repository](../../metadata.json) en de [ondersteuning en bekende beperkingen](../../README.md#ondersteuning-en-compatibiliteit) horen bij elkaar. Een geslaagde structuurcontrole bewijst geen compatibele dependencycombinatie of werkende uitrol.

## Versiebron en rapportage

Kies de releaseversie volgens het [versie- en releasebeleid](../../AGENTS.md#versioning-and-releases). De metadatatool controleert of metadata die gekozen versie volgen. Hij beoordeelt de compatibiliteitsimpact niet en verhoogt de versie niet zelfstandig.

De check leest de projectversie uitsluitend uit `<projectroot>/VERSION`. Het bestand bevat `MAJOR.MINOR.PATCH`: drie gehele getallen zonder voorloopnullen, bijvoorbeeld `2.0.0`. Een afsluitend regeleinde is toegestaan; een `v`-prefix, prerelease, buildmetadata, spaties of extra regels zijn ongeldig. De validator ondersteunt daarmee alleen de normale SemVer-versienummers, zonder de optionele prerelease- en buildtoevoegingen. De [VERSION van deze repository](../../VERSION) bepaalt de versie van het hoofdproject en de eigen modules; de Ruby-gems behouden hun afzonderlijke pakketversies.

Een ontbrekend, onleesbaar, leeg of ongeldig `VERSION`-bestand levert één bronfout bij `VERSION` op. De check gebruikt geen Git-tags, branches, commits of metadata als terugval. Hij werkt ook in een gewone projectmap zonder `.git` en zonder beschikbaar `git`-commando. Git blijft alleen nodig voor afzonderlijke handelingen die Git gebruiken, zoals een checkout of Git-installatie van de gem. Ook een project zonder eigen modules heeft een eigen `VERSION` nodig.

Een inladend project gebruikt uitsluitend zijn eigen `<projectroot>/VERSION`. Bij `3.1.0` in dat bestand volgen zijn rootmetadata en eigen modules versie `3.1.0`. Heeft `global-modules/VERSION` waarde `2.0.0`, dan blijven de metadata van dat gedeelde project bij `2.0.0`. Houd dependencies buiten de ingestelde eigen modulemap of sluit ze expliciet uit. `PROJECT_TOOLS_MODULEPATH` selecteert hun metadata niet. Om het gedeelde project zelf te controleren, voer je de metadata-aanroep vanuit die projectroot uit met zijn eigen modulelocatie.

Synchroniseer de gekozen projectversie volgens het [versiebeleid](../../AGENTS.md#version-updates-and-release-preparation) als volgt:

1. Wijzig uitsluitend het eigen `VERSION`-bestand naar de gekozen projectversie.
2. Gebruik de hieronder beschreven `--fix`-aanroep om die waarde over te nemen in het veld `version` van `<projectroot>/metadata.json` en iedere geselecteerde eigen module onder `PROJECT_METADATA_MODULES_PATH`. Behoud alle andere metadatavelden en de bestanden van ingeladen dependencies. Gebruik ook bij nieuwe metadata altijd de waarde uit `VERSION`.
3. Voer de normale volledige metadatascan uit en beoordeel de diff. Een afwijking noemt het metadatapad, de aangetroffen versie en de verwachte versie uit `VERSION`.

De richting is `VERSION` → `metadata.json`. Zonder `--fix` controleert de metadatatool uitsluitend. Met `--fix` synchroniseert hij de geselecteerde metadata volgens [Metadata automatisch herstellen](#metadata-automatisch-herstellen). `VERSION` blijft in beide gevallen ongewijzigd; pas het niet aan om een bestaande moduleversie over te nemen.

Resterende metadataproblemen hebben severity `error` en geven exitcode 1. Uitgevoerde correcties krijgen `fixed` en veroorzaken zelf geen foutstatus. Ontbrekende of onleesbare metadata, ongeldige JSON en een JSON-waarde die geen object is geven één melding per bestand. Naam en versie krijgen ieder hun eigen melding wanneer beide afwijken. Een onjuist rootveld krijgt één melding voor die eigenschap; een ontbrekende `version` geeft dus geen tweede melding over dezelfde waarde. Bij een leesbare versiebron ziet een versieverschil er bijvoorbeeld zo uit:

```text
site-modules/profile/metadata.json:1:1: project_metadata: error: version: expected 3.1.0 from VERSION; found "2.0.0"
```

De melding toont alleen de aangetroffen waarde van `version`, geen overige metadata of parserfragmenten. Een ontbrekende waarde wordt als `nil` weergegeven. Configuratiefouten bij `configuration` noemen de betreffende omgevingsvariabele. De meldingen gebruiken regel en kolom 1 omdat dit bestandscontroles zijn. Bij een ongeldige versiebron blijven aanwezigheid, JSON, naamgeving en de overige veldcontroles actief.

De console en het eigen JUnit-rapport verwerken dezelfde bevindingen. Het rapport bevat één testcase per geselecteerd metadatabestand of bronfout, ook voor schone bestanden. Openstaande fouten zijn failures; correcties staan in `system-out`. Een geslaagd metadatarapport bewijst geen geldige manifests of compatibele dependencies.

De [metadataregressietests](tests) controleren beide indelingen, root- en modulemetadata, projecten zonder modules, modules zonder manifests, expliciete modulelocaties en configuratiefouten, veldstructuur, foutmeldingen, uitsluitingen, onafhankelijke VERSION-bestanden, uitvoering zonder Git, naamgeving, daadwerkelijk herstel en behoud bij `--fix`, gedeeltelijke fixes, idempotentie en zelfstandige rapportage. De pakkettest voert de controle uit vanuit een onafhankelijk geïnstalleerde gem.

## Metadata automatisch herstellen

Gebruik `project-tools-metadata --fix` om metadata te herstellen. De selectie omvat de projectroot en eigen modules onder `PROJECT_METADATA_MODULES_PATH`, met de beschreven uitsluitingen en projectgrenzen. Alleen dit commando wijzigt metadata; `puppet-lint --fix` corrigeert uitsluitend zijn eigen invoer.

**Werkmap:** Repositoryroot. **Shell:** POSIX shell. **Vereisten:** Ontwikkelbundle en een bewust gekozen versie in VERSION. **Invoer:** Rootmetadata en eigen modules onder het expliciete modulepad. **Wijzigt bestanden:** metadata.json waar veilig herstel mogelijk is. **Verwacht resultaat:** Versieverschillen opgelost; ontbrekende inhoud blijft als fout zichtbaar.

```sh
export PROJECT_METADATA_MODULES_PATH=.
bundle exec project-tools-metadata --fix
bundle exec project-tools-metadata
git diff
```

In een ander project voeg je `--fix` toe aan de [metadata-aanroep](#gebruik-in-een-ander-project), vanuit de eigen projectroot en met de eigen modulelocatie en naamprefix. De optie `--fix` is expliciet; het commando leest geen `.puppet-lint.rc` of persoonlijke lintopties.

| Situatie | Herstel met `--fix` | Wat je zelf moet doen |
| --- | --- | --- |
| Geldig JSON-object, ontbrekende of afwijkende `version` | Alleen de betreffende waarde vervangen of het ontbrekende veld invoegen uit de eigen VERSION | Overige inhoud beoordelen; bestaande velden, onbekende velden, witruimte en regeleinden blijven behouden |
| Ontbrekende metadata, naam en/of versie bekend | Een geldig JSON-object met uitsluitend die bekende velden aanmaken | De gerapporteerde ontbrekende velden inhoudelijk invullen; de foutstatus blijft staan |
| Ontbrekende modulemetadata | Naam afleiden uit de expliciete eigenaar en modulemap; versie uit de eigen VERSION | Geen licentie, omschrijving, bron, dependencies of platformclaims overnemen zonder bewijs |
| Ontbrekende rootmetadata | In deze repository de vastgelegde projectnaam opnemen; in een consumer alleen de bekende versie | Zelf de projectnaam en overige inhoud bepalen; mapnaam en moduleprefix bepalen geen rootnaam |
| VERSION ontbreekt of is ongeldig | Geen versiesynchronisatie; onafhankelijk bekende module-identiteit mag wel worden aangemaakt | De bronfout bij VERSION oplossen; metadata en Git leveren geen terugvalversie |
| Moduleprefix ontbreekt | Bekende versies blijven herstelbaar; geen modulenaam verzinnen | PROJECT_METADATA_PREFIX instellen en de ontbrekende naam invullen |
| Ontbrekend naamveld met bekende projectidentiteit | De vastgelegde rootnaam of geconfigureerde modulenaam invullen | De overige ontbrekende inhoud aanvullen |
| Bestaande afwijkende naam | Naam behouden | Een naamswijziging kan externe afhankelijkheden breken; beoordeel eerst de publieke identiteit |
| Ongeldige JSON, dubbelzinnige dubbele sleutels, niet-object of onleesbaar bestand | Niet overschrijven | Het bestaande bestand onderzoeken en herstellen |
| Symbolische link of schrijffout | Geen schrijfhandeling via de link; fout blijft zichtbaar | Een eigen regulier bestand en passende schrijfrechten verzorgen |
| Geen bekende velden of onbetrouwbare modulelocatie | Geen leeg basisobject of gegokte bestemming aanmaken | De concreet genoemde versiebron, eigenaar of modulelocatie instellen |

Een onbekende dependencylijst wordt niet vertaald naar `[]`. Ontbrekende inhoud blijft bij de hercontrole een fout, ook na een gedeeltelijke correctie en in een volgende run. De fixrun controleert de herstelde metadata opnieuw op veldniveau; opgeloste versie- en bestandsmeldingen verdwijnen uit de actieve fouten. Een tweede `--fix` schrijft niets zolang geen nieuwe informatie of wijziging is aangeleverd. De [CLI-regressies](tests/metadata_autofix_test.rb) en de [pakkettest](tests/external_metadata_test.rb) controleren deze route buiten de repository met synthetische projecten.

## Aanvullende validatie

Controleer bij gewijzigde modulemetadata daarnaast het uitgebreidere Puppet-metadataschema. `metadata-json-lint` is een aanvullende ontwikkeldependency in de rootbundle; de metadatatool installeert deze niet voor afnemers.

**Werkmap:** Repositoryroot. **Shell:** POSIX shell. **Vereisten:** Ontwikkelbundle. **Invoer:** De gewijzigde modulemetadata. **Wijzigt bestanden:** Geen bronbestanden. **Verwacht resultaat:** Exitcode 0 bij geldige modulemetadata.

```sh
bundle exec metadata-json-lint basic_settings/metadata.json
```
