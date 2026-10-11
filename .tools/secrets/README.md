# Gevoelige gegevens lokaal controleren

`project-tools-secrets` leest bestanden lokaal voordat je de inhoud gebruikt voor externe analyse of AI-analyse. De tool meldt mogelijke geheimen zonder hun waarden te tonen en kan afzonderlijke kopieën maken waarin die waarden zijn gemaskeerd. De tool maakt geen netwerkverbindingen, voert geen invoer uit en wijzigt nooit de bronbestanden. Neem je deze repository als `global-modules` op in een ander project, begin dan bij [Gebruik in een ander project](#gebruik-in-een-ander-project).

## Inhoudsopgave

- [Inhoudsopgave](#inhoudsopgave)
- [Controleren voor het lezen](#controleren-voor-het-lezen)
- [Analysekopieën maken](#analysekopieën-maken)
- [Resultaten en exitcodes](#resultaten-en-exitcodes)
- [Patronen en beperkingen](#patronen-en-beperkingen)
- [Archieven controleren](#archieven-controleren)
- [Exacte lokale beoordelingen](#exacte-lokale-beoordelingen)
- [Puppet-manifesten in standaardtests en CI](#puppet-manifesten-in-standaardtests-en-ci)
- [Een afgekeurd manifest herstellen](#een-afgekeurd-manifest-herstellen)
- [Gemiste gegevens of een fout melden](#gemiste-gegevens-of-een-fout-melden)
- [Gebruik in een ander project](#gebruik-in-een-ander-project)
  - [Kies de controles voor je project](#kies-de-controles-voor-je-project)
  - [Installeer in de eigen bundle](#installeer-in-de-eigen-bundle)
  - [Richt de voorcontrole voor AI en externe analyse in](#richt-de-voorcontrole-voor-ai-en-externe-analyse-in)
  - [Koppel de Puppet-controle aan eigen taken](#koppel-de-puppet-controle-aan-eigen-taken)
  - [Neem de controle op in CI](#neem-de-controle-op-in-ci)
  - [Beheer lokale beoordelingen en updates](#beheer-lokale-beoordelingen-en-updates)
- [Ontwikkelen en testen](#ontwikkelen-en-testen)

## Controleren voor het lezen

Installeer de bundle volgens de [gezamenlijke installatiehandleiding](../README.md#installatie). Geef bestanden of mappen op ten opzichte van je huidige werkmap. Je kunt meerdere bestanden en mappen combineren in één aanroep. De tool controleert mappen recursief, inclusief verborgen bestanden, zonder Git-uitsluitingen of andere impliciete uitsluitingen.

```sh
bundle exec project-tools-secrets manifests/site.pp data/
bundle exec project-tools-secrets --json manifests/site.pp data/
```

Beoordeel eerst de metadata in het rapport. Maak bij bevindingen gemaskeerde kopieën voordat je de inhoud leest. Los bij een onvolledige controle of twijfel eerst de oorzaak op, of laat iemand de bron lokaal beoordelen buiten de AI-context. Toon het origineel nooit aan een assistent om een bevinding te onderzoeken. Controleer gewijzigde invoer opnieuw; de kopieën bevatten precies de gecontroleerde versie.

Zoek alleen in gecontroleerde kopieën. Exporteer voor diffs beide volledige bronversies lokaal, controleer ze en vergelijk daarna hun kopieën: een diff alleen mist de context van meerregelige waarden en Hiera. Sla commando-uitvoer die brongegevens kan bevatten eerst op in een afgeschermd lokaal bestand. Controleer dat bestand en deel uitsluitend de gecontroleerde of gemaskeerde uitvoer. Toon de ongefilterde uitvoer niet tegelijkertijd via `tee`.

De CLI onderschept geen assistenttools, bestandslezingen door editors of uploads. Pas de [verplichte voorcontrole](../../AGENTS.md#local-inspection-before-disclosure) daarom bij iedere aanroeper toe. Een geautomatiseerde integratie moet een volledig resultaat vereisen en uitsluitend de bijbehorende kopieën lezen.

## Analysekopieën maken

Kies een **nieuwe** map buiten de geselecteerde invoer, waarvan de bovenliggende map al bestaat:

```sh
bundle exec project-tools-secrets --redact /tmp/analysis-copies manifests/site.pp data/
```

De tool controleert de invoer opnieuw en vervangt gevonden waarden in dezelfde gecontroleerde inhoud door `[REDACTED]`. Veldnamen en de omliggende structuur blijven waar mogelijk behouden. YAML-mappings en -lijsten behouden hun structuur; bij Puppet blijft de omhullende `Sensitive('...')`-constructie staan. De kopieën zijn bedoeld voor analyse: typen van vervangende waarden en regelaantallen kunnen afwijken van het origineel.

Het rapport koppelt de bronbestanden aan `file-000001.txt`, `file-000002.txt`, enzovoort. Deze nummering voorkomt dat geheime waarden uit bronbestandsnamen worden overgenomen. De map krijgt modus `0700`; bestanden krijgen vóór het schrijven modus `0600`. Gewone lokale lees- en schrijfrechten volstaan.

Als een invoerbestand niet volledig kan worden gecontroleerd of een waarde niet betrouwbaar kan worden afgebakend, schrijft de tool **geen kopieën**. Bij een schrijffout verwijdert de tool de kopieën van die aanroep. Bestaande doelbestanden, doelmappen en symlinks worden geweigerd. De tool schrijft geen ongefilterde broninhoud naar tijdelijke uitvoer. Houd de bronbestanden tijdens de controle ongewijzigd; de tool biedt geen snapshotgarantie tegen kwaadwillende gelijktijdige wijzigingen.

## Resultaten en exitcodes

| Exitcode | JSON `status` | Betekenis |
| --- | --- | --- |
| `0` | `no_findings` | Alle geselecteerde bestanden zijn geïnspecteerd of exact lokaal beoordeeld; geen actieve bevindingen. Controleer `coverage`. **Dit is geen veiligheidsgarantie.** |
| `1` | `findings` | Mogelijke geheime waarden of aanwijzingen voor gevoelige gegevens gevonden. Beoordeel en maskeer de inhoud vóór openbaarmaking; ook na maskeren blijft de exitcode 1. |
| `2` | `incomplete` | Selectie, controle, maskeren of rapportage is mislukt of onvolledig. Geef de inhoud niet vrij totdat de oorzaak is verholpen of iemand de inhoud lokaal heeft beoordeeld. |

Per bestand bevat het rapport `file`, `complete`, `findings`, `errors` en eventueel `copy`. Iedere bevinding vermeldt het oorspronkelijke regelnummer in `line`, een vaste herkenningsregel in `rule` en het soort bevinding in `kind`: `value` voor een mogelijke geheime waarde, `indicator` voor een naam of constructie. Geen enkele regel controleert of een gevonden inloggegeven actief is. De algemene JSON-eigenschap `complete` omvat ook fouten bij uitvoer en rapportage en is leidend boven geslaagde deelcontroles.

Een verwijzing via `lookup('mysql::user::example::password', Sensitive[String])` bevat zelf geen wachtwoord. De scanner behoudt deze expressie in de analysekopie en meldt uitsluitend aanwijzingen (`indicator`), geen geheime waarde (`value`). Exitcode 1 blijft van toepassing omdat het veld op gevoelige gegevens wijst. De daadwerkelijke waarde in het bijbehorende YAML-bestand wordt afzonderlijk gecontroleerd en gemaskeerd; neem dat bestand mee in de selectie. Een letterlijk meegegeven standaardwaarde valt niet onder deze uitzondering en wordt wel gemaskeerd.

Console-uitvoer, JSON en JUnit bevatten geen bronfragmenten, gevonden waarden, fingerprints of oorspronkelijke foutteksten. Fouten hebben vaste identificaties. Gevonden waarden en herkenbare tokenpatronen worden uit getoonde paden verwijderd; vertrouwelijke bestandsnamen vereisen nog steeds lokale beoordeling. Zet geen inloggegevens in argumenten of bestandsnamen. De CLI schakelt het afdrukken van exceptions in Ruby-debugmodus uit en heeft geen modus die gevonden waarden logt.

Met `--junit /existing/parent/new-report.xml` krijg je dezelfde bevindingen ook als JUnit: bevindingen worden `failures`, onvolledig gecontroleerde bestanden worden `errors`. De bovenliggende map moet bestaan en het doelbestand moet nieuw zijn en buiten de invoer liggen. Een schrijffout bij het rapport geeft exitcode 2 en houdt de analysekopieën tegen. Beoordeelde bestanden vermelden hun dekking ook in de console en in JUnit. Zonder deze optie blijven rapportbestanden ongemoeid. `--json` wijzigt de presentatie op stdout; `--help` toont de gebruiksinstructies zonder te scannen.

## Patronen en beperkingen

| Regel of constructie | Ondersteund gedrag |
| --- | --- |
| `sensitive_name`, `sensitive_assignment` | Herkent `password`, `passwd`, `passphrase`, `secret`, `token`, `api_key`/`apiKey`, `access_key`/`accessKey`, `private_key`/`privateKey`, `encryption_key`/`encryptionKey`, `signing_key`/`signingKey`, `license_key`/`licenseKey`/`license-key`/`license.key`, `authorization` en naamdelen met `pwd`, ongeacht hoofdletters. Herkent toewijzingen met `=`, Puppet `=>` of `:`, optionele aanhalingstekens, geïndexeerde sleutels en namespaceprefixen. Niet-lege waarden worden ook zonder `Sensitive` gemaskeerd. Benoemde geheime commandoregelopties worden zowel met `=` als met een afzonderlijk argument onderzocht. |
| `sensitive_yaml_value` | Ondersteunt YAML/Hiera/JSON-mappings, geneste waarden, lijsten, meerregelige waarden tussen aanhalingstekens en blokken met `\|`/`>`. Gebruikt bronposities uit de parser zonder tags of objecten te laden. Lege waarden en gewone YAML-nulls tellen als aanwijzing. |
| `puppet_sensitive` | `Sensitive[...]` wijst op gevoeligheid; argumenten van `Sensitive.new` en `Sensitive('...')` worden bij sluitende haakjes gemaskeerd, inclusief geneste expressies. Rechtstreekse variabelen, `lookup('key')` en `lookup('key', Sensitive[String])` zonder extra argumenten tellen als aanwijzing en blijven behouden, ook binnen `Sensitive(...)`. Andere lookup-vormen worden conservatief als mogelijke waarde behandeld. |
| `hiera_sensitive_conversion` | Herkent letterlijke sleutels in `lookup_options` met `convert_to: Sensitive`, `Sensitive[...]` of `[Sensitive]`. Overeenkomende datasleutels in **alle geselecteerde YAML/JSON-bestanden** worden als gevoelig behandeld. Neem de toepasselijke conversiebestanden mee bij je gegevens. |
| `encrypted_secret` | Herkent volledige `ENC[...]`-waarden, waaronder Hiera eyaml PKCS7 en SOPS AES256_GCM. Maskeert de volledige versleutelde waarde zonder die te ontsleutelen. |
| `pem_material` | Herkent volledige blokken met privésleutels, certificaten en CSR's, inclusief headers voor RSA-, EC-, OpenSSH- en PGP-privésleutels. Maskeert iedere regel. |
| `token_signature` | Herkent GitHub-, GitLab PAT-, Slack- en AWS-access-key-ID-patronen, OpenAI-achtige prefixen en JWT-achtige tekenreeksen. De exacte prefixen en lengten staan in de [patroondefinities](lib/project_tools/secrets/patterns.rb). |
| `authorization`, `credential_url` | Herkent losse `Basic`/`Bearer`-waarden van minimaal 12 tokentekens en gebruikersgegevens vóór `@` in URL's; bij `ssh://` en `git+ssh://` blijft een gewone gebruikersnaam zonder wachtwoord behouden. Benoemde autorisatievelden vallen ook onder de toewijzingsregels. |

Niet-afgesloten aanhalingstekens, haakjes of blokken, geneste blokmarkeringen, onduidelijke ingesprongen vervolgregels en niet-ondersteunde gevoelige heredocs blokkeren het maken van kopieën. YAML-aliases, complexe sleutels en Hiera-conversieselectoren met reguliere expressies vereisen lokale beoordeling. Als het bereik van een conversie niet kan worden bepaald, wordt de volledige selectie geblokkeerd. Parserfouten, ongeldige UTF-8, binaire inhoud of besturingstekens, symlinks, bijzondere bestandstypen, onleesbare of ontbrekende paden, lege mappen en bestanden groter dan 5 MiB geven een onvolledige controle. Lege gewone bestanden kunnen wel worden gecontroleerd. De ondersteunde archiefformaten en grenzen staan bij [Archieven controleren](#archieven-controleren).

De algemene scanmodus herkent afgebakende tekstpatronen; de onderstaande Puppet-modus gebruikt daarnaast de syntaxisboom van OpenVox. JSON wordt met de YAML-bronparser gelezen, zonder strikte JSON-validatie. Variabelen, includes, externe Hiera-hiërarchieën en -backends en runtime-lookups worden niet uitgewerkt. XML-elementen, onbekende veldnamen, verhulde of gecodeerde waarden en inloggegevens die over meerdere bestanden zijn verdeeld, kunnen worden gemist. Onterechte bevindingen zijn mogelijk, ook in broncode en synthetische testbestanden. Persoons-, klant-, host- en andere vertrouwelijke gegevens worden niet volledig herkend. Laat bij twijfel de inhoud lokaal door iemand beoordelen voordat je die deelt, ook bij gemaskeerde kopieën.

Een naam of getal alleen bepaalt geen uitzondering. `api_key_count` met een geheel getal, de numerieke beleidsvelden `password.minlength`, `password.retrylimit` en `password.expiration` (ook de ondersteunde underscore- en koppeltekenvarianten), en `TOKEN_EXPIRE`, `TOKEN_TTL` of `TOKEN_LIFETIME` met een getal en eventueel `s`, `m`, `h`, `d` of `w` beschrijven metadata. Een numeriek `password` of een willekeurige tekenreeks in zo'n beleidsveld blijft een mogelijke geheime waarde. Een expliciete Hiera-conversie naar `Sensitive` blijft leidend. Private-keyvelden met een `puppet:///`-bronverwijzing bevatten geen sleutelbytes; controleer de bron afzonderlijk. Een bestandsachtig woord onder een onduidelijke eigen interface vraagt een exacte lokale beoordeling.

Een volledige ERB-verwijzing naar een instantievariabele, eventueel met `.unwrap`, of `ENV['NAAM']` blijft behouden. Een letterlijk fallbackargument blijft een waarde. De scanner herkent een CI-job met een naam met spaties, een `stage` en een `script` op het hoogste YAML-niveau; het joblabel maakt de gewone opdrachten niet gevoelig. Geneste geheime velden en letterlijke credentials in die opdrachten worden wel onderzocht. Rake-taaknamen na het commando `rake` worden als opdrachten behandeld. Dit maakt de overige inhoud van een script of codeblok niet automatisch veilig.

Voor Ruby-bronnen gebruikt de scanner Ripper uitsluitend om geldige bronsyntaxis te herkennen. Dit voorkomt dat een volgende Ruby-opdracht als ingesprongen vervolgwaarde wordt behandeld. Ongeldige Ruby en onbegrensde geheime invoer in testliterals blijven onvolledig; geldige Ruby maakt de inhoud van die literals niet automatisch veilig. Bij geciteerde shellopdrachten begrenst het omringende aanhalingsteken de waarde. Niet-ondersteunde heredocs en andere onduidelijke grenzen blijven geblokkeerd. De tool voert broncode of fixtures nooit uit.

## Archieven controleren

De algemene scan ondersteunt tar, gzip, `.tar.gz` en `.tgz` lokaal in het geheugen. Dezelfde controles gelden voor gewone tekstleden, inclusief Hiera-conversies tussen geselecteerde leden en andere geselecteerde databestanden. Er worden geen leden naar het bestandssysteem uitgepakt en geen programma's gestart. ZIP/JAR, uitvoerbare bestanden en andere niet-ondersteunde binaire formaten blijven onvolledig, tenzij het exacte artefact afzonderlijk is beoordeeld volgens de onderstaande procedure.

Per bestand of lid geldt de bestaande grens van 5 MiB. Een aanroep verwerkt maximaal 25 MiB uitgepakte gegevens, 1000 leden en drie archieflagen. Dubbele leden, absolute paden, `..`, symlinks, hardlinks, bijzondere bestandstypen, ongeldige headers, afgebroken inhoud en aanvullende gegevens na het archief worden geweigerd. Een overschreden grens of ongeldig archief is geen goedgekeurd binair artefact en kan niet worden uitgezonderd.

Het rapport behoudt één record per geselecteerd bestand. `coverage: archive` benoemt archiefinspectie; bevindingen hebben daarnaast een numerieke `member`-route. Een analysekopie van een archief bevat alleen de gemaskeerde tekstleden met genummerde labels. Zij is geen opnieuw verpakt archief en bevat geen oorspronkelijke lidnamen. Een fout in één lid houdt alle kopieën van de aanroep tegen.

## Exacte lokale beoordelingen

Gebruik `--review POLICY.json` uitsluitend voor lokaal beoordeelde niet-geheime inhoud of bewust synthetische fixtures. Het beleid wordt niet automatisch gezocht. Dezelfde CLI, JSON en expliciete beleidsfile gelden lokaal en in CI. Een algemene mapuitsluiting, alleen een bestandsnaam of een losse hash is geen beoordeling.

Een JSON-object met `schema: 1` bevat een `entries`-array. Iedere entry heeft precies de onderstaande velden. Laat de inhoud lokaal beoordelen voordat je de entry toevoegt; de tool kan die menselijke beslissing niet zelf bevestigen.

| Veld | Vereiste |
| --- | --- |
| `path` | Eén bestaand regulier bestand, relatief aan de huidige projectroot; geen globs, symlinks, absolute paden of `..`. |
| `control` | `non_secret_value`, `non_secret_artifact` of `synthetic_fixture`. |
| `rationale`, `owner` | Niet-lege uitleg en verantwoordelijke voor de lokale beoordeling; geen credentials of private inhoud. |
| `reviewed_on`, `expires_on` | ISO-datums `YYYY-MM-DD`; beoordeling niet in de toekomst, herbeoordeling uiterlijk vóór de vervaldatum. |
| `sha256` | SHA256 van de exacte lokaal beoordeelde bestandsbytes, uitsluitend voor deze niet-geheime of synthetische inhoud. |
| `findings` | De volledige verwachte lijst uit dezelfde scanmodus, met precies `line`, `rule` en `kind` per bevinding. |
| `errors` | De volledige verwachte lijst vaste foutcodes; nooit parserdiagnostiek of bronfragmenten. |

`non_secret_value` vereist een volledige inspectie zonder fouten. `non_secret_artifact` staat uitsluitend `unsupported_encoding` en `binary_content` toe. `synthetic_fixture` kan daarnaast de expliciet ondersteunde onbegrensde tekst- of blokwaarden en ongeldige YAML/Ruby beschrijven; de exacte lijst staat in [het beleidsschema](lib/project_tools/secrets/review_policy.rb). Ontbrekende invoer, onleesbare bestanden, gewijzigde bronnen, gereedschapsfouten, archieffouten, ongeldige configuratie en rapportagefouten blijven fouten. Onbekende of dubbele velden, dubbele paden, verlopen entries en te brede scopes worden geweigerd. Alle entries moeten geldige velden, bestaande paden en geldige datums hebben, ook als hun bestanden niet in de huidige selectie staan. Bij geselecteerde bestanden maken andere bytes, fouten of bevindingen de beoordeling ongeldig.

Maak een beoordeling in deze volgorde:

1. Scan vanuit de consumerroot het exacte bestand, met de scanmodus die je later ook gebruikt. Neem `findings` en `errors` uit dat metadataresultaat over; pas ze niet aan om de scan te laten slagen.
2. Laat de inhoud lokaal beoordelen en leg vast waarom het een niet-geheim artefact, niet-geheime waarde of synthetische fixture is. Gebruik geen echte credential als review-uitzondering.
3. Bereken pas voor die beoordeelde inhoud de SHA256, bijvoorbeeld met `bundle exec ruby -rdigest -e 'puts Digest::SHA256.file(ARGV.fetch(0)).hexdigest' modules/example/files/artifact.bin`. De opdracht leest lokaal en toont alleen de hash; neem geen bronbytes of hashes van echte geheimen over in de beleidsfile of externe communicatie.
4. Vul de verantwoordelijke, reden, beoordelingsdatum en vervaldatum in en laat de beleidswijziging volgens de eigen projectwerkwijze reviewen.

Onderstaand JSON-fragment toont de complete bestandsstructuur voor een beoordeeld binair artefact waarvan de scan geen bevindingen en uitsluitend `unsupported_encoding` heeft gemeld. Het is een **invulsjabloon**: vervang het voorbeeldpad en alle `<...>`-velden door de lokaal vastgestelde gegevens. De scanner weigert het oningevulde sjabloon. Gebruik bij een andere scanuitkomst de bijbehorende volledige metadata en het passende controltype.

```json
{
  "schema": 1,
  "entries": [
    {
      "path": "modules/example/files/artifact.bin",
      "control": "non_secret_artifact",
      "rationale": "<reden voor de lokale beoordeling>",
      "owner": "<verantwoordelijke>",
      "reviewed_on": "<YYYY-MM-DD>",
      "expires_on": "<YYYY-MM-DD>",
      "sha256": "<SHA256 van de beoordeelde bytes>",
      "findings": [],
      "errors": ["unsupported_encoding"]
    }
  ]
}
```

Bewaar bijvoorbeeld `.tools/secrets-review.json` in het afnemende project en geef de beleidsfile expliciet mee. Voer de scan opnieuw uit vanuit dezelfde consumerroot:

```sh
bundle exec project-tools-secrets --json --review .tools/secrets-review.json modules/example/files/artifact.bin
```

Een geaccepteerde beoordeling verplaatst de oorspronkelijke metadata naar `reviewed_findings` en `reviewed_errors`. `coverage` begint dan met `reviewed_`; dit is een lokale beoordeling, geen inspectie die afwezigheid van geheimen heeft vastgesteld. Actieve indicators behouden exitcode 1; zonder actieve bevindingen kan de aanroep exitcode 0 geven. Een consumer die uitsluitend volledige resultaten zonder actieve value-bevindingen accepteert, kan hetzelfde beleid gebruiken. Maak die dekking ook in de review zichtbaar.

Analysekopieën van beoordeelde bestanden bevatten altijd `[REVIEWED CONTENT WITHHELD]`, nooit de uitgezonderde bron. De bestaande directory- en bestandsrechten blijven gelden. Gebruik een review-entry dus niet om een onbekend binair bestand of een synthetisch geachte waarde via een analysekopie te delen.

## Puppet-manifesten in standaardtests en CI

Gebruik voor de verplichte controle op hardcoded waarden de bestaande CLI met `--puppet`. Deze modus vereist OpenVox 8 in dezelfde bundle; de repositorybundle bevat die dependency al. De parser leest alleen syntaxis: de scanner compileert geen catalogus en voert geen functies, facts of Hiera-lookups uit. De algemene voorcontrole voor externe analyse blijft afzonderlijk verplicht en omvat ook YAML, templates en overige geselecteerde bestanden.

```sh
bundle exec project-tools-secrets --puppet manifests/ modules/example/manifests/ extra.pp
bundle exec rake secrets:puppet
bundle exec rake test
```

De CLI accepteert een hele map, meerdere mappen, een lijst bestanden of een combinatie in één proces. Met `--puppet` worden uitsluitend `.pp`-bestanden geselecteerd. Een selectie zonder manifesten, onleesbare invoer of een parserfout faalt met exitcode 2. Niet-geselecteerde bestandstypen zijn daarmee niet gecontroleerd. De repositorytaak selecteert alle eigen manifesten, inclusief `examples/`, en sluit `.tools/`, `vendor/` en de vier externe modules `concat`, `debconf`, `reboot` en `stdlib` uit. `bundle exec rake test` en de standaardtaak `bundle exec rake` voeren deze controle verplicht vóór de tooltests uit. De gerichte `test:*`-taken testen alleen de betreffende tool. De afzonderlijke native parservalidatie blijft verplicht.

`puppet_hardcoded_value` meldt letterlijke waarden in gevoelige parameters, variabelen, resourceattributen en hashvelden. Ook een letterlijk argument van `Sensitive` of `Sensitive.new` wordt afgekeurd. De bestaande herkenning van tokenprefixen, autorisatie, credential-URL's, versleutelde waarden en PEM-materiaal blijft actief. Het rapport toont uitsluitend bestand, regelnummer, regel en volledigheid; exitcode 1 blokkeert de tests. `--json`, `--junit` en `--redact` blijven beschikbaar met hetzelfde veilige uitvoercontract.

Een variabele, geïndexeerde verwijzing, `.unwrap`, `undef`, `Sensitive[String]` of getypeerde Hiera-lookup bevat zelf geen hardcoded geheim. Deze constructies veroorzaken in Puppet-modus geen bevinding en dus geen onterechte testfout. Letterlijke lookup-defaults via argumenten, `default_value`, `default_values_hash`, `override` of een defaultlambda worden wel onderzocht in een gevoelige context; deze invoervormen volgen de [Puppet-lookupinterface](https://help.puppet.com/core/current/Content/PuppetCore/puppet_lookup.htm). Ook ongequote veldnamen en letterlijke woordwaarden worden onderzocht. Een YAML-waarde achter de lookup moet met de algemene scanmodus afzonderlijk worden gecontroleerd.

De controle onderscheidt code van gegevens. Namen voor bestandspaden, scripts en wachtwoordbeleid worden beperkt uitgezonderd volgens `METADATA_NAME` in de [Puppet-implementatie](lib/project_tools/secrets/puppet_scan.rb). Lege waarden en Unix-vergrendelmarkeringen zijn geen credential. Template-, EPP- en bestandsverwijzingen worden niet uitgevoerd. Een uit verwijzingen samengestelde expressie binnen `Sensitive` is op zichzelf geen letterlijk geheim; herkenbare letterlijke geheime commandoregelargumenten en lookup-defaults in die expressie worden wel onderzocht. De inhoud van de verwijzingen vereist afzonderlijke beoordeling. De scanner voert geen gegevensstroomanalyse uit. Geheimen onder onbekende namen, verborgen in berekeningen, tekstfragmenten van samengestelde commando's of gewone commentaren kunnen daarom worden gemist. Bekende token- en PEM-signaturen worden ook in commentaren gevonden. **Geen bevindingen betekent alleen dat de uitgevoerde controles geen patroon vonden.**

De [GitHub-workflow](../../.github/workflows/checks.yml) voert `bundle exec rake secrets:puppet` uit in de vaste job **Puppet secrets**, bij iedere push, pull request en merge-group. Er zijn geen padfilters die een vereiste controle in afwachting laten. Andere jobs wachten op deze controle, zodat hun bronfragmenten niet verschijnen wanneer de secrets-controle faalt. Ook `git diff` gebruikt daar uitsluitend een stille statuscontrole. Het secrets-resultaat bevat geen bronfragmenten en er worden geen bronbestanden of analysekopieën als artifact gepubliceerd.

Selecteer na de eerste workflowuitvoering **Puppet secrets** als verplichte statuscontrole in branch protection of het ruleset van de doelbranch. Dit is een instelling van de repositorybeheerder; alleen een workflowbestand maakt een check niet verplicht. Behoud de jobnaam en neem bij gebruik van een merge queue de `merge_group`-trigger over. Zie GitHubs [uitleg over vereiste controles](https://docs.github.com/en/pull-requests/how-tos/merge-and-close-pull-requests/troubleshooting-required-status-checks).

## Een afgekeurd manifest herstellen

Beoordeel de gemelde locatie lokaal zonder de waarde te kopiëren naar logs, tickets of AI-context. Verplaats het geheim naar de daarvoor goedgekeurde Hiera- of secretbackend en gebruik in het manifest een lookup of parameterverwijzing. `Sensitive` beschermt Puppet-uitvoer maar maakt een hardcoded waarde niet toegestaan. Bij een fout of onvolledige scan herstel je eerst de invoer of parserdependency; omzeil de controle niet met een uitsluiting of een genegeerde exitcode. Laat twijfelgevallen lokaal beoordelen. Gebruik bij vermoede blootstelling de [meld- en herstelprocedure](#gemiste-gegevens-of-een-fout-melden).

Voer na herstel opnieuw `bundle exec rake secrets:puppet` en de standaardtests uit. Bij een onterechte melding voeg je een volledig synthetisch voorbeeld toe aan de bestaande regressietests, pas je de centrale regel aan en controleer je ook de bijbehorende echte positieve gevallen. Een consumer krijgt geen eigen scanner of afwijkende detectieregels.

## Gemiste gegevens of een fout melden

Blijkt dat de scanner gevoelige gegevens heeft gemist, onvolledig heeft gemaskeerd of via een rapport of foutmelding heeft getoond, volg dan de [incidentafspraken](../../AGENTS.md#disclosure-incidents). Die vereisen een directe melding aan de gebruiker met hersteladvies, ook als het probleem lokaal is ontdekt voordat iets extern is gedeeld. Een eerdere exitcode 0 of een gemaakte analysekopie neemt die meldplicht niet weg. De scanner kan een patroon dat hij niet herkent niet zelf als gemist rapporteren; deze werkwijze geldt zodra een gebruiker, assistent of aanvullende controle het probleem vaststelt of vermoedt.

Gebruik voor de melding uitsluitend veilige metadata: het soort gegevens, een geanonimiseerde bronverwijzing, zo mogelijk het regelnummer of de herkenningsregel, en waar de gegevens mogelijk terechtkwamen. Maak onderscheid tussen alleen lokaal aangetroffen gegevens, bevestigde externe blootstelling en onbekende of vermoede blootstelling. Neem geen waarde, ongefilterd tekstfragment, fingerprint of oorspronkelijke fouttekst over. Benoem een oorzaak alleen als die is vastgesteld; geef anders aan wat nog onderzocht moet worden.

Geef in dezelfde melding een uitvoerbaar hersteladvies. Stel verdere analyse van de betrokken uitvoer uit en gebruik de bestaande kopieën niet opnieuw. Bij blootgestelde inloggegevens of sleutels omvat de incidentafhandeling ook intrekken of vervangen; alleen de scanner repareren maakt die blootstelling niet ongedaan. Kies de technische correctie op basis van het aangetroffen probleem:

| Probleem | Gericht hersteladvies |
| --- | --- |
| Een veld of patroon wordt gemist. | Maak een lokaal voorbeeld met volledig fictieve gegevens en voeg herkenning en regressiedekking toe aan de gedeelde tool. Beschrijf een resterende beperking als betrouwbare herkenning niet mogelijk is. |
| Een waarde blijft geheel of gedeeltelijk zichtbaar in een analysekopie. | Herstel de afbakening en het maskeren van de volledige waarde, inclusief vervolgregels. Laat de tool kopieën weigeren als die afbakening niet betrouwbaar vaststaat. |
| Een rapport, foutmelding of log toont brongegevens. | Verwijder de ongefilterde uitvoer uit dat uitvoerpad en gebruik veilige metadata of een vaste foutidentificatie. Controleer alle betrokken uitvoervormen op hetzelfde lek. |
| Een aanroeper leest het origineel of deelt uitvoer vóór de scan. | Herstel de aanroepvolgorde zodat de lokale controle en beoordeling vóór het lezen plaatsvinden en de analyse de vrijgegeven kopieën gebruikt. |

De [onderhoudsinstructies](AGENTS.md) regelen de synthetische reproductie, regressietests en reparatie van de gedeelde implementatie. Maak na herstel nieuwe kopieën uit opnieuw gecontroleerde bronnen en beoordeel de betrokken uitvoerpaden opnieuw. Vermeld welke correctie is uitgevoerd, waarmee die is gecontroleerd en welke onzekerheden of vervolgstappen openstaan. Zolang veilige controle of maskering onzeker blijft, blijft lokale menselijke beoordeling nodig voordat de betrokken inhoud extern wordt gebruikt.

## Gebruik in een ander project

Deze stappen zijn bedoeld voor een Puppet-project dat deze repository al als `global-modules/` gebruikt. Voer alle commando's uit vanuit de root van dat afnemende project, waar zijn eigen `Gemfile` staat. Gebruik de bestaande gedeelde scanner; je project stelt alleen de bestandsselectie, taken, CI en eventuele lokale beoordelingen in. Een geïnstalleerde gem start geen controles en neemt de instructies uit de submodule niet automatisch over.

### Kies de controles voor je project

De tool heeft twee toepassingen. Richt ze afzonderlijk in, omdat ze verschillende invoer en vervolgstappen hebben:

| Toepassing | Aanroep | Wat je ermee controleert |
| --- | --- | --- |
| Vóór AI of externe analyse | `bundle exec project-tools-secrets PATH ...` | De werkelijk te lezen bestanden, waaronder YAML/Hiera, templates, scripts en configuratie. Bij bevindingen maak je met `--redact` afzonderlijke analysekopieën. Volg [Controleren voor het lezen](#controleren-voor-het-lezen). |
| Vóór tests en diagnoses in CI | `bundle exec project-tools-secrets --puppet PATH ...` | Hardcoded waarden in de eigen Puppet-manifesten. Alleen exitcode 0 laat de volgende controle starten. Volg [Puppet-manifesten in standaardtests en CI](#puppet-manifesten-in-standaardtests-en-ci). |

`--puppet` selecteert alleen `.pp`-bestanden. Een geslaagde Puppet-controle geeft dus geen toestemming om daarna Hiera, templates of andere bestanden ongecontroleerd te lezen. Een algemene scan kan op zijn beurt exitcode 1 geven voor een veilige verwijzing: beoordeel daarbij de metadata volgens [Resultaten en exitcodes](#resultaten-en-exitcodes).

### Installeer in de eigen bundle

Zorg dat de vastgelegde revisie van `global-modules` de gekozen scannerfunctionaliteit bevat. Met de onderstaande opdracht haal je de reeds vastgelegde submodule en haar dependencies op; je kiest hiermee geen nieuwere revisie:

```sh
git submodule update --init --recursive global-modules
```

Voeg de volgende dependencies toe aan de **eigen** Gemfile, zonder bestaande gemdefinities dubbel op te nemen. Dit voorbeeld ondersteunt beide scanmodi en de Rake-taak hieronder. Gebruik de [gedeelde Ruby- en Bundler-installatie](../README.md#benodigde-omgeving) als voorbereiding.

```ruby
source 'https://rubygems.org'

gem 'project-tools-shared', path: 'global-modules/.tools/shared', require: false
gem 'project-tools-secrets', path: 'global-modules/.tools/secrets', require: false
gem 'openvox', '~> 8.0', require: false
gem 'syslog', require: false
gem 'rake', require: false
```

Voor uitsluitend de algemene voorcontrole volstaan shared en secrets; JSON en Psych worden via de gemdependencies geïnstalleerd. OpenVox is nodig voor `--puppet`, `syslog` voor die runtime met Ruby 4 en Rake voor de eigen taken. De scanner vereist geen rootmetadata, `VERSION`, lintconfiguratie of `PROJECT_TOOLS_MODULEPATH`. Andere tools in je bundle kunnen die wel vereisen.

Installeer vanuit de consumerroot en controleer waar Bundler de gem vandaan haalt:

```sh
bundle install
bundle info --path project-tools-secrets
bundle exec project-tools-secrets --help
```

`bundle install` werkt de eigen `Gemfile.lock` bij. Bij deze path-installatie moet `bundle info` naar `global-modules/.tools/secrets` wijzen. Bewaar de gekozen submodulerevisie en de eigen lockfile volgens je projectwerkwijze. Voer de scan ook daarna vanuit de consumerroot uit; laad hiervoor niet de Gemfile of het Rakefile van `global-modules`. Voor een [Git-gembron of gebouwd pakket](../README.md#importeren-en-distribueren) blijven de verdere stappen gelijk, maar gebruik je de daar beschreven Gemfile-bronnen.

### Richt de voorcontrole voor AI en externe analyse in

Leg in de eigen `AGENTS.md` vast dat de voorcontrole verplicht is. Een korte verwijzing maakt de centrale werkwijze bereikbaar zonder de detectieregels te kopiëren. Bijvoorbeeld, als fragment voor de projectroot:

```markdown
## Local inspection before disclosure

Before project content enters AI context or external analysis, follow the [shared local inspection procedure](global-modules/.tools/secrets/README.md#controleren-voor-het-lezen). Run the installed scanner from this project root and withhold content when inspection or masking is incomplete. These instructions also apply to command output and diffs.
```

Kies de bestanden die je daadwerkelijk nodig hebt en neem toepasselijke Hiera-`lookup_options` in dezelfde scan mee. De scanner ontdekt geen externe Hiera-hiërarchie. Geef niet zonder selectie de volledige projectroot op: `.git`, geïnstalleerde gems, de submodule, binaire bestanden en oude uitvoer vallen dan ook binnen de recursieve scan; `.gitignore` is geen scanneruitsluiting.

Onderstaand voorbeeld veronderstelt dat beide genoemde bestanden bestaan. Vervang ze door je eigen bronselectie. De tweede opdracht schrijft alleen gemaskeerde kopieën naar een **nieuwe** map buiten de invoer; kies bij een volgende uitvoering een andere nieuwe map.

```sh
bundle exec project-tools-secrets --json modules/profile/manifests/init.pp data/common.yaml
bundle exec project-tools-secrets --json --redact /tmp/puppet-analysis-01 modules/profile/manifests/init.pp data/common.yaml
```

Beoordeel na iedere aanroep eerst de metadata. Exitcode 1 blijft ook na succesvol maskeren bestaan; dat is geen reden om het origineel te openen. Lees uitsluitend de door dat resultaat aangewezen kopieën en volg het [maskeringscontract](#analysekopieën-maken). Exitcode 2 of `complete: false` blokkeert vrijgave. Een automatische koppeling controleert ook de geselecteerde bestanden, hun foutstatus en de geproduceerde kopieën; gebruik niet alleen de aanwezigheid van een uitvoermap als bewijs. Kopieën met `[REVIEWED CONTENT WITHHELD]` geven de beoordeelde bron niet vrij.

### Koppel de Puppet-controle aan eigen taken

Gebruik één selectie van je eigen manifesten voor lokaal werk en CI. Het onderstaande fragment selecteert `environments/**/*.pp` en `modules/**/*.pp`; pas die patronen aan je project aan en houd geïmporteerde modules buiten deze selectie. De gem voegt zelf geen Rake-taak toe.

Plaats dit fragment in het eigen `Rakefile`, **vóór** de bestaande definities en prerequisites van `test`. Daardoor draait de secrets-controle voordat testtaken of andere prerequisites bronfragmenten kunnen tonen. Behoud de bestaande testimplementatie onder het fragment; importeer het Rakefile van `global-modules` niet.

```ruby
require 'rake'

task test: 'secrets:puppet'

namespace :secrets do
  desc 'Check hardcoded values in project Puppet manifests'
  task :puppet do
    manifests = FileList['environments/**/*.pp', 'modules/**/*.pp']
    abort 'No Puppet manifests selected.' if manifests.empty?

    sh 'bundle', 'exec', 'project-tools-secrets', '--puppet', *manifests, verbose: false do |ok, status|
      raise SignalException, status.termsig if status.signaled?

      exit status.exitstatus unless ok
    end
  end
end
```

De taak bewaart de scannerstatus: een bevinding of onvolledige inspectie stopt `rake test` vóór de eigen tests. Een lege selectie faalt ook. Laat een bestaande standaardtaak via `test` lopen als `bundle exec rake` dezelfde controle moet uitvoeren. Heeft je project geen eigen tests, gebruik dan alleen de taak `secrets:puppet` en laat de prerequisite voor `test` weg; maak geen lege testsuite aan.

Controleer vanuit de consumerroot beide ingangen wanneer je project eigen tests heeft:

```sh
bundle exec rake secrets:puppet
bundle exec rake test
```

Controleer de koppeling ook met een tijdelijk synthetisch manifest buiten versiebeheer: een hardcoded waarde moet de testtaak blokkeren, een gewone lookup moet worden toegestaan en een parserfout moet als fout blijven terugkomen. Gebruik hiervoor nooit een echte credential. Een geslaagde secrets-controle vervangt de afzonderlijke parser-, lint- of dependencycontrole niet.

### Neem de controle op in CI

Gebruik de [centrale voorbeelden voor GitHub Actions en GitLab](../README.md#controle-in-ci) voor installatie, jobafhankelijkheden en rapporten. Iedere job gebruikt de eigen Gemfile en lockfile en haalt `global-modules` met haar submodules op. Neem de secrets-job vóór de jobs die brongegevens kunnen tonen op; een mislukte of onvolledige scan mag die jobs niet laten starten.

De voorbeelden roepen de gedeelde CLI rechtstreeks aan met `environments/ modules/`. Gebruik je de bovenstaande Rake-taak, vervang dan in de secrets-job alleen die scanaanroep door:

```sh
bundle exec rake secrets:puppet
```

Zo gebruiken lokaal werk en CI dezelfde selectie. Zonder Rake houd je de rechtstreekse CLI-aanroep en stem je de paden zelf af. Behoud de oorspronkelijke foutstatus; voeg geen `|| true`, `allow_failure` of `continue-on-error` toe. Publiceer geen bronbestanden of analysekopieën als artifact. Voor een gewenst metadatarapport gebruik je de bestaande [JUnit-optie](#resultaten-en-exitcodes) met een nieuw rapportpad buiten de invoer.

Stel de gate ook verplicht voor samenvoegen in volgens de regels van je hostingplatform. Behoud in GitHub de statusnaam **Puppet secrets** uit het voorbeeld; een workflowbestand alleen maakt die status niet verplicht. Controleer na publicatie met een synthetische fout dat downstreamjobs en samenvoegen worden geblokkeerd. De lokale tooltests voeren die instelling op je hostingplatform niet uit.

### Beheer lokale beoordelingen en updates

Een reviewbeleid is optioneel. Bewaar het, wanneer nodig, in het afnemende project, bijvoorbeeld als `.tools/secrets-review.json`. De `path`-velden zijn relatief aan de consumerroot, niet aan de map van de beleidsfile of aan `global-modules`. Volg [Exacte lokale beoordelingen](#exacte-lokale-beoordelingen) voor het schema en de inhoudelijke beoordeling; het installeren van de gem maakt geen uitzonderingen aan.

Geef het beleid expliciet met `--review` mee aan iedere bedoelde aanroep. Bij de Rake-taak voeg je daarvoor `'--review', '.tools/secrets-review.json'` vóór `*manifests` toe aan de `sh`-aanroep. Gebruik lokaal en in CI dezelfde versie van het beleid voor dezelfde scanmodus en invoer. Bevindingen in de algemene modus en in `--puppet` kunnen verschillen; een beoordeling voor de ene modus is geen automatische uitzondering in de andere. Beheer zo nodig afzonderlijke beleidsfiles per modus. Werk nooit alleen de hash bij om gewijzigde inhoud alsnog te accepteren: beoordeel de inhoud opnieuw.

Werk de tooling bij door een goedgekeurde revisie van `global-modules` te kiezen en vanuit de consumerroot `bundle install` uit te voeren. Controleer met `bundle info --path project-tools-secrets` de gebruikte bron en doorloop daarna de lokale voorcontrole, Puppet-gate en eigen kwaliteitscontroles opnieuw. Leg de nieuwe gitlink, lockfile en eventuele opnieuw beoordeelde beleidsentries samen ter review voor. Ook na een update blijven onvolledig gecontroleerde bestanden afgeschermd.

## Ontwikkelen en testen

Voeg nieuwe detectie toe in deze bestaande tool: gedeelde signaturen in `patterns.rb`, Puppet-syntaxis in `puppet_scan.rb` en YAML/Hiera in `yaml_scan.rb`. Voeg positieve, negatieve, meerregelige en rapportagegevallen met synthetische waarden toe onder `tests/`; test gewijzigde Rake- en CI-koppelingen onder `../repository-checks/tests/`. Werk deze patroonbeschrijving in dezelfde wijziging bij. Volg de [onderhoudsinstructies](AGENTS.md). De gem bevat runtimecode, de executable, de README en de licentie. Links naar andere tools, instructies en tests vereisen de bijbehorende checkout.

Voer `bundle exec rake test:secrets` uit voor synthetische tests van herkenning, maskeren, gegevensbescherming, foutafhandeling en zelfstandige installatie. `bundle exec rake test` neemt deze tests mee in de [gezamenlijke suite](../README.md#gezamenlijke-tooltests). Geslaagde tests onderbouwen de geteste afspraken; ze bewijzen niet dat willekeurige bestanden geen onbekende geheimen bevatten.
