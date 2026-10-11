# Gevoelige gegevens lokaal controleren

`project-tools-secrets` leest bestanden lokaal voordat je de inhoud gebruikt voor externe analyse of AI-analyse. De tool meldt mogelijke geheimen zonder hun waarden te tonen en kan afzonderlijke kopieën maken waarin die waarden zijn gemaskeerd. De tool maakt geen netwerkverbindingen, voert geen invoer uit en wijzigt nooit de bronbestanden.

## Inhoudsopgave

- [Inhoudsopgave](#inhoudsopgave)
- [Controleren voor het lezen](#controleren-voor-het-lezen)
- [Analysekopieën maken](#analysekopieën-maken)
- [Resultaten en exitcodes](#resultaten-en-exitcodes)
- [Patronen en beperkingen](#patronen-en-beperkingen)
- [Puppet-manifesten in standaardtests en CI](#puppet-manifesten-in-standaardtests-en-ci)
- [Een afgekeurd manifest herstellen](#een-afgekeurd-manifest-herstellen)
- [Gemiste gegevens of een fout melden](#gemiste-gegevens-of-een-fout-melden)
- [Gebruik in een ander project](#gebruik-in-een-ander-project)
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
| `0` | `no_findings` | Alle geselecteerde bestanden zijn gecontroleerd; geen ondersteund patroon gevonden. **Dit is geen veiligheidsgarantie.** |
| `1` | `findings` | Mogelijke geheime waarden of aanwijzingen voor gevoelige gegevens gevonden. Beoordeel en maskeer de inhoud vóór openbaarmaking; ook na maskeren blijft de exitcode 1. |
| `2` | `incomplete` | Selectie, controle, maskeren of rapportage is mislukt of onvolledig. Geef de inhoud niet vrij totdat de oorzaak is verholpen of iemand de inhoud lokaal heeft beoordeeld. |

Per bestand bevat het rapport `file`, `complete`, `findings`, `errors` en eventueel `copy`. Iedere bevinding vermeldt het oorspronkelijke regelnummer in `line`, een vaste herkenningsregel in `rule` en het soort bevinding in `kind`: `value` voor een mogelijke geheime waarde, `indicator` voor een naam of constructie. Geen enkele regel controleert of een gevonden inloggegeven actief is. De algemene JSON-eigenschap `complete` omvat ook fouten bij uitvoer en rapportage en is leidend boven geslaagde deelcontroles.

Een verwijzing via `lookup('mysql::user::example::password', Sensitive[String])` bevat zelf geen wachtwoord. De scanner behoudt deze expressie in de analysekopie en meldt uitsluitend aanwijzingen (`indicator`), geen geheime waarde (`value`). Exitcode 1 blijft van toepassing omdat het veld op gevoelige gegevens wijst. De daadwerkelijke waarde in het bijbehorende YAML-bestand wordt afzonderlijk gecontroleerd en gemaskeerd; neem dat bestand mee in de selectie. Een letterlijk meegegeven standaardwaarde valt niet onder deze uitzondering en wordt wel gemaskeerd.

Console-uitvoer, JSON en JUnit bevatten geen bronfragmenten, gevonden waarden, fingerprints of oorspronkelijke foutteksten. Fouten hebben vaste identificaties. Gevonden waarden en herkenbare tokenpatronen worden uit getoonde paden verwijderd; vertrouwelijke bestandsnamen vereisen nog steeds lokale beoordeling. Zet geen inloggegevens in argumenten of bestandsnamen. De CLI schakelt het afdrukken van exceptions in Ruby-debugmodus uit en heeft geen modus die gevonden waarden logt.

Met `--junit /existing/parent/new-report.xml` krijg je dezelfde bevindingen ook als JUnit: bevindingen worden `failures`, onvolledig gecontroleerde bestanden worden `errors`. De bovenliggende map moet bestaan en het doelbestand moet nieuw zijn en buiten de invoer liggen. Een schrijffout bij het rapport geeft exitcode 2. Zonder deze optie blijven rapportbestanden ongemoeid. `--json` wijzigt de presentatie op stdout; `--help` toont de gebruiksinstructies zonder te scannen.

## Patronen en beperkingen

| Regel of constructie | Ondersteund gedrag |
| --- | --- |
| `sensitive_name`, `sensitive_assignment` | Herkent `password`, `passwd`, `passphrase`, `secret`, `token`, `api_key`/`apiKey`, `access_key`/`accessKey`, `private_key`/`privateKey`, `encryption_key`/`encryptionKey`, `signing_key`/`signingKey`, `authorization` en naamdelen met `pwd`, ongeacht hoofdletters. Herkent toewijzingen met `=`, Puppet `=>` of `:`, optionele aanhalingstekens, geïndexeerde sleutels en namespaceprefixen. Niet-lege waarden worden ook zonder `Sensitive` gemaskeerd. |
| `sensitive_yaml_value` | Ondersteunt YAML/Hiera/JSON-mappings, geneste waarden, lijsten, meerregelige waarden tussen aanhalingstekens en blokken met `\|`/`>`. Gebruikt bronposities uit de parser zonder tags of objecten te laden. Lege waarden en gewone YAML-nulls tellen als aanwijzing. |
| `puppet_sensitive` | `Sensitive[...]` wijst op gevoeligheid; argumenten van `Sensitive.new` en `Sensitive('...')` worden bij sluitende haakjes gemaskeerd, inclusief geneste expressies. Rechtstreekse variabelen, `lookup('key')` en `lookup('key', Sensitive[String])` zonder extra argumenten tellen als aanwijzing en blijven behouden, ook binnen `Sensitive(...)`. Andere lookup-vormen worden conservatief als mogelijke waarde behandeld. |
| `hiera_sensitive_conversion` | Herkent letterlijke sleutels in `lookup_options` met `convert_to: Sensitive`, `Sensitive[...]` of `[Sensitive]`. Overeenkomende datasleutels in **alle geselecteerde YAML/JSON-bestanden** worden als gevoelig behandeld. Neem de toepasselijke conversiebestanden mee bij je gegevens. |
| `encrypted_secret` | Herkent volledige `ENC[...]`-waarden, waaronder Hiera eyaml PKCS7 en SOPS AES256_GCM. Maskeert de volledige versleutelde waarde zonder die te ontsleutelen. |
| `pem_material` | Herkent volledige blokken met privésleutels, certificaten en CSR's, inclusief headers voor RSA-, EC-, OpenSSH- en PGP-privésleutels. Maskeert iedere regel. |
| `token_signature` | Herkent GitHub-, GitLab PAT-, Slack- en AWS-access-key-ID-patronen, OpenAI-achtige prefixen en JWT-achtige tekenreeksen. De exacte prefixen en lengten staan in de [patroondefinities](lib/project_tools/secrets/patterns.rb). |
| `authorization`, `credential_url` | Herkent losse `Basic`/`Bearer`-waarden van minimaal 12 tokentekens en gebruikersgegevens vóór `@` in URL's. Benoemde autorisatievelden vallen ook onder de toewijzingsregels. |

Niet-afgesloten aanhalingstekens, haakjes of blokken, geneste blokmarkeringen, onduidelijke ingesprongen vervolgregels en niet-ondersteunde gevoelige heredocs blokkeren het maken van kopieën. YAML-aliases, complexe sleutels en Hiera-conversieselectoren met reguliere expressies vereisen lokale beoordeling. Als het bereik van een conversie niet kan worden bepaald, wordt de volledige selectie geblokkeerd. Parserfouten, ongeldige UTF-8, binaire inhoud of besturingstekens, symlinks, bijzondere bestandstypen, onleesbare of ontbrekende paden, lege mappen en bestanden groter dan 5 MiB geven een onvolledige controle. Lege gewone bestanden kunnen wel worden gecontroleerd; archieven worden niet uitgepakt.

De algemene scanmodus herkent afgebakende tekstpatronen; de onderstaande Puppet-modus gebruikt daarnaast de syntaxisboom van OpenVox. JSON wordt met de YAML-bronparser gelezen, zonder strikte JSON-validatie. Variabelen, includes, externe Hiera-hiërarchieën en -backends en runtime-lookups worden niet uitgewerkt. XML-elementen, onbekende veldnamen, verhulde of gecodeerde waarden en inloggegevens die over meerdere bestanden zijn verdeeld, kunnen worden gemist. Onterechte bevindingen zijn mogelijk, ook in broncode en synthetische testbestanden. Persoons-, klant-, host- en andere vertrouwelijke gegevens worden niet volledig herkend. Laat bij twijfel de inhoud lokaal door iemand beoordelen voordat je die deelt, ook bij gemaskeerde kopieën.

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

De controle onderscheidt code van gegevens. Namen voor bestandspaden, scripts en wachtwoordbeleid worden beperkt uitgezonderd volgens `METADATA_NAME` in de [Puppet-implementatie](lib/project_tools/secrets/puppet_scan.rb). Lege waarden en Unix-vergrendelmarkeringen zijn geen credential. Template-, EPP- en bestandsverwijzingen worden niet uitgevoerd. Een uit verwijzingen samengestelde expressie binnen `Sensitive` is geen letterlijk geheim; de inhoud van die verwijzingen vereist afzonderlijke beoordeling. De scanner voert geen gegevensstroomanalyse uit. Geheimen onder onbekende namen, verborgen in berekeningen, tekstfragmenten van samengestelde commando's of gewone commentaren kunnen daarom worden gemist. Bekende token- en PEM-signaturen worden ook in commentaren gevonden. **Geen bevindingen betekent alleen dat de uitgevoerde controles geen patroon vonden.**

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

Gebruik de gedeelde implementatie uit je goedgekeurde checkout:

```ruby
source 'https://rubygems.org'

gem 'project-tools-shared', path: 'global-modules/.tools/shared', require: false
gem 'project-tools-secrets', path: 'global-modules/.tools/secrets', require: false
```

Voer `bundle install` uit en gebruik daarna dezelfde CLI met je eigen paden. Tijdens uitvoering zijn shared, JSON en Psych nodig; Voor de algemene scan zijn Puppet, rootmetadata, `VERSION` en een modulepad niet vereist. Voeg voor `--puppet` ook `gem 'openvox', '~> 8.0', require: false` toe; met Ruby 4 is daarnaast de afzonderlijke `syslog`-gem nodig. Ook [distributie via Git en gebouwde gems](../README.md#importeren-en-distribueren) wordt ondersteund.

Leg de [verplichte voorcontrole](../../AGENTS.md#local-inspection-before-disclosure) vast in de eigen `AGENTS.md` van het afnemende project en verwijs naar deze handleiding via `global-modules/.tools/secrets/README.md`. Instructies in een submodule gelden niet automatisch als beleid voor het bovenliggende project. Kopieer de implementatie niet. Gebruik voor de Puppet-controle de eigen manifestselectie en dezelfde CLI, bijvoorbeeld `bundle exec project-tools-secrets --puppet environments/ modules/`. Neem deze aanroep als prerequisite op in de eigen standaardtesttaak en als job **Puppet secrets** in de eigen CI. De [centrale CI-voorbeelden](../README.md#controle-in-ci) laten de gedeelde installatie en jobafhankelijkheden zien. Werk eerst de submodule bij naar een goedgekeurde revisie die `.tools/secrets` bevat; oudere checkouts bevatten dit commando niet.

## Ontwikkelen en testen

Voeg nieuwe detectie toe in deze bestaande tool: gedeelde signaturen in `patterns.rb`, Puppet-syntaxis in `puppet_scan.rb` en YAML/Hiera in `yaml_scan.rb`. Voeg positieve, negatieve, meerregelige en rapportagegevallen met synthetische waarden toe onder `tests/`; test gewijzigde Rake- en CI-koppelingen onder `../repository-checks/tests/`. Werk deze patroonbeschrijving in dezelfde wijziging bij. Volg de [onderhoudsinstructies](AGENTS.md). De gem bevat runtimecode, de executable, de README en de licentie. Links naar andere tools, instructies en tests vereisen de bijbehorende checkout.

Voer `bundle exec rake test:secrets` uit voor synthetische tests van herkenning, maskeren, gegevensbescherming, foutafhandeling en zelfstandige installatie. `bundle exec rake test` neemt deze tests mee in de [gezamenlijke suite](../README.md#gezamenlijke-tooltests). Geslaagde tests onderbouwen de geteste afspraken; ze bewijzen niet dat willekeurige bestanden geen onbekende geheimen bevatten.
