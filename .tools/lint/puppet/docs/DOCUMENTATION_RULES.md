# Documentatienormen en reviewcriteria

Dit document bevat de algemene normen voor repositorydocumentatie, informatieplaatsing, Markdown, README's en redactionele review. De aanvullende codecommentaar- en interfaceregels benoemen hun scope; Puppet Strings en Puppet-specifieke opmaak blijven tot Puppet beperkt. Gebruik de [gezamenlijke ontwikkelwerkwijze](../../../../CONTRIBUTING.md) en het [testbeleid](../../../../TESTS.md) voor voorbereiding, verplichte validatie en oplevering.

Volg bij codewijzigingen ook de toepasselijke [algemene en taalspecifieke coderegels](CODE_RULES.md), en bij bestanden, rechten, beveiliging, services, shell, runtime-tools of monitoring de [operationele normen](OPERATIONAL_RULES.md). De drie bronnen kunnen tegelijk gelden. Een groene scan bewijst geen volledige naleving; normen zonder automatische controle blijven verplicht.

De [linthandleiding](../README.md) beheert gebruik, architectuur en linteronderhoud. Alleen normen toepassen vereist die onderhoudsroute niet. Het bestaande [documentatieschema](../README.md#schema-voor-regels-en-procedures) geldt voor de aanvullende coderegels onder Commentaar en documentatie; de algemene documentatie- en redactionele afspraken hieronder hebben hun eigen onderwerpstructuur.

## Inhoudsopgave

- [Inhoudsopgave](#inhoudsopgave)
- [Algemene documentatienormen](#algemene-documentatienormen)
  - [Taal en informatieplaatsing](#taal-en-informatieplaatsing)
    - [Informatieplaatsing](#informatieplaatsing)
  - [Duurzame documentatie](#duurzame-documentatie)
  - [Markdown](#markdown)
- [Redactionele review](#redactionele-review)
  - [Doelgroep en leesroute](#doelgroep-en-leesroute)
    - [Vóór bewerken](#vóór-bewerken)
    - [Tijdens bewerken](#tijdens-bewerken)
    - [Na bewerken](#na-bewerken)
  - [Technisch bewijs en links](#technisch-bewijs-en-links)
  - [Proza beoordelen](#proza-beoordelen)
  - [Grenzen van redactionele automatisering](#grenzen-van-redactionele-automatisering)
- [README-richtlijnen](#readme-richtlijnen)
  - [Scope en configuratie](#scope-en-configuratie)
  - [Stijl en uitleg](#stijl-en-uitleg)
  - [Navigatie en prerequisites](#navigatie-en-prerequisites)
  - [Modulesecties](#modulesecties)
    - [Belangrijke aandachtspunten](#belangrijke-aandachtspunten)
- [Afspraken onderhouden](#afspraken-onderhouden)
  - [Wijzigingsbereik en noodzaak](#wijzigingsbereik-en-noodzaak)
  - [Inhoud behouden en samenbrengen](#inhoud-behouden-en-samenbrengen)
  - [Regelstructuur en formulering](#regelstructuur-en-formulering)
  - [Conflicten beoordelen](#conflicten-beoordelen)
  - [Eindreview van afspraken](#eindreview-van-afspraken)
- [Commentaar en documentatie](#commentaar-en-documentatie)
  - [Toelichtingen bij code](#toelichtingen-bij-code)
  - [Toelichtingsblokken van eerdere code scheiden](#toelichtingsblokken-van-eerdere-code-scheiden)
    - [Verdieping bij Toelichtingsblokken van eerdere code scheiden](#verdieping-bij-toelichtingsblokken-van-eerdere-code-scheiden)
  - [Een resource na een afgesloten blok toelichten](#een-resource-na-een-afgesloten-blok-toelichten)
  - [Bestaande implementatie-uitleg actueel houden](#bestaande-implementatie-uitleg-actueel-houden)
  - [Niet-zichtbare implementatiekeuzes toelichten](#niet-zichtbare-implementatiekeuzes-toelichten)
  - [Codecommentaar in Engelse zinnen schrijven](#codecommentaar-in-engelse-zinnen-schrijven)
  - [Voorwaarden toelichten](#voorwaarden-toelichten)
    - [Verdieping bij Voorwaarden toelichten](#verdieping-bij-voorwaarden-toelichten)
  - [Variabelen groeperen](#variabelen-groeperen)
  - [Een variabelegroep bij blokbegin toelichten](#een-variabelegroep-bij-blokbegin-toelichten)
  - [Een onafhankelijke groep na afhankelijke waarden beginnen](#een-onafhankelijke-groep-na-afhankelijke-waarden-beginnen)
    - [Verdieping bij Een onafhankelijke groep na afhankelijke waarden beginnen](#verdieping-bij-een-onafhankelijke-groep-na-afhankelijke-waarden-beginnen)
  - [Puppet Strings](#puppet-strings)
  - [Publieke declaraties bij de code documenteren](#publieke-declaraties-bij-de-code-documenteren)
    - [Verdieping bij Publieke declaraties bij de code documenteren](#verdieping-bij-publieke-declaraties-bij-de-code-documenteren)
  - [Strings API-markering](#strings-api-markering)
  - [Strings-summary op één regel](#strings-summary-op-één-regel)
  - [Strings-parametercontract](#strings-parametercontract)
  - [Uitvoerbare Strings-voorbeelden](#uitvoerbare-strings-voorbeelden)
    - [Verdieping bij Uitvoerbare Strings-voorbeelden](#verdieping-bij-uitvoerbare-strings-voorbeelden)
  - [Strings-regelbreedte](#strings-regelbreedte)
    - [Verdieping bij Strings-regelbreedte](#verdieping-bij-strings-regelbreedte)
  - [Strings-taginspringing](#strings-taginspringing)
  - [Strings-secties met commentregels scheiden](#strings-secties-met-commentregels-scheiden)
    - [Verdieping bij Strings-secties met commentregels scheiden](#verdieping-bij-strings-secties-met-commentregels-scheiden)
  - [Lengtesuppressions in Strings begrenzen](#lengtesuppressions-in-strings-begrenzen)
  - [Waar de uitleg hoort](#waar-de-uitleg-hoort)
  - [Interfacebeschrijvingen synchroniseren](#interfacebeschrijvingen-synchroniseren)
  - [Documentatie op haar aangewezen plaats onderhouden](#documentatie-op-haar-aangewezen-plaats-onderhouden)
  - [Uitvoerbare voorbeeldscenario’s onderhouden](#uitvoerbare-voorbeeldscenarios-onderhouden)

## Algemene documentatienormen

Deze normen gelden voor alle repository-eigen documentatie, inclusief verborgen mappen, geneste componenten, voorbeelden, nieuwe bestanden en centrale of lokale agentinstructies. Beoordeel ieder document naar zijn doelgroep en taak. De aanvullende regels onder [Commentaar en documentatie](#commentaar-en-documentatie) benoemen hun eigen code- en Puppet-scope; Puppet Strings-tags zijn geen vereiste voor andere talen.

### Taal en informatieplaatsing

Schrijf technische documentatie in het Engels, inclusief changelogteksten en ieder root- of lokaal `AGENTS.md`, behalve de Nederlandstalige bronnen: root-`README.md`, `CONTRIBUTING.md`, `TESTS.md`, alle eigen README's op iedere diepte onder `.tools/` (ook nieuwe tools) en de drie regelsdocumenten `CODE_RULES.md`, `DOCUMENTATION_RULES.md` en `OPERATIONAL_RULES.md`. Een expliciet verzoek van de gebruiker kan een andere taal bepalen. Pas duurzame documentatie toe op bestaande en toekomstige Markdown volgens het doel van het document.

Voeg alleen een ADR toe wanneer gevraagd of al gebruikelijk. Dit ontslaat je niet van documentatie van de geraakte interface of het gedrag.

#### Informatieplaatsing

Ieder onderwerp heeft één volledige, onderhouden uitleg. Andere locaties mogen een korte samenvatting en een gerichte verwijzing geven; de samenvatting maakt de relevantie of het gevolg zelfstandig duidelijk. De bestandsextensie bepaalt niet hoeveel detail nuttig is: een beheerhandleiding of normdocument mag uitgebreid zijn wanneer de lezer dat voor zijn taak nodig heeft.

Iedere duurzame norm heeft precies één gezaghebbende locatie. Bepaal die aan de hand van de beslissing die de norm regelt, niet van het bestand waar het probleem is gevonden. Splits gemengde passages vóór toewijzing en gebruik voor toolprocedures de specifieke eigenaar hieronder.

| Bron | Verantwoordelijkheid |
| --- | --- |
| Root-`README.md` | Doel, installatie, algemene voorwaarden, beginnen en ingangen naar modules, voorbeelden en procedures, met een vindbare ontwikkelaarsingang. |
| [CONTRIBUTING.md](../../../../CONTRIBUTING.md) | Gezamenlijke voorbereiding, scope, ontwikkelworkflow, impact- en beveiligingsreview, Git-beleid, versiebeleid en oplevering. |
| [TESTS.md](../../../../TESTS.md) | Repositorybreed testbeleid, toepasselijkheid en volgorde van verplichte controles, scenarioselectie, aanvullende validatie en bewijsvoering. |
| Root- en lokale `AGENTS.md` | Verplichte agentleesroutes, instructiehiërarchie en werkelijk agentspecifieke aanwijzingen. |
| [Gedeelde tooling-README](../../../README.md) | Installatie, pakketkeuze, modulepad, commando-overzicht, CI, rapporten, consumerintegratie, distributie, gezamenlijke tooltests en gedeeld toolingonderhoud. |
| Tool-README's | Publieke interfaces, architectuur, ondersteund gebruik, componentonderhoud, verificatie en concrete testaanroepen; vind de eigenaar via het [tooloverzicht](../../../README.md#pakketten-en-commandos). |
| [Lint-README](../README.md) | Lintgebruik, dagelijkse correctiewerkwijze, het enige checkregister, configuratie, autofixgedrag, architectuur, lintonderhoud en linttestaanroepen. |
| [CODE_RULES.md](CODE_RULES.md) | Algemene codeprincipes voor alle eigen talen en componenten, inclusief tooling; herkenbaar afgebakende taalregels, voorwaarden, uitzonderingen, handmatige reviewcriteria, detectie- en autofixgrenzen en voorbeelden. Puppet-syntax en resourceregels gelden alleen voor Puppet. |
| Dit document | Algemene documentatienormen en aanvullende codecommentaar-, Puppet Strings- en interfaceafspraken, met toepasselijke uitzonderingen, detectie- en autofixgrenzen en voorbeelden. |
| [OPERATIONAL_RULES.md](OPERATIONAL_RULES.md) | Operationele implementatie en reviewcriteria voor beheerde bestanden, rechten, beveiliging, systemd, shell, runtimeafhankelijkheden en monitoring, met algemene normen en specifieke uitwerkingen, uitzonderingen, detectie- en autofixgrenzen en voorbeelden. |
| Puppet Strings | Betekenis, invoerbeperkingen en gevolgen van publieke class-, defined-type- en functieparameters, direct boven die interface. De declaratie beheert type en default. |
| Implementatiecomments | Redenen voor technische keuzes, volgorde en uitzonderingen bij de betrokken code. Scripts onderhouden hun opties in de bestaande usage- of hulptekst. |
| `examples/` | Samenhangende configuratiescenario's met meerdere onderdelen. |
| Bestaande passende procedure | Herbruikbare beheer-, herstel- en datamigratieprocedures, met voorwaarden, volgorde en verwachte resultaten. |
| Gegenereerde parameterreferentie | Eventueel een reeds gebruikte leesbare referentie buiten de editor; onderhoud via de codebron en het bestaande generatieproces. |
| Tooltests | Toolgedrag, regressies, grenzen, fouten en automatisch verifieerbare toolcontracten. |
| Projectdocumentatie | Systeemstructuur, gegevensstromen, componentrelaties en -doel, installatie, deployment, beheer en probleemoplossing. |
| Feature- of implementatiedocumentatie | Featurespecifieke interfaces, implementatiestappen en acceptatiescenario's buiten projectbreed beleid. |
| Configuratiereferentie | Volledige configuratievariabelen, operationele defaults en exacte start- of deploymentcommando's buiten Puppet Strings. |
| ADR's | Architectuurbesluiten, alternatieven, afwegingen en onderbouwing. |
| Release notes of changelog | Wijzigingen per release, breaking changes en concrete overstapstappen vanaf eerdere interfaces, defaults of configuratie. |
| Wijzigingsreviews en uitvoeringsrapporten | Wijzigingsspecifieke beslissingen, compatibiliteitsafwegingen, voortgang, validatiecommando's en resultaten, dekking en open bevindingen. |

- Kies de kleinste toepasselijke eigenaar en splits gemengde scope eerst. Algemene ontwikkelworkflow hoort in CONTRIBUTING, testbeleid in TESTS, gedeeld toolonderhoud in de tooling-README en componentonderhoud in de eigen README. Houd algemene workflow uit de regelsdocumenten; zij bezitten de inhoudelijke normen en hun specifieke reviewcriteria.
- Dupliceer geen volledige norm tussen deze lagen. Verwijs naar de bron wanneer een workflowverplichting van een code- of implementatienorm afhangt. Een korte toelichting is alleen gerechtvaardigd voor een eigen lezersbeslissing en mag geen tweede norm worden: voorwaarden, uitzonderingen en concrete eisen blijven bij de eigenaar. Checklists verwijzen daarnaar zonder de norm opnieuw te definiëren.
- Houd codestijl, layout, naamgeving en implementatieconventies bij het passende regelsdocument, niet in agentinstructies. Lintarchitectuur hoort bij de lint-README, gedeelde packagearchitectuur en installatie bij de tooling-README.
- Eigenaarschap hangt niet af van automatisering. De regelsdocumenten zijn de centrale code- en implementatiestandaard, ook voor gedeeltelijke detectie, uitsluitend detectie en volledig handmatige normen. Een ontbrekende check of onveilige autofix verplaatst de norm niet naar `AGENTS.md` en maakt haar niet optioneel.
- Classificeer een nieuwe algemene afspraak vóór bewerken, ook als de vraag haar een agentregel noemt of `AGENTS.md` noemt. Voeg daar alleen de verwijzing toe die agents nodig hebben om de gezamenlijke bron te vinden. Pas dit eigenaarschap ook toe op onderhoud van bestaande normen en verwijzingen.
- De twee rootdocumenten CONTRIBUTING en TESTS bestaan naast de vier centrale lintdocumenten; zij vormen geen vijfde lintregelsdocument. Behoud de [lintdocumentgrenzen](../README.md#grenzen-van-de-lintdocumentatie), inclusief het enige checkregister, en maak geen extra regelsbestand per klein onderwerp.

### Duurzame documentatie

- Beschrijf ondersteund gedrag, verantwoordelijkheden, voorwaarden en herbruikbare procedures rechtstreeks in de tegenwoordige tijd. Leg een blijvende keuze uit wanneer de reden een beperking begrijpelijk maakt of correct handelen ondersteunt. Werk bij veranderd gedrag de bestaande uitleg bij in plaats van taakgeschiedenis toe te voegen.
- Plaats wijzigingsgebonden migratie-instructies, oude-naar-nieuwe parametermappings en vergelijkingen met eerdere interfaces of defaults uitsluitend in release notes of een changelog. README's, gebruikshandleidingen, voorbeelden en parameterdocumentatie beschrijven het huidige ondersteunde gebruik. Bewaar input voor nog niet voorbereide release notes bij de wijzigingsreview; voeg die niet tijdelijk aan gebruiksdocumentatie toe. Behoud blijvende voorwaarden, risico's en herbruikbare beheer- of datamigratieprocedures bij de actuele handeling, zonder versiegeschiedenis.
- Houd voortgang, voltooiingsclaims, afzonderlijke validatieresultaten en wijzigingsspecifieke oordelen in de review of een passend uitvoeringsrapport. Een instructie om een reviewuitkomst vast te leggen of te onderbouwen bedoelt die bestemming tenzij zij een andere noemt. Blijvende interface-eisen en noodzakelijke lokale implementatieredenen horen bij hun gezaghebbende documentatie of code. Maak geen permanent Markdown-document per bevinding.
- Onderhoud ieder technisch feit op één plaats. Verwijs voor veranderlijke waarden naar de configuratie, implementatie, het register of de referentie; leg zo nodig een bestaande opvraagopdracht uit. Behoud alleen een korte samenvatting voor een eigen lezersbehoefte, met voorwaarden en volledig detail bij de eigenaar. Een link moet de benodigde informatie leveren en mag ontbrekende uitleg niet verhullen.
- Vermijd onnodige kopieën van versies, aantallen, namen, omgevingen, status en voorbeelduitvoer. Gebruik herkenbare placeholders voor eigen invoer en leg de herkomst uit. Behoud letterlijke waarden die nodig zijn voor geldige commando's, defaults, eenheden, limieten, compatibiliteit, migratiegrenzen, waarschuwingen en exacte contracten. Label illustratieve uitvoer; wijzig dependency-pins of runtimegedrag niet om waarden niet te hoeven documenteren.
- Beoordeel alle eigen Markdown naar doel, inclusief verborgen mappen, geneste componenten, voorbeelden en instructies. Historische rapporten behouden gebeurtenis, datum of identificatie en noodzakelijke feiten; een statusregister maakt doel en geldigheid duidelijk. Behoud juridische tekst en fixtures met exacte inhoudscontracten. Corrigeer bij gegenereerde uitvoer eerst de beheerde bron en genereer opnieuw. Benoem extern eigenaarschap en de upstreamonderhoudsroute; bewerk dependencies niet als eigen proza.
- Houd noodzakelijke workarounds en beperkingen naast de betrokken actie, met voorwaarde, gevolg en vereiste handeling. Verwijs voor veranderlijke voortgang naar haar bron. Verifieer vermeende veroudering vóór verwijderen van een waarschuwing, uitzondering of technische beperking en meld onopgeloste verschillen volgens de technische review.

### Markdown

- Gebruik relatieve paden vanaf het huidige Markdown-bestand voor eigen bestanden en mappen, met `#anker` voor eigen secties. Zet daarin geen hostingdomein, repository-eigenaar, repositorynaam, branch of absoluut filesystempad vast. Dit geldt ook voor verpakte documentatie; links buiten een gem vereisen de bijbehorende checkout. Gebruik de herkenbare placeholder `<repository-url>` voor clone- en Git-bronvoorbeelden. Externe documentatielinks behouden hun echte URL.
- Onderhoud bovenaan ieder eigen `.md`-bestand een gekoppelde inhoudsopgave, behalve bij de enige bestandsnaamexceptie: `AGENTS.md` op iedere diepte. Neem alle secties en subsecties op alle dieptes in documentvolgorde op, genest volgens de headinghiërarchie, zonder documenttitel of headings in codevoorbeelden. Beperk alleen bij root-`README.md` de inhoudsopgave tot niveau twee en drie. Werk haar bij en controleer de links bij gewijzigde headings.
- Houd zinnen, alinea's, lijsten, tabellen en voorbeelden bij het onderwerp van hun heading en in logische leesvolgorde. Introduceer begrippen vóór gebruik en verbind uitleg vóór en na voorbeelden en tabellen. Herschrijf omringende tekst als verplaatsing of toevoeging die samenhang breekt.
- Houd iedere prozaalinea of lijstitem op één fysieke regel zonder harde regelafbreking, behalve waar Markdownsyntax, tabellen of codeblokken dat vereisen. Scheid onderwerpen met gewone alineagrenzen en schrijf professioneel, concreet en gericht op operationele gevolgen en risico's.

## Redactionele review

### Doelgroep en leesroute

#### Vóór bewerken

- Bepaal de lezer en taak van ieder geraakt document; onderscheid modulegebruik, moduleontwikkeling en toolingonderhoud.
- Bepaal bij iedere inhoudelijke wijziging welke informatie ontbreekt, onjuist of geraakt is, inclusief interfaces, gebruiksvoorwaarden, risico's en eigenschappen. Benoem welke keuze, voorbereiding, actie, verwachte uitkomst of concrete waarschuwing zij ondersteunt. Noteer geraakte documenten of de reden dat bijwerken niet nodig is in de review; een bestaand documentatiegat binnen het geraakte onderwerp kan ook een update rechtvaardigen.
- Lees vóór iedere inhoudelijke wijziging en iedere bewerking van eigen Markdown de volledige geraakte secties en omliggende leesroute, ook bij `AGENTS.md` en kleine aanvullingen. Lees voor de root-README de volledige geraakte modulesectie en pas de scope- en configuratierichtlijnen toe.
- Inventariseer bij een projectbrede Markdown-review zowel versiebeheer als het filesystem, inclusief verborgen, genegeerde, nieuwe en anders gekapitaliseerde Markdown, zonder versiebeheeropslag. Lees ieder gevonden bestand volledig. Noteer pad, doel, eigenaar, eventuele generatiebron, oordeel, actie en bijzondere behandeling in review of uitvoeringsrapport. Zoekpatronen en automatische controles bewijzen geen volledige inhoudelijke dekking.

#### Tijdens bewerken

- Integreer wijzigingen in de bestaande uitleg en verbind omringende tekst volgens de Markdownregels. Beschrijf actueel gebruik als een samenhangend geheel volgens taal en informatieplaatsing.
- Vraag bij iedere toevoeging, herschrijving, verplaatsing en voorgenomen verwijdering: welke keuze, voorbereiding, handeling of interpretatie van de bedoelde lezer ondersteunt deze informatie? Beoordeel de volledige passage en de omringende uitleg op document- en headingscope, nuttige informatie en consistentie. Pas voor gebruikersbeschrijvingen de [README-richtlijn voor scope en configuratie](#scope-en-configuratie) toe.
- Behoud bij consolidatie samenvattingen, opvallende waarschuwingen en prerequisites die een eigen beslissing of ingang bedienen. Herhaling alleen rechtvaardigt geen verwijdering.
- Controleer of een passage onjuist zou worden door een incidentele waarde- of statuswijziging. Pas duurzame documentatie toe op betekenis en doel, niet door alleen een getal, datum of woord te schrappen.
- Verwijder passages zonder taak voor de lezer; verplaats ze niet automatisch naar een andere heading, een commentaarblok, voorbeeld of nieuw document. Geef noodzakelijke ontwikkelaarskennis alleen een andere bestemming wanneer zij duurzaam nuttig is en een passende bestaande plek heeft. Controleer die bestemming en behoud een gerichte verwijzing als de gebruiker die nodig heeft. Verwijder overbodige parameteruitleg die een gelinkt contract herhaalt en heroverweeg de subheading; behoud lokaal gerechtvaardigde samenvattingen, waarschuwingen en beperkingen, ook als zij veel tekst vragen.

#### Na bewerken

- Herlees de volledige geraakte secties en leesroute, inclusief de hele geraakte root-README-modulesectie, niet alleen de diff. Controleer samenhang, plaatsing en of de gebruikersgids geen tweede parameterreferentie of implementatiehandleiding is geworden. Een nieuwe lezer moet prerequisites, volgende actie en verwachte uitkomst kunnen vinden zonder ontbrekende context te reconstrueren.
- Controleer volgens [duurzame documentatie](#duurzame-documentatie) dat geraakte gebruiksuitleg geen wijzigingsgebonden migratietekst bevat, dat release-informatie op haar bestemming is vastgelegd en dat actuele voorwaarden en waarschuwingen behouden zijn. Beoordeel de betekenis; alleen zoeken naar migratiewoorden bewijst dit niet.
- Herlees bij projectbrede review volledige gewijzigde documenten en sluit de eindinventaris aan op de oorspronkelijke lijst, met toevoegingen, verplaatsingen en verwijderingen. Geef ieder bestand een afgerond oordeel of expliciet open punt. Controleer dat centrale en lokale instructies overeenstemmen en naar unieke normeigenaars verwijzen. Bewaar dit bewijs bij de wijziging, buiten permanente projectinstructies.

### Technisch bewijs en links

- Verifieer gewijzigde, verplaatste of als verouderd verwijderde technische claims tegen actuele manifests, Puppet Strings, scripts, templates en voorbeelden. De README is geen implementatiebewijs.
- Meld onopgeloste verschillen tussen documentatie en implementatie en behoud noodzakelijke waarschuwingen totdat het verschil is opgelost.
- Controleer commando's, paden, opties en verwijzingen tegen voorbeelden en actuele implementatie. Controleer gewijzigde links en relatieve repositorylinks met de [documentatietests](../../../repository/README.md); beoordeel externe bestemmingen afzonderlijk. Controleer dat verplaatste informatie daadwerkelijk op de bestemming staat.

### Proza beoordelen

Lees de passage als doorlopende uitleg, inclusief ongewijzigde omgeving. Corrigeer onnatuurlijke formulering, wisselende terminologie, abrupte overgangen en onverklaarde onderwerpwisselingen zonder technische betekenis te veranderen. Vergelijk gewijzigd lint-README-proza met representatieve root-README-passages volgens de README-stijlafspraken. Neem een korte representatieve passage op in de review voor feedback van de eigenaar en gebruik een geaccepteerde passage als concreet stijlvoorbeeld.

### Grenzen van redactionele automatisering

Een technische controle bewijst nooit dat uitleg duidelijk, prettig leesbaar of nuttig is. Gebruik geen AI-detectiescores of woordenblacklists voor stijlkwaliteit of relevantie. Leg geen vaste aantallen of lengtes van woorden, zinnen of alinea's op aan verklarend proza, ook niet via tests. Pas bij normteksten de [regelstructuur](#regelstructuur-en-formulering) toe.

## README-richtlijnen

### Scope en configuratie

- Pas inhoud aan doel en doelgroep aan; leg moduleoverzichten en toolinghandleidingen niet dezelfde outline op. De root-README helpt technisch vaardige beheerders het project te begrijpen, gebruiken en beheren; exacte parameters, paden, voorwaarden en statusnamen kunnen daarvoor noodzakelijk zijn. Gebruik vóór, tijdens en na root-README-wijzigingen de redactionele review.
- Voeg detail aan de root-README uitsluitend toe wanneer gebruikers het vóór gebruik of tijdens de beschreven handeling nodig hebben, het een beveiligings- of compatibiliteitskeuze verandert of het basisvoorbeeld het vereist.
- Neem programmeertalen, interne bibliotheken, parsingmethoden, hulpprogramma's en automatisch beheerde afhankelijkheden alleen op in gebruikersbeschrijvingen wanneer zij nodig zijn voor een concrete gebruikerskeuze, installatievoorwaarde, beheerhandeling of interpretatie van een resultaat. Maak het gevolg voor de gebruiker duidelijk. Technische juistheid of belang tijdens de ontwikkeling is op zichzelf onvoldoende. Laat opsommingen van niet-gebruikte technieken of pakketten zonder concrete gebruiksnoodzaak weg.
- Behoud een zelf te installeren afhankelijkheid, relevante platformbeperking of concrete herstelstap op de passende bestaande plek. Ook een automatisch geïnstalleerde afhankelijkheid kan een ondersteund platform of installatievoorwaarde bepalen; beschrijf dan die voorwaarde. Onderscheid uitrol via Puppet van ondersteund zelfstandig scriptgebruik: houd de vereisten voor dat laatste bij de bestaande scriptheader, hulptekst of gebruiksinstructie en controleer of ze daar werkelijk staan voordat een noodzakelijke verwijzing verdwijnt.
- Kies gebruikersinformatie afzonderlijk van parametercontracten en implementatiekennis. Parameter-voor-parameterinstructies, volledige contracten en ontwikkelaarsspecifieke implementatiekennis blijven buiten de rootgebruikersgids bij hun eigenaar. Een codewijziging of nieuwe parameter rechtvaardigt niet vanzelf een README-aanvulling; onderzoek eerst of bestaande uitleg correctie nodig heeft.
- Gebruik een gerichte link naar Strings of een bestaand voorbeeld wanneer die volstaat. Onderbouw extra proza met wat de lezer anders niet correct en veilig kan kiezen, doen of begrijpen. Werk standaard bestaande uitleg bij, overal in de root-README en niet alleen onder aandachtspunten. Voeg een passage of subsection alleen toe voor een aparte relevante taak of noodzakelijke uitleg; een featurenaam of parametergroep is op zichzelf geen taak.
- Hergebruik documentatie voor uitgebreide varianten en parameterdetails; maak geen document per detail en kopieer geen volledige contracten tussen lagen.
- Verifieer vóór voorgeschreven configuratie wat defaults, overerving en gedeclareerde componenten al leveren. Beschrijf dat effectieve gedrag eerst. Leg aanvullende configuratie alleen uit als de lezer een keuze of handeling nodig heeft; presenteer optionele overrides niet als verplichte inrichting.
- Houd actuele, blijvende gebruiksvoorwaarden bij de betrokken handeling; plaats wijzigingsgebonden overstapstappen volgens [duurzame documentatie](#duurzame-documentatie) bij release notes of changelog.

### Stijl en uitleg

- Schrijf als een ervaren collega voor een technisch vaardige lezer die het project nog niet kent. Gebruik representatief root-README-proza als referentie voor een directe, praktische infrastructuurtoon, niet als template of kwaliteitsbewijs. Kopieer onnatuurlijke of te samengeperste tekst niet omwille van consistentie.
- Schrijf gewoon, toegankelijk Nederlands rond exacte identifiers. Kies vertrouwde Nederlandse woorden boven onnodig Engels of abstract toolingjargon en spreek de lezer direct aan. Behoud natuurlijke verbindingen zonder boilerplate, stockovergangen, ongebruikelijke synoniemen, reclame of geforceerde informaliteit.
- Organiseer gebruiksuitleg rond de lezerstaak, niet de implementatievolgorde of reviewvereisten. Geef iedere alinea één samenhangend onderwerp; scheid onafhankelijke aanwijzingen in plaats van ze voor beknoptheid samen te persen. Beschrijf concrete acties, voorwaarden en gevolgen en verklaar niet-vanzelfsprekende keuzes wanneer dat handelen helpt.
- Gebruik headings, lijsten en tabellen waar navigatie of vergelijking dat vraagt. Behoud nuttige lijsten zoals eigenschappen en installatiestappen. Voeg geen vulling toe om secties uniform te maken; het lintdocumentatiecontract onderscheidt automatische controles van handmatige normen.
- Behoud noodzakelijke technische termen en exacte identifiers; leg projectbegrippen vóór gebruik uit. Begin README-prozalijstitems met een hoofdletter, met behoud van case van identifiers, module- en classnamen, paden en literals. Behoud bedoelde auteursstandpunten en relevante projectcontext bij herindeling.
- Behoud noodzakelijke technische eisen, waarschuwingen, uitzonderingen, waarborgen en operationele kennis bij hun eigenaar; volg voor lint de [documentgrenzen](../README.md#grenzen-van-de-lintdocumentatie). Voeg geen extra documentlaag toe om omvang te reduceren. Verwijder duplicaten en aantoonbaar verouderde informatie pas na redactionele review.

### Navigatie en prerequisites

- Houd prerequisites, essentiële waarschuwingen en beveiligings- of compatibiliteitsvoorwaarden naast de geraakte actie, ook bij verplaatsing van verdieping. Verbind de achterblijvende waarschuwing en actie met de nieuwe uitleg.
- Houd placeholderhostnamen, vervangwaarden, Hiera-uitleg en de behandeling van `Sensitive`-wrappers bij de quick start.
- Gebruik in Nederlandse README's `## Inhoudsopgave`, nooit `Legenda`. Onderhoud onderaan een lijst met uitgebreide voorbeelden.

### Modulesecties

Behoud de bestaande modulevolgorde. Help de lezer begrijpen wat het onderdeel doet, voor wie het bruikbaar is, wat nodig is en hoe hij begint. Gebruik een algemeen basisvoorbeeld dat past bij het onderdeel; specifieke platform- en toepassingsscenario's krijgen een herkenbare ingang naar hun bestaande voorbeeld of procedure. Het voorbeeld toont alleen de daarvoor benodigde parameters en voorwaarden.

Kies de indeling op de taak. Herhaal dezelfde eigenschappen niet onder doel, mogelijkheden en eigenschappen. Gebruik geen vaste aantallen koppen of eigenschappen. Een root-README beschrijft het project en de ingang naar onderdelen; een tool-README behandelt het gebruik en onderhoud van die tool. Behoud belangrijke gevolgen en afwijkende standaardinstellingen bij de ingang, met een gerichte link naar de uitwerking. Link naar de concrete publieke class, functie, het defined type of de procedure wanneer die bekend is; alleen “de code” of een grote map is onvoldoende. Onderhoud geen volledige handmatige parametertabel naast de broncodedocumentatie.

#### Belangrijke aandachtspunten

- Beperk deze sectie tot modulespecifieke voorwaarden, risico's, beperkingen en niet-vanzelfsprekende keuzes voor correct gebruik, een relevante keuze of het voorkomen van een concrete fout, onveiligheid of onverwachte wijziging.
- Sluit volledige parameterbeschrijvingen, interne uitvoeringsvolgorde, testresultaten, ontwikkelgeschiedenis en algemeen beheeradvies zonder concrete gebruiksnoodzaak uit. Neem bestandsnamen, rechten, defaults en ander technisch detail alleen op als het een gebruikerskeuze of -actie beïnvloedt.
- Beoordeel ernst naast frequentie. Verwijder waarschuwingen voor gegevensverlies, verlies van beheertoegang, overschreven configuratie, beveiliging of incompatibiliteit nooit alleen wegens zeldzaamheid of tekstlengte.
- Maak toepasselijke voorwaarde, gevolg en vereiste actie duidelijk zonder vast zinsjabloon. Gebruik proza voor samenhangende uitleg, een lijst voor afzonderlijke voorwaarden en nummering voor uit te voeren stappen. Laat de heading weg wanneer geen relevante aandachtspunten overblijven. Behoud complete beheer-, herstel- en migratieprocedures; laat de lezer de volgorde niet uit losse parametercomments reconstrueren.

## Afspraken onderhouden

Deze criteria gelden voor duurzame gezamenlijke afspraken en agentroutes. Kies de kleinste eigenaar volgens informatieplaatsing; een componentwijziging vereist geen rootwijziging zolang routing en projectbrede afspraken correct blijven. Specifiek laden en volgen van agentinstructies wordt in de agentroute geregeld.

### Wijzigingsbereik en noodzaak

- Lees vóór inhoudelijke wijziging het volledige geraakte afsprakenbestand zodat bestaande regels, uitzonderingen en verwijzingen worden meegenomen. Werk de eigenaar bij wanneer een conventie, architectuurgrens, validatiecommando, beveiligingseis of operationele werkwijze verandert; codeafspraken blijven bij hun regelbron en de rootroute verandert alleen waar nodig.
- Beperk routineonderhoud tot geraakte regels en direct betrokken verwijzingen. Herstructureer een heel bestand alleen op expliciet verzoek of bij gedocumenteerde tegenspraak tussen secties.
- Bepaal vóór nieuw beleid het doel, vereiste gedrag of blijvende kennis, scope, uitzonderingen en eigenaar, ook als de opdracht al een bestandsnaam noemt. Zoek bestaande regels die dit geheel of gedeeltelijk dekken.
- Onderscheid ontbrekend beleid, vindbaarheids- of interpretatieproblemen en verificatiegaten van het niet volgen van een duidelijke, vindbare regel. Herhaalde overtreding alleen rechtvaardigt geen nieuwe regel; onderzoek welke instructie, uitvoeringsstap of reviewverbinding faalde.
- Laat afspraken ongewijzigd wanneer bestaand beleid volledig en ondubbelzinnig dekt en plaatsing en verificatie geen verbetering vragen, ook na herhaalde overtreding. Herstel uitvoeringsfouten via de werkwijze. Verduidelijk of consolideer bij gebrekkige vindbaarheid, interpretatie of verificatie de eigenaar of diens reviewverbinding. Een vergelijkbare regel elders is geen reden om gerichte verbetering af te wijzen. Verbreed uitsluitend op basis van bestaande autoriteit of expliciete opdracht; voeg alleen nieuw beleid toe voor nog ongedekt noodzakelijk duurzaam gedrag.

### Inhoud behouden en samenbrengen

- Bewaar alleen duurzame afspraken binnen de scope van de eigenaar en blijvende kennis voor latere ontwikkeling. Neem geen taak-, ticket-, bug-, feature- of promptgeschiedenis op, behalve historische context die noodzakelijk is voor een technisch contract of bewuste uitzondering.
- Zet opdrachten, terugkerende reviewbevindingen, productie- of beveiligingsproblemen, testfouten, toolingwijzigingen en agentfouten alleen om in regels wanneer het benodigde gedrag verder reikt dan één taak. Kopieer een opdracht niet letterlijk als beleid alleen omdat om een beleidsupdate is gevraagd.
- Plaats featurespecifieke implementatiekennis, configuratiehandleidingen, probleemoplossing, plannen, voorbeelden en concrete scenario's bij hun aangewezen eigenaar. Behoud exacte namen, waarden en versies waar contract, beperking, uitzondering, compatibiliteit of beveiliging die vereisen.
- Behoud relevante techniek, uitleg, voorbeelden en verificatie-instructies bij de juiste eigenaar. Een structurele bewerking rechtvaardigt geen herverdeling van unieke inhoud. Review eigendomsoverdracht als inhoudelijke wijziging, met behoud van informatie en een gerichte verwijzing; eigendomsoverdracht staat nooit informatieverlies toe.
- Consolideer dubbele of zwakkere varianten uitsluitend met behoud van hun volledige betekenis: afzonderlijke voorwaarden, uitzonderingen, uitleg, voorbeelden en verificatie-eisen. Orden op onderwerp en werkelijk bereik, niet op oorspronkelijke taak; plaats uitzonderingen direct bij de regel.
- Combineer alleen regels met hetzelfde doel, bereik, gedrag en beslismoment zonder zelfstandige verplichtingen te verbergen. Consolideer bij gedeeltelijke overlap de gedeelde norm en behoud aanvullende voorwaarden zichtbaar. Pas de grenzen voor samenvattingen en checklists toe en kopieer projectbeleid nooit naar codecommentaar.

### Regelstructuur en formulering

- Gebruik een herkenbare heading per zelfstandig onderwerp of beslisdomein. Gebruik normatieve bullets wanneer die regels onderscheidbaar maken, met samenhangende voorwaarden en uitzonderingen bij elkaar. Splits alleen als onafhankelijke beslissingen daardoor duidelijker worden, niet uitsluitend omdat een regel meerdere samenhangende zinnen bevat.
- Stel geen vaste limieten aan woorden, zinnen, bullets, headings of nestingdiepte; kies een begrijpelijke structuur. Gebruik proza voor samenhangende uitleg, definities, doel, reden en context. Orden waar nuttig van algemeen naar specifiek, zonder vast sectiesjabloon. Tabellen dienen echte matrices of vaste relaties, niet het verbergen van lange prozaregels.
- Formuleer actief en concreet met consistente terminologie, expliciet bereik en triggers, verplicht gedrag en technische grenzen. Generaliseer alleen zover de afspraak draagt, met behoud van specifieke grenzen en uitzonderingen.
- Gebruik verplichtende taal voor eisen en verboden; reserveer mogen, kunnen, bij voorkeur en optioneel voor werkelijke keuzevrijheid. Benoem hoe naleving wordt geverifieerd als dat niet duidelijk is.
- Geef volledigheid, juistheid, leesbaarheid, scope en traceerbaarheid voorrang boven minder woorden of headings. Verbeter ordening zonder informatie samen te persen; maak van onafhankelijke eisen geen dichte alinea om het document te verkorten.

### Conflicten beoordelen

- Behoud bij consolidatie de sterkste toepasselijke beveiligingsregel.
- Corrigeer onduidelijke, verouderde, onjuiste of tegenstrijdige normen alleen wanneer repositorybewijs of een expliciete projectbeslissing de bedoeling vaststelt. Een verschil tussen code en documentatie bewijst niet welke fout is.
- Noteer inhoudelijke beleidswijzigingen, tegenstrijdigheden en redenen voor correctie of verwijdering in de review: betreffende passages, oude en nieuwe betekenis en ondersteunend bewijs of besluit.
- Houd onbeslisbare informatie herkenbaar, markeer het conflict als onopgelost en benoem de ontbrekende beslissing. Ga door met onbetwist werk, maar presenteer het resultaat niet als conflictvrij en kies niet automatisch de strengste, breedste of schijnbaar veiligste tekst.

### Eindreview van afspraken

- Vergelijk met de eerdere versie via de [toegestane Git-inspectie](../../../../CONTRIBUTING.md#git-inspectie), met gecontroleerde analysekopieën voor gevoelige inhoud. Verifieer behoud bij de eigenaar van iedere oorspronkelijke verplichting, verbod, voorkeur, voorwaarde, uitzondering, technisch contract, compatibiliteitseis, waarborg, uitleg, voorbeeld en verificatie-instructie, of een expliciet onderbouwde correctie. Controleer bij eigendomsoverdracht ook de werkende verwijzing.
- Controleer dat verbreding en herindeling verplichtingen niet optioneel en opties niet verplicht maken. Review iedere gewijzigde norm handmatig op noodzaak, herbruikbaarheid, scanbaarheid, unieke plaats, ondubbelzinnigheid en consistentie met instructieketen, terminologie en verwijzingen.
- Voer automatische controles op letterlijke duplicaten en lokale links uit met bestaande tooling of geïsoleerde tijdelijke controles. Review betekenis, structuur en leesbaarheid handmatig, zonder numerieke prozalengte-eisen.
- Leg voor iedere inhoudelijke regelwijziging bestaand beleid, reden, behouden verplichtingen en uitzonderingen vast buiten permanente instructies. Controleer ook de omgekeerde richting: iedere nieuwe verplichting, uitzondering of technische claim moet steunen op eerder beleid, een bestaande projectafspraak of expliciete opdracht. Maak open conflicten zichtbaar vóór oplevering.

## Commentaar en documentatie

<!-- lint-rule-group -->

Gebruik implementatiecomments voor redenen, betekenisvolle samenhang en niet-vanzelfsprekende beperkingen, bij de betrokken code. Herhaal niet alleen de volgende regel of een duidelijke variabelenaam. Behoud nuttige technische onderbouwing; verzamel haar niet in één groot commentblok bovenaan het bestand.

De onderstaande regels gelden voor Puppet, tenzij het toepassingsgebied expliciet alle eigen code noemt. In die algemene gevallen blijven Puppet Strings-tags, Puppet-opmaak en de lintdetectie beperkt tot hun beschreven Puppet-uitwerking.

### Toelichtingen bij code

<!-- lint-rule-group -->

### Toelichtingsblokken van eerdere code scheiden

**Norm**

Een zelfstandig toelichtingsblok begint na een lege regel wanneer er code aan voorafgaat. Aaneengesloten commentaarregels vormen samen één blok; commentaar achter code en lintmarkeringen vormen geen nieuwe toelichting. Direct na `{`, `[` of `(` is geen lege regel vóór het commentaar nodig.

Bij een lokaal gedeelde berekening voor één resource of ondersteunde zelfstandige instructie blijft het gewone leidende toelichtingsblok boven de combinatie van voorbereiding en handeling: commentaar, toekenning en instructie volgen zonder extra lege regel. Bij meerdere eigenaren staat de gedeelde toekenning vóór het commentaar van de eerste eigenaar, met één lege regel ertussen. Bepaal eigenaarschap uit codegrenzen, niet uit commentaarwoorden of gelijke teksten. Behoud bestaande commentaarinhoud en inline bindingen; verander het bereik van lintmarkeringen, Strings-documentatie, formatteringsaanwijzingen en beheer- of licentieheaders niet. De [groepsuitleg bij blokbegin](#een-variabelegroep-bij-blokbegin-toelichten) blijft verplicht.

**Herkomst**

Projectregel; de bestaande norm blijft van kracht waar automatische dekking ontbreekt.

**Toepassingsgebied**

Een zelfstandig toelichtingsblok begint na een lege regel wanneer er code aan voorafgaat. Aaneengesloten commentaarregels vormen samen één blok; commentaar achter code en lintmarkeringen vormen geen nieuwe toelichting. Direct na `{`, `[` of `(` is geen lege regel vóór het commentaar nodig.

**Automatische controle**

`project_comment_spacing`

**Detectiegrenzen**

Direct na {, [ of ( hoeft geen lege regel vóór commentaar. Een trailing comment of lintmarkering is geen zelfstandig toelichtingsblok. De inhoudelijke juistheid van de uitleg blijft review.

**Meldingen en severity**

`Put a blank line before a standalone explanatory comment block`: `warning` wanneer een zelfstandig toelichtingsblok direct op code volgt.

**Autofix**

Voorwaardelijk

**Autofixvoorwaarden**

Voegt alleen een lege regel vóór bestaande uitleg toe; behoudt aaneengesloten comments, trailing comments en genegeerde delen.

**Toegestane uitzonderingen**

Direct na {, [ of ( hoeft geen lege regel vóór commentaar. Een trailing comment of lintmarkering is geen zelfstandig toelichtingsblok.

**Suppressions**

Suppressie niet toegestaan voor deze projectchecks. De afzonderlijke lengte- en bronuitzonderingen veranderen deze regel niet.

**Onjuist voorbeeld**

Fragment; alleen de controle `project_comment_spacing` is voor dit voorbeeld bedoeld. Verwacht een warning.

<!-- lint-example: project_comment_spacing warning -->
```puppet
$value = 1
# Explain the next value.
$other = 2
```

**Correct voorbeeld**

Fragment; alleen de controle `project_comment_spacing` is voor dit voorbeeld bedoeld. Verwacht geen melding voor deze check; de gewijzigde constructie voldoet aan de norm.

<!-- lint-example: project_comment_spacing clean -->
```puppet
$value = 1

# Explain the next value.
$other = 2
```

**Grensgevallen**

Direct na {, [ of ( hoeft geen lege regel vóór commentaar. Een trailing comment of lintmarkering is geen zelfstandig toelichtingsblok.

**Handmatige review**

Vergelijk de toelichting met de direct betrokken verwerking en controleer dat scheiding en witruimte haar bij de juiste resource of het juiste blok houden.

**Verificatie**

De voorbeeldparen worden via de native engine gecontroleerd door `guide/examples_test.rb`. Aanvullende detectie-, grens- en fixscenario’s: [comment_spacing_test.rb](../tests/comment_spacing_test.rb), [resource_sections_test.rb](../tests/resource_sections_test.rb), [brace_layout_test.rb](../tests/brace_layout_test.rb), [cli/sections_test.rb](../tests/cli/sections_test.rb). Bij fixes verifiëren `assert_fix` en de CLI-tests de exacte uitvoer, parsergeldigheid, hercontrole en ongewijzigde tweede run. Zie de tests per beschreven grens; een succesvolle lintscan is geen catalogusvalidatie.

#### Verdieping bij Toelichtingsblokken van eerdere code scheiden

`project_comment_spacing` kan de lege regel vóór een bestaand commentaarblok toevoegen. De [accoladeopmaak](CODE_RULES.md#inhoud-direct-na-een-openingsaccolade-beginnen) beschrijft de afzonderlijke `project_layout`-correctie en haar grenzen. `project_resource_sections` controleert of de toelichting bij een nieuwe resource aanwezig is en heeft geen autofix.

### Een resource na een afgesloten blok toelichten

**Norm**

Een resourcedeclaratie na een afgesloten `}` begint met een lege regel en een eigen toelichting direct boven de declaratie. Dat geldt ook voor defined types, resourcedefaults en overrides. Resources die met `->` of `~>` verbonden zijn blijven samen één keten.

**Herkomst**

Projectregel; de bestaande norm blijft van kracht waar automatische dekking ontbreekt.

**Toepassingsgebied**

Een resourcedeclaratie na een afgesloten `}` begint met een lege regel en een eigen toelichting direct boven de declaratie. Dat geldt ook voor defined types, resourcedefaults en overrides. Resources die met `->` of `~>` verbonden zijn blijven samen één keten.

**Automatische controle**

`project_resource_sections`

**Detectiegrenzen**

Dit omvat defined types, resourcedefaults en overrides. Resources verbonden met een relatiepijl blijven samen één keten. De inhoudelijke juistheid van de uitleg blijft review.

**Meldingen en severity**

`Start a resource declaration after a closed block with a blank line and a preceding explanatory comment`: `warning` bij ontbrekende eigen toelichting of scheiding.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: de check verzint geen uitleg en verplaatst geen resources.

**Toegestane uitzonderingen**

Dit omvat defined types, resourcedefaults en overrides. Resources verbonden met een relatiepijl blijven samen één keten.

**Suppressions**

Suppressie niet toegestaan voor deze projectchecks. De afzonderlijke lengte- en bronuitzonderingen veranderen deze regel niet.

**Onjuist voorbeeld**

Fragment; alleen `project_resource_sections`; verwacht warning.

<!-- lint-example: project_resource_sections warning -->
```puppet
if $active { notice('Active') }
notify { 'example': }
```

**Correct voorbeeld**

Fragment; alleen `project_resource_sections`; verwacht geen melding.

<!-- lint-example: project_resource_sections clean -->
```puppet
if $active { notice('Active') }

# Report the independently configured state.
notify { 'example': }
```

**Grensgevallen**

Dit omvat defined types, resourcedefaults en overrides. Resources verbonden met een relatiepijl blijven samen één keten.

**Handmatige review**

Vergelijk de toelichting met de direct betrokken verwerking en controleer dat scheiding en witruimte haar bij de juiste resource of het juiste blok houden.

**Verificatie**

De voorbeeldparen worden via de native engine gecontroleerd door `guide/examples_test.rb`. Aanvullende detectie-, grens- en fixscenario’s: [comment_spacing_test.rb](../tests/comment_spacing_test.rb), [resource_sections_test.rb](../tests/resource_sections_test.rb), [brace_layout_test.rb](../tests/brace_layout_test.rb), [cli/sections_test.rb](../tests/cli/sections_test.rb). Bij fixes verifiëren `assert_fix` en de CLI-tests de exacte uitvoer, parsergeldigheid, hercontrole en ongewijzigde tweede run. Zie de tests per beschreven grens; een succesvolle lintscan is geen catalogusvalidatie.

### Bestaande implementatie-uitleg actueel houden

**Norm**

Controleer bij de review of de uitleg nog klopt en of lange reeksen instellingen herkenbaar zijn gegroepeerd. Vergelijk de passage met goed gedocumenteerde bestaande code en verwijder verouderde, dubbele of overbodige uitleg. Projectbeleid hoort in de documentatie; implementatiecommentaar legt de lokale reden en gevolgen uit.

**Herkomst**

Projectregel

**Toepassingsgebied**

Bestaande toelichtingen in geraakte implementatieblokken van alle eigen code, inclusief scripts, templates, bibliotheken en tooling.

**Automatische controle**

Geen automatische controle voor deze afzonderlijke inhoudelijke verplichting. De gerelateerde technische controles staan bij [Toelichtingen bij code](#toelichtingen-bij-code).

**Detectiegrenzen**

De gerelateerde checks voeren de beschreven runtime- of inhoudelijke beoordeling niet uit. Het verwijderen van uitleg is alleen passend wanneer zij verouderd, dubbel of overbodig is; noodzakelijke lokale redenen blijven staan.

**Toegestane uitzonderingen**

Het verwijderen van uitleg is alleen passend wanneer zij verouderd, dubbel of overbodig is; noodzakelijke lokale redenen blijven staan.

**Onjuist voorbeeld**

Handmatig reviewscenario: Commentaar beschrijft een verwijderde fallback en dupliceert projectbeleid. Keur dit af tegen de norm.

**Correct voorbeeld**

Handmatig reviewscenario: Verwijder verouderde of overbodige uitleg en behoud lokale redenen en gevolgen; laat beleid in de documentatie. Beoordeel de genoemde voorwaarden afzonderlijk.

**Handmatige review**

Vergelijk met de huidige code en goed gedocumenteerde voorbeelden en controleer herkenbare groepering van lange instellingenreeksen.

**Verificatie**

Vergelijk de voorbeeldscenario’s met de norm en voer de hierboven beschreven handmatige review uit. Leg de bevindingen en eventuele functionele validatie vast in de wijzigingsreview volgens de [projectafspraken](../../../../TESTS.md#isolatie-en-bewijsvoering). De voorbeelden zijn geen uitgevoerde host- of modulegedragstests.

### Niet-zichtbare implementatiekeuzes toelichten

**Norm**

Licht vooral de keuzes toe die niet uit de volgende regel blijken. Dat geldt bijvoorbeeld voor een resourcegroep, exec, afgeleide waarde, voorwaardelijke directive, gedelegeerde resource of opruimroute. Ook helpers en templatelogica verdienen uitleg wanneer de invoer, uitvoer of gevolgen voor exitcodes niet vanzelf spreken. Bij escaping, parsing, classificatie, samenvoegen van resultaten en terugvalgedrag helpt zo'n toelichting om een latere wijziging veilig te beoordelen.

**Herkomst**

Projectregel

**Toepassingsgebied**

Alle eigen code: onder meer afgeleide waarden, delegatie, opruimroutes, helpers en templatelogica; resourcegroepen en execs zijn Puppet-uitwerkingen.

**Automatische controle**

Geen automatische controle voor deze afzonderlijke inhoudelijke verplichting. De gerelateerde technische controles staan bij [Toelichtingen bij code](#toelichtingen-bij-code).

**Detectiegrenzen**

De gerelateerde checks voeren de beschreven runtime- of inhoudelijke beoordeling niet uit. Vanzelfsprekende code verlangt geen overbodige herhaling; de norm richt zich op keuzes en gevolgen die niet direct zichtbaar zijn.

**Toegestane uitzonderingen**

Vanzelfsprekende code verlangt geen overbodige herhaling; de norm richt zich op keuzes en gevolgen die niet direct zichtbaar zijn.

**Onjuist voorbeeld**

Handmatig reviewscenario: Een complexe escaping- of terugvalstap heeft geen uitleg over haar gevolgen. Keur dit af tegen de norm.

**Correct voorbeeld**

Handmatig reviewscenario: Beschrijf de reden en de relevante invoer, uitvoer of exitgevolgen wanneer die niet vanzelf spreken. Beoordeel de genoemde voorwaarden afzonderlijk.

**Handmatige review**

Controleer iedere genoemde soort keuze en koppel de uitleg aan het lokale risico van parsing, classificatie of samenvoegen.

**Verificatie**

Vergelijk de voorbeeldscenario’s met de norm en voer de hierboven beschreven handmatige review uit. Leg de bevindingen en eventuele functionele validatie vast in de wijzigingsreview volgens de [projectafspraken](../../../../TESTS.md#isolatie-en-bewijsvoering). De voorbeelden zijn geen uitgevoerde host- of modulegedragstests.

### Codecommentaar in Engelse zinnen schrijven

**Norm**

Een toelichting vertelt waarom de code nodig is, welke beperking ermee wordt opgevangen of welk gevolg de lezer moet kennen. Schrijf codecommentaar in het Engels en houd iedere zin op één fysieke regel. Lijsten, voorbeelden en syntaxis mogen hun eigen regels krijgen. Voor [Puppet Strings](#puppet-strings) geldt een andere opmaak, met afgebroken documentatietekst. Werk willekeurige regelafbrekingen in geraakte codecomments weg.

**Herkomst**

Projectregel

**Toepassingsgebied**

Gewone codecomments in alle eigen talen, buiten Puppet Strings; de aparte Strings-opmaak geldt alleen voor Puppet.

**Automatische controle**

Geen automatische controle voor deze afzonderlijke inhoudelijke verplichting. De gerelateerde technische controles staan bij [Toelichtingen bij code](#toelichtingen-bij-code).

**Detectiegrenzen**

De gerelateerde checks voeren de beschreven runtime- of inhoudelijke beoordeling niet uit. Lijsten, voorbeelden en syntaxis mogen eigen regels krijgen; Puppet Strings heeft afgebroken tekst volgens de aparte opmaak.

**Toegestane uitzonderingen**

Lijsten, voorbeelden en syntaxis mogen eigen regels krijgen; Puppet Strings heeft afgebroken tekst volgens de aparte opmaak.

**Onjuist voorbeeld**

Handmatig reviewscenario: Een Engelse zin wordt willekeurig over meerdere fysieke regels verdeeld. Keur dit af tegen de norm.

**Correct voorbeeld**

Handmatig reviewscenario: Houd iedere zin op één fysieke regel en leg de reden, beperking of relevante gevolgen uit. Beoordeel de genoemde voorwaarden afzonderlijk.

**Handmatige review**

Lees de volledige zin en werk willekeurige afbrekingen in geraakte comments weg.

**Verificatie**

Vergelijk de voorbeeldscenario’s met de norm en voer de hierboven beschreven handmatige review uit. Leg de bevindingen en eventuele functionele validatie vast in de wijzigingsreview volgens de [projectafspraken](../../../../TESTS.md#isolatie-en-bewijsvoering). De voorbeelden zijn geen uitgevoerde host- of modulegedragstests.

### Voorwaarden toelichten

**Norm**

Geef iedere `if` en `unless` een toelichting die de voorwaarde en de bijbehorende verwerking verklaart. Als direct ervoor variabelen worden berekend die de voorwaarde voorbereiden, staat die toelichting boven de eerste toekenning. De voorbereiding en de voorwaarde vormen dan samen één blok:

**Herkomst**

Projectregel; de bestaande norm blijft van kracht waar automatische dekking ontbreekt.

**Toepassingsgebied**

If/unless, geneste voorwaarden, toekenningsvormen en aaneengesloten voorbereiding inclusief transitieve invoer en elsif-condities.

**Automatische controle**

`project_if_sections`

**Detectiegrenzen**

Een ongerelateerde toekenning of andere opdracht onderbreekt de terugwaartse reeks. Bestaand commentaar wordt alleen op plaatsing beoordeeld; inhoud blijft review.

**Meldingen en severity**

`Explain the conditional above its preparatory variable assignments, or above the if/unless when there are none`: `warning` bij ontbrekende toelichting boven het vastgestelde begin.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: deze check heeft geen autofix; inhoudelijke correctie vereist de hieronder beschreven review.

**Toegestane uitzonderingen**

Elsif deelt de ketentoelichting. Tussen uitleg en blok mag een lege regel staan. Een geneste if heeft wel een eigen toelichting nodig.

**Suppressions**

Suppressie niet toegestaan voor deze projectchecks. De afzonderlijke lengte- en bronuitzonderingen veranderen deze regel niet.

**Onjuist voorbeeld**

Fragment; alleen de controle `project_if_sections` is voor dit voorbeeld bedoeld. Verwacht een warning.

<!-- lint-example: project_if_sections warning -->
```puppet
if $active { notice('Active') }
```

**Correct voorbeeld**

Fragment; alleen de controle `project_if_sections` is voor dit voorbeeld bedoeld. Verwacht geen melding voor deze check; de gewijzigde constructie voldoet aan de norm.

<!-- lint-example: project_if_sections clean -->
```puppet
# Report the active state.
if $active { notice('Active') }
```

**Grensgevallen**

Elsif deelt de ketentoelichting. Tussen uitleg en blok mag een lege regel staan. Een geneste if heeft wel een eigen toelichting nodig. Een ongerelateerde toekenning of andere opdracht onderbreekt de terugwaartse reeks. Bestaand commentaar wordt alleen op plaatsing beoordeeld; inhoud blijft review. De aanvullende scenario’s en gedeelde analysegrenzen zijn uitgewerkt bij [Verdieping bij Voorwaarden toelichten](#verdieping-bij-voorwaarden-toelichten).

**Handmatige review**

Controleer dat de uitleg alle voorbereide waarden en de feitelijke voorwaarde verklaart en niet alleen een vorig of buitenste blok beschrijft.

**Verificatie**

De voorbeeldparen worden via de native engine gecontroleerd door `guide/examples_test.rb`. Aanvullende detectie-, grens- en fixscenario’s: [if_sections_test.rb](../tests/if_sections_test.rb), [cli/sections_test.rb](../tests/cli/sections_test.rb). Bij fixes verifiëren `assert_fix` en de CLI-tests de exacte uitvoer, parsergeldigheid, hercontrole en ongewijzigde tweede run. Zie de tests per beschreven grens; een succesvolle lintscan is geen catalogusvalidatie.

#### Verdieping bij Voorwaarden toelichten

Fragment; de omliggende regel beschrijft de te beoordelen constructie. Dit is geen bewijs van een groene volledige profielscan.

Voor dit fragment wordt uitsluitend `project_if_sections` gecontroleerd.

<!-- lint-example: project_if_sections clean -->
```puppet
# Register this target only when monitoring is enabled.
$active = $ensure == present and defined(Class['basic_settings::monitoring']) and $basic_settings::monitoring::package != 'none'
if ($active) {
  notice('Register the active monitoring target')
}
```

Zonder voorbereiding staat de toelichting boven de voorwaarde zelf. Bij `$result = if ...` staat zij boven de toekenning en eventuele voorbereiding. Een `elsif` hoort bij dezelfde keten; een geneste voorwaarde krijgt een eigen toelichting. Er mag een lege regel tussen toelichting en blok staan. De [gewone commentaaropmaak](#toelichtingen-bij-code) regelt de scheiding met eerdere code.

`project_if_sections` volgt de aaneengesloten voorbereiding van de voorwaarde. Een losstaande toekenning of andere opdracht onderbreekt die reeks. De [technische analyse](../README.md#voorbereiding-van-voorwaarden) beschrijft hoe indirecte afhankelijkheden worden gevolgd.

De check schrijft of verplaatst geen commentaar. Beoordeel bij een melding of de toelichting zowel de voorbereiding als de voorwaarde uitlegt. Commentaar bij een eerder of bovenliggend blok vervangt die uitleg niet.

### Variabelen groeperen

<!-- lint-rule-group -->

### Een variabelegroep bij blokbegin toelichten

**Norm**

Groepeer variabelen op het doel waarvoor je ze berekent. Begin een codeblok dat na `{` meteen variabelen toekent met een toelichting binnen dat blok, direct boven de eerste toekenning. Dit geldt ook voor één variabele en voor korte `else`-, `elsif`- en `case`-takken, classes, defined types en lambdablokken. De toelichting boven de voorwaarde beschrijft waarom de tak wordt uitgevoerd; de uitleg binnen het blok beschrijft de variabelen.

Een autofix die een variabele toevoegt, moet deze toelichting behouden of de correctie weigeren. Zij mag geen inhoudelijke uitleg verzinnen of resourcecommentaar op grond van tekstherkenning omzetten in groepscommentaar. Bij één eigenaar kan diens bestaande gewone toelichting de combinatie van voorbereiding en handeling introduceren volgens de [commentaarplaatsing](#toelichtingsblokken-van-eerdere-code-scheiden).

**Herkomst**

Projectregel; de bestaande norm blijft van kracht waar automatische dekking ontbreekt.

**Toepassingsgebied**

Toekenningen direct na { in classes, defines, lambdas, else-, elsif- en case-takken.

**Automatische controle**

`project_variable_sections`

**Detectiegrenzen**

Buiten een blokopening worden alleen al toegelichte reeksen onderzocht. Echte variabelereferenties inclusief interpolatie tellen; namen en dezelfde functie bewijzen geen samenhang. Lambdaparameters hebben eigen scope.

**Meldingen en severity**

`Explain the variable group immediately inside the opening brace`: `warning` bij ontbrekende inhoudelijke toelichting. Een eventuele groepeerhint blijft onderdeel van die warning; zie de gedeelde verdieping.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: deze check heeft geen autofix; inhoudelijke correctie vereist de hieronder beschreven review.

**Toegestane uitzonderingen**

Ook één variabele verlangt de toelichting. De toelichting boven een voorwaarde vervangt die binnen haar tak niet.

**Suppressions**

Suppressie niet toegestaan voor deze projectchecks. De afzonderlijke lengte- en bronuitzonderingen veranderen deze regel niet.

**Onjuist voorbeeld**

Fragment; alleen de controle `project_variable_sections` is voor dit voorbeeld bedoeld. Verwacht een warning.

<!-- lint-example: project_variable_sections warning -->
```puppet
if $active {
  $value = 1
}
```

**Correct voorbeeld**

Fragment; alleen de controle `project_variable_sections` is voor dit voorbeeld bedoeld. Verwacht geen melding voor deze check; de gewijzigde constructie voldoet aan de norm.

<!-- lint-example: project_variable_sections clean -->
```puppet
if $active {
  # Prepare the selected value.
  $value = 1
}
```

**Grensgevallen**

Onafhankelijke instellingen mogen samen één toelichting delen. Er is geen verplicht commentaar per variabele. Een resource, voorwaarde of andere opdracht beëindigt de reeks. Buiten een blokopening worden alleen al toegelichte reeksen onderzocht. Echte variabelereferenties inclusief interpolatie tellen; namen en dezelfde functie bewijzen geen samenhang. Lambdaparameters hebben eigen scope. De aanvullende scenario’s en gedeelde analysegrenzen zijn uitgewerkt bij [Verdieping bij Een onafhankelijke groep na afhankelijke waarden beginnen](#verdieping-bij-een-onafhankelijke-groep-na-afhankelijke-waarden-beginnen).

**Handmatige review**

Controleer per groep het doel en de werkelijk gebruikte variabelen. Beoordeel vóór samenvoegen of een eerste gebruik of andere uitvoering de verplaatsing verhindert.

**Verificatie**

De voorbeeldparen worden via de native engine gecontroleerd door `guide/examples_test.rb`. Aanvullende detectie-, grens- en fixscenario’s: [variable/openings_test.rb](../tests/variable/openings_test.rb), [variable/dependencies_test.rb](../tests/variable/dependencies_test.rb). Bij fixes verifiëren `assert_fix` en de CLI-tests de exacte uitvoer, parsergeldigheid, hercontrole en ongewijzigde tweede run. Zie de tests per beschreven grens; een succesvolle lintscan is geen catalogusvalidatie.

### Een onafhankelijke groep na afhankelijke waarden beginnen

**Norm**

Maak een nieuwe groep wanneer na onderling afhankelijke berekeningen een losstaande instelling volgt. De [verdieping bij deze regel](#verdieping-bij-een-onafhankelijke-groep-na-afhankelijke-waarden-beginnen) laat dit zien met een genormaliseerde servernaam, een ge-escapete waarde en een label, gevolgd door afzonderlijke configuratie-instellingen.

**Herkomst**

Projectregel; de bestaande norm blijft van kracht waar automatische dekking ontbreekt.

**Toepassingsgebied**

Reeds toegelichte aaneengesloten toekenningsreeksen met echte lokale afhankelijkheden.

**Automatische controle**

`project_variable_sections`

**Detectiegrenzen**

Buiten een blokopening worden alleen al toegelichte reeksen onderzocht. Echte variabelereferenties inclusief interpolatie tellen; namen en dezelfde functie bewijzen geen samenhang. Lambdaparameters hebben eigen scope.

**Meldingen en severity**

`Start unrelated assignments after a dependent variable group with a blank line and a preceding explanatory comment`: `warning` bij een onafhankelijke toekenning na een aantoonbaar afhankelijke groep. Een eventuele groepeerhint blijft warning.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: deze check heeft geen autofix; inhoudelijke correctie vereist de hieronder beschreven review.

**Toegestane uitzonderingen**

Onafhankelijke instellingen mogen samen onder één toelichting. De check verlangt geen commentaar per variabele. Andere opdrachten beëindigen de reeks; buiten blokbegin worden alleen reeds toegelichte reeksen onderzocht.

**Suppressions**

Suppressie niet toegestaan voor deze projectchecks. De afzonderlijke lengte- en bronuitzonderingen veranderen deze regel niet.

**Onjuist voorbeeld**

Fragment; alleen `project_variable_sections`; verwacht warning.

<!-- lint-example: project_variable_sections warning -->
```puppet
# Prepare a related pair.
$a = 'a'
$b = $a
$c = 'c'
```

**Correct voorbeeld**

Fragment; alleen `project_variable_sections`; verwacht geen melding.

<!-- lint-example: project_variable_sections clean -->
```puppet
# Prepare a related pair.
$a = 'a'
$b = $a

# Configure the independent value.
$c = 'c'
```

**Grensgevallen**

Onafhankelijke instellingen mogen samen één toelichting delen. Er is geen verplicht commentaar per variabele. Een resource, voorwaarde of andere opdracht beëindigt de reeks. Buiten een blokopening worden alleen al toegelichte reeksen onderzocht. Echte variabelereferenties inclusief interpolatie tellen; namen en dezelfde functie bewijzen geen samenhang. Lambdaparameters hebben eigen scope. De aanvullende scenario’s en gedeelde analysegrenzen zijn uitgewerkt bij [Verdieping bij Een onafhankelijke groep na afhankelijke waarden beginnen](#verdieping-bij-een-onafhankelijke-groep-na-afhankelijke-waarden-beginnen).

**Handmatige review**

Controleer per groep het doel en de werkelijk gebruikte variabelen. Beoordeel vóór samenvoegen of een eerste gebruik of andere uitvoering de verplaatsing verhindert.

**Verificatie**

De voorbeeldparen worden via de native engine gecontroleerd door `guide/examples_test.rb`. Aanvullende detectie-, grens- en fixscenario’s: [variable/openings_test.rb](../tests/variable/openings_test.rb), [variable/dependencies_test.rb](../tests/variable/dependencies_test.rb). Bij fixes verifiëren `assert_fix` en de CLI-tests de exacte uitvoer, parsergeldigheid, hercontrole en ongewijzigde tweede run. Zie de tests per beschreven grens; een succesvolle lintscan is geen catalogusvalidatie.

#### Verdieping bij Een onafhankelijke groep na afhankelijke waarden beginnen

Maak een nieuwe groep wanneer na onderling afhankelijke berekeningen een losstaande instelling volgt. In dit voorbeeld horen de genormaliseerde servernaam, de ge-escapete waarde en het label bij elkaar. Het configuratiepad en de numerieke instellingen vormen de volgende groep:

Fragment; de omliggende regel beschrijft de te beoordelen constructie. Dit is geen bewijs van een groene volledige profielscan.

Voor dit fragment wordt uitsluitend `project_variable_sections` gecontroleerd.

<!-- lint-example: project_variable_sections clean -->
```puppet
# Prepare arguments only for an active certificate check.
if $active {
  # Normalize the name for the command and its label.
  $server_name_correct = regsubst($server_name ? { undef => '', default => $server_name }, '\s+', ' ', 'G')
  $server_name_shell = stdlib::shell_escape($server_name_correct)
  $check_friendly = "Nginx TLS ${server_name_correct}"

  # Escape the configuration path and numeric settings before passing them to the check.
  $config_file_shell = stdlib::shell_escape($config_file)
  $detail_limit_shell = stdlib::shell_escape(String($detail_limit))
  $timeout_shell = stdlib::shell_escape(String($timeout))
  $validity_critical_shell = stdlib::shell_escape(String($validity_critical))
  $validity_warning_shell = stdlib::shell_escape(String($validity_warning))
}
```

`project_variable_sections` controleert de toelichting aan het begin van een blok en de grenzen tussen toegelichte groepen. Een leeg commentaar of alleen een lintmarkering telt niet als toelichting. Zodra een toekenning een eerder berekende variabele uit de groep gebruikt, zoekt de check naar de eerste volgende toekenning die onafhankelijk van die groep is. Die krijgt een eigen toelichting; alleen een lege regel is onvoldoende. Een later samengesteld commando maakt zo'n eerdere scheiding niet overbodig.

Onafhankelijke instellingen mogen samen onder één toelichting staan, zoals de numerieke instellingen in het voorbeeld. De check verlangt dus geen commentaar per variabele. Hij leidt samenhang af uit echte verwijzingen, ook in interpolatie. Een overeenkomstige naam, dezelfde functie of hetzelfde externe invoerveld is daarvoor geen bewijs.

Een resource, voorwaarde of andere opdracht beëindigt de onderzochte reeks. Buiten het begin van een blok onderzoekt de check alleen reeksen die al een toelichting hebben. De analyse houdt lokale lambdavariabelen en parameters gescheiden van variabelen buiten de lambda.

Bij een ontbrekende toelichting kan de melding wijzen op een latere groep met dezelfde buitenste functie. Gebruik die hint om te beoordelen of de waarden bij elkaar horen en of de volgorde van uitvoeren mag veranderen. De [technische naslag](../README.md#hints-voor-variabelegroepen) beschrijft wanneer de hint verschijnt. Er is geen autofix: de linter kan de inhoudelijke samenhang niet bepalen en verplaatst daarom geen code.

### Puppet Strings

<!-- lint-rule-group -->

De volgende zelfstandige regels delen de Strings-parser. Inhoudelijke controles en opmaakcontroles zijn afzonderlijke checks; iedere regel vermeldt haar eigen varianten.

### Publieke declaraties bij de code documenteren

**Norm**

Documenteer publieke interfaces bij hun beheerde bron, zodat aanroepers het ondersteunde contract kunnen vinden zonder een tweede handmatig contract te onderhouden. Gebruik de documentatievorm van de betreffende taal of component; tool-README's blijven eigenaar van hun CLI- en gebruikscontracten.

Voor Puppet beschrijft Puppet Strings de publieke interface bij de code. Zet die documentatie direct boven iedere publieke class en ieder publiek defined type. De lezer moet daarmee kunnen bepalen welke parameters nodig zijn en wat de declaratie op een host verandert.

**Herkomst**

Projectregel voor publieke interfaces; de Puppet-uitwerking is een projectspecificatie van de [Puppet Strings-stijlgids](https://help.puppet.com/core/current/Content/PuppetCore/puppet_strings_style.htm). De precieze verplichte velden en projectbreedtes volgen uit de behouden projectafspraak.

**Toepassingsgebied**

Publieke interfaces in alle eigen code. Voor Puppet: Strings direct boven classes en defined types; API-markering van nieuwe functies blijft handmatig waar die niet wordt geanalyseerd. Andere talen krijgen geen Puppet Strings-tagverplichting.

**Automatische controle**

`project_documentation`

**Detectiegrenzen**

Aanwezigheid van tekst bewijst niet dat die tekst het gedrag beschrijft. Alleen statisch gevonden Puppet-declaraties worden onderzocht; de linter voert voorbeelden niet uit en controleert interfaces in andere talen niet.

**Meldingen en severity**

De inhoudscheck meldt ontbrekende summary, API-tag, voorbeeld en parameterbeschrijvingen afzonderlijk; de exacte warnings staan bij [Summary](#strings-summary-op-één-regel), [API](#strings-api-markering), [Voorbeeld](#uitvoerbare-strings-voorbeelden) en [Parameters](#strings-parametercontract).

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: de check kan ontbrekende of inhoudelijk onjuiste documentatie niet invullen.

**Toegestane uitzonderingen**

Geen uitzondering op de beschreven documentatieplicht; een detectiegrens heft haar niet op.

**Suppressions**

Suppressie niet toegestaan voor `project_documentation` of `project_documentation_layout`. Alleen de begrensde letterlijke lengte-uitzondering mag de native `140chars` onderdrukken; zie [Lange regels](CODE_RULES.md#lange-regels).

**Onjuist voorbeeld**

Fragment; alleen `project_documentation`; verwacht warning.

<!-- lint-example: project_documentation warning -->
```puppet
class example {}
```

**Correct voorbeeld**

Fragment; alleen `project_documentation`; verwacht geen melding.

<!-- lint-example: project_documentation clean -->
```puppet
# @summary Demonstrates the interface.
#
# @example Declare the class
#   include example
#
# @api public
class example {}
```

**Grensgevallen**

De inhoudscheck betrekt ook niet als public gemarkeerde classes en defined types. Een functionele beschrijving voor een functie wordt niet door deze check bewezen.

**Handmatige review**

Controleer voor iedere geraakte publieke interface de vindbare bron, invoer, resultaat en gevolgen tegen de implementatie en werkelijke aanroepers. Vergelijk voor Puppet de publieke parameters en gevolgen op een host; beoordeel ook een aanwezig maar onjuist contract.

**Verificatie**

De gemarkeerde paren worden uitgevoerd door [guide/examples_test.rb](../tests/guide/examples_test.rb). [interface_contract_test.rb](../tests/interface_contract_test.rb), `test_documentation_matches_each_declaration`, verifieert afzonderlijke declaraties. Controleer inhoud en uitvoerbaarheid bovendien volgens de handmatige review; aanwezigheid van tags is geen gedragsbewijs.

#### Verdieping bij Publieke declaraties bij de code documenteren

`project_documentation` controleert bij classes en defined types de summary, API-markering, voorbeeldtag en parameterbeschrijvingen. De check controleert aanwezigheid en volgorde, niet of de tekst het werkelijke gedrag volledig beschrijft. Ontbrekende uitleg of tags worden niet automatisch ingevuld.

### Strings API-markering

**Norm**

Markeer nieuwe classes, defined types en functies met `@api public` of `@api private`.

**Herkomst**

Projectspecificatie van upstream; [Puppet Strings-stijlgids](https://help.puppet.com/core/current/Content/PuppetCore/puppet_strings_style.htm). De precieze verplichte velden en projectbreedtes volgen uit de behouden projectafspraak.

**Toepassingsgebied**

Puppet Strings direct boven publieke classes, defined types en functies. De automatische analyse van classes en defined types bewijst geen functiedocumentatie; beoordeel die handmatig.

**Automatische controle**

`project_documentation`

**Detectiegrenzen**

Aanwezigheid van tekst bewijst niet dat die tekst het gedrag beschrijft. Alleen statisch gevonden declaraties worden onderzocht; de linter voert voorbeelden niet uit. Functies vallen buiten deze inhoudscheck.

**Meldingen en severity**

`Document the declaration with @api public or @api private`: `warning` wanneer niet precies één geldige API-regel aanwezig is.

**Autofix**

Geen

**Autofixvoorwaarden**

Niet van toepassing: de check kan ontbrekende of inhoudelijk onjuiste documentatie niet invullen.

**Toegestane uitzonderingen**

Geen uitzondering op de beschreven documentatieplicht; een detectiegrens heft haar niet op.

**Suppressions**

Suppressie niet toegestaan voor `project_documentation` of `project_documentation_layout`. Alleen de begrensde letterlijke lengte-uitzondering mag de native `140chars` onderdrukken; zie [Lange regels](CODE_RULES.md#lange-regels).

**Onjuist voorbeeld**

Fragment; alleen `project_documentation`; verwacht warning.

<!-- lint-example: project_documentation warning -->
```puppet
# @summary Demonstrates the interface.
#
# @example Declare the class
#   include example
#
class example {}
```

**Correct voorbeeld**

Fragment; alleen `project_documentation`; verwacht geen melding.

<!-- lint-example: project_documentation clean -->
```puppet
# @summary Demonstrates the interface.
#
# @example Declare the class
#   include example
#
# @api public
class example {}
```

**Grensgevallen**

Een dubbele API-tag geeft dezelfde warning. Een nieuwe functie zonder API-markering vraagt handmatige afkeur; dat ontbreken wordt hier niet automatisch gedetecteerd.

**Handmatige review**

Bepaal de bedoelde public/private-interface en controleer nieuwe classes, defines én functies.

**Verificatie**

De gemarkeerde paren worden uitgevoerd door [guide/examples_test.rb](../tests/guide/examples_test.rb). [interface_contract_test.rb](../tests/interface_contract_test.rb) controleert documentatie per declaratie; het bovenstaande fragment bewijst de API-variant. Controleer inhoud en uitvoerbaarheid bovendien volgens de handmatige review; aanwezigheid van tags is geen gedragsbewijs.

### Strings-summary op één regel

**Norm**

Begin met een korte `@summary` op één regel en zet verdere uitleg eronder.

**Herkomst**

Projectspecificatie van upstream; [Puppet Strings-stijlgids](https://help.puppet.com/core/current/Content/PuppetCore/puppet_strings_style.htm). De precieze verplichte velden en projectbreedtes volgen uit de behouden projectafspraak.

**Toepassingsgebied**

Puppet Strings direct boven classes en defined types; de opmaakcheck betrekt ook functies en typedeclaraties.

**Automatische controle**

`project_documentation`, `project_documentation_layout`

**Detectiegrenzen**

Aanwezigheid van tekst bewijst niet dat die tekst het gedrag beschrijft. Alleen statisch gevonden declaraties worden onderzocht; de linter voert voorbeelden niet uit. Summarytekst wordt niet automatisch ingekort.

**Meldingen en severity**

`Document the declaration with one non-empty @summary`: `warning` bij ontbrekende, lege of dubbele summary. `Keep @summary on one line; move additional explanation to the overview`: `warning` bij vervolgtekst in de summary. Lengtevarianten en hun suffix staan bij [Strings-regelbreedte](#strings-regelbreedte).

**Autofix**

Geen voor de inhoudsvariant en summaryvervolgtekst. Voor de lengtevariant bij een summary: Geen.

**Autofixvoorwaarden**

Niet van toepassing: de check kan ontbrekende of inhoudelijk onjuiste documentatie niet invullen.

**Toegestane uitzonderingen**

Geen uitzondering op de beschreven documentatieplicht; een detectiegrens heft haar niet op.

**Suppressions**

Suppressie niet toegestaan voor `project_documentation` of `project_documentation_layout`. Alleen de begrensde letterlijke lengte-uitzondering mag de native `140chars` onderdrukken; zie [Lange regels](CODE_RULES.md#lange-regels).

**Onjuist voorbeeld**

Fragment; alleen `project_documentation`; verwacht warning.

<!-- lint-example: project_documentation warning -->
```puppet
#
# @example Declare the class
#   include example
#
# @api public
class example {}
```

**Correct voorbeeld**

Fragment; alleen `project_documentation`; verwacht geen melding.

<!-- lint-example: project_documentation clean -->
```puppet
# @summary Demonstrates the interface.
#
# @example Declare the class
#   include example
#
# @api public
class example {}
```

**Grensgevallen**

Een lange summary wordt handmatig ingekort zonder betekenisverlies; nadere uitleg verhuist naar de overview. Een ingesprongen vervolgzin is geen tweede toegestane summaryregel.

**Handmatige review**

Controleer één korte summary en behoud noodzakelijke details in de overview.

**Verificatie**

De gemarkeerde paren worden uitgevoerd door [guide/examples_test.rb](../tests/guide/examples_test.rb). [documentation/structure_test.rb](../tests/documentation/structure_test.rb), `test_summary_requires_manual_shortening_without_deleting_text`, verifieert behoud en weigering. Controleer inhoud en uitvoerbaarheid bovendien volgens de handmatige review; aanwezigheid van tags is geen gedragsbewijs.

### Strings-parametercontract

**Norm**

Beschrijf iedere parameter eenmaal met `@param`, in dezelfde volgorde als de declaratie, boven de publieke class, het defined type of de functie die de gebruiker aanroept. Gebruik de bestaande `@summary` en relevante `@example`-blokken. De publieke parameter is zelfstandig begrijpelijk; een verwijzing naar een interne helper vervangt de uitleg niet.

Leid het contract af uit de actuele implementatie. Beschrijf waar relevant het waarneembare effect, de betekenis van `true`, `false`, `undef`, weglaten en lege waarden, eenheden, invoerbeperkingen en toegestane keuzes. Leg afhankelijkheden en voorrang ten opzichte van andere parameters uit, inclusief gevolgen voor bestaande configuratie, verwijderen, behoud en serviceherstarts. Neem niet aan dat `false` altijd ongemoeid laten of `undef` altijd hetzelfde betekent.

De declaratie blijft leidend voor type en standaardwaarde. Onderhoud die gegevens niet opnieuw in handmatige overzichten; vermeld ze kort wanneer dat de werking verduidelijkt of de gebruikte parameterhulp ze onvoldoende zichtbaar maakt. Beschrijf bij een berekende default de relevante keuzeregel. Korte parameters krijgen korte uitleg; neem meer ruimte wanneer de waarde anders niet verantwoord te kiezen is. Houd volledige beheerprocedures en interne uitvoeringsbeschrijvingen buiten dit blok.

Controleer waar mogelijk de daadwerkelijk getoonde parameterhulp in de gebruikte editor, ook vanuit een consumerproject met `global-modules`. Veronderstel niet dat iedere editor beschrijving, type en default samen toont. Houd de bron rechtstreeks leesbaar en vermeld een niet-uitgevoerde editorcontrole in de review.

**Herkomst**

Projectspecificatie van upstream; [Puppet Strings-stijlgids](https://help.puppet.com/core/current/Content/PuppetCore/puppet_strings_style.htm). De precieze verplichte velden en projectbreedtes volgen uit de behouden projectafspraak.

**Toepassingsgebied**

Puppet Strings direct boven publieke classes, defined types en functies. De automatische analyse van classes en defined types bewijst geen functiedocumentatie; beoordeel die handmatig.

**Automatische controle**

`project_documentation`

**Detectiegrenzen**

Aanwezigheid van tekst bewijst niet dat die tekst het gedrag beschrijft. Alleen statisch gevonden declaraties worden onderzocht; de linter voert voorbeelden niet uit. De check leest tagvolgorde en aanwezige tekst, geen defaultsemantiek.

**Meldingen en severity**

`Document every parameter exactly once, in declaration order`: `warning` bij een verschil tussen tagnamen en declaratievolgorde. `Give each @param a description of its contract and default meaning`: `warning` wanneer tekst op de tagregel en de eerstvolgende ingesprongen regel ontbreekt.

**Autofix**

Voorwaardelijk voor de tagvolgorde; ontbrekende tags en beschrijvingen blijven handmatig.

**Autofixvoorwaarden**

De fix sorteert een aaneengesloten groep bestaande `@param`-tags naar de actuele declaratievolgorde wanneer iedere parameter precies eenmaal voorkomt. De beschrijving en ingesprongen vervolgregels verhuizen met hun tag. Ontbrekende, onbekende of dubbele tags, onderbreking door andere inhoud en suppressions verhinderen de herschikking; de check verzint of verwijdert geen documentatie. Ontbrekende inhoud blokkeert andere zelfstandig veilige fixes niet.

**Toegestane uitzonderingen**

Een korte beschrijving mag op de @param-regel staan; de [tagopmaak](#strings-taginspringing) bepaalt langere tekst.

**Suppressions**

Suppressie niet toegestaan voor `project_documentation` of `project_documentation_layout`. Alleen de begrensde letterlijke lengte-uitzondering mag de native `140chars` onderdrukken; zie [Lange regels](CODE_RULES.md#lange-regels).

**Onjuist voorbeeld**

Fragment; alleen `project_documentation`; verwacht warning.

<!-- lint-example: project_documentation warning -->
```puppet
# @summary Demonstrates the interface.
#
# @example Declare the class
#   include example
#
# @api public
class example (String $label) {}
```

**Correct voorbeeld**

Fragment; alleen `project_documentation`; verwacht geen melding.

<!-- lint-example: project_documentation clean -->
```puppet
# @summary Demonstrates the interface.
#
# @example Declare the class
#   include example
#
# @param label
#   Supplies the displayed label.
#
# @api public
class example (String $label) {}
```

**Grensgevallen**

Typeannotaties zoals @param [String] label worden herkend. Lege beschrijvingen, dubbelen en verkeerde volgorde vragen correctie; aanwezige maar onjuiste defaultuitleg blijft review.

**Handmatige review**

Vergelijk iedere parameter, default, undef/true/false-betekenis, dependency, gegenereerde resource, fallback en beveiligings- of compatibiliteitsgevolg met de implementatie.

**Verificatie**

[cli/safe_fixes_test.rb](../tests/cli/safe_fixes_test.rb) controleert bestaande tekst, samengestelde parameter- en tagsortering, onvolledige documentatie en een ongewijzigde tweede fixrun.

De gemarkeerde paren worden uitgevoerd door [guide/examples_test.rb](../tests/guide/examples_test.rb). [documentation/scope_test.rb](../tests/documentation/scope_test.rb), beschrijvingsscenario’s, en [interface_contract_test.rb](../tests/interface_contract_test.rb) controleren aanwezigheid en volgorde. Controleer inhoud en uitvoerbaarheid bovendien volgens de handmatige review; aanwezigheid van tags is geen gedragsbewijs.

### Uitvoerbare Strings-voorbeelden

**Norm**

Een eenvoudig uitvoerbaar `@example` laat het normale gebruik zien. De titel staat achter de tag, de code op de ingesprongen commentregels eronder. Dit documentatieblok toont de opmaak:

**Herkomst**

Projectspecificatie van upstream; [Puppet Strings-stijlgids](https://help.puppet.com/core/current/Content/PuppetCore/puppet_strings_style.htm). De precieze verplichte velden en projectbreedtes volgen uit de behouden projectafspraak.

**Toepassingsgebied**

Puppet Strings direct boven classes en defined types; de opmaakcheck betrekt ook functies en typedeclaraties.

**Automatische controle**

`project_documentation`, `project_documentation_layout`

**Detectiegrenzen**

Aanwezigheid van tekst bewijst niet dat die tekst het gedrag beschrijft. Alleen statisch gevonden declaraties worden onderzocht; de linter voert voorbeelden niet uit. De opmaakcheck herkent vervolgregels, maar bewijst geen syntactisch of functioneel juist voorbeeld.

**Meldingen en severity**

`Provide a Puppet Strings @example`: `warning` bij ontbrekende tag met niet-lege titel. `Put the example description on the @example line`: `warning` bij lege titel. `Put example code on indented comment lines below @example`: `warning` wanneer de eerstvolgende inhoud ontbreekt of een nieuwe tag is. Inspringing en breedte volgen de afzonderlijke opmaakregels.

**Autofix**

Geen voor deze drie varianten.

**Autofixvoorwaarden**

Niet van toepassing: de check kan ontbrekende of inhoudelijk onjuiste documentatie niet invullen.

**Toegestane uitzonderingen**

Voorbeeldcode bewaart haar eigen verdere inspringing; zij wordt niet als gewone tekst afgebroken.

**Suppressions**

Suppressie niet toegestaan voor `project_documentation` of `project_documentation_layout`. Alleen de begrensde letterlijke lengte-uitzondering mag de native `140chars` onderdrukken; zie [Lange regels](CODE_RULES.md#lange-regels).

**Onjuist voorbeeld**

Fragment; alleen `project_documentation`; verwacht warning.

<!-- lint-example: project_documentation warning -->
```puppet
# @summary Demonstrates the interface.
#
# @api public
class example {}
```

**Correct voorbeeld**

Fragment; alleen `project_documentation`; verwacht geen melding.

<!-- lint-example: project_documentation clean -->
```puppet
# @summary Demonstrates the interface.
#
# @example Declare the class
#   include example
#
# @api public
class example {}
```

**Grensgevallen**

Een lege titel, ontbrekende code, onjuiste eerste inspringing en code boven 140 tekens zijn verschillende scenario’s. Markdown- of code-inhoud wordt niet geherformuleerd.

**Handmatige review**

Werk het voorbeeld met prerequisites tijdelijk uit, valideer correcte en onjuiste invoer met parser en volledig profiel en beoordeel het normale gebruik.

**Verificatie**

De gemarkeerde paren worden uitgevoerd door [guide/examples_test.rb](../tests/guide/examples_test.rb). [documentation/examples_test.rb](../tests/documentation/examples_test.rb) controleert behoud van voorbeeldcode, breedte, handmatige inspringing en titel/body. Controleer inhoud en uitvoerbaarheid bovendien volgens de handmatige review; aanwezigheid van tags is geen gedragsbewijs.

#### Verdieping bij Uitvoerbare Strings-voorbeelden

Fragment; dit behouden documentatieblok toont de opmaak en is op zichzelf geen volledige declaratie.

Voor dit fragment wordt uitsluitend `project_documentation, project_documentation_layout` gecontroleerd. Voeg voor uitvoering `class example (Boolean $keyboard_enable = true) {}` toe na het blok.

<!-- lint-example: project_documentation, project_documentation_layout clean keyboard_class -->
```puppet
# @summary Manages local console configuration.
#
# This class manages console packages and configuration when keyboard management is enabled.
#
# @example Enable keyboard configuration
#   class { 'example':
#     keyboard_enable => true,
#   }
#
# @param keyboard_enable
#   Controls keyboard package and configuration management.
#   `true` enables management and `false` disables it; omission uses the declared default.
#
# @api public
```

### Strings-regelbreedte

**Norm**

Breek gewone beschrijvingen af op logische plaatsen, bij voorkeur rond 120 tekens en uiterlijk bij 140 tekens. De inspringing en het commentteken tellen mee. Houd woorden, technische identifiers en inline code intact en behoud de alinea-indeling. Een ondeelbaar element tussen 120 en 140 tekens mag op zijn regel blijven staan. Voor langere letterlijke waarden geldt de uitzondering bij [Lange regels](CODE_RULES.md#lange-regels).

**Herkomst**

Projectspecificatie van upstream; [Puppet Strings-stijlgids](https://help.puppet.com/core/current/Content/PuppetCore/puppet_strings_style.htm). De precieze verplichte velden en projectbreedtes volgen uit de behouden projectafspraak.

**Toepassingsgebied**

Puppet Strings direct boven classes en defined types; de opmaakcheck betrekt ook functies en typedeclaraties.

**Automatische controle**

`project_documentation_layout`

**Detectiegrenzen**

Voorbeeldcode wordt pas boven 140 tekens gemeld. Een ondeelbaar element tussen 120 en 140 blijft intact. Gewone tekst, summaries, voorbeeldtitels, Markdownstructuur en letterlijke waarden krijgen verschillende fixbehandeling.

**Meldingen en severity**

`Puppet Strings documentation exceeds the maximum 140-character line length`: `warning` boven 140 zonder geldige literaluitzondering. `Puppet Strings documentation exceeds the preferred 120-character line width`: `warning` voor afbreekbare niet-voorbeeldtekst boven 120. Het suffix is `Shorten @summary and move the full description into the overview`, `Keep the @example title on one line and shorten it manually` of `Wrap documentation across comment lines; preserve literal values and example code`. Onveilig herschrijven voegt ` [review] Adjust manually; this construct cannot be safely rewritten` toe. `[review]` blijft warning.

**Autofix**

| Variant en constructie | Classificatie |
| --- | --- |
| Maximum of preferred bij veilig afbreekbare gewone tekst | Voorwaardelijk |
| Maximum of preferred bij summary, voorbeeldtitel, codevoorbeeld of onveilige structuur | Geen |

**Autofixvoorwaarden**

Breekt alleen gewone tekst op woorden af; behoudt backticks, identifiers, whitespace in literals en alinea’s. Herkenbare @param-tekst kan onder de tag verhuizen. Lijsten, tabellen, codefences, ingesprongen code, harde Markdownregeleinden, ongebalanceerde delimiters, onleesbare tags en ondeelbare te brede output krijgen geen onveilige herschrijving.

**Toegestane uitzonderingen**

Ondeelbare elementen van 120–140 tekens blijven toegestaan; langere literals uitsluitend met de begrensde uitzondering bij Lange regels.

**Suppressions**

Suppressie niet toegestaan voor `project_documentation` of `project_documentation_layout`. Alleen de begrensde letterlijke lengte-uitzondering mag de native `140chars` onderdrukken; zie [Lange regels](CODE_RULES.md#lange-regels).

**Onjuist voorbeeld**

Fragment; alleen `project_documentation_layout`; verwacht warning.

<!-- lint-example: project_documentation_layout warning -->
```puppet
# @summary Demonstrates the interface.
#
# word word word word word word word word word word word word word word word word word word word word word word word word end.
#
# @example Declare the class
#   include example
#
# @api public
class example {}
```

**Correct voorbeeld**

Fragment; alleen `project_documentation_layout`; verwacht geen melding.

<!-- lint-example: project_documentation_layout clean -->
```puppet
# @summary Demonstrates the interface.
#
# word word word word word word word word word word word word
# word word word word word word word word word word word word end.
#
# @example Declare the class
#   include example
#
# @api public
class example {}
```

**Grensgevallen**

120 tekens: schoon. Afbreekbare tekst op 121 en 140: preferred-warning. 141: maximum-warning. Een ondeelbaar pad van 126 tekens blijft schoon; een lange URL verbergt omringende afbreekbare tekst niet. Unicode en geneste inspringing tellen mee. De afzonderlijke Markdown-weigeringscategorieën staan in de autofixvoorwaarden.

**Handmatige review**

Lees tekst en gerenderde Markdown na; behoud alle woorden en technische waarden en controleer de werkelijke regellengte inclusief # en inspringing.

**Verificatie**

De gemarkeerde paren worden uitgevoerd door [guide/examples_test.rb](../tests/guide/examples_test.rb). [documentation/width_test.rb](../tests/documentation/width_test.rb) controleert 120/121/140/141, identifiers, URL, Unicode en parametertekst; [documentation/markup_test.rb](../tests/documentation/markup_test.rb) controleert iedere genoemde structuurweigering en woord-/alineabehoud. Controleer inhoud en uitvoerbaarheid bovendien volgens de handmatige review; aanwezigheid van tags is geen gedragsbewijs.

#### Verdieping bij Strings-regelbreedte

`project_documentation_layout` controleert de opmaak boven classes, defined types, Puppet-functies en typedeclaraties. Afbreekbare tekst boven 120 tekens en documentatieregels boven 140 tekens geven een melding, ook als de standaardcheck een URL zou overslaan. Voorbeeldcode krijgt alleen boven 140 tekens een lengtemelding.

Met `--fix` kan de documentatiecheck gewone tekst afbreken en herkenbare tag-inspringing en sectiescheiding herstellen. Woorden, backtick-inhoud en alinea's blijven behouden. Summaries, voorbeeldtitels, voorbeeldcode en gestructureerde Markdown, zoals lijsten, tabellen en codeblokken, vragen waar nodig handmatige correctie. Een lange summary of voorbeeldtitel kort je zelf in. Bij onveilige of onduidelijke correcties blijft een melding met `[review]` staan.

> **Verschil tussen norm en lintgedrag:** de norm noemt circa 120 tekens een voorkeur en 140 het uiterste. De check meldt afbreekbare tekst op 121–140 tekens met een warning, waardoor het profiel faalt. Breek zulke tekst af tot maximaal 120 tekens om deze melding te verhelpen. De grensgevallen staan in `test_preferred_width_is_distinguished_from_hard_maximum` en `test_exact_line_width_boundaries_include_the_comment_prefix` van [documentation/width_test.rb](../tests/documentation/width_test.rb). Of de voorkeur een verplichte grens moet zijn, vereist een expliciet besluit volgens de [conflictprocedure](#conflicten-beoordelen); het lintgedrag stelt die norm niet vast.

### Strings-taginspringing

**Norm**

Bij een lange parameterbeschrijving staat alleen de naam achter `@param`; de uitleg volgt met twee extra spaties, als `#   ...`. Een korte beschrijving mag achter de parameternaam blijven staan.

**Herkomst**

Projectspecificatie van upstream; [Puppet Strings-stijlgids](https://help.puppet.com/core/current/Content/PuppetCore/puppet_strings_style.htm). De precieze verplichte velden en projectbreedtes volgen uit de behouden projectafspraak.

**Toepassingsgebied**

Puppet Strings direct boven classes en defined types; de opmaakcheck betrekt ook functies en typedeclaraties.

**Automatische controle**

`project_documentation_layout`

**Detectiegrenzen**

Herkenbare voortzettingstekst wordt onderscheiden van voorbeeldcode en gestructureerde Markdown. Een lange @param-tag zonder leesbare parameternaam wordt niet herschreven.

**Meldingen en severity**

`Puppet Strings continuation lines must be indented with two spaces`: `warning` bij afwijkende voortzettingsinspringing. Kan met sectiescheiding of breedte op dezelfde regel worden gecombineerd met `; `. Onveilige constructies houden het [review]-suffix uit de breedteregel.

**Autofix**

Voorwaardelijk voor gewone herkenbare vervolgtekst; Geen voor onveilig te herschrijven voorbeeldcode, summaryvervolg of gestructureerde inhoud.

**Autofixvoorwaarden**

Herstelt uitsluitend herkenbare tekstinspringing; behoudt verdere inspringing in codevoorbeelden en weigert samenvattingen of gestructureerde Markdown wanneer het herschrijven onveilig is.

**Toegestane uitzonderingen**

Korte parameterbeschrijvingen mogen achter de parameternaam blijven staan.

**Suppressions**

Suppressie niet toegestaan voor `project_documentation` of `project_documentation_layout`. Alleen de begrensde letterlijke lengte-uitzondering mag de native `140chars` onderdrukken; zie [Lange regels](CODE_RULES.md#lange-regels).

**Onjuist voorbeeld**

Fragment; alleen `project_documentation_layout`; verwacht warning.

<!-- lint-example: project_documentation_layout warning -->
```puppet
# @summary Demonstrates the interface.
#
# @example Declare the class
#   include example
#
# @param label
# Supplies the displayed label.
#
# @api public
class example (String $label) {}
```

**Correct voorbeeld**

Fragment; alleen `project_documentation_layout`; verwacht geen melding.

<!-- lint-example: project_documentation_layout clean -->
```puppet
# @summary Demonstrates the interface.
#
# @example Declare the class
#   include example
#
# @param label
#   Supplies the displayed label.
#
# @api public
class example (String $label) {}
```

**Grensgevallen**

Korte inlinebeschrijving: toegestaan. Lange beschrijving: onder de tag. Verkeerd ingesprongen gewone vervolgtekst: fix. Eerste voorbeeldregel met afwijkende inspringing: handmatig; verdere voorbeeldcode blijft exact.

**Handmatige review**

Controleer het verschil tussen proza en voorbeeldcode en behoud de betekenisvolle code-inspringing.

**Verificatie**

De gemarkeerde paren worden uitgevoerd door [guide/examples_test.rb](../tests/guide/examples_test.rb). [documentation/structure_test.rb](../tests/documentation/structure_test.rb), `test_continuation_indentation_is_corrected_for_parameters_and_other_tags`; [documentation/examples_test.rb](../tests/documentation/examples_test.rb), inspringingsweigeringen. Controleer inhoud en uitvoerbaarheid bovendien volgens de handmatige review; aanwezigheid van tags is geen gedragsbewijs.

### Strings-secties met commentregels scheiden

**Norm**

Scheid secties en afzonderlijke parameters met een lege commentregel `#`, zodat het één documentatieblok blijft. Een volledig lege broncoderegel hoort daar niet tussen. Behoud binnen voorbeeldcode de verdere code-inspringing.

**Herkomst**

Projectspecificatie van upstream; [Puppet Strings-stijlgids](https://help.puppet.com/core/current/Content/PuppetCore/puppet_strings_style.htm). De precieze verplichte velden en projectbreedtes volgen uit de behouden projectafspraak.

**Toepassingsgebied**

Puppet Strings direct boven classes en defined types; de opmaakcheck betrekt ook functies en typedeclaraties.

**Automatische controle**

`project_documentation_layout`

**Detectiegrenzen**

Een lege bronregel en whitespace-only comment worden anders behandeld dan een lege commentregel. Herkende sectieovergangen krijgen scheiding; gewone alinea’s behouden hun volgorde.

**Meldingen en severity**

`Separate Puppet Strings sections with a blank comment line (#)`: `warning` bij volledig lege bronregel, whitespace-only comment of ontbrekende sectiescheiding. De formatter kan dit met inspringings- en breedtemeldingen op dezelfde regel combineren.

**Autofix**

Voorwaardelijk

**Autofixvoorwaarden**

Vervangt lege bronregels door # en voegt herkenbare sectiescheiding toe. Correctie met daarnaast onveilige inspringing of te brede ondeelbare output kan worden geweigerd; tekst en alinea’s blijven behouden.

**Toegestane uitzonderingen**

Lege commentregels bewaren één documentatieblok; betekenisvolle lege regels in voorbeeldcode blijven behouden.

**Suppressions**

Suppressie niet toegestaan voor `project_documentation` of `project_documentation_layout`. Alleen de begrensde letterlijke lengte-uitzondering mag de native `140chars` onderdrukken; zie [Lange regels](CODE_RULES.md#lange-regels).

**Onjuist voorbeeld**

Fragment; alleen `project_documentation_layout`; verwacht warning.

<!-- lint-example: project_documentation_layout warning -->
```puppet
# @summary Demonstrates the interface.
#
# @example Declare the class
#   include example
# @api public
class example {}
```

**Correct voorbeeld**

Fragment; alleen `project_documentation_layout`; verwacht geen melding.

<!-- lint-example: project_documentation_layout clean -->
```puppet
# @summary Demonstrates the interface.
#
# @example Declare the class
#   include example
#
# @api public
class example {}
```

**Grensgevallen**

Volledig lege bronregel: wordt #. Comment met alleen spaties: wordt #. Twee bestaande alinea’s: blijven gescheiden en in volgorde. Ontbrekende scheiding plus onveilige code-inspringing: handmatige review.

**Handmatige review**

Lees sectiegrenzen en alinea’s en controleer dat voorbeeldcode en letterlijke inhoud niet zijn samengevoegd.

**Verificatie**

De gemarkeerde paren worden uitgevoerd door [guide/examples_test.rb](../tests/guide/examples_test.rb). [documentation/structure_test.rb](../tests/documentation/structure_test.rb) controleert secties en lege bronregels; [documentation/markup_test.rb](../tests/documentation/markup_test.rb) controleert alinea’s en whitespace-only comments. Controleer inhoud en uitvoerbaarheid bovendien volgens de handmatige review; aanwezigheid van tags is geen gedragsbewijs.

#### Verdieping bij Strings-secties met commentregels scheiden

De [Puppet Strings-stijlgids](https://help.puppet.com/core/current/Content/PuppetCore/puppet_strings_style.htm) beschrijft de algemene opbouw.

### Lengtesuppressions in Strings begrenzen

**Norm**

Een overbodig `140chars`-blok rond uitsluitend gewone documentatie kan de autofix verwijderen. Een blok met een toelichtende reden, een gecombineerde uitzondering of een uitzondering die ook Puppet-code omvat vraagt handmatige begrenzing. Controleer na correctie de tekst en Markdown-opbouw en valideer de voorbeelden volgens [Aanvullende validatie](../README.md#aanvullende-validatie).

**Herkomst**

Projectspecificatie van upstream; [Puppet Strings-stijlgids](https://help.puppet.com/core/current/Content/PuppetCore/puppet_strings_style.htm). De precieze verplichte velden en projectbreedtes volgen uit de behouden projectafspraak.

**Toepassingsgebied**

Puppet Strings direct boven classes en defined types; de opmaakcheck betrekt ook functies en typedeclaraties.

**Automatische controle**

`project_documentation_layout`

**Detectiegrenzen**

Een suppression moet uitsluitend gewone documentatie beslaan om automatisch verwijderd te kunnen worden. Gemengde inhoud, toelichtende reden en gecombineerde checks worden niet stilzwijgend herschreven.

**Meldingen en severity**

`Do not disable the 140-character rule for normal Puppet Strings documentation; wrap the documentation instead`: `warning`. Bij handmatige begrenzing volgt ` [review] Narrow the suppression manually, preserving literal values and other checks`.

**Autofix**

Voorwaardelijk voor een verwijderbaar uitsluitend-documentatieblok; Geen voor niet veilig te begrenzen blokken.

**Autofixvoorwaarden**

Verwijdert uitsluitend een overbodig enkelvoudig 140chars-blok en breekt veilige gewone tekst af; behoudt redenen, gecombineerde checks, letterlijke waarden en Puppet-code.

**Toegestane uitzonderingen**

Een ondeelbare lange letterlijke waarde mag een minimaal begrensde 140chars-uitzondering krijgen; sluit vóór gewone documentatie.

**Suppressions**

Suppressie niet toegestaan voor `project_documentation` of `project_documentation_layout`. Alleen de begrensde letterlijke lengte-uitzondering mag de native `140chars` onderdrukken; zie [Lange regels](CODE_RULES.md#lange-regels).

**Onjuist voorbeeld**

Fragment; alleen `project_documentation_layout`; verwacht warning.

<!-- lint-example: project_documentation_layout warning -->
```puppet
# lint:ignore:140chars
# @summary Demonstrates the interface.
#
# @example Declare the class
#   include example
#
# @api public
class example {}
# lint:endignore
```

**Correct voorbeeld**

Fragment; alleen `project_documentation_layout`; verwacht geen melding.

<!-- lint-example: project_documentation_layout clean -->
```puppet
# @summary Demonstrates the interface.
#
# @example Declare the class
#   include example
#
# @api public
class example {}
```

**Grensgevallen**

Uitsluitend gewone documentatie zonder reden: verwijderbaar. Reden achter de markering, meerdere checks, code in hetzelfde bereik of literalgrens: handmatig behouden en begrenzen.

**Handmatige review**

Controleer ieder teken van het suppressionbereik; verifieer dat gewone tekst weer wordt gecontroleerd en literals en andere checks behouden blijven.

**Verificatie**

De gemarkeerde paren worden uitgevoerd door [guide/examples_test.rb](../tests/guide/examples_test.rb). [documentation/suppressions_test.rb](../tests/documentation/suppressions_test.rb) controleert verwijderbare en geweigerde suppressions en scopes. Controleer inhoud en uitvoerbaarheid bovendien volgens de handmatige review; aanwezigheid van tags is geen gedragsbewijs.

### Waar de uitleg hoort

<!-- lint-rule-group -->

### Interfacebeschrijvingen synchroniseren

**Norm**

Beoordeel bij iedere wijziging de geraakte informatie bij haar eigenaar:

- Een nieuwe of gewijzigde parameter: de uitleg bij die parameter.
- Een gewijzigde interne keuze: de reden in het commentaar bij de betrokken implementatie.
- Een verandering in doel, starten, gebruik, voorwaarden of belangrijke gevolgen: de passende README.
- Een geraakt configuratiescenario of gewijzigde beheerhandeling: het voorbeeld of de volledige procedure.
- Een gegenereerde referentie: haar bron en het bestaande generatieproces.

Pas de uitleg aan wanneer de beoordeling daar aanleiding toe geeft en vergelijk haar met de actuele implementatie. Behoud bestaande README-tekst wanneer zij inhoudelijk correct blijft en de lezerstaak al ondersteunt; leg die reviewuitkomst vast. Een nieuwe feature verplicht niet tot een nieuw Markdown-bestand of een uitgebreide root-README-sectie. Voor monitoring kan de gewijzigde ingang het bestaande checkoverzicht zijn.

**Herkomst**

Projectregel

**Toepassingsgebied**

Bronbeschrijvingen en voorbeelden van alle eigen publieke interfaces; Puppet Strings en het beheerdergerichte checkoverzicht zijn de specifieke Puppet- en monitoringuitwerkingen.

**Detectiegrenzen**

De linter beoordeelt de genoemde runtimeobjecten, intentie en operationele gevolgen niet. Het checkoverzicht verandert alleen wanneer het beheerdergerichte monitoringgedrag verandert.

**Toegestane uitzonderingen**

Het checkoverzicht verandert alleen wanneer het beheerdergerichte monitoringgedrag verandert.

**Onjuist voorbeeld**

Handmatig reviewscenario: Een parameterdefault verandert, maar Strings en het voorbeeld noemen de oude waarde. De beschreven constructie wordt afgekeurd.

**Correct voorbeeld**

Handmatig reviewscenario: Werk Strings en geraakte voorbeelden bij en pas bij gewijzigd monitoringgedrag het checkoverzicht aan. Dit voldoet aan de norm onder de genoemde voorwaarden.

**Handmatige review**

Vergelijk het gewijzigde interfacecontract en voorbeelden met de implementatie en gebruikers. Controleer bij Puppet defaults, relaties en gegenereerde configuratie afzonderlijk tegen het manifest.

Beoordeel deze handmatige scenario's met de [README-richtlijn](#scope-en-configuratie):

| Situatie | Beoordeling |
| --- | --- |
| Een interne XML-parser wordt vervangen. Gebruik, gebruiksvoorwaarden en betekenis van resultaten blijven gelijk. De README krijgt een alinea over de nieuwe bibliotheek en de pakketten die niet meer nodig zijn. | Afkeuren: de toevoeging verantwoordt de implementatie zonder een taak voor de gebruiker te ondersteunen. |
| Dezelfde parserwijziging wordt uitgevoerd. Noodzakelijke implementatiecomments en eventueel geraakte vereisten voor zelfstandig scriptgebruik worden bijgewerkt. De bestaande gebruikersbeschrijving blijft inhoudelijk correct en wordt behouden. | Goedkeuren: de geraakte documentatie is beoordeeld en op haar passende plek bijgewerkt. |
| Een wijziging vereist een nieuwe handeling van de gebruiker of verandert de betekenis van een status. | Werk de bestaande gebruiksinstructie of statusuitleg bij en maak het concrete gevolg duidelijk. |

**Verificatie**

Vergelijk de voorbeeldscenario’s met de norm en voer de hierboven beschreven handmatige review uit. Leg de bevindingen en eventuele functionele validatie vast in de wijzigingsreview volgens de [projectafspraken](../../../../TESTS.md#isolatie-en-bewijsvoering). De voorbeelden zijn geen uitgevoerde host- of modulegedragstests.

### Documentatie op haar aangewezen plaats onderhouden

**Norm**

Onderhoud parametercontracten in Puppet Strings bij de code. Onderhoud geen tweede handmatige parameterreferentie. Een bestaande gegenereerde referentie wordt via haar bron bijgewerkt. Gerichte procedures blijven op een passende bestaande documentatieplek staan; hun samenhang hoort niet in losse parametercomments. Gebruik voor algemene informatieplaatsing en ADR’s de [repositorydocumentatie-indeling](#taal-en-informatieplaatsing).

**Herkomst**

Projectregel

**Toepassingsgebied**

Puppet-parametercontracten en handmatige duplicaten van genereerbare API-documentatie.

**Detectiegrenzen**

De linter beoordeelt de genoemde runtimeobjecten, intentie en operationele gevolgen niet. Een verwijzing naar gegenereerde API-documentatie is toegestaan; zij vervangt het parametercontract bij de code niet.

**Toegestane uitzonderingen**

Een verwijzing naar gegenereerde API-documentatie is toegestaan; zij vervangt het parametercontract bij de code niet.

**Onjuist voorbeeld**

Handmatig reviewscenario: Een handmatig REFERENCE.md dupliceert de door Puppet Strings te genereren parameterbeschrijvingen. De beschreven constructie wordt afgekeurd.

**Correct voorbeeld**

Handmatig reviewscenario: Behoud parametercontracten bij de code en gebruik Puppet Strings als bron voor eventuele gegenereerde API-documentatie; beoordeel de overige informatieplaatsing volgens de gekoppelde repositoryafspraken. Dit voldoet aan de norm onder de genoemde voorwaarden.

**Handmatige review**

Controleer de verantwoordelijkheden van iedere geraakte uitleg en voorkom een tweede handmatige contractbron.

**Verificatie**

Vergelijk de voorbeeldscenario’s met de norm en voer de hierboven beschreven handmatige review uit. Leg de bevindingen en eventuele functionele validatie vast in de wijzigingsreview volgens de [projectafspraken](../../../../TESTS.md#isolatie-en-bewijsvoering). De voorbeelden zijn geen uitgevoerde host- of modulegedragstests.

### Uitvoerbare voorbeeldscenario’s onderhouden

**Norm**

Breid bij voorkeur een bestaand voorbeeldscenario uit. Toon daarin de benodigde parameters en zorg dat het voorbeeld met de genoemde voorwaarden uitvoerbaar is. De [project-README](../../../../README.md#gebruik-van-voorbeelden-en-parameterdocumentatie) beschrijft het gebruik van voorbeeldwaarden, `Sensitive`-wrappers en Hiera; voor synthetische gegevens gelden de [beveiligingsregels](../../../../CONTRIBUTING.md#veilig-werken-en-gegevensdeling).

**Herkomst**

Projectregel

**Toepassingsgebied**

Nieuwe en bijgewerkte gebruiksvoorbeelden bij publieke interfaces.

**Detectiegrenzen**

De linter beoordeelt de genoemde runtimeobjecten, intentie en operationele gevolgen niet. Uitbreiden van een bestaand scenario is een voorkeur. De uitvoerbaarheid onder de vermelde voorwaarden en de beveiligingsafspraken blijven verplicht.

**Toegestane uitzonderingen**

Uitbreiden van een bestaand scenario is een voorkeur. De uitvoerbaarheid onder de vermelde voorwaarden en de beveiligingsafspraken blijven verplicht.

**Onjuist voorbeeld**

Handmatig reviewscenario: Een voorbeeld mist een verplicht argument en presenteert een geheim als gewone tekst. De beschreven constructie wordt afgekeurd.

**Correct voorbeeld**

Handmatig reviewscenario: Breid bij voorkeur het bestaande scenario uit, vermeld voorwaarden en vereiste argumenten en volg de beschreven Sensitive- en Hiera-afspraken. Dit voldoet aan de norm onder de genoemde voorwaarden.

**Handmatige review**

Controleer alle genoemde prerequisites, argumenten en synthetische waarden; valideer het uitgewerkte voorbeeld volgens Aanvullende validatie.

**Verificatie**

Vergelijk de voorbeeldscenario’s met de norm en voer de hierboven beschreven handmatige review uit. Leg de bevindingen en eventuele functionele validatie vast in de wijzigingsreview volgens de [projectafspraken](../../../../TESTS.md#isolatie-en-bewijsvoering). De voorbeelden zijn geen uitgevoerde host- of modulegedragstests.
