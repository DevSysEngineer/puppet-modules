# Testbeleid en validatie

Dit document bepaalt welke controles bij een wijziging verplicht zijn, welke scenario's je kiest en welk bewijs je vastlegt. Het geldt voor moduleontwikkelaars en toolingmaintainers. De [ontwikkelwerkwijze](CONTRIBUTING.md) regelt voorbereiding, scope en oplevering; de regelsdocumenten houden iedere inhoudelijke norm bij haar eigen handmatige beoordelingscriteria. Concrete commando's, opties en rapportinstellingen staan in de gekoppelde toolinghandleidingen.

## Inhoudsopgave

- [Inhoudsopgave](#inhoudsopgave)
- [Soorten bewijs](#soorten-bewijs)
- [Controlevolgorde en verplichte eindcontroles](#controlevolgorde-en-verplichte-eindcontroles)
- [Testscope en plaatsing](#testscope-en-plaatsing)
- [Scenario's kiezen](#scenarios-kiezen)
- [Onderwerpgebonden validatie](#onderwerpgebonden-validatie)
  - [Interfaces, dependencies en gegenereerde inhoud](#interfaces-dependencies-en-gegenereerde-inhoud)
  - [Shellvalidatie](#shellvalidatie)
  - [Monitoringvalidatie](#monitoringvalidatie)
  - [Documentatievalidatie](#documentatievalidatie)
- [Isolatie en bewijsvoering](#isolatie-en-bewijsvoering)

## Soorten bewijs

| Controle | Wat zij vaststelt | Grens |
| --- | --- | --- |
| Linting | Statische codeafspraken en detecteerbare afwijkingen; Puppet-lint en RuboCop hebben eigen selecties en commando's. | Geen bewijs van functioneel gedrag, volledige documentatie of veilige uitrol. |
| Syntaxvalidatie | Of de native parser of bedoelde interpreter de geselecteerde invoer accepteert. | Geen catalogustoepassing of bewezen dependencies en runtimewerking. |
| Cataloguscompilatie | Of vaste classcombinaties met synthetische facts en de echte moduleset compileren. | Geen catalogustoepassing of bewijs van alle configuraties en runtimegedrag. |
| Tooltests | Gedrag, regressies en interfaces van eigen gereedschap met synthetische invoer. | Geen algemene module-, catalogus-, template-, script- of monitoringgedragstests. |
| Functionele validatie | Gedrag van de geraakte implementatie en haar werkelijke aanroepers met bestaande validators en geïsoleerde tijdelijke controles. | Alleen bewijs voor de uitgevoerde scenario's en omstandigheden. |
| Handmatige review | Normnaleving, verantwoordelijkheden, veiligheidsbesluiten, betekenis en samenhang die automatische controles niet volledig vaststellen. | Een groene scan vervangt deze review niet. |

Metadata-, secrets- en dependencycontroles hebben ieder hun eigen selectie en resultaat. Een geslaagde metadata- of dependencycontrole bewijst evenmin een werkende uitrol. Gebruik vendored submoduletooling nooit als validatie van eigen modules.

## Controlevolgorde en verplichte eindcontroles

Richt ontwikkeling en CI in met de [gedocumenteerde bundle](.tools/README.md#installatie). Pas vóór lezen en delen de [lokale inspectie](CONTRIBUTING.md#lokale-inspectie-vóór-inzage) toe; die algemene voorcontrole is niet dezelfde controle als de Puppet-gate hieronder.

1. Voltooi de verplichte [Puppet-secretscontrole](.tools/secrets/README.md#puppet-manifesten-in-standaardtests-en-ci) voordat andere controles manifestinformatie in diagnostiek mogen tonen. Pas de [credentialnorm](.tools/lint/docs/OPERATIONAL_RULES.md#geheimen-buiten-puppet-manifesten-beheren) toe. Een geweigerde scan blokkeert zulke vervolgdiagnostiek.
2. Bepaal bestaande lintbevindingen vóór wijzigen en volg de [correctiewerkwijze](.tools/lint/README.md#werkwijze-bij-een-wijziging): beginscan, veilige afgebakende correctie, hercontrole en resterend handmatig herstel. Inspecteer configuratie en relevante checkimplementaties wanneer je dekking vaststelt of een bevinding oplost.
3. Voer tijdens ontwikkeling de gerichte controles en functionele scenario's uit. Scan gewijzigde invoer opnieuw vóór openbaarmaking. Gerichte taken vervangen de verplichte volledige eindselecties niet.
4. Voer na alle correcties de eindcontroles in onderstaande tabel uit, inclusief alle tooltests en toepasselijke CI-controles. Beoordeel elke status afzonderlijk en review de uiteindelijke diff volgens de Git-inspectievoorwaarden.

`bundle exec rake test` is niet de volledige eindcontrole. De [root-Rakefile](Rakefile) koppelt de standaardtesttaak aan de Puppet-secretsvoorcontrole en selecteert vervolgens recursief alle `.tools/*/tests/**/*_test.rb`. De standaardtaak `bundle exec rake` kiest dezelfde route. De gerichte `test:<component>`-taken selecteren hun eigen suite; zij verzorgen die voorcontrole niet zelf. Metadata, volledige linting, RuboCop, de werkelijke dependencycontrole en repositorybrede parservalidatie en de vaste catalogusmatrix blijven afzonderlijke controles. De taak `catalog:compile` compileert de vaste scenario’s uit [catalog](.tools/catalog/README.md) na de Puppet-secretsgate. De taak `syntax:puppet` selecteert eigen manifests en gebruikt native parservalidatie; zij schrijft uitsluitend op expliciet verzoek JUnit. Zie [gezamenlijke tooltests](.tools/README.md#gezamenlijke-tooltests), [CI-volgorde](.tools/README.md#ci-van-deze-repository) en [parseruitvoering](.tools/syntax/README.md#puppet-manifests-valideren).

| Type wijziging | Verplichte controle | Voorwaarden en selectie | Uitvoerinstructie |
| --- | --- | --- | --- |
| Iedere afgeronde wijziging, ook alleen documentatie | Puppet-secretsvoorcontrole | Moet slagen vóór controles die manifestdiagnostiek kunnen tonen. | [Scanner en standaardtests](.tools/secrets/README.md#puppet-manifesten-in-standaardtests-en-ci) |
| Iedere afgeronde wijziging | Zelfstandige metadatascan vanuit root | Eigen modulepad `.`; vraag `.tools/metadata/results/metadata-report.xml` expliciet aan. | [Metadata controleren](.tools/metadata/README.md#modulemetadata-controleren) |
| Iedere afgeronde wijziging | Volledige Puppet-lintscan vanuit root | Gebruik expliciet `.puppet-lint.rc` met `--no-config`; selecteer `.`. | [Lint-CLI](.tools/lint/README.md#werking-van-de-controles) |
| Iedere afgeronde wijziging | Alle tooltests na correcties | `bundle exec rake test`; alle suites uit de gedeelde testinrichting, geen parser- of echte dependencycontrole als testdependency. | [Gezamenlijke tooltests](.tools/README.md#gezamenlijke-tooltests) |
| Iedere afgeronde wijziging | Volledige eigen Puppet-syntaxselectie | Afzonderlijke `syntax:puppet`-taak met expliciet `.tools/syntax/results/syntax-report.xml`. | [Parservalidatie](.tools/syntax/README.md#puppet-manifests-valideren) |
| Iedere afgeronde wijziging | Vaste catalogusmatrix | Afzonderlijke `catalog:compile`-taak met expliciet `.tools/catalog/results/catalog-report.xml`. | [Cataloguscompilatie](.tools/catalog/README.md#uitvoeren) |
| Iedere afgeronde wijziging | Handmatige review en toepasselijke CI-controles | Normcriteria, impact, beveiliging, documentatie en versie; complete eindinventaris inclusief nieuwe bestanden. | [Wijzigingsreview](CONTRIBUTING.md#afronden-en-wijzigingsreview), [CI](.tools/README.md#ci-van-deze-repository) |
| Iedere afgeronde wijziging | Whitespace- en inhoudsreview | `git diff --check` uitsluitend voor vrijgegeven bestanden én versies. Voor overige bestanden gecontroleerde analysekopieën; meld de achtergehouden originele controle en scope, niet als geslaagde `git diff --check`. | [Git-inspectie](CONTRIBUTING.md#git-inspectie) |
| Eigen Ruby-code of Ruby-tooling | Volledige RuboCop-scan | Herstel binnen scope; meld overige bevindingen zonder ze voor een groene status te onderdrukken. | [Ruby-controle](.tools/ruby-lint/README.md#ruby-code-controleren) |
| Tooling, modulemetadata of dependencies | Werkelijke dependencycontrole | Expliciet projectmodulepad; vraag `.tools/module-dependencies/results/project-tools-module-dependencies-report.xml` aan. Meld echte conflicten los van falende tooltests en onderdruk ze niet. | [Dependencycontrole](.tools/module-dependencies/README.md#een-controle-uitvoeren) |
| Gewijzigd Puppet-manifest | Afzonderlijke native parservalidatie van ieder gewijzigd bestand | Naast de volledige eindselectie; geef het bestandspad door aan de native parser. | [Parservalidatie](.tools/syntax/README.md#puppet-manifests-valideren) |
| Gedrag, publieke interface, configuratie, template, script, monitoring of integratie | Aanvullende functionele validatie en normreview | Kies toepasselijke scenario's hieronder en bij de betreffende norm; neem werkelijke aanroepers mee. | [Aanvullende validatie](#onderwerpgebonden-validatie), [lintuitvoering](.tools/lint/README.md#aanvullende-validatie) |
| Documentstructuur, links, instructieroutes of documentatiecontracten | Bestaande documentatie- en navigatietests plus redactionele review | Verifieer ontdekking en uitvoering van de bedoelde tests; test gewijzigde controles ook met synthetische fouten. | [Repositorycontroles](.tools/repository-checks/README.md#onderhoud), [lintdocumentatie](.tools/lint/README.md#documentatiecontract-voor-maintainers) |

## Testscope en plaatsing

- Voeg blijvende repository-eigen gedragstests uitsluitend voor repositorytools toe of onderhoud ze daarvoor. Daarnaast is de vaste cataloguscompilatiematrix onder `.tools/catalog/` toegestaan als afzonderlijke controle. Classificeer een test naar wat zijn assertions verifiëren, niet naar naam, invoerformaat of gebruikte technologie.
- Houd repositorybrede Puppet-syntaxvalidatie als afzonderlijke taak met native `puppet parser validate` buiten tooltests en hun taakdependencies. Ook de werkelijke dependencycontrole van de checkout blijft afzonderlijk.
- Houd de vaste [catalogusmatrix](.tools/catalog/README.md#vaste-scenarios) buiten tooltests en hun taakdependencies. Voeg daarnaast geen algemene module-, catalogus-, template-, script- of monitoringgedragstests toe aan de repository, ook niet indirect via tooltests, helpers of hooks. Voer vereiste functionele validatie uit met bestaande validators en geïsoleerde tijdelijke controles buiten de repository.
- Maak geen eigen testmappen of testbestanden buiten de [gedocumenteerde toollocaties](.tools/README.md#gezamenlijke-tooltests): dus ook geen root-`test/`, `tests/` of `spec/`, losse roottests of moduletestsuites. Volg bij toevoegen of verplaatsen het [tooltestonderhoud](.tools/README.md#toolteststructuur-onderhouden), inclusief gedeelde testondersteuning en afzonderlijke taken.

## Scenario's kiezen

- Leid scenario's en verwachte resultaten bij nieuwe of gewijzigde tests, ook tijdelijke functionele controles, af uit het ondersteunde contract, werkelijke afnemers en plausibele fouten. Test normaal gebruik en bevraag aannames over invoer, toestand, dependencies en uitvoering; alleen het gemelde voorbeeld of de huidige implementatietakken bepalen geen voldoende dekking.
- Neem relevante grenzen en fouten mee: ontbrekende, lege, misvormde en buiten bereik liggende invoer; nul, één en meerdere items; ontbrekende dependencies of geweigerde toegang; onderbroken of gedeeltelijke uitvoering; herhaling en verschillende volgorden wanneer het contract daardoor wordt geraakt. Selecteer op gewijzigd gedrag en gevolgen van falen.
- Test samenwerkende combinaties, inclusief meerdere onafhankelijke fouten, gemengd succesvolle en falende invoer en fouten nadat eerder werk slaagde. Verifieer ieder relevant resultaat en dat een latere fout eerdere bevindingen niet verbergt of volledige voltooiing suggereert.
- Assert waarneembaar gedrag en vereiste invarianten: resultaten, diagnostiek, status of exitcodes, toestandswijzigingen en opruimen waar toepasselijk. Controleer ook vereiste afwezigheid van neveneffecten. Leid assertions onafhankelijk van de implementatie af; dezelfde berekening herhalen of alleen voltooiing controleren onderbouwt het geclaimde gedrag niet.
- Neem bij een bugfix een regressietest op die het defect afwijst en de correctie accepteert, binnen de testscope. Onderzoek nabije invoer en combinaties die om dezelfde reden kunnen falen; één reproductie rondt die review niet af.
- Vergelijk vóór oplevering tests met de gekozen scenario's en noteer dekking, bewuste weglatingen en niet-geverifieerde gevallen. Een groene suite of hoog testaantal bewijst geen ongeteste dekking. Behoud testscope en [implementatiescope](CONTRIBUTING.md#scope-en-bestaande-wijzigingen): onderzoek van fouten staat geen nieuwe invoer, fallbacks of productgedrag toe uitsluitend om een zelfgeschreven test te laten slagen.

## Onderwerpgebonden validatie

### Interfaces, dependencies en gegenereerde inhoud

Controleer dat de centrale lintoplossing en vereiste handmatige review het gewijzigde publieke contract dekken. Pas de [prerequisitecriteria](.tools/lint/docs/CODE_RULES.md#prerequisites-van-ordering-onderscheiden) toe en verifieer beschikbaarheid én afwezigheid, inclusief relevante declaratie- en evaluatievolgorde. Beoordeel execresources en beheerde scripts volgens het [packagecontract](.tools/lint/docs/CODE_RULES.md#packageafhankelijkheden-bij-externe-commandos) en zijn uitzonderingen.

Render gewijzigde templates en samengestelde fragmenten; controleer het resulterende formaat en de toepasselijke code- en operationele normen. Valideer Puppet-voorbeelden in Strings en Markdown tijdelijk buiten de repository met lintprofiel en parser: de gewone manifestscan vindt die niet. Bij gedrag beoordeel je geschreven bestanden, serviceherstarts, benodigde rechten en verbindingen, normaal gebruik en een praktisch foutgeval met synthetische invoer. Neem alle geraakte gebruikers van een gedeelde bouwsteen mee. De [lintgids](.tools/lint/README.md#aanvullende-validatie) beschrijft de uitvoeringsroute.

Bij toolinterfaces gelden bovendien de [gedeelde integratie- en CI-review](.tools/README.md#gedeeld-toolingonderhoud) en de concrete verificatie in iedere betrokken toolhandleiding, inclusief geïnstalleerde CLI en ondersteunde consumerinstallaties. Een gedeelde librarytest vervangt de validatie van haar gemigreerde aanroepers niet.

### Shellvalidatie

- Beoordeel bron én gerenderde uitvoer volgens de [shellnormen](.tools/lint/docs/OPERATIONAL_RULES.md#shellscripts) en valideer syntax met de bedoelde interpreter. Puppet-lint valideert shellsyntax en de volledige shellstijl niet.
- Valideer gewijzigde scripts met geïsoleerde synthetische gevallen voor iedere ondersteunde invoerbron: defaults, uitsluitend environment, environment met CLI, lege en ongeldige waarden en gedeeltelijke overrides. Neem gerelateerde waardevolgorde, herhaalde opties, booleanresets en timeouts mee waar toepasselijk.
- Valideer iedere ondersteunde gegenereerde tak en het gedeelde helpercontract volgens de [templateregels](.tools/lint/docs/OPERATIONAL_RULES.md#puppet-waarden-rechtstreeks-in-shelltemplates-invoegen) en [helperregels](.tools/lint/docs/OPERATIONAL_RULES.md#shellhelpers-op-een-herkenbare-taak-afbakenen), inclusief herhaalde aanroepen en gebruik zonder ongerelateerde classdeclaraties.
- Verifieer bij vervanging van externe tools gelijkwaardig gedrag, validatie, foutafhandeling, monitoringstatussen, exitcodes en extern gebruikte uitvoer, tenzij gedragswijziging expliciet gevraagd is. Neem relevante witruimte, escaping, locale en grenzen mee en pas de prerequisitecriteria toe op verwijderde of verplaatste dependencies.
- Houd functionele controles buiten de repository; neem foutpaden en opruimen van tijdelijke bestanden mee wanneer geraakt.

### Monitoringvalidatie

- Verifieer packagegaranties van iedere check volgens het algemene [packagecontract en zijn uitzonderingen](.tools/lint/docs/CODE_RULES.md#packageafhankelijkheden-bij-externe-commandos). Pas shellvalidatie toe op gewijzigde implementaties.
- Valideer bronkeuze en status tegen de scenario's bij [runtimebronnen](.tools/lint/docs/OPERATIONAL_RULES.md#actuele-hosttoestand-uit-kernelgegevens-bepalen) en [inspectiestatus](.tools/lint/docs/OPERATIONAL_RULES.md#vastgestelde-afwijkingen-en-onvolledige-inspecties-onderscheiden). Neem ondersteunde expliciete keuzes, automatische detectie en vereiste of optionele componenten over de geraakte aanroepers mee.
- Controleer voor iedere nieuwe of gewijzigde plugin alle uitvoerpaden en de gerenderde Puppet-integratie tegen de [centrale uitvoernorm](.tools/lint/docs/OPERATIONAL_RULES.md#pipes-en-lege-regels-in-lange-uitvoer-veilig-maken). Vergelijk representatieve gezonde, afwijkende en onvolledige resultaten op behoud van status en perfdata; meld ontbrekende monitoringinterfacevalidatie expliciet.
- Valideer voor iedere gewijzigde check registraties met minstens twee targets die hetzelfde executable met eigen instellingen aanroepen. Verifieer dat het verwijderen van één target het gedeelde executable en de andere registraties behoudt.
- Beoordeel executorplanning afzonderlijk van scriptopties volgens het [agentplanningscontract](.tools/lint/docs/OPERATIONAL_RULES.md#agentplanning-afzonderlijk-afstemmen). Rapporteer gewijzigde operationele risico's en verifieer het geraakte monitoringgedrag.

### Documentatievalidatie

Bij gewijzigde Puppet-voorbeelden in Markdown of Strings controleer je de codeblokken afzonderlijk met de bestaande lint- en parserroute. Een gewone manifestscan vindt ze niet. Plaats fragmenten zo nodig in hun bedoelde geldige context in een tijdelijk manifest buiten de repository; voeg daarvoor geen algemene extractievoorziening toe. Controleer ook de redactionele samenhang en gerichte links volgens de [documentatienorm](.tools/lint/docs/DOCUMENTATION_RULES.md#redactionele-review). Leg vast of parameterhulp in de gebruikte editor en een consumer met `global-modules` daadwerkelijk is bekeken.

## Isolatie en bewijsvoering

Houd synthetische tests en validatie gescheiden van productiecredentials, productieverbindingen en beheerde hosts. Een geslaagde lintscan vervangt functionele validatie of review nooit.

Leg de toepasselijke reviewuitkomsten en functionele validatiecommando's met resultaten vast in de wijzigingsreview. Vermeld per controle selectie, status, relevant rapport, bewezen scenario's en grenzen. Rapporteer ontbrekende tooling, mislukte of niet-uitgevoerde controles, vervangende controles, bewuste weglatingen, resterende bevindingen en onzekerheden. Beschrijf onvolledige validatie nooit als volledig; vermeld expliciet welke vereiste controle nog ontbreekt. De [opleverwerkwijze](CONTRIBUTING.md#afronden-en-wijzigingsreview) verbindt dit bewijs aan de eindstatus.
