# Puppet-moduledependencies controleren

`project-tools-module-dependencies` vergelijkt gedeclareerde module- en rootdependencies met één native OpenVox-moduleset. Het commando staat los van Puppet-lint en gebruikt `project-tools-shared` voor XML en modulepadvalidatie. Installeer het via de [gezamenlijke toolinghandleiding](../README.md#installatie-in-je-project); alleen dependencycontrole installeren vraagt geen linter, lintplugins of RuboCop.

Voor links buiten deze gem lees je de handleiding in de bijbehorende repositorycheckout.

## Inhoudsopgave

- [Inhoudsopgave](#inhoudsopgave)
- [Een controle uitvoeren](#een-controle-uitvoeren)
- [Native selectie en dekking](#native-selectie-en-dekking)
- [Rootdependencies](#rootdependencies)
- [Exitcodes en rapporten](#exitcodes-en-rapporten)
- [Runtime en veiligheidsgrenzen](#runtime-en-veiligheidsgrenzen)
- [Ontwikkelen en testen](#ontwikkelen-en-testen)

## Een controle uitvoeren

Het publieke commando is `project-tools-module-dependencies [--junit REPORT.xml]`. Zonder opties verschijnen uitslag en dekking alleen in de console; de tool maakt dan geen rapportbestanden of rapportmappen aan en werkt bestaande rapporten niet bij. De werkmap bepaalt de actieve rootmetadata; de geminstallatiemap en `global-modules` doen dat niet.

**Werkmap:** Repositoryroot. **Shell:** POSIX shell. **Vereisten:** Ontwikkelbundle en submodules. **Invoer:** Expliciete modulepath en rootmetadata. **Wijzigt bestanden:** Geen. **Verwacht resultaat:** Exit 0 bij passende dependencies, 1 bij conflicten en 2 bij een onvolledige controle.

```sh
export PROJECT_TOOLS_MODULEPATH="$PWD"
bundle exec project-tools-module-dependencies
```

Voeg voor CI of een bewaard resultaat `--junit REPORT.xml` toe met een relatief of absoluut pad dat eindigt op `.xml`. Alleen dan maakt de tool de bovenliggende rapportmap aan. Een afnemend project kiest zijn eigen rapportmap en modulepaden. `PROJECT_REPORT_DIR` is een shellafspraak; de tool leest uitsluitend het uitgewerkte argument.

**Werkmap:** Consumerroot met metadata.json. **Shell:** POSIX shell. **Vereisten:** Eigen bundle, global-modules en modules. **Invoer:** De lokale equivalent van één servermodulepath. **Wijzigt bestanden:** Het genoemde rapport. **Verwacht resultaat:** Dependencybeoordeling van de native geselecteerde modules en de consumerroot.

```sh
export PROJECT_REPORT_DIR=".tools/quality/results"
export PROJECT_TOOLS_MODULEPATH="$PWD/global-modules:$PWD/modules"
bundle exec project-tools-module-dependencies --junit "$PROJECT_REPORT_DIR/project-tools-module-dependencies-report.xml"
```

Gebruik voor verschillende environments afzonderlijke aanroepen met hun eigen modulepath. De [gedeelde instellingen](../README.md#gedeeld-modulepad) onderscheiden dit zoekpad van de eigen metadataselectie. De dependencytool vereist geen `VERSION`, `PROJECT_METADATA_MODULES_PATH` of `PROJECT_METADATA_PREFIX`.

## Native selectie en dekking

De adapter maakt één `Puppet::Node::Environment` met de expliciete, geordende paden. `environment.modules` kiest de eerste moduledirectory per naam. De tool zoekt nooit een hogere of beter passende versie in latere paden, hersorteert geen modulepaden en maakt geen tijdelijke symlinkselectie. Ook een eerste lege directory blijft de eerste. Een module van een andere Forge-eigenaar voldoet niet door een later passende kopie te kiezen. Legitieme Puppet-module-symlinks blijven bruikbaar; overschaduwde metadata worden niet opnieuw geparsed.

Alle effectieve modules met bruikbare metadata worden beoordeeld, inclusief externe dependencies. De tool gebruikt `Puppet::Module#unmet_dependencies` vóór native consolegroepering; twee aanvragers van dezelfde dependency blijven afzonderlijke relaties. Indirecte conflicten worden gevonden doordat iedere effectieve module wordt beoordeeld, zonder eigen resolver of recursieve graphwalker. Een ontbrekende moduledependencyrange behoudt de native standaard `>= 0.0.0`.

Directories zonder metadata, bijvoorbeeld `examples` en `vendor`, worden afzonderlijk vermeld als niet beoordeeld. Ze tellen niet als succesvolle metadata. Bestaande maar kapotte, lege, onleesbare of onbruikbare metadata geven een uitvoerfout. Een inventaris met native directoryherkenning controleert dat de runtime geen geselecteerde module heeft overgeslagen. Een scan zonder bruikbare modulemetadata geeft `empty_scan` en exitcode 2.

Een groene uitslag betekent dat de beoordeelde gedeclareerde dependencies passen bij de geselecteerde versies. Ze bewijst geen volledige dependencydeclaratie, werkende catalogus, functionele modulecompatibiliteit, gelijkheid van alle Ruby-pluginlaadpaden of ondersteuning van iedere Puppet-, OpenVox- of OS-versie.

## Rootdependencies

De tool leest uitsluitend `<werkmap>/metadata.json` als aanvullend rootcontract. Het bestand moet een JSON-object met een `dependencies`-array zijn. Iedere entry bevat een door Puppet erkende Forge-naam en een niet-lege string `version_requirement`. Naamgeving, platformclaims, overige metadata en synchronisatie met `VERSION` horen bij de [metadatatool](../metadata/README.md).

De Forge-schrijfwijzen `owner-module` en `owner/module` worden volgens de native betekenis genormaliseerd. `environment.module_by_forge_name` zoekt in dezelfde geselecteerde set. `SemanticPuppet::VersionRange` en `SemanticPuppet::Version` vergelijken de opgegeven range en geselecteerde versie. Een ontbrekende module, onverenigbare versie of niet-semantische range/versie levert een bevinding op. De rootcontrole maakt geen kunstmatige module en haalt geen registrygegevens op.

Het rootbestand van een ingeladen `global-modules` wordt geen tweede rootcontract. De individuele modules uit die checkout worden wel beoordeeld wanneer ze in de actieve modulepath staan.

## Exitcodes en rapporten

| Code | Betekenis |
| --- | --- |
| `0` | Controle uitgevoerd; geen onvoldane gedeclareerde dependencies gevonden. |
| `1` | Dependencybevindingen zonder uitvoerfouten. |
| `2` | Configuratie-, lees-, metadata-, runtime-, inventarisatie- of rapportagefout; geen betrouwbaar volledig oordeel. |

Uitvoerfouten hebben voorrang op bevindingen; reeds betrouwbare bevindingen blijven zichtbaar. `missing`, `version_mismatch` en `non_semantic_version` worden JUnit-`failure`-cases. De laatste reden kan zowel de voorwaarde als de geselecteerde versie betreffen. Uitvoerfouten krijgen `error`. Normale bevindingen gaan naar stdout, uitvoerdiagnoses naar stderr, zonder stacktrace of metadata-dump.

Console en JUnit gebruiken dezelfde deterministisch gesorteerde resultaten. De suite heet `project-tools-module-dependencies`. Een testcase benoemt scope, aanvrager, dependency, requirement en geselecteerde versie. De tekst bevat reden en bronpaden, relatief aan de actieve projectroot; paden buiten de root blijven via `../` herleidbaar. Er worden geen JSON-regelnummers verzonnen. Een schone scan krijgt één geslaagde testcase, met dekking in `system-out`. Tellingen beschrijven testcases, niet modules of dependencydiepte.

Een representatieve failure luidt:

```text
Puppet module dependencies: FAILED

  module: saz/timezone 7.0.0 -> stm/debconf; requires >= 2.0.0 < 7.0.0; selected 8.0.0
  version_mismatch: The selected version does not satisfy the declared requirement.
  Request metadata: timezone/metadata.json
  Selected metadata: debconf/metadata.json
```

Die relatie wordt een `<testcase>` met `<failure type="version_mismatch">`; een rootbevinding begint met `root:`. XML-escaping gebeurt via Builder. Terminalcontroltekens worden afgevlakt en onbetrouwbare velden worden ingesprongen, zodat ze geen GitHub-workflowcommando vormen.

Met `--junit` wordt het expliciete rapport vóór de scan vervangen door een `incomplete_scan`-error. Na de scan vervangt het definitieve rapport die voorlopige status. Daardoor blijft een oud groen rapport niet staan na een nieuwe invoer- of runtimefout. Een argumentfout krijgt ook een errorrapport als daarvoor al een geldig `--junit`-pad is verwerkt; zonder bekend rapportpad wordt geen rapport geschreven. Alleen het gekozen rapport wordt geschreven. Een onschrijfbare bestemming of crash vóór het laden van de reporter kan XML onmogelijk maken; de tool claimt dan geen geschreven rapport. Zonder `--junit` vervallen alleen deze schrijfhandelingen: bevindingen en scanstatus blijven gelijk. Een gevraagd maar onschrijfbaar rapport geeft exitcode 2. De bestaande lint- en parserreporters behouden hun eigen levenscyclus en exitstatus.

De [CI-handleiding](../README.md#ci-van-deze-repository) beheert rapportlocaties, artifactnamen en GitHub/GitLab-presentatie. Een dependencyconflict maakt de zelfstandige job rood terwijl upload en summary doorgaan.

## Runtime en veiligheidsgrenzen

De adapter gebruikt de actieve OpenVox-bundle, neutraliseert tijdelijk `PUPPETLIB` en construeert de environment rechtstreeks. `require 'puppet'` levert de runtime-defaults; de adapter roept geen applicatie-initialisatie aan die persoonlijke configuratie, extra load paths of facts inleest. Tijdelijke ENV-, strict- en loginstellingen worden hersteld na in-process gebruik. Native parserlogs kunnen invoerfragmenten bevatten; de tool vervangt ze door gerichte, gestructureerde fouten.

De controle installeert of wijzigt geen modules, metadata, gitlinks, lockfiles of hostconfiguratie. Er is geen catalogus, facts-uitvoering, pluginsync, Puppet Server of verbinding met beheerde hosts nodig. Het laden van de vertrouwde Ruby-runtime is geen sandbox voor willekeurige externe code. De [gemspec](project-tools-module-dependencies.gemspec) begrenst de OpenVox- en JSON-versies; de [lockfile](../../Gemfile.lock) legt de ontwikkelbundle vast.

## Ontwikkelen en testen

Voer vanuit de repositoryroot `bundle exec rake test:module_dependencies` uit voor de synthetische toolcontracten. De tests behandelen eerste-modulekeuze, omgekeerde paden, ontbrekende en onbruikbare metadata, Forge-identiteit, symlinks, externe aanvragers, native ranges, rootinvoer, persoonlijke instellingen, rapportvervanging, escaping en foutstatussen. Native CLI-vergelijkingen gebruiken `RbConfig.ruby` en `Gem.bin_path('openvox', 'puppet')` met afzonderlijke stdout, stderr en processtatus.

Distributietests installeren shared en de dependencygem in een eigen consumerbundle zonder lintgem, lintplugins, RuboCop of ontwikkelgems. Ze controleren ook pathbronnen en de gezamenlijke Git-bronroute. De Git-test gebruikt vóór een menselijke commit een local override; de [gedocumenteerde beperking](../README.md#git-dependency-uit-de-monorepo) blijft zichtbaar. Sluit af met alle [gezamenlijke controles](../README.md#gezamenlijke-tooltests). Een echt repositoryconflict hoort bij de afzonderlijke dependencyjob, nooit als bewust falende tooltest.
