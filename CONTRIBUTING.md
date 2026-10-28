# Bijdragen aan de Puppet-modules

Deze werkwijze geldt voor menselijke ontwikkelaars en AI-agents bij iedere wijziging aan eigen modules, documentatie en tooling. Begin bij de voorbereiding, kies de toepasselijke normen en sluit af met de controles uit [TESTS.md](TESTS.md). De [README](README.md) blijft de gebruikershandleiding; `AGENTS.md` geeft agents hun verplichte leesroute.

## Inhoudsopgave

- [Inhoudsopgave](#inhoudsopgave)
- [Leesroute en verantwoordelijkheid](#leesroute-en-verantwoordelijkheid)
- [Voorbereiding en wijzigingsscope](#voorbereiding-en-wijzigingsscope)
  - [Bestaande situatie onderzoeken](#bestaande-situatie-onderzoeken)
  - [Scope en bestaande wijzigingen](#scope-en-bestaande-wijzigingen)
  - [Hergebruik en samenhang](#hergebruik-en-samenhang)
- [Impact en inhoudelijke review](#impact-en-inhoudelijke-review)
  - [Beveiligingsreview](#beveiligingsreview)
- [Veilig werken en gegevensdeling](#veilig-werken-en-gegevensdeling)
  - [Lokale inspectie vóór inzage](#lokale-inspectie-vóór-inzage)
  - [Geheimen en vertrouwelijke gegevens](#geheimen-en-vertrouwelijke-gegevens)
  - [Minimale en geanonimiseerde openbaarmaking](#minimale-en-geanonimiseerde-openbaarmaking)
  - [Openbaarmakingsincidenten](#openbaarmakingsincidenten)
- [Git-inspectie en opleverstatus](#git-inspectie-en-opleverstatus)
  - [Git-inspectie](#git-inspectie)
- [Compatibiliteit en versies](#compatibiliteit-en-versies)
  - [Ondersteunde platforms](#ondersteunde-platforms)
  - [Release-impact bepalen](#release-impact-bepalen)
  - [Versie kiezen en synchroniseren](#versie-kiezen-en-synchroniseren)
- [Afronden en wijzigingsreview](#afronden-en-wijzigingsreview)

## Leesroute en verantwoordelijkheid

| Je werk | Lees en pas toe |
| --- | --- |
| Iedere wijziging | Deze werkwijze, [testbeleid](TESTS.md) en de toepasselijke [documentatienormen](.tools/lint/puppet/docs/DOCUMENTATION_RULES.md). |
| Eigen code, ook scripts en tooling | [Algemene ontwerpregels](.tools/lint/puppet/docs/CODE_RULES.md#algemene-ontwerpregels). |
| Puppet-code of Puppet Strings | De [lintwerkwijze](.tools/lint/puppet/README.md#werkwijze-bij-een-wijziging) en de [leeswijzer](.tools/lint/puppet/README.md#leeswijzer) naar toepasselijke Puppet-regels, documentatieregels en hun reviewcriteria. |
| Bestanden, rechten, beveiliging, services, shell, runtime-tools of monitoring | De relevante [operationele normen](.tools/lint/puppet/docs/OPERATIONAL_RULES.md), naast de code- en documentatienormen. |
| Tooling, inclusief root-Gemfile, Rakefile, CI en consumervoorbeelden | [Gedeeld toolingonderhoud](.tools/README.md#gedeeld-toolingonderhoud) en de README van ieder geraakt component uit het [pakketoverzicht](.tools/README.md#pakketten-en-commandos), inclusief [repositorycontroles](.tools/repository/README.md). |

Lees de relevante bron daadwerkelijk vóór het wijzigen. Breid de leesroute uit wanneer nieuwe dependencies, integraties of aanroepers in beeld komen; ongewijzigde, al gelezen bronnen hoef je niet opnieuw te lezen. Bij gedeelde interfaces horen de contracten van alle werkelijk geraakte afnemers. Alleen codeafspraken onder `lint/docs/` toepassen vereist geen linteronderhoud; die afspraken wijzigen wel.

Iedere duurzame norm heeft één eigenaar volgens de [informatieplaatsing](.tools/lint/puppet/docs/DOCUMENTATION_RULES.md#informatieplaatsing). Lokale afspraken vullen gezamenlijke afspraken aan en mogen ze niet afzwakken, tegenspreken of dupliceren. Een uitzondering is alleen geldig binnen een uitzondering die de normeigenaar toestaat. Leg onopgeloste verschillen vast volgens [conflicten beoordelen](.tools/lint/puppet/docs/DOCUMENTATION_RULES.md#conflicten-beoordelen), zonder lokale tekst stilzwijgend voorrang te geven.

## Voorbereiding en wijzigingsscope

### Bestaande situatie onderzoeken

- Inventariseer vóór bewerken de wijzigingen volgens [Git-inspectie](#git-inspectie).
- Lees de relevante modulebestanden en README-secties vóór gedrags- of structuurwijzigingen, plus de modulemetadata als die bestaan. Pas bij nieuwe modules, metadata-, versie- of consumerintegratiewijzigingen de [metadata-inhoudsreview](.tools/metadata/README.md#modulemetadata-controleren) toe.
- Inspecteer gerelateerde manifests, templates, statische bestanden, voorbeelden en systemd-units, ook gegenereerde units. Controleer relevante integraties met `basic_settings`, monitoring, systemd, security-audit, `php8::fpm`, `nginx` en andere lokale modules. Bekijk bestaande patronen voor eigenaar, modus, `require`, `notify` en `subscribe` vóór nieuwe resources.
- Beoordeel bij nieuwe tooling meteen of een eigen CLI nodig is en waar die hoort volgens de [componentstructuur](.tools/README.md#componentstructuur). Controleer de aansluiting tussen library, CLI en eventuele gemregistratie, de uitvoering via Rake, CI en externe consumers, en welke bestaande tests, documentatie en instructieroutes mee moeten veranderen.
- Alle modulemappen uit de README zijn eigen code, behalve de vendored Git-submodules `concat`, `debconf`, `reboot` en `stdlib`. Beperk wijzigingen tot eigen code, documentatie en tooling, tenzij de opdracht een dependencywijziging vereist. Gebruik vendored modules nooit als stijlvoorbeeld.

### Scope en bestaande wijzigingen

- Behoud niet-gerelateerde gebruikerswijzigingen. Een corrigerende gebruikerswijziging is het actuele voorkeursmodel; herstel een eerdere agentaanpak uitsluitend op expliciet verzoek.
- Houd wijzigingen en ondersteunende refactors binnen de opdracht en het geraakte gebied. Kies de eenvoudigste implementatie die het gevraagde gedrag en bestaande contracten behoudt, beginnend bij bestaande ingebouwde functionaliteit.
- Een expliciet gevraagde uitvoeringsmethode hoort bij het opdrachtcontract. Vervang haar niet door een eigen runner, hulpscript, request-fileprotocol of extra uitvoeringslaag vanwege een veronderstelde voorkeur. Leg een concreet onoplosbaar conflict uit vóór je een ander ontwerp kiest.
- Voeg invoerformaten, normalisatie, randgevalafhandeling, fallbacks, controles, helpers, configuratiebestanden of abstracties alleen toe vanwege de opdracht, een bestaand project- of interfacecontract of een aangetoonde fout binnen de scope. Hypothetische randgevallen, toekomstig gebruik en algemene robuustheid zijn onvoldoende; tests voor een ongevraagde uitbreiding maken haar niet noodzakelijk.
- Benoem vóór zo'n toevoeging de concrete eis of fout en waarom de eenvoudigere implementatie niet voldoet. Leg die onderbouwing vast in de wijzigingsreview. Laat de toevoeging weg als de noodzaak niet aantoonbaar is en verwijder onvoldoende onderbouwde toevoegingen bij de eindreview. Verwijder bij een vereenvoudigingsopdracht ook hun ondersteunende code.

### Hergebruik en samenhang

Deze review geldt bij features en substantiële wijzigingen aan alle eigen code, inclusief scripts, bibliotheken, tools en integratiecode, binnen de geraakte implementatie en haar werkelijke aanroepers.

- Onderzoek vóór implementatie bestaande verantwoordelijkheden, interfaces, verwante implementaties en werkelijke aanroepers. Bepaal wat kan worden hergebruikt, uitgebreid of samengebracht voordat je een nieuwe implementatie toevoegt.
- Pas de [algemene ontwerpcriteria](.tools/lint/puppet/docs/CODE_RULES.md#algemene-ontwerpregels) en hun Puppet- en shelluitwerkingen toe. Volg bij tooling ook de [integratiereview](.tools/README.md#verantwoordelijkheden-en-integratie-reviewen). Onderbouw nieuwe abstracties volgens de wijzigingsscope, zonder lagen voor hypothetisch hergebruik.
- Rond consolidatie af door alle geraakte aanroepers te migreren en vervangen implementaties en verwijzingen te verwijderen. Behoud bij vervanging van een ontwikkel- of consumerinterface één ondersteunde werkwijze, zonder aliases, adapters, fallbacks of tijdelijke compatibiliteitsperiode. Migreer consumers, instructies en tests tegelijk; beschrijf vereiste consumeracties en breaking release-impact volgens het versiebeleid.
- Volg bij toolwijzigingen de [integratiereview voor logging en rapportage](.tools/README.md#verantwoordelijkheden-en-integratie-reviewen): lees het centrale contract, onderzoek shared en vergelijkbare tools, en onderhoud de vereiste gedragstests en documentatie samen.
- Beoordeel het geheel op verantwoordelijkheidsgrenzen, dependencyrichting en consistent gedrag over alle ingangen. Noteer wat is hergebruikt, geconsolideerd, verwijderd of bewust afzonderlijk gehouden, met de wezenlijke redenen. Behoud beveiliging en levenscyclus van iedere aanroeper en valideer hun gedrag en dependencies volgens [TESTS.md](TESTS.md).

## Impact en inhoudelijke review

Bepaal bij iedere wijziging welke parameteruitleg, implementatiecomments, README-ingang, voorbeelden, procedures en eventuele gegenereerde referentie geraakt zijn. Volg daarvoor [interfacebeschrijvingen synchroniseren](.tools/lint/puppet/docs/DOCUMENTATION_RULES.md#interfacebeschrijvingen-synchroniseren) en de [informatieplaatsing](.tools/lint/puppet/docs/DOCUMENTATION_RULES.md#informatieplaatsing); leg in de review vast wat is bijgewerkt of waarom de bestaande uitleg volstaat.

- Pas de normen en hun handmatige reviewcriteria toe, ook als lint slaagt. De [lintconfiguratie](.puppet-lint.rc), gedeelde profielen en [checks](.tools/lint/puppet/lib/project_lint/checks/) bepalen automatische detectie en correctie; tooltests bewijzen alleen hun uitgevoerde scenario's. Houd verschillen tussen norm, configuratie, implementatie en testbewijs zichtbaar en wijzig geen bron stilzwijgend zonder bewijs of expliciete projectbeslissing.
- Neem bij wijzigingen aan Puppet-conventies hun tests en alle geraakte eigen code in dezelfde wijziging mee.
- Beoordeel gevolgen voor conventies, Puppet-abstracties en herbruikbare wrappers. Onderzoek bij een concreet voorbeeld of hetzelfde principe geldt voor andere resourcetypen, consumers of integraties binnen het geraakte gebied. Pas gedeeld gedrag consistent toe, behoud typespecifieke betekenis en noteer bereik en bewuste beperkingen.
- Beoordeel monitoring, logging, alarmering, auditregels en operationele diagnostiek, evenals documentatie, voorbeelden, platforms, compatibiliteit en operationele commando's. Volg voor documentatiewijzigingen de volledige [redactionele review](.tools/lint/puppet/docs/DOCUMENTATION_RULES.md#redactionele-review).
- Beoordeel prerequisites, resourceplaatsing en runtime-inventarisatie met de criteria bij [dependencies](.tools/lint/puppet/docs/CODE_RULES.md#resources-en-afhankelijkheden), [ordering](.tools/lint/puppet/docs/CODE_RULES.md#volgorde-en-meldingen) en [Facter](.tools/lint/puppet/docs/CODE_RULES.md#runtime-inventarisatie-met-facter-modelleren). Beoordeel beheerde inhoud, helpers, shell en monitoring met de betreffende [operationele criteria](.tools/lint/puppet/docs/OPERATIONAL_RULES.md).
- Meld mogelijkheden voor veilige lintdetectie of autofix die nog ontbreken als mogelijke linterverbeteringen. Implementeer ze alleen wanneer linterontwikkeling binnen de opdracht valt.

### Beveiligingsreview

Behandel beveiliging vanaf het ontwerp als eis. Behoud correcte hardening en verbeter die alleen wanneer applicatie- en operationeel gedrag correct blijven. Kies het eenvoudigere ontwerp wanneer dat het aanvalsoppervlak verkleint zonder eisen te schenden.

- Beoordeel privileges, rechten, gebruikers, groepen, capabilities, sudo en geheimen. Onderzoek minder privilege of een beperktere service-identiteit; benoem nieuwe trust boundaries, sudo-routes, schrijfbare paden, capabilities en privilegeaannames.
- Beoordeel systemd-ordering, targets, hardening, herstartgedrag en foutafhandeling. Onderzoek strakkere isolatie zonder gedragsbreuk.
- Beoordeel netwerken, poorten, sockets, firewalls, TLS en servicedependencies. Benoem nieuw blootgestelde poorten. Gebruik bij firewalls het [deployment- en monitoringcontract](.tools/lint/puppet/docs/OPERATIONAL_RULES.md#firewallconfiguratie-bij-de-deployment-houden); valideer packetbereikbaarheid afzonderlijk wanneer nodig. Een geslaagde structurele inspectie bewijst die bereikbaarheid niet.

## Veilig werken en gegevensdeling

Externe openbaarmaking is iedere overdracht buiten een door de organisatie beheerde of expliciet goedgekeurde omgeving: zoekvragen, AI-prompts, geplakte tekst, uploads, screenshots, codefragmenten, forums, leveranciersportalen, externe issues, codedeling, chat, e-mail en browsertools. Toestemming voor een dienst is geen toestemming voor ieder datatype. Pas classificatie, minimale openbaarmaking en noodzakelijkheid toe bij elke goedgekeurde dienst.

### Lokale inspectie vóór inzage

- Voer buiten de onderstaande leesuitzondering vóór AI-context of externe analyse de lokale gedeelde scanner uit: `bundle exec project-tools-secrets PATH ...`. Dit geldt vóór bestanden openen, zoekresultaten, terminaluitvoer of diffs tonen. Inspecteer nooit eerst ruwe inhoud om te bepalen of scanning nodig is.
- Alle `.md`-bestanden direct in de repositoryroot en bestanden met de naam `AGENTS.md` op iedere diepte mogen zonder secrets-tool rechtstreeks worden geopend, gelezen en doorzocht. Zo zijn de projectafspraken, waaronder `README.md`, `CONTRIBUTING.md` en `TESTS.md`, direct toegankelijk voor ontwikkelaars en agents. De uitzondering geldt niet voor overige bestanden in submappen of alleen omdat een vrijgesteld document ernaar linkt. Overige openbaarmakingsbeperkingen en Git-inspectie blijven gelden.
- Beoordeel eerst alleen scanmetadata. Gebruik bij bevindingen `bundle exec project-tools-secrets prepare` met expliciete selectie en context, en lees alleen de vrijgegeven analysewerkboom volgens de [scannerprocedure](.tools/secrets/README.md#controleren-voor-het-lezen). Behoud originelen en scan gewijzigde invoer opnieuw.
- Houd inhoud achter bij fouten, onvolledige dekking of onzekere maskering totdat dit is opgelost of een persoon haar lokaal buiten AI-context beoordeelt. Installeer een ontbrekende scanner vóór inzage. Geen matches betekent uitsluitend dat de ondersteunde checks niets vonden, geen veiligheidsgarantie of vervanging van de openbaarmakingsreview.
- Gebruik de [voorbereide bewerkingsroute](.tools/secrets/README.md#ontwikkelen-met-een-analysewerkboom) wanneer beschermde waarden bewerkingen moeten overleven. Private ID-koppelingen en hersteljournal horen bij de schrijfactie, niet bij een AI-sessie. De aanroeper volgt deze werkwijze; een aparte veilige AI-sessie, launcher of automatische afdwinglaag is niet vereist.
- Behandel gemiste gegevens en inspectie- of redactiedefecten volgens [incidentafhandeling](#openbaarmakingsincidenten) en de [herstelprocedure](.tools/secrets/README.md#gemiste-gegevens-of-een-fout-melden). Pas deze werkwijze in consumerprojecten toe via hun eigen instructie-ingang, met dezelfde implementatie en [consumerinrichting](.tools/secrets/README.md#gebruik-in-een-ander-project).

### Geheimen en vertrouwelijke gegevens

- Deel nooit wachtwoorden, passphrases, API-keys, access- of refreshtokens, sessie-identificaties, cookies, back-upcodes of verbindingstrings met credentials extern, ook niet in zoekvragen. Deel evenmin private sleutels, certificaatmateriaal, CSR's, certificaatketens, key- of truststores, secret- of tokenbestanden, kubeconfig of `.env`-inhoud.
- Verwijder geheimen volledig vóór extern gebruik. Gebruik geen gedeeltelijke maskering, voor- of achtervoegsels, fingerprints, hashes of gecodeerde varianten wanneer die de oorspronkelijke waarde kunnen identificeren of verifiëren.
- Zet nooit echte geheimen of credentials in code, commentaar, documentatie, voorbeelden, tests, fixtures, logs, commits, tickets, prompts of probleemanalyses. Gebruik duidelijk synthetische authenticatiewaarden in ieder voorbeeld en iedere reproductie.
- Deel geen ruwe operationele, persoonlijke, medische, klant-, medewerker-, organisatie- of commercieel vertrouwelijke gegevens buiten de goedgekeurde omgeving. Behandel logs, stacktraces, HL7, FHIR, EDI, databaserecords, exports, configuratie, packetcaptures, screenshots, bronfragmenten, headers en queryparameters als potentieel gevoelig. Dat geldt ook voor hostnamen, IP-adressen, interne URL's, bestandsnamen, gebruikersnamen, tenant- en projectidentificaties en metadata.

### Minimale en geanonimiseerde openbaarmaking

- Beperk een externe vraag tot de noodzakelijke technische feiten. Gebruik bij voorkeur een generieke beschrijving of minimale reproductie met uitsluitend synthetische gegevens en deel het kleinst bruikbare geschoonde fragment. Upload geen volledige repository, databasedump, configuratieverzameling, berichtenarchief of logcollectie wanneer een kleinere synthetische reproductie volstaat.
- Anonimiseer of vervang alle gegevens vóór vertrek uit de goedgekeurde omgeving. Vervang echte namen, identificaties, adressen, getallen, tijdstippen, domeinen, hostnamen en omgevingswaarden. Behoud alleen relaties die voor reproductie nodig zijn. Gebruik consistente synthetische placeholders voor noodzakelijke correlatie, zonder productiewaarden te hergebruiken.
- Beoordeel combinaties van overgebleven velden op heridentificatie van personen, organisaties, klanten, systemen en omgevingen. Alleen een naam weghalen volstaat niet als de rest redelijkerwijs herkenning mogelijk maakt. Noem gedeeltelijk gemaskeerde of gepseudonimiseerde gegevens niet anoniem als heridentificatie mogelijk blijft.
- Inspecteer vóór delen de volledige uitgaande inhoud: logs, stacktraces, shellhistorie, opdrachtuitvoer, request- en responseheaders, URL's, querystrings, commentaar, bestandsnamen, metadata, screenshots, diffs, archieven en omringende gekopieerde context.
- Deel niets wanneer veilige sanitization niet voldoende aantoonbaar is. Gebruik dan goedgekeurde interne documentatie, tooling, collega's of veilige supportkanalen; ook een supportkanaal heft de openbaarmakingsbeperkingen niet op.

### Openbaarmakingsincidenten

- Meld bevestigde of vermoede openbaarmaking én ieder ontdekt inspectie- of redactiedefect dat gevoelige gegevens kan doorlaten onmiddellijk aan de gebruiker, ook wanneer lokaal onderschept vóór openbaarmaking. Verberg dit niet achter een geslaagde scan en repareer het niet stilzwijgend.
- Stop onmiddellijk met delen van de getroffen inhoud. Beschrijf in dezelfde melding veilig de scope en het kanaal, of blootstelling bevestigd, vermoed, afwezig of onbekend is, en concrete maatregelen voor indamming, herstel en verificatie. Onderscheid feiten van mogelijke oorzaken en uitgevoerde reparaties van aanbevelingen; benoem onbekende oorzaak of omvang.
- Herhaal de blootgestelde waarde niet. Behandel blootgestelde credentials en sleutelmateriaal als gecompromitteerd; trek ze waar toepasselijk in of roteer ze. Volg de toepasselijke security-incidentprocedure.
- Benoem open bevindingen en noodzakelijke opvolging in de oplevering, met verificatiebewijs voor herstel. Hervat delen pas wanneer de lokale inspectievoorwaarden opnieuw zijn vervuld.

## Git-inspectie en opleverstatus

### Git-inspectie

- Inventariseer vóór iedere inhoudsvergelijking staged, unstaged, nieuwe, verwijderde en hernoemde paden met `git --no-pager status --porcelain=v1 --untracked-files=all`. Sla de inventaris eerst lokaal op en pas de lokale inspectie toe vóór je mogelijk vertrouwelijke bestandsnamen toont.
- Scan de volledige versies die je werkelijk vergelijkt met de algemene scanner en de vereiste context van elke versie: index en werkboom voor unstaged, gekozen basis en index voor staged, of de oude revisie en gekozen nieuwe versie. Neem oude inhoud bij verwijderingen en beide paden en inhouden bij hernoemingen mee. Alleen actuele bestanden, patches of Puppet scannen volstaat niet. Exporteer versies rechtstreeks naar private lokale bestanden zonder ruwe bytes of ongecontroleerde fouten te tonen, volgens de [praktische Git-procedure](.tools/secrets/README.md#git-versies-lokaal-controleren-en-vergelijken).
- Behandel een bestand voor deze beslissing als gevoelig zodra een vergeleken versie een bevinding heeft, ook alleen een indicator, of de classificatie onzeker is. Gebruik nooit `git diff` op zulke originelen, ook niet wanneer alleen de oude versie gevoelig is of de uitvoer wordt omgeleid. Vergelijk uitsluitend succesvol vrijgegeven analysekopieën volgens de [gecontroleerde vergelijkingsprocedure](.tools/secrets/README.md#diagnostiek-en-veilige-diff). Onvolledige of mislukte inspectie staat vergelijking of openbaarmaking niet toe.
- Gewone diff is uitsluitend toegestaan als alle versies en hun context volledig zijn geïnspecteerd zonder gevoelige gegevens. Beperk haar tot precies die bestanden en versies, zonder externe diff- of textconvhelpers; inspecteer opnieuw na wijzigingen aan bronnen, index, basis of relevante context. Eén vrijgegeven bestand staat geen repositorybrede diff toe.
- Deze voorwaarde geldt voor alle inhoudsuitvoer, ook `git show`, `git log -p`, `git diff --check`, gewone bestandsvergelijking, grafische Git-diffs en editorpreviews. `git diff --check` kan bronregels tonen bij fouten. Rapporteer achtergehouden controles expliciet en niet als geslaagd.

Laat gevalideerde wijzigingen beschikbaar in de werkboom voor menselijke review en commit. Herstel nooit bestanden uitsluitend om een CI-cleanlinesscontrole groen te maken. Het verbod voor AI-agents op het maken, amenderen of herschrijven van commits staat in hun [agentinstructies](AGENTS.md#agent-specific-instructions).

## Compatibiliteit en versies

### Ondersteunde platforms

De eigen modules richten zich op Debian- en Ubuntu-servers. De volledige combinatie richt zich vooral op `amd64`; afzonderlijke platformroutes kunnen meer of minder releases of architecturen ondersteunen. Ondersteuningsclaims voor besturingssysteem, release, architectuur, Puppet of OpenVox moeten in dezelfde wijziging overeenkomen met implementatie, relevante metadata, beschikbare validatie en Nederlandstalige README.

Runtime-modulekeuze volgt de [lokale integratie- en dependencyregels](.tools/lint/puppet/docs/OPERATIONAL_RULES.md#lokale-integraties-en-runtimeafhankelijkheden-kiezen).

### Release-impact bepalen

Gebruik [Semantic Versioning](https://semver.org/spec/v2.0.0.html), `MAJOR.MINOR.PATCH`. Root-`VERSION` is de enige projectversiebron; rootmetadata en alle eigen modulemetadata volgen haar. Een breaking wijziging in één module raakt dus de versie van de volledige moduleset, ook ongewijzigde modules. Consumerprojecten, geïmporteerde gedeelde projecten en externe dependencies behouden eigen versies.

Beoordeel iedere wijziging tegen de laatste gepubliceerde release en noteer de impact in de review. Het publieke contract omvat ondersteunde classes, defined types, parameters, Hiera-instellingen, gedocumenteerd beheergedrag en gedocumenteerde toolingintegratie. Beoordeel het effect op ondersteund gebruik, niet de diffgrootte; onuitgebrachte tussenimplementaties zijn geen afzonderlijke releasebasis.

| Niveau | Vereist voor | Vanaf `3.2.4` |
| --- | --- | --- |
| MAJOR | Incompatibiliteit: bijvoorbeeld een publieke parameter verwijderen of hernoemen zonder compatibiliteit, een optionele parameter verplicht maken of een default wijzigen waardoor ondersteund gebruik faalt. | `4.0.0` |
| MINOR | Compatibele functionaliteit: bijvoorbeeld een optionele parameter met behoudende default, een nieuwe module of define, of deprecatie aankondigen met behoud van ondersteuning. | `3.3.0` |
| PATCH | Compatibele foutreparaties, zoals ongeldige gegenereerde configuratie herstellen zonder interfacewijziging, en correcties aan documentatie, voorbeelden of workflow die ondersteund gebruik behouden. | `3.2.5` |

Het hoogste vereiste niveau van alle releasewijzigingen bepaalt de versie. Zet bij MINOR de PATCH op nul en bij MAJOR beide overige delen op nul. Behandel delen als integers: `3.9.0` kan naar `3.10.0`. Verwijderen van deprecated functionaliteit is MAJOR wanneer het publieke contract breekt. Neem toolingconsumers mee: een nieuw verplicht versiebestand of expliciete configuratie is breaking als de laatste gepubliceerde release zonder werkte.

### Versie kiezen en synchroniseren

Kies vóór iedere oplevering de projectversie voor alle verzamelde wijzigingen sinds de laatste gepubliceerde release en noteer keuze en onderbouwing. Werk `VERSION` en metadata in dezelfde wijziging bij; stel dit niet uit tot een releasetaak.

De versie moet nieuwer zijn dan de laatste gepubliceerde release en het hoogste vereiste niveau dekken. Behoud een al gekozen onuitgebrachte versie alleen wanneer die alle verzamelde wijzigingen nog dekt en leg uit waarom geen verdere verhoging nodig is. Verhoog niet automatisch per commit of lintrun en leid impact niet uit bestandsnamen af.

Stel eerst `VERSION` in en synchroniseer uitsluitend de `version`-velden in root- en eigen modulemetadata. Behoud overige metadata en versies van imports en dependencies. Leid `VERSION` nooit af uit metadata of Git en werk haar daaruit niet automatisch bij; releasetags volgen de gekozen versie. Geef bij breaking wijzigingen concrete consumermigratie in release notes of een changelog en werk de gebruiksdocumentatie bij naar het actuele contract, volgens [duurzame documentatie](.tools/lint/puppet/docs/DOCUMENTATION_RULES.md#duurzame-documentatie). Houd gepubliceerde releases onveranderlijk en lever volgende wijzigingen onder een nieuwe versie.

De [metadatahandleiding](.tools/metadata/README.md#versiebron-en-rapportage) beheert validatie, selectie en synchronisatie; een geslaagde consistentiecontrole bewijst geen compatibiliteit. De lintgem heeft een afzonderlijke versie en [releaseprocedure](.tools/lint/puppet/README.md#een-gem-bouwen-en-versie-uitbrengen).

## Afronden en wijzigingsreview

Voltooi [TESTS.md](TESTS.md), inclusief de toepasselijke CI-controles, de laatste Git-inventaris met nieuwe bestanden en de toegestane diffreview. Controleer de volledige wijziging op semantiek en scope, ook autofix: gedrag, resourcerelaties, dependencies en bedoelde configuratie moeten behouden blijven. Beoordeel correcties handmatig wanneer veiligheid niet aantoonbaar is.

Controleer vóór oplevering de voorbereiding, scope, normeigenaars en toepasselijke code-, operationele, beveiligings- en documentatiereview, impact, versie en metadata. Gebruik bij herindeling van afspraken de [regels voor informatiebehoud en eindreview](.tools/lint/puppet/docs/DOCUMENTATION_RULES.md#afspraken-onderhouden). Controleer voor externe deling geheimenbescherming, minimale en synthetische of voldoende geanonimiseerde inhoud, volledige uitgaande context en het verbod op onzekere sanitization.

Vermeld in de wijzigingsreview en het eindantwoord:

- De gewijzigde paden en eventuele ondersteunende refactor met reden.
- Relevante beveiligings- en systemdbesluiten, de documentatie- en agentroutekeuzes en de compatibiliteits- en versieafweging.
- Uitgevoerde controles en resultaten, ontbrekende of mislukte controles, resterende bevindingen, aannames, onzekerheden en opvolging volgens [bewijsvoering](TESTS.md#isolatie-en-bewijsvoering).
- Bij verplaatste afspraken de oude en nieuwe eigenaar, samenvoegingen, behouden voorwaarden en uitzonderingen, en eventuele expliciet onderbouwde correcties of onopgeloste conflicten. Bewaar dit bij de wijziging, zonder permanent migratieregister toe te voegen.
