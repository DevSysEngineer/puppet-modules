# Gevoelige gegevens lokaal controleren

`project-tools-secrets` leest bestanden lokaal voordat je de inhoud gebruikt voor externe analyse of AI-analyse. De tool meldt mogelijke geheimen zonder hun waarden te tonen en bereidt een analysewerkboom voor waarin die waarden zijn gemaskeerd. Scanner en voorbereiding maken geen netwerkverbindingen, voeren geen invoer uit en wijzigen geen bronbestanden. Het subcommando `write` kan gecontroleerde bronwijzigingen toepassen; expliciete diagnostiek start goedgekeurde lokale opdrachten. Neem je deze repository als `global-modules` op in een ander project, begin dan bij [Gebruik in een ander project](#gebruik-in-een-ander-project).

## Inhoudsopgave

- [Inhoudsopgave](#inhoudsopgave)
- [Controleren voor het lezen](#controleren-voor-het-lezen)
- [Analysekopieën maken](#analysekopieën-maken)
- [Taakingangen en migratie](#taakingangen-en-migratie)
- [Ontwikkelen met een analysewerkboom](#ontwikkelen-met-een-analysewerkboom)
  - [Lokale selectie en bevoegdheden vastleggen](#lokale-selectie-en-bevoegdheden-vastleggen)
  - [Voorbereiden en een gewone wijziging toepassen](#voorbereiden-en-een-gewone-wijziging-toepassen)
  - [Volledig herschrijven en expliciete operaties](#volledig-herschrijven-en-expliciete-operaties)
  - [Herstelcontext en validatie](#herstelcontext-en-validatie)
  - [Diagnostiek en veilige diff](#diagnostiek-en-veilige-diff)
  - [Conflicten en herstel na fouten](#conflicten-en-herstel-na-fouten)
  - [Synthetische fixtures bewerken](#synthetische-fixtures-bewerken)
- [Git-versies lokaal controleren en vergelijken](#git-versies-lokaal-controleren-en-vergelijken)
- [Oude integraties opruimen](#oude-integraties-opruimen)
- [Migreren van genummerde kopieën](#migreren-van-genummerde-kopieën)
- [Resultaten en exitcodes](#resultaten-en-exitcodes)
- [Patronen en beperkingen](#patronen-en-beperkingen)
  - [Markdown-codefragmenten](#markdown-codefragmenten)
- [Archieven controleren](#archieven-controleren)
- [Puppet-manifesten in standaardtests en CI](#puppet-manifesten-in-standaardtests-en-ci)
- [Een afgekeurd manifest herstellen](#een-afgekeurd-manifest-herstellen)
- [Gemiste gegevens of een fout melden](#gemiste-gegevens-of-een-fout-melden)
- [Gebruik in een ander project](#gebruik-in-een-ander-project)
  - [Kies de controles voor je project](#kies-de-controles-voor-je-project)
  - [Installeer in de eigen bundle](#installeer-in-de-eigen-bundle)
  - [Richt de voorcontrole voor AI en externe analyse in](#richt-de-voorcontrole-voor-ai-en-externe-analyse-in)
  - [Koppel de Puppet-controle aan eigen taken](#koppel-de-puppet-controle-aan-eigen-taken)
  - [Neem de controle op in CI](#neem-de-controle-op-in-ci)
  - [Werk de tooling bij](#werk-de-tooling-bij)
- [Ontwikkelen en testen](#ontwikkelen-en-testen)
  - [Interne verantwoordelijkheden](#interne-verantwoordelijkheden)

## Controleren voor het lezen

De [repositorywerkwijze](../../CONTRIBUTING.md#lokale-inspectie-vóór-inzage) bepaalt welke bestanden je vooraf moet controleren en welke documentatie je rechtstreeks mag lezen. De onderstaande voorcontrole geldt voor inhoud buiten die leesuitzondering.

Installeer de bundle volgens de [gezamenlijke installatiehandleiding](../README.md#installatie). Geef bestanden of mappen op ten opzichte van je huidige werkmap. Je kunt meerdere bestanden en mappen combineren in één aanroep. De tool controleert mappen recursief, inclusief verborgen bestanden, zonder Git-uitsluitingen of andere impliciete uitsluitingen.

```sh
bundle exec project-tools-secrets manifests/site.pp data/
bundle exec project-tools-secrets --json manifests/site.pp data/
```

Beoordeel eerst de metadata in het rapport. Maak bij bevindingen gemaskeerde kopieën voordat je de inhoud leest. Los bij een onvolledige controle of twijfel eerst de oorzaak op, of laat iemand de bron lokaal beoordelen buiten de AI-context. Toon het origineel nooit aan een assistent om een bevinding te onderzoeken. Controleer gewijzigde invoer opnieuw; de kopieën bevatten precies de gecontroleerde versie.

Zoek alleen in gecontroleerde kopieën. Exporteer voor diffs beide volledige bronversies lokaal, controleer ze en vergelijk daarna hun kopieën: een diff alleen mist de context van meerregelige waarden en Hiera. Sla commando-uitvoer die brongegevens kan bevatten eerst op in een afgeschermd lokaal bestand. Controleer dat bestand en deel uitsluitend de gecontroleerde of gemaskeerde uitvoer. Toon de ongefilterde uitvoer niet tegelijkertijd via `tee`.

De CLI onderschept geen assistenttools, bestandslezingen door editors of uploads. Pas de [verplichte voorcontrole](../../CONTRIBUTING.md#lokale-inspectie-vóór-inzage) daarom bij iedere aanroeper toe. Een geautomatiseerde integratie moet een volledig resultaat vereisen en uitsluitend de bijbehorende kopieën lezen.

## Analysekopieën maken

Gebruik voor alle analysekopieën dezelfde [analysewerkboom](#ontwikkelen-met-een-analysewerkboom): leg bestanden en context vast in een lokaal beleid, voer `project-tools-secrets prepare` uit en lees uitsluitend de bijbehorende vrijgegeven bestanden. Voor alleen lezen sluit je daarna af met `close`; voor wijzigingen gebruik je `write`, gevolgd door `diff` en `close`. Er is geen afzonderlijke kopieeroptie.

De analysemap behoudt veilige relatieve paden en extensies. De map krijgt modus `0700`, de bestanden `0600`. Bevindingen krijgen lokale occurrence-ID's; hun oorspronkelijke waarden blijven in private state. Bestaande doelen worden geweigerd en onvolledige voorbereiding geeft geen gedeeltelijke analysemap vrij. Zie het [doorlopende voorbeeld](#voorbereiden-en-een-gewone-wijziging-toepassen) voor selectie, resultaatcontrole en afsluiten.

## Taakingangen en migratie

Het pakket levert uitsluitend `project-tools-secrets`. Zonder subcommando scant deze executable de opgegeven paden; bewerkingen gebruiken expliciete subcommando's:

| Aanroep | Taak |
| --- | --- |
| `project-tools-secrets [--puppet] PATH ...` | Alleen scanmetadata tonen. |
| `project-tools-secrets prepare` | Analysewerkboom en private waardekoppelingen voorbereiden. |
| `project-tools-secrets write` | Gevalideerde analysewijzigingen toepassen. |
| `project-tools-secrets clone`, `register`, `fixture` | Expliciete markers voor hergebruik of nieuwe waarden registreren. |
| `project-tools-secrets run` | Goedgekeurde diagnostiek uitvoeren en beide uitvoerstromen controleren. |
| `project-tools-secrets diff` | Toegepaste wijzigingen gecontroleerd vergelijken. |
| `project-tools-secrets close`, `cancel` | De lokale bewerking afsluiten of annuleren. |
| `project-tools-secrets recover` | Een onderbroken schrijfactie herstellen. |

Gebruik `project-tools-secrets --help` of `project-tools-secrets ACTION --help`. Een bronbestand dat naar een subcommando is genoemd, selecteer je als `./run` of na `--`. Bundler-aanroepen beginnen steeds met `bundle exec`.

Vanaf pakketversie `0.4.0` vervalt `--redact`, inclusief `files[].copy` en genummerde bestanden. De eerdere losse prepare-, write- en review-executables worden niet geleverd. Vervang hun aanroepen door respectievelijk `project-tools-secrets prepare`, `project-tools-secrets write` en `project-tools-secrets diff`; ondersteunende subcommando's staan rechtstreeks achter `project-tools-secrets`. Deze wijziging vereist aanpassing van consumers; er is geen alias, fallback of tijdelijke compatibiliteitsroute.

Ruby-consumers gebruiken één ingang: `ProjectTools::Secrets.run(arguments, output: io)`. Bijvoorbeeld `.run(['prepare', *options])`, `.run(['write', *options])` of `.run(['run', *options])`. De methode retourneert de exitcode en schrijft uitsluitend het gecontroleerde publieke resultaat naar `io`.

Werk gemselectie, lockfile, scripts, resultaatlezers en eigen instructies samen bij en doorloop het oefenvoorbeeld hieronder vanuit de consumerbundle. De bestaande private state en het hersteljournal behouden hun formaat: afronden en herstel gebruiken dezelfde `--state` en `--session`. Bewaar die state zolang herstel nodig is. De [migratie van kopieën](#migreren-van-genummerde-kopieën) beschrijft de gewijzigde resultaatvelden.

## Ontwikkelen met een analysewerkboom

Gebruik `project-tools-secrets prepare` voor ontwikkeling. Deze route behoudt veilige relatieve paden en extensies, geeft ieder beschermd voorkomen een willekeurige ID van 128 bits en bindt die aan één lokale bewerking. Het veld `session` en de optie `--session` identificeren uitsluitend de lokale ID-koppelingen en het hersteljournal voor die bewerking; ze maken geen AI-sessie aan. Het subcommando `project-tools-secrets write` herstelt volledige gewijzigde bestanden. De subcommando's gebruiken dezelfde scanner, bronlezer, parsers en gecontroleerde publicatie; een Git-repository of bijzondere agentstart is niet nodig.

### Lokale selectie en bevoegdheden vastleggen

De vertrouwde lokale aanroeper kiest de projectroot, een nieuwe analysemap, een private statemap en een JSON-beleidsbestand. Bronroot, analysemap en statemap mogen elkaar niet bevatten. Bewaar state en beleid buiten versiebeheer en buiten de inhoudelijke toegang van de agent. Gebruik echte absolute paden zonder symlinkcomponenten; op macOS zijn bijvoorbeeld `/tmp` en `/var` symlinks. `pwd -P` levert het fysieke pad. State gebruikt `0700`, mappings en analysekopieën `0600`.

Het beleid bevat expliciete bestanden, geen recursieve projectselectie. Dit synthetische voorbeeld hoort bij één Hiera-hiërarchie:

```json
{
  "files": ["data/common.yaml", "modules/example/manifests/init.pp"],
  "context": ["data/options.yaml"],
  "destinations": {"data/moved.yaml": "0600", "tests/example.rb": "0644"},
  "aliases": {},
  "sensitive_paths": ["private/**"],
  "commands": {"validate": ["bundle", "exec", "rake", "test"]}
}
```

| Sleutel | Betekenis |
| --- | --- |
| `files` | Niet-lege lijst bronbestanden, relatief aan de gekozen root. |
| `context` | Verplichte contextbestanden, bijvoorbeeld toepasselijke `lookup_options`. Deze worden mee voorbereid en versiegebonden. Gebruik afzonderlijke sessies voor onafhankelijke hiërarchieën. |
| `destinations` | Vooraf toegestane, nog ontbrekende doelen voor toevoegingen en hernoemingen. Modus is expliciet `0600`, `0644`, `0700` of `0755`. Een hernoeming behoudt de bestaande metadata. |
| `aliases` | Echte relatieve bronpaden naar veilige relatieve analysepaden. Classificeer vertrouwelijke namen zelf; herkenning van tokens is geen volledige naamclassificatie. Letterlijke verwijzingen naar expliciet gealiaste paden worden eveneens beschermd. |
| `sensitive_paths` | Relatieve globpatronen voor reeds geclassificeerde vertrouwelijke bestanden. Hun hele inhoud wordt afgeschermd, ook onder onbekende veldnamen; het rapport vermeldt `writable: false`. Ze blijven leescontext en kunnen niet inhoudelijk worden herschreven. |
| `commands` | Lokaal goedgekeurde diagnostiek, als naam naar argumentenlijst. `run` voert die opdracht op de echte bron uit en controleert beide uitvoerstromen. Dit is uitvoering van vertrouwde opdrachten, geen sandbox voor willekeurige code. |
| `fixture_paths` | Expliciete testbestanden waarvoor de tool [synthetische waarden](#synthetische-fixtures-bewerken) mag genereren. |

Selecteer alle benodigde context expliciet. Dit geldt ook voor instructiebestanden die je bij de bewerking wilt betrekken; de tool zoekt niet automatisch naar agentconfiguratie. Gewijzigde geselecteerde context of gewijzigd beleid maakt een oude voorbereiding ongeldig. De tool ontdekt geen ontbrekende Hiera-hiërarchie: de aanroeper blijft verantwoordelijk voor een volledige `context`-selectie. De [repositorywerkwijze](../../CONTRIBUTING.md#lokale-inspectie-vóór-inzage) bepaalt ook hier wanneer voorcontrole verplicht is; er is geen aparte agentlauncher nodig.

### Voorbereiden en een gewone wijziging toepassen

Dit doorlopende voorbeeld gebruikt uitsluitend synthetische invoer. Voer het uit vanuit een project met de gem in zijn bundle, in een POSIX-shell. De bestanden komen in een tijdelijke oefenmap; de eigen projectbestanden veranderen niet. Ruby, de gem en de externe programma's `cp` en `diff` moeten beschikbaar zijn. Voor `.pp` vereist voorbereiding OpenVox 8 in dezelfde bundle; zonder parser volgt een fout, geen terugval naar tekstpatronen.

```sh
TASK_BASE=$(mktemp -d)
TASK_BASE=$(cd "$TASK_BASE" && pwd -P)
export TASK_BASE
mkdir "$TASK_BASE/source"
ruby -rjson <<'RUBY'
root = ENV.fetch('TASK_BASE')
File.write(File.join(root, 'source', 'common.yaml'),
           "password: 'synthetic-example-only'\nordinary: before\n")
File.write(File.join(root, 'policy.json'), JSON.generate(
  'files' => ['common.yaml'],
  'destinations' => { 'nested/moved.yaml' => '0600', 'extra.yaml' => '0600' }
))
RUBY

if bundle exec project-tools-secrets prepare \
    --root "$TASK_BASE/source" --policy "$TASK_BASE/policy.json" \
    --tree "$TASK_BASE/analysis" --state "$TASK_BASE/state" \
    > "$TASK_BASE/prepared.json"; then
    PREPARE_STATUS=0
else
    PREPARE_STATUS=$?
fi
[ "$PREPARE_STATUS" -le 1 ] || exit "$PREPARE_STATUS"
SESSION_REF=$(ruby -rjson -e '
  result = JSON.parse(File.read(ARGV.fetch(0)))
  abort "Preparation incomplete" unless result["complete"] && result["prepared"]
  abort "Selection differs" unless result.fetch("files").map { |f| f.fetch("file") } == ["common.yaml"]
  print result.fetch("session")
' "$TASK_BASE/prepared.json")
export SESSION_REF
```

Beoordeel `prepared.json` voordat de agent de analysemap krijgt. Exitcode 1 is bij volledige voorbereiding met bevindingen normaal. Vereis `complete: true`, `prepared: true`, de verwachte bestandsselectie en de bijbehorende nieuwe analysebestanden. `coverage` onderscheidt `text_patterns`, `yaml_parser` en `puppet_parser`; `context` bevat veilige contextpaden. `context_omitted` meldt weggelaten meerregelige inhoud. Bij ontbrekende invoer, onvolledige inspectie of mislukte voorbereiding wordt geen gedeeltelijke werkboom vrijgegeven.

De inhoudelijke agent leest en bewerkt nu alleen `$TASK_BASE/analysis`. Voor deze gewone wijziging blijft de marker staan:

```sh
ruby <<'RUBY'
root = ENV.fetch('TASK_BASE')
path = File.join(root, 'analysis', 'common.yaml')
File.write(path, File.read(path).sub('ordinary: before', 'ordinary: after'))
RUBY
printf '%s\n' '{"write":["common.yaml"]}' > "$TASK_BASE/changes.json"

bundle exec project-tools-secrets write \
    --state "$TASK_BASE/state" --session "$SESSION_REF" \
    --changes "$TASK_BASE/changes.json"
bundle exec project-tools-secrets diff \
    --state "$TASK_BASE/state" --session "$SESSION_REF"
bundle exec project-tools-secrets close \
    --state "$TASK_BASE/state" --session "$SESSION_REF"
```

De lokale caller voert writer, diagnostiek en diff uit; de agent krijgt hun gecontroleerde resultaten. Een geslaagde writer meldt `status: applied`. De gevoelige waarde blijft lokaal; de veilige diff gebruikt dezelfde occurrence-ID. Ongewijzigde bronnen worden niet opnieuw geschreven. Na toepassing is de sessie voor schrijven verbruikt, maar blijft zij beschikbaar voor review. `close` wist de mapping; `cancel` doet dat bij annulering. De gesaneerde analysemap blijft staan en vormt geen bewijs voor een volgende voorbereiding. Gebruik voor een volgende wijziging een nieuwe analysemap en een nieuwe sessie; fysieke vernietiging van filesystemkopieën of snapshots wordt niet beloofd.

### Volledig herschrijven en expliciete operaties

Kies hieronder één variant voor een **nieuw voorbereide** sessie met het oefenbeleid. De variabelen verwijzen naar die sessie en haar analysemap. De writer werkt op de huidige markerposities, niet op oorspronkelijke regelnummers. Het wijzigingsbestand accepteert uitsluitend de volgende velden:

| Veld | Invoer en bedoeling |
| --- | --- |
| `write` | Lijst bestaande analysepaden waarvan de volledige nieuwe inhoud wordt gelezen. |
| `add` | Lijst vooraf toegestane nieuwe doelen met een volledig analysebestand. |
| `rename` | Mapping bestaand analysepad naar toegestaan nieuw doel; plaats de volledige nieuwe inhoud op dat doel in de analysemap. |
| `delete` | Lijst bewust te verwijderen bestaande bestanden. |
| `remove_ids` | Lijst bewust verwijderde IDs, zonder markerhaken. Ook nodig bij bestandsverwijdering. |
| `move_ids` | Mapping ID naar bedoeld analysepad voor een expliciete verplaatsing naar een ander bestand of een andere veldcontext. Een bestandshernoeming alleen heeft dit niet nodig. |

Voor een volledige herschrijving van het gemengde YAML-bestand kun je het geheim tussen andere regels plaatsen:

```sh
ruby -rjson <<'RUBY'
root = ENV.fetch('TASK_BASE')
path = File.join(root, 'analysis', 'common.yaml')
marker = File.read(path)[/\[REDACTED-[0-9a-f]{32}\]/]
File.write(path, "ordinary: reorganized\npassword: '#{marker}'\nextra: enabled\n")
File.write(File.join(root, 'changes.json'), JSON.generate('write' => ['common.yaml']))
RUBY
bundle exec project-tools-secrets write --state "$TASK_BASE/state" \
    --session "$SESSION_REF" --changes "$TASK_BASE/changes.json"
```

Voor een hernoeming naar een vooraf toegestaan doel:

```sh
mkdir -p "$TASK_BASE/analysis/nested"
mv "$TASK_BASE/analysis/common.yaml" "$TASK_BASE/analysis/nested/moved.yaml"
printf '%s\n' '{"rename":{"common.yaml":"nested/moved.yaml"}}' > "$TASK_BASE/changes.json"
bundle exec project-tools-secrets write --state "$TASK_BASE/state" \
    --session "$SESSION_REF" --changes "$TASK_BASE/changes.json"
```

Voor bewuste verwijdering haal je eerst de publieke ID uit de analysekopie. Dit voorbeeld verwijdert het hele bestand; laat bij alleen een veldverwijdering het bestand bestaan en gebruik `write`:

```sh
ruby -rjson <<'RUBY'
root = ENV.fetch('TASK_BASE')
ids = File.read(File.join(root, 'analysis', 'common.yaml')).scan(/\[REDACTED-([0-9a-f]{32})\]/).flatten
File.write(File.join(root, 'changes.json'), JSON.generate('delete' => ['common.yaml'], 'remove_ids' => ids))
RUBY
bundle exec project-tools-secrets write --state "$TASK_BASE/state" \
    --session "$SESSION_REF" --changes "$TASK_BASE/changes.json"
```

Voor hergebruik vraag je met `clone --id ID --to extra.yaml` een **nieuwe** marker aan. Gebruik die in de nieuwe file en zet `extra.yaml` onder `add`. De oorspronkelijke marker blijft in `common.yaml`. Een ID zomaar kopiëren wordt over de volledige eindtoestand als `duplicate_marker` geweigerd, ook als het oorspronkelijke bestand niet onder `write` staat. Een onbekende, beschadigde of onbedoeld ontbrekende ID blokkeert eveneens vóór schrijven. `clone` vereist geen afzonderlijke bevestiging per ID; de expliciete opdracht legt de bedoeling vast.

```sh
ID_REF=$(ruby -e 'print File.read(ARGV[0])[/\[REDACTED-([0-9a-f]{32})\]/, 1]' "$TASK_BASE/analysis/common.yaml")
bundle exec project-tools-secrets clone --state "$TASK_BASE/state" \
    --session "$SESSION_REF" --id "$ID_REF" --to extra.yaml > "$TASK_BASE/clone.json"
ruby -rjson <<'RUBY'
root = ENV.fetch('TASK_BASE')
marker = JSON.parse(File.read(File.join(root, 'clone.json'))).fetch('marker')
File.write(File.join(root, 'analysis', 'extra.yaml'), "password: '#{marker}'\n")
File.write(File.join(root, 'changes.json'), JSON.generate('add' => ['extra.yaml']))
RUBY
bundle exec project-tools-secrets write --state "$TASK_BASE/state" \
    --session "$SESSION_REF" --changes "$TASK_BASE/changes.json"
```

### Herstelcontext en validatie

| Inhoud | Schrijfcontract |
| --- | --- |
| Puppet `.pp` | Native parser tijdens voorbereiding en herstel; veilige lookups en verwijzingen blijven zichtbaar. Letterlijke stringwaarden kunnen naar een ondersteunde literalcontext worden verplaatst. De Puppet-gate beoordeelt daarna de echte herstelde bron. |
| YAML/Hiera/JSON | Complete scalarwaarden gebruiken de parserwaarde. Ongewijzigde context herstelt exacte bronbytes; ondersteunde wijzigingen van quotes of inspringing worden opnieuw gecodeerd. Niet-stringtypen met een gewijzigde representatie worden geweigerd. Bij schrijven van `.json` controleert ook de JSON-parser de volledige kandidaat. |
| Letterlijke YAML-scriptblokken | Alleen wanneer gedecodeerde tekens exact naar bronposities zijn terug te voeren, blijft gewone code rondom een credential zichtbaar. Anders wordt de hele gevoelige scalar afgeschermd en meldt het rapport contextverlies. |
| Gewone tekst, shell en ERB | Afgebakende fragmenten herstellen uitsluitend bij dezelfde extensie, quotes en omliggende regelcontext. Veranderde gevoelige expressies of onzekere interpolatie geven `unsupported_marker_context`. Gewone `.sh`-bestanden krijgen shellsyntaxcontrole; herkende ERB-templates krijgen de hieronder beschreven templatevalidatie. |
| Eenvoudige Ruby-stringliterals | Enkele quotes en JSON-compatibele dubbele quotes kunnen als waarde herstellen, onder andere voor fixtures. Interpolatie en andere Ruby-escapes worden niet geëvalueerd; een niet-ondersteunde verplaatsing wordt geweigerd. |
| Archieven | De scan geeft uitsluitend metadata. Laat de lokale caller de benodigde leden veilig naar een private bronmap exporteren en bereid die gewone bestanden met hun context voor. `prepare` weigert het archiefbestand zelf. |

Bestaande markerachtige tekst in broncode of documentatie wordt tijdens voorbereiding eveneens beschermd met een nieuwe ID. De writer herstelt die oorspronkelijke tekst pas nadat de markers in de analyse zijn gevalideerd. Een onbekende of beschadigde marker in de analyse blijft een weigering.

De writer herkent `.erb` als ERB. Ook bestanden onder een map `templates/` met een volledige ERB-tag (`<% … %>`, inclusief expressies, commentaar en trimtags) krijgen templatevalidatie, ongeacht hun extensie. Dit omvat de `.sh`-templates en templates zonder extensie in deze repository. Alleen de tekst `<%` is onvoldoende: een gewoon shellscript dat die tekst afdrukt blijft shellcode. Een `.sh`-bestand buiten `templates/` blijft eveneens shellcode; gebruik daar `.erb` om een template aan te geven.

Templatevalidatie vertaalt de herstelde inhoud met `ERB.new(bytes, trim_mode: '-')` naar Ruby-bron en parseert die met Ripper. De writer voert de Ruby-code niet uit. Geldige Puppet-trimtags zoals `<%-` en `-%>` worden ondersteund; ongeldige Ruby-expressies geven `invalid_template`. Een geslaagde controle bewijst alleen syntactische geldigheid van de gegenereerde Ruby-bron. Zij bewijst niet dat templatevariabelen beschikbaar zijn of dat de gerenderde shellcode geldig is. Render vaste synthetische varianten afzonderlijk en controleer hun uitvoer met de passende shellparser. Gewone `.sh`-bestanden worden met `sh -n` gecontroleerd, of met `bash -n` wanneer de eerste regel `bash` bevat; afkeuring geeft `invalid_shell`. Ook die syntaxcontrole voert het script niet uit en bewijst geen correct runtimegedrag.

Bij fragmentherstel telt de tekst vóór en achter de marker op dezelfde regel mee, inclusief quotes, expressietekst en commentaar. Voorloopinspringing mag bij een eenregelig fragment veranderen. De volgende voorbeelden gebruiken `MARKER` als leesbaar label voor de exacte marker die `prepare` heeft gemaakt; typ dit label niet in de analysekopie en wijzig de echte marker niet. Uitgaande van `<%= render(MARKER) %>` wordt een inline voorwaarde geweigerd:

```erb
<%= render(MARKER) if enabled %>
```

Een omvattend blok behoudt de regelcontext en is voor een eenregelig fragment wel ondersteund:

```erb
<% if enabled -%>
  <%= render(MARKER) %>
<% end -%>
```

Ook commentaar achter het fragment op dezelfde regel verandert de herstelcontext en wordt geweigerd:

```erb
<%= render(MARKER) %> # toelichting
```

Plaats commentaar op een eigen regel om de fragmentcontext te behouden:

```erb
<%# Toelichting bij de volgende expressie. %>
<%= render(MARKER) %>
```

Bij meerregelig afgeschermde inhoud moet bovendien de oorspronkelijke inspringing behouden blijven. Een marker kan in de analysekopie op één regel staan terwijl hij meerdere oorspronkelijke regels vervangt; `context_omitted` meldt dat contextverlies. Het omvattende blok hierboven kan dan alsnog `unsupported_marker_context` geven door de twee extra spaties vóór de markerregel. Laat in dat geval de oorspronkelijke inspringing intact.

Een marker in een YAML-sleutel, commentaar of niet-ondersteunde expressie is geen geldige nieuwe bestemming voor een literal. Behoud van markercontext en van de oorspronkelijke waarde bewijst niet dat de gewijzigde programmatuur het correct gebruikt: omliggende code kan bijvoorbeeld logging toevoegen. Codereview en functionele validatie blijven nodig.

De writer inspecteert alle herstelde kandidaten samen met de kandidaatversie van de context. Ook ongewijzigde geselecteerde bestanden blijven onder de marker-, syntax- en bronversiecontroles vallen; alleen het opnieuw schrijven van ongewijzigde bytes wordt overgeslagen. Een algemene bevinding voor een behouden waarde in toegestane Hiera-data is geen schrijfweigering. Een nieuw herkenbaar geheim als gewone analysetekst geeft `unregistered_value`, ook wanneer gewijzigde `lookup_options` een voorheen onopvallende waarde gevoelig maakt. Voeg echte nieuwe waarden uitsluitend via de lokale caller toe met `register --input PRIVATE_FILE --to PATH`; geef nooit de inhoud van dat invoerbestand aan de agent. De caller ontvangt een nieuwe marker voor een ondersteunde literalcontext.

Voor migratie van een synthetisch hardcoded Puppet-stringgeheim bereid je het manifest en de benodigde Hiera-context voor, met het nieuwe databestand onder `destinations`. Vervang de toewijzing in de analysekopie door een gewone lookup, plaats de oorspronkelijke marker als YAML-waarde in het nieuwe bestand en benoem de verplaatsing:

```json
{
  "write": ["modules/example/manifests/init.pp"],
  "add": ["data/common.yaml"],
  "move_ids": {"REPLACE_WITH_ID_FROM_ANALYSIS": "data/common.yaml"}
}
```

Gebruik in het manifest bijvoorbeeld `$password = lookup('example::password', Sensitive[String])` en in het databestand `example::password: 'MARKER_FROM_ANALYSIS'`, waarbij je de marker letterlijk uit de analyse kopieert. Pas het wijzigingsbestand toe met `project-tools-secrets write --state STATE --session SESSION --changes CHANGES`. Het manifest moet na herstel de Puppet-gate passeren. Laat je het hardcoded geheim in Puppet staan, dan volgt `puppet_policy_rejected`; alleen de placeholderversie valideren is onvoldoende.

### Diagnostiek en veilige diff

```sh
bundle exec project-tools-secrets run --state STATE --session SESSION --command validate
bundle exec project-tools-secrets diff --state STATE --session SESSION
bundle exec project-tools-secrets close --state STATE --session SESSION
```

Vervang de hoofdletterargumenten door de bestaande lokale sessie en beleidsnaam. `run` vangt stdout en stderr lokaal op, maskeert bekende oorspronkelijke fragmenten en waarden, en past daarna de gedeelde detectie toe. De proces-exitcode blijft behouden. Bij onvolledige uitvoerinspectie worden beide stromen achtergehouden. Opdrachten die diagnostiek in eigen bestanden schrijven, moeten die bestanden afzonderlijk gecontroleerd aanbieden; `run` onderschept alleen de twee processtromen en is geen gegevensstroomanalyse.

`diff` vereist een toegepaste sessie. De complete bronversies met context worden lokaal geïnspecteerd en de huidige geschreven bestanden moeten overeenkomen met de transactie. Daarna vergelijkt de tool de gecontroleerde representaties met stabiele IDs. Het resultaat bevat integriteitsmetadata: `preserved`, `moved`, `reused` en `removed`. Publiceer geen ruwe `git diff`, mappings of herstelde bronkopieën.

### Conflicten en herstel na fouten

Een tussentijds gewijzigde bron geeft `source_conflict` of `metadata_conflict`. Nieuwe doelen die inmiddels bestaan geven `destination_conflict`. Traversal, absolute relatieve doelen, symlinks en conflicterende aliases worden geweigerd. Behoud de wijziging van de andere gebruiker, annuleer de oude sessie en bereid een nieuwe analysemap voor. Het opnieuw aanbieden van dezelfde oude wijzigingen om het conflict te omzeilen helpt niet.

Alle kandidaten worden gecontroleerd en op het doelfilesystem gestaged voordat de eerste bron wordt vervangen. Naast ieder doel bewaart een private map `._secrets-<willekeurige ID>` met modus `0700` de tijdelijke bestanden en herstelkopie. Een punt aan het begin verbergt die map, maar sluit haar niet automatisch uit van Git. Neem bij Git-gebruik `._*` op in de toepasselijke `.gitignore`; deze repository bevat die regel al. Verwijder achtergebleven stagingmappen niet zolang herstel nodig is.

Op macOS gebruikt metadataoverdracht `cp -p`; op Linux `cp --preserve=all`. Rechten, eigenaar, groep en executable-bit worden behouden, evenals de door native `cp` ondersteunde ACL's en extended attributes. Speciale privilegebits worden geweigerd. Een ontbrekend programma of mislukte metadataoverdracht stopt de transactie. Er is geen privilegeverhoging.

Na alle vervangingen controleert de writer opnieuw de inhoud en bestandsidentiteit van ieder gewijzigd doel, inclusief rechten, eigenaar, groep en wijzigingstijd. Verwijderde doelen moeten ontbreken. Pas daarna meldt hij `applied` en ruimt hij de stagingmappen op. Een afwijking start het bestaande herstelpad; bij onvolledig herstel blijven journal en herstelkopieën beschikbaar.

Het duurzame journal legt intentie vast vóór staging en vervanging. Locks serialiseren meewerkende writers voor dezelfde bronroot. Iedere afzonderlijke vervanging is atomair waar het filesystem dat ondersteunt; de reeks bestanden is geen atomaire transactie. Bij fouten probeert herstel alleen aantoonbaar eigen versies terug te zetten. Gewijzigde bytes, bestandsidentiteit of metadata van derden worden niet overschreven. Locks en vergelijkingen voorkomen niet iedere race met een niet-meewerkend proces tussen controle en filesystemoperatie. Voer de writer daarom uit terwijl andere bronmutaties gepauzeerd zijn.

| Writerstatus | Betekenis en vervolgstap |
| --- | --- |
| `applied` | De gerapporteerde acties zijn toegepast. `files` geeft veilige identiteit, actie en toestand; `integrity` beschrijft markerbehoud. Review en valideer de echte bron. |
| `refused` | Validatie of selectie blokkeerde vóór schrijven. Herstel de genoemde vaste foutcode; bij een bronconflict is nieuwe voorbereiding nodig. |
| `rolled_back` | De schrijfactie mislukte, maar eigen wijzigingen zijn teruggedraaid. De commandostatus blijft afkeurend; begin opnieuw met actuele bronnen. |
| `recovery_required` | Herstel is onvolledig. Bewaar state en staging; een lokale beheerder beoordeelt de genoemde bestandsstaten buiten AI-context. |
| `error` | De aanroep kon niet volledig worden uitgevoerd. Foutteksten en bronnen blijven afgeschermd. |

Na procesuitval gebruik je `project-tools-secrets recover --state STATE --session SESSION`. `recover` verwerkt het bestaande journal; het voert de oorspronkelijke wijziging niet opnieuw uit. `external_change` en `recovery_failed` vereisen lokale beoordeling. `close` en `cancel` weigeren zolang herstel nodig is.

Laad voor een Ruby-integratie `require 'project_tools/secrets'` en gebruik de [taakmethoden](#taakingangen-en-migratie). Geef de interne stateobjecten nooit door aan een agent.

Sessieacties geven JSON, ook zonder `--json`. Voorbereiding gebruikt de bestaande scan-exitcodes 0/1/2 plus `prepared`; een succesvolle writer geeft 0, een weigering, rollback of onvolledige uitvoering 2. `run` geeft de processtatus terug na gecontroleerde uitvoer. Optioneel `--junit NEW_FILE` bevat hetzelfde veilige resultaat. Bij een rapportfout na toepassing blijft `status: applied` staan, naast `complete: false` en `report_error`; dat betekent niet dat niets is geschreven. Een rapportfout tijdens voorbereiding trekt de nieuwe werkboom en mapping terug.

### Synthetische fixtures bewerken

Zet uitsluitend bedoelde testpaden onder `fixture_paths` en sta eventuele nieuwe bestanden expliciet toe in `destinations`. `fixture --to tests/example.rb` genereert lokaal een nieuwe fictieve waarde en retourneert alleen haar marker. Gebruik `clone` voor een tweede voorkomen in een assertion:

```sh
bundle exec project-tools-secrets fixture --state STATE --session SESSION --to tests/example.rb
bundle exec project-tools-secrets clone --state STATE --session SESSION --id FIRST_ID --to tests/example.rb
```

Plaats de eerste marker als geciteerde waarde in de fixture en de tweede als geciteerde verwachte waarde in de assertion. Voeg de volledige Ruby-file toe via `add`, of bewerk een bestaande via `write`. Gewone testlogica blijft zichtbaar. De detector blijft de fictieve oorspronkelijke waarde herkennen. Een tekstlabel `dummy` of `synthetic` vormt geen algemene uitzondering.

De tool geeft geen publicatievrijstelling voor fixtures. Ook synthetische bevindingen betekenen bij [Git-review](../../CONTRIBUTING.md#git-inspectie) dat je uitsluitend gecontroleerde analysekopieën vergelijkt. Beoordeel publicatie afzonderlijk volgens het projectbeleid; de reguliere Puppet-secretscontrole blijft gelden.

## Git-versies lokaal controleren en vergelijken

De [gezamenlijke Git-afspraken](../../CONTRIBUTING.md#git-inspectie) bepalen welke vergelijking is toegestaan. De onderstaande opdrachten zijn handmatige lokale stappen met Git en de bestaande scanner. De secrets-tool verwerkt zelf geen index, revisies of Git-opdrachten.

Begin vanuit de repositoryroot met alleen de inventaris. Bestandsnamen kunnen vertrouwelijk zijn: bewaar ook deze uitvoer eerst lokaal, zonder `tee` of shelltracing. Gebruik een POSIX-shell, de geïnstalleerde bundle en een private tijdelijke map:

```sh
umask 077
REVIEW_DIR=$(mktemp -d)
REVIEW_DIR=$(cd "$REVIEW_DIR" && pwd -P)
git --no-pager status --porcelain=v1 --untracked-files=all \
    > "$REVIEW_DIR/status.txt" 2> "$REVIEW_DIR/status-errors.txt"
INVENTORY_STATUS=$?
bundle exec project-tools-secrets --json \
    "$REVIEW_DIR/status.txt" "$REVIEW_DIR/status-errors.txt"
[ "$INVENTORY_STATUS" -eq 0 ] || exit "$INVENTORY_STATUS"
```

Beoordeel het Git-resultaat en de scanmetadata. Bereid bij bevindingen de inventarisbestanden met `prepare` voor en lees alleen de vrijgegeven analysebestanden; los een onvolledige inventaris of scan eerst op. Kies vervolgens lokaal de te vergelijken bestanden, inclusief toegevoegde, verwijderde en hernoemde paden. Gebruik veilige aliases voor vertrouwelijke namen. Een geschatte of afgekorte naam uit een gemaskeerde inventaris is geen bronpad; laat de lokale aanroeper die koppeling vastleggen.

Exporteer de volledige inhoud rechtstreeks naar private bestanden. Dit voorbeeld vergelijkt de index met de werkboom voor `data/common.yaml` en zijn context `data/options.yaml`; beide bestanden moeten in beide versies bestaan. Pas de selectie aan het project aan en behoud extensies en contextstructuur. De `|| exit 1` stopt bij een exportfout; de fouttekst blijft lokaal en moet vóór inzage apart worden gescand.

```sh
mkdir -p "$REVIEW_DIR/index/data" "$REVIEW_DIR/worktree/data"
git cat-file blob ':data/common.yaml' \
    > "$REVIEW_DIR/index/data/common.yaml" 2> "$REVIEW_DIR/export-errors.txt" || exit 1
git cat-file blob ':data/options.yaml' \
    > "$REVIEW_DIR/index/data/options.yaml" 2>> "$REVIEW_DIR/export-errors.txt" || exit 1
cp data/common.yaml "$REVIEW_DIR/worktree/data/common.yaml" \
    2>> "$REVIEW_DIR/export-errors.txt" || exit 1
cp data/options.yaml "$REVIEW_DIR/worktree/data/options.yaml" \
    2>> "$REVIEW_DIR/export-errors.txt" || exit 1

bundle exec project-tools-secrets --json "$REVIEW_DIR/index"
bundle exec project-tools-secrets --json "$REVIEW_DIR/worktree"
```

Scan beide versies afzonderlijk met hun eigen volledige context. Zo beïnvloeden bijvoorbeeld oude en nieuwe `lookup_options` elkaars scan niet. Gebruik de algemene scanner; `--puppet` alleen dekt deze vergelijking niet. Houd bron, index en relevante referenties tijdens export, inspectie en vergelijking ongewijzigd; herhaal de voorbereiding zodra een versie verandert.

| Vergelijking | Volledige versies die je lokaal aanbiedt |
| --- | --- |
| Gewone `git diff` | `git cat-file blob ':pad'` voor de index en een lokale kopie van de werkboom. |
| Staged wijziging | `git cat-file blob 'HEAD:pad'` voor de gekozen basis en `git cat-file blob ':pad'` voor de index. Leg bij een andere basis die revisie expliciet vast. |
| Oudere revisie | `git cat-file blob 'REV:pad'` en de gekozen nieuwe revisie, index of werkboom, elk met eigen context. Vervang `REV` door de bedoelde vaste revisie. |
| Verwijdering | De volledige oude inhoud uit de betrokken index of revisie; de nieuwe kant is aantoonbaar afwezig. |
| Toevoeging | De volledige nieuwe inhoud; de oude kant is aantoonbaar afwezig. Een nog niet gevolgd bestand staat alleen in de werkboom. |
| Hernoeming | De oude inhoud onder het oude pad en de nieuwe inhoud onder het nieuwe pad, met de context van beide versies. |

Leid afwezigheid af uit de inventaris en de gekozen versie; behandel een mislukte export niet als een leeg bestand. Bij een onopgelost indexconflict zijn meerdere indexversies mogelijk: los het conflict lokaal op of selecteer en controleer die versies expliciet. Geef geen inhoud vrij zolang de selectie onvolledig is.

Als beide scans volledig zijn, geen bevindingen bevatten en de classificatie zeker is, mag je uitsluitend deze gecontroleerde bestanden en versies normaal vergelijken. Voor het ongewijzigde index/werkboom-paar uit het voorbeeld:

```sh
git --no-pager diff --no-ext-diff --no-textconv --no-renames -- data/common.yaml
git --no-pager diff --no-ext-diff --no-textconv --no-renames --check -- data/common.yaml
```

Voer deze opdrachten **niet** uit wanneer een van beide versies een bevinding bevat, ook niet bij alleen een indicator of wanneer het geheim alleen in de oude versie staat. Een volledige scan met bevindingen geeft exitcode 1; onvolledige inspectie geeft 2 en houdt de inhoud tegen. Redirectie van een gewone Git-diff maakt een gevoelige bronvergelijking niet toegestaan.

Bereid bij bevindingen beide volledige selecties voor via dezelfde analysewerkwijze. Maak een beleidsbestand naast de exports; het voorbeeld bevat exact de twee eerder geëxporteerde bestanden:

```sh
printf '%s\n' '{"files":["data/common.yaml"],"context":["data/options.yaml"]}' \
    > "$REVIEW_DIR/policy.json"
bundle exec project-tools-secrets prepare \
    --root "$REVIEW_DIR/index" --policy "$REVIEW_DIR/policy.json" \
    --tree "$REVIEW_DIR/index-safe" --state "$REVIEW_DIR/index-state" \
    > "$REVIEW_DIR/index-result.json"
bundle exec project-tools-secrets prepare \
    --root "$REVIEW_DIR/worktree" --policy "$REVIEW_DIR/policy.json" \
    --tree "$REVIEW_DIR/worktree-safe" --state "$REVIEW_DIR/worktree-state" \
    > "$REVIEW_DIR/worktree-result.json"
```

Controleer beide resultaten zoals in het [voorbereidingsvoorbeeld](#voorbereiden-en-een-gewone-wijziging-toepassen): exitcode 0 of 1, `complete: true`, `prepared: true` en de verwachte selectie. `files[].file` verwijst naar het veilige relatieve pad in de betreffende werkboom. Gebruik expliciete aliases wanneer bronpaden vertrouwelijk zijn. Vergelijk alleen de bij elkaar horende vrijgegeven bestanden:

```sh
diff -u "$REVIEW_DIR/index-safe/data/common.yaml" \
    "$REVIEW_DIR/worktree-safe/data/common.yaml" \
    > "$REVIEW_DIR/comparison.txt" 2> "$REVIEW_DIR/comparison-errors.txt"
COMPARE_STATUS=$?
bundle exec project-tools-secrets --json \
    "$REVIEW_DIR/comparison.txt" "$REVIEW_DIR/comparison-errors.txt"
[ "$COMPARE_STATUS" -le 1 ] || exit "$COMPARE_STATUS"
```

Bij `diff` betekent 0 gelijk, 1 verschillen en een hogere status een fout. Beoordeel de scanmetadata voordat je vergelijkingsuitvoer leest. Bij bevindingen bereid je ook deze uitvoerbestanden met hun eigen selectie voor. Sluit beide bronvoorbereidingen na review af met `close`, met de `session` uit hun resultaat en hun eigen `--state`.

Bij een bevestigde toevoeging of verwijdering vergelijk je de betreffende analysekopie met een lokaal leeg bestand; een mislukte scan is nooit een lege kant. Onafhankelijke voorbereidingen gebruiken verschillende ID's en bewijzen geen gelijkheid van geheime waarden. Voor door de writer toegepaste wijzigingen gebruik je de [veilige diff met stabiele IDs](#diagnostiek-en-veilige-diff).

Dezelfde voorcontrole geldt voor `git show`, `git log -p`, `git diff --check`, gewone bestandsvergelijkingen en editorpreviews. Meld expliciet voor welke oorspronkelijke bestanden de Git-diff- of whitespacecontrole is achtergehouden en welke controle van analysekopieën wel is uitgevoerd. Verwijder de private exportmap na lokale beoordeling; bewaar geen bronexports, mappings of analysewerkbomen als CI-artifact.

## Oude integraties opruimen

Verwijder bij bestaande lokale inrichting uitsluitend de eerder door deze secrets-tool geïnstalleerde hooks of de bijbehorende aanroepen in samengestelde hooks. Behoud andere hooks en projectcontroles. Laat een lokale beheerder de herkomst vaststellen voordat iets wordt verwijderd; de tool installeert of beheert geen hooks meer. `git-check`, `install-hooks`, `start` en `--event` zijn vervallen. Verwijder de bijbehorende beleidsvelden `git_exclude`, `puppet_paths`, `agents` en `fixture_registry` uit lokale configuratie. Een oude private fixture-registratie is niet meer nodig.

`fixture_paths` blijft de expliciete selectie voor synthetische waardegeneratie. `prepare`, `--state`, `--session`, writer, `run`, `diff`, `close`, `cancel` en herstel blijven bestaan voor lokale bestandsbewerkingen. Rond oude bewerkingen af of annuleer ze en bereid opnieuw voor met alleen de benodigde bestanden en expliciete context. Verwijder state of staging niet zolang een schrijffout nog herstel vereist. Er is geen vervangende Git-integratie of AI-startprocedure.

De zelfstandige Puppet-secretscontrole in tests en CI blijft behouden. De [centrale CI-handleiding](../README.md#ci-van-deze-repository) beschrijft de bestaande jobs en de vereiste hostinginstelling. Een CI-run na `push` vervangt de lokale controle vóór openbaarmaking niet.

## Migreren van genummerde kopieën

Vervang oude kopieeropdrachten door `prepare` met expliciete bestanden, context, veilige paden en private state. Vereis `complete: true` én `prepared: true`; lees `files[].file` relatief aan `--tree`. `files[].copy` en de nummering bestaan niet meer. Gebruik dezelfde voorbereiding voor alleen lezen of voor bewerken; sluit de bewerking af met `close` of `cancel`.

Pas de rootinstructie en scripts van ieder afnemend project in dezelfde migratie aan. Werk de gem en lockfile bij en verwijder de oude aanroepen en resultaatlezers. De zelfstandige scan en `--puppet` houden hun detectie en exitcodes; zij publiceren uitsluitend metadata. Archiefconsumers moeten de benodigde leden lokaal veilig exporteren en die via `prepare` aanbieden, zoals beschreven bij [Archieven controleren](#archieven-controleren).

De keuze voor één analysewerkwijze volgt de repositorybrede [consolidatieafspraak](../../CONTRIBUTING.md#hergebruik-en-samenhang); de [toolingafspraken](../README.md#verantwoordelijkheden-gescheiden-houden) bepalen de verdeling tussen CLI en library.

## Resultaten en exitcodes

| Exitcode | JSON `status` | Betekenis |
| --- | --- | --- |
| `0` | `no_findings` | Alle geselecteerde bestanden zijn geïnspecteerd; geen bevindingen. Controleer `coverage`. **Dit is geen veiligheidsgarantie.** |
| `1` | `findings` | Mogelijke geheime waarden of aanwijzingen voor gevoelige gegevens gevonden. Beoordeel en maskeer de inhoud vóór openbaarmaking; ook na maskeren blijft de exitcode 1. |
| `2` | `incomplete` | Selectie, controle, maskeren of rapportage is mislukt of onvolledig. Geef de inhoud niet vrij totdat de oorzaak is verholpen of iemand de inhoud lokaal heeft beoordeeld. |

Per bestand bevat het rapport `file`, `complete`, `findings`, `errors` en `coverage`. Iedere bevinding vermeldt het oorspronkelijke regelnummer in `line`, een vaste herkenningsregel in `rule` en het soort bevinding in `kind`: `value` voor een mogelijke geheime waarde, `indicator` voor een naam of constructie. Geen enkele regel controleert of een gevonden inloggegeven actief is. De algemene JSON-eigenschap `complete` omvat ook fouten bij uitvoer en rapportage en is leidend boven geslaagde deelcontroles.

De console volgt het [centrale logcontract](../README.md#joblogs): schone bestanden verschijnen alleen in de tellingen. `Files` telt geselecteerde bronnen en onderscheidt volledige en onvolledige controles; een archief telt als één bron. `Findings` telt afzonderlijke meldingen, uitgesplitst naar mogelijke geheime waarden en gevoeligheidsindicatoren. Eén bron kan meerdere meldingen hebben. `Errors` telt bron- en uitvoeringsproblemen, inclusief rapportfouten. `Coverage` vat de brontypen samen; het is geen garantie dat een bron volledig is gecontroleerd.

Elke bevinding toont de veilige bestandslocatie, het regelnummer, het soort bevinding, een vaste uitleg en de herkenningscode. Bij archieven verwijst de extra lidnummering naar de onderzochte archiefleden; het regelnummer hoort bij dat lid. Fouten krijgen eveneens een vaste uitleg, zonder oorspronkelijke exceptiontekst. Bevindingen blijven zichtbaar wanneer de scan of rapportage later faalt. JSON en JUnit behouden de volledige bestandsselectie, inclusief bestanden zonder bevindingen; gebruik die formaten voor automatische verwerking.

Een verwijzing via `lookup('mysql::user::example::password', Sensitive[String])` bevat zelf geen wachtwoord. De scanner behoudt deze expressie in de analysekopie en meldt uitsluitend aanwijzingen (`indicator`), geen geheime waarde (`value`). Exitcode 1 blijft van toepassing omdat het veld op gevoelige gegevens wijst. De daadwerkelijke waarde in het bijbehorende YAML-bestand wordt afzonderlijk gecontroleerd en gemaskeerd; neem dat bestand mee in de selectie. Een letterlijk meegegeven standaardwaarde valt niet onder deze uitzondering en wordt wel gemaskeerd.

Console-uitvoer, JSON en JUnit bevatten geen bronfragmenten, gevonden waarden, fingerprints of oorspronkelijke foutteksten. Fouten hebben vaste identificaties. Gevonden waarden en herkenbare tokenpatronen worden uit getoonde paden verwijderd; vertrouwelijke bestandsnamen vereisen nog steeds lokale beoordeling. Zet geen inloggegevens in argumenten of bestandsnamen. De CLI schakelt het afdrukken van exceptions in Ruby-debugmodus uit en heeft geen modus die gevonden waarden logt.

Met `--junit /existing/parent/new-report.xml` krijg je dezelfde bevindingen ook als JUnit: bevindingen worden `failures`, onvolledig gecontroleerde bestanden worden `errors`. De bovenliggende map moet bestaan en het doelbestand moet nieuw zijn en buiten de invoer liggen. Een schrijffout bij het rapport geeft exitcode 2. Zonder deze optie blijven rapportbestanden ongemoeid. `--json` wijzigt de presentatie op stdout; `--help` toont de gebruiksinstructies zonder te scannen.

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

Niet-afgesloten aanhalingstekens, haakjes of blokken, geneste blokmarkeringen, onduidelijke ingesprongen vervolgregels en niet-ondersteunde gevoelige heredocs blokkeren het maken van kopieën wanneer geen betrouwbare afbakening beschikbaar is. Voor onvolledige codevoorbeelden biedt [Markdown-context](#markdown-codefragmenten) een aanvullende afbakening. YAML-aliases, complexe sleutels en Hiera-conversieselectoren met reguliere expressies vereisen lokale beoordeling. Als het bereik van een conversie niet kan worden bepaald, wordt de volledige selectie geblokkeerd. Parserfouten, ongeldige UTF-8, binaire inhoud of besturingstekens, symlinks, bijzondere bestandstypen, onleesbare of ontbrekende paden, lege mappen en bestanden groter dan 5 MiB geven een onvolledige controle. Lege gewone bestanden kunnen wel worden gecontroleerd. De ondersteunde archiefformaten en grenzen staan bij [Archieven controleren](#archieven-controleren).

In vastgestelde shellcontext eindigt een toekenning of benoemd optieargument bij het einde van het shellwoord. Enkele en dubbele quotes, escapes, regelvoortzettingen en aaneengesloten woorddelen blijven daarbij samen, ook bij meerregelige waarden en geneste parameterexpansies. Een volgend argument of een volgende opdracht wordt afzonderlijk onderzocht; alleen inspringing maakt die niet tot een vervolgwaarde. Deze afbakening geldt voor code in `.sh` en bestanden met een `sh`- of `bash`-shebang, dus ook shelltemplates zonder extensie. Commentaar, geciteerde gegevens en heredoc-inhoud krijgen hierdoor geen kortere woordgrens. Zonder voldoende broncontext blijft de algemene, conservatieve afbakening gelden. De contextanalyse is geen volledige shellparser; bij een niet herkende heredoc wordt de rest van de bron conservatief als gegevens behandeld.

Een zuivere variabelereferentie zoals `"$VALUE"` bevat zelf geen runtimewaarde en blijft in shellcontext zichtbaar. Dat zegt niets over de veiligheid van de waarde waarnaar zij verwijst. Een letterlijk standaardargument in een parameterexpansie wordt wel onderzocht: de scanner behandelt zo'n expressie onder een gevoelige naam conservatief als mogelijke waarde en maskeert het volledige shellwoord. Dat kan ook een standaardbestandspad afschermen. Namen met `_PATH` of `_FILE` geven geen vrijstelling. Er worden geen opdrachten uitgevoerd en geen omgevingswaarden of runtimebestanden opgezocht.

Een losse PEM-markering binnen een betrouwbaar begrensd, geankerd zoekpatroon vormt geen PEM-blok. De scanner herkent hiervoor geciteerde patronen bij `grep` en shellcommandoreferenties, en AWK-patronen tussen slashes, inclusief de afzonderlijke patronen van een bereik. Begin- en eindmarkeringen uit zulke zelfstandige zoekpatronen worden niet aan elkaar gekoppeld. Dit sluit de overige broncode niet uit van detectie: opgenomen PEM-inhoud blijft gevoelig, ook in strings, meerregelige inhoud en gesplitste literals. De inhoud hoeft geen cryptografisch geldig certificaat of geldige sleutel te zijn. Een ontbrekend einde, onjuiste nesting of een niet betrouwbaar herkenbaar zoekpatroon blijft de voorbereiding blokkeren zodra vermoed PEM-materiaal niet volledig kan worden afgebakend.

De algemene scanmodus herkent afgebakende tekstpatronen; de onderstaande Puppet-modus gebruikt daarnaast de syntaxisboom van OpenVox. JSON wordt met de YAML-bronparser gelezen, zonder strikte JSON-validatie. Variabelen, includes, externe Hiera-hiërarchieën en -backends en runtime-lookups worden niet uitgewerkt. XML-elementen, onbekende veldnamen, verhulde of gecodeerde waarden en inloggegevens die over meerdere bestanden zijn verdeeld, kunnen worden gemist. Onterechte bevindingen zijn mogelijk, ook in broncode en synthetische testbestanden. Persoons-, klant-, host- en andere vertrouwelijke gegevens worden niet volledig herkend. Laat bij twijfel de inhoud lokaal door iemand beoordelen voordat je die deelt, ook bij gemaskeerde kopieën.

Een naam of getal alleen bepaalt geen uitzondering. `api_key_count` met een geheel getal, de numerieke beleidsvelden `password.minlength`, `password.retrylimit` en `password.expiration` (ook de ondersteunde underscore- en koppeltekenvarianten), en `TOKEN_EXPIRE`, `TOKEN_TTL` of `TOKEN_LIFETIME` met een getal en eventueel `s`, `m`, `h`, `d` of `w` beschrijven metadata. Een numeriek `password` of een willekeurige tekenreeks in zo'n beleidsveld blijft een mogelijke geheime waarde. Een expliciete Hiera-conversie naar `Sensitive` blijft leidend. Private-keyvelden met een `puppet:///`-bronverwijzing bevatten geen sleutelbytes; controleer de bron afzonderlijk. Een bestandsachtig woord onder een onduidelijke eigen interface blijft een mogelijke geheime waarde.

Een volledige ERB-verwijzing naar een instantievariabele, eventueel met `.unwrap`, of `ENV['NAAM']` blijft behouden. Een letterlijk fallbackargument blijft een waarde. De scanner herkent een CI-job met een naam met spaties, een `stage` en een `script` op het hoogste YAML-niveau; het joblabel maakt de gewone opdrachten niet gevoelig. Geneste geheime velden en letterlijke credentials in die opdrachten worden wel onderzocht. Rake-taaknamen na het commando `rake` worden als opdrachten behandeld. Dit maakt de overige inhoud van een script of codeblok niet automatisch veilig.

In `.sh`-bestanden en bestanden met een `sh`- of `bash`-shebang herkent de scanner eenvoudige ongequote `case`-taklabels aan het begin van een regel na `case … in` of `;;`, eventueel met lege regels of commentaar ertussen. Een optionele openingshaak en alternatieven met `|` worden ondersteund. De dubbele punt na een patroonnaam zoals `caching_sha2_password` of `mysql_native_password`, gevolgd door `*)`, is daar onderdeel van het patroon, geen toewijzing. De naam kan een gevoeligheidsindicator blijven, maar levert zelf geen waardebevinding op. Dit geldt ook bij voorbereiding en schrijven: zo'n nieuw programmapatroon vereist geen geheimregistratie. Echte toewijzingen en ondersteunde geheime commandoregelopties in de tak blijven afzonderlijk gecontroleerd en afgeschermd. Een nieuw geheim als gewone analysetekst blijft `unregistered_value` geven. Dit is beperkte constructieherkenning, geen volledige shellparser; niet-herkende vormen en onzekere waardegrenzen behouden de conservatieve controle.

Voor Ruby-bronnen gebruikt de scanner Ripper uitsluitend om geldige bronsyntaxis te herkennen. Dit voorkomt dat een volgende Ruby-opdracht als ingesprongen vervolgwaarde wordt behandeld. Ongeldige Ruby en onbegrensde geheime invoer in testliterals blijven onvolledig; geldige Ruby maakt de inhoud van die literals niet automatisch veilig. Bij geciteerde shellopdrachten begrenst het omringende aanhalingsteken de waarde. Niet-ondersteunde heredocs en andere onduidelijke grenzen blijven geblokkeerd. De tool voert broncode of fixtures nooit uit.

In `.pp`-bestanden begrenst de algemene scan lambda-expressies met ongetypeerde variabeleparameters tussen `|` en een bijbehorend `{ ... }`-blok. Komma's en regeleinden tussen parameters beëindigen de toegewezen waarde niet; strings en geneste haakjes blijven onderdeel van de expressie. Na een variabeleverwijzing met eventuele indexen of argumentloze methoden, of na een afgesloten lambda herkent de scanner een volgende ingesprongen `if` of `unless` met een conditie en sluitend blok als afzonderlijk statement. Deze beperkte bronherkenning vereist geen OpenVox en vervangt geen Puppet-parservalidatie. Getypeerde parameters, parameterdefaults en andere niet-herkende lambdavormen blijven conservatief behandeld; onvolledige lambda's, strings en onzekere voortzettingen blokkeren analysekopieën. De algemene scan kan de volledige afgebakende expressie maskeren en exitcode 1 geven, ook wanneer de Puppet-modus geen credential vindt.

### Markdown-codefragmenten

In bestanden met extensie `.md` of `.markdown`, inclusief hoofdlettervarianten, begrenst de scanner codevoorbeelden voordat hij gevoelige expressies afbakent. Inlinecode gebruikt even lange reeksen backticks; kortere reeksen binnen het fragment blijven inhoud. Een inlinefragment mag meerdere regels binnen dezelfde gewone paragraaf beslaan. Een codeblok begint met minstens drie backticks of tildes en hoogstens drie spaties inspringing. De afsluitende regel gebruikt hetzelfde teken, minstens dezelfde lengte en verder alleen spaties of tabs. Een taalnaam of andere informatie achter de opening verandert de detectie niet; bij backtickblokken mag die informatie zelf geen backticks bevatten. Dit volgt de betreffende [CommonMark-afbakeningen](https://spec.commonmark.org/0.31.2/#fenced-code-blocks), zonder Markdown te renderen of voorbeeldcode uit te voeren.

Toewijzingen, gevoelige commandoregelopties en Sensitive-aanroepen gebruiken dezelfde waardeafbakening. Die zoekt ontbrekende quotes of haakjes uitsluitend binnen de context waarin de detectie begint. Eerst wordt de individuele waarde afgeschermd. Als de expressie daar niet betrouwbaar kan worden geïnterpreteerd, wordt de volledige inhoud van het kleinste betrouwbaar afgesloten codefragment gemaskeerd. De omringende backticks of blokmarkeringen, de afsluitende regelovergang en onbetrokken documentatie blijven behouden. UTF-8 en CRLF worden niet genormaliseerd. Meerregelige maskeringen melden via het bestaande veld `context_omitted` dat inhoud is weggelaten.

De tekstregels blijven het hele document doorzoeken, inclusief gewone tekst, blokinformatie en alle codevoorbeelden. Token-, credential-, sleutel- en versleutelde-waardesignaturen houden hun bestaande documentbrede controle. Een taalnaam zoals `puppet`, `ruby`, `bash` of `yaml` schakelt geen regel uit en activeert geen afzonderlijke taalparser. YAML/Hiera-bestanden en hun ingebedde waarden behouden hun bestaande parserroute; backticks daarin worden niet als Markdown behandeld. Fragmentmaskering heft een fout in een andere controle, zoals een onafgesloten sleutelblok, nooit op.

Ingesprongen code krijgt grenzen, maar geen toestemming om bij een onduidelijke expressie het hele fragment vrij te geven na maskering: inspringing kan ook bij een lijst horen. De controle op onduidelijke vervolgregels blijft buiten betrouwbaar afgesloten codefragmenten actief. Paragrafen met lijst- of blockquotemarkeringen, ATX-koppen, linkdoelen of linkdefinities krijgen geen aanvullende inline-afbakening. Backticks in bijvoorbeeld een linktitel mogen een gevoelige waarde niet voortijdig afsnijden. Bij HTML-achtige tekst of autolinks buiten fenced codeblokken vervalt de aanvullende Markdown-afbakening vanaf de betrokken tekst tot het bestandseinde. De scanner interpreteert de HTML-blokstructuur niet en kan daardoor in deze gevallen meer inhoud maskeren of een onvolledig voorbeeld weigeren. HTML binnen een herkend fenced codeblok blijft gewone voorbeeldinhoud.

Ontbrekende afsluitingen, verschillende delimiters en niet-ondersteunde Markdown-contexten leveren geen betrouwbare fragmentfallback. Een ontbrekende waarde aan de fragmentgrens blokkeert, zodat een toewijzing niet stilzwijgend haar waarde in een volgend fragment verliest. Alleen wanneer de bestaande detectie waarden zelfstandig volledig kan afbakenen, kan dergelijke inhoud alsnog worden gecontroleerd. Bij onvolledige inspectie blijft de hele voorbereiding geblokkeerd; er verschijnen geen gedeeltelijke analysekopieën.

Voor `prepare`, `write` en `diff` gelden dezelfde [marker- en herstelregels](#herstelcontext-en-validatie) als voor tekstfragmenten. Een fragmentmarker bewaart de exacte oorspronkelijke broninhoud. Verander de marker of zijn gebonden regelcontext niet zonder de daarvoor ondersteunde expliciete bewerking. Een geslaagde scan of maskering bewijst uitsluitend dekking van de beschreven patronen, niet dat ieder mogelijk geheim is herkend.

## Archieven controleren

De algemene scan ondersteunt tar, gzip, `.tar.gz` en `.tgz` lokaal in het geheugen. Dezelfde controles gelden voor gewone tekstleden, inclusief Hiera-conversies tussen geselecteerde leden en andere geselecteerde databestanden. Er worden geen leden naar het bestandssysteem uitgepakt en geen programma's gestart. ZIP/JAR, uitvoerbare bestanden en andere niet-ondersteunde binaire formaten blijven onvolledig.

Per bestand of lid geldt de bestaande grens van 5 MiB. Een aanroep verwerkt maximaal 25 MiB uitgepakte gegevens, 1000 leden en drie archieflagen. Dubbele leden, absolute paden, `..`, symlinks, hardlinks, bijzondere bestandstypen, ongeldige headers, afgebroken inhoud en aanvullende gegevens na het archief worden geweigerd. Een overschreden grens of ongeldig archief geeft een onvolledige controle.

Het rapport behoudt één record per geselecteerd bestand. `coverage: archive` benoemt archiefinspectie; bevindingen hebben daarnaast een numerieke `member`-route. Er wordt geen afzonderlijke archiefkopie gepubliceerd. Voor inhoudelijke inzage exporteert een vertrouwde lokale caller de benodigde leden veilig naar een private bronmap, zonder inhoud of lidnamen vooraf te tonen. Selecteer deze bestanden en hun volledige Hiera-context daarna met `prepare`. De export verleent op zichzelf geen toestemming tot inzage. Onvolledige inspectie blijft een blokkade; een tekstweergave kan niet naar een archief worden teruggeschreven.

## Puppet-manifesten in standaardtests en CI

Gebruik voor de verplichte controle op hardcoded waarden de bestaande CLI met `--puppet`. Deze modus vereist OpenVox 8 in dezelfde bundle; de repositorybundle bevat die dependency al. De parser leest alleen syntaxis: de scanner compileert geen catalogus en voert geen functies, facts of Hiera-lookups uit. De algemene voorcontrole voor externe analyse blijft afzonderlijk verplicht en omvat ook YAML, templates en overige geselecteerde bestanden.

```sh
bundle exec project-tools-secrets --puppet manifests/ modules/example/manifests/ extra.pp
bundle exec rake secrets:puppet
bundle exec rake test
```

De CLI accepteert een hele map, meerdere mappen, een lijst bestanden of een combinatie in één proces. Met `--puppet` worden uitsluitend `.pp`-bestanden geselecteerd. Een selectie zonder manifesten, onleesbare invoer of een parserfout faalt met exitcode 2. Niet-geselecteerde bestandstypen zijn daarmee niet gecontroleerd. De repositorytaak selecteert alle eigen manifesten, inclusief `examples/`, en sluit `.tools/`, `vendor/` en de vier externe modules `concat`, `debconf`, `reboot` en `stdlib` uit. `bundle exec rake test` en de standaardtaak `bundle exec rake` voeren deze controle verplicht vóór de tooltests uit. De gerichte `test:*`-taken testen alleen de betreffende tool. De afzonderlijke native parservalidatie blijft verplicht.

`puppet_hardcoded_value` meldt letterlijke waarden in gevoelige parameters, variabelen, resourceattributen en hashvelden. Ook een letterlijk argument van `Sensitive` of `Sensitive.new` wordt afgekeurd. De bestaande herkenning van tokenprefixen, autorisatie, credential-URL's, versleutelde waarden en PEM-materiaal blijft actief. Het rapport toont uitsluitend bestand, regelnummer, regel en volledigheid; exitcode 1 blokkeert de tests. `--json` en `--junit` presenteren hetzelfde veilige metadatarapport.

Een variabele, geïndexeerde verwijzing, `.unwrap`, `undef`, `Sensitive[String]` of getypeerde Hiera-lookup bevat zelf geen hardcoded geheim. Deze constructies veroorzaken in Puppet-modus geen bevinding en dus geen onterechte testfout. Letterlijke lookup-defaults via argumenten, `default_value`, `default_values_hash`, `override` of een defaultlambda worden wel onderzocht in een gevoelige context; deze invoervormen volgen de [Puppet-lookupinterface](https://help.puppet.com/core/current/Content/PuppetCore/puppet_lookup.htm). Ook ongequote veldnamen en letterlijke woordwaarden worden onderzocht. Een YAML-waarde achter de lookup moet met de algemene scanmodus afzonderlijk worden gecontroleerd.

De controle onderscheidt code van gegevens. Namen voor bestandspaden, scripts en wachtwoordbeleid worden beperkt uitgezonderd volgens `METADATA_NAME` in de [Puppet-implementatie](lib/project_tools/secrets/puppet_scan.rb). Lege waarden en Unix-vergrendelmarkeringen zijn geen credential. Template-, EPP- en bestandsverwijzingen worden niet uitgevoerd. Een uit verwijzingen samengestelde expressie binnen `Sensitive` is op zichzelf geen letterlijk geheim; herkenbare letterlijke geheime commandoregelargumenten en lookup-defaults in die expressie worden wel onderzocht. De inhoud van de verwijzingen vereist afzonderlijke beoordeling. De scanner voert geen gegevensstroomanalyse uit. Geheimen onder onbekende namen, verborgen in berekeningen, tekstfragmenten van samengestelde commando's of gewone commentaren kunnen daarom worden gemist. Bekende token- en PEM-signaturen worden ook in commentaren gevonden. **Geen bevindingen betekent alleen dat de uitgevoerde controles geen patroon vonden.**

Bij een `reduce` met twee lambdaparameters en een lege hash als beginwaarde herkent de Puppet-modus het volgende telpatroon: een `if` vergelijkt een geïndexeerde accumulator met `undef`, de eerste tak voegt voor die variabele sleutel `1` toe en de andere tak verhoogt dezelfde accumulatorwaarde met `1`. Alleen die twee literals zijn telwaarden. Bij `filter` met twee parameters wordt een gehele grenswaarde achter `>`, `>=`, `<` of `<=` op de tweede parameter als selectiegrens behandeld. Andere literals in dezelfde blokken, lookup-defaults en herkenbare token- of sleutelinhoud blijven gecontroleerd. Een naam met `count` of `counts`, een willekeurig getal of alleen het gebruik van een lambda geeft geen vrijstelling; afwijkende telvormen kunnen nog bevindingen geven.

De [GitHub-workflow](../../.github/workflows/checks.yml) voert `bundle exec rake secrets:puppet` uit in de vaste job **Puppet secrets**, bij iedere push, pull request en merge-group. Er zijn geen padfilters die een vereiste controle in afwachting laten. Andere jobs wachten op deze controle, zodat hun bronfragmenten niet verschijnen wanneer de secrets-controle faalt. Ook `git diff` gebruikt daar uitsluitend een stille statuscontrole. Het secrets-resultaat bevat geen bronfragmenten en er worden geen bronbestanden of analysekopieën als artifact gepubliceerd.

Selecteer na de eerste workflowuitvoering **Puppet secrets** als verplichte statuscontrole in branch protection of het ruleset van de doelbranch. Dit is een instelling van de repositorybeheerder; alleen een workflowbestand maakt een check niet verplicht. Behoud de jobnaam en neem bij gebruik van een merge queue de `merge_group`-trigger over. Zie GitHubs [uitleg over vereiste controles](https://docs.github.com/en/pull-requests/how-tos/merge-and-close-pull-requests/troubleshooting-required-status-checks).

## Een afgekeurd manifest herstellen

Beoordeel de gemelde locatie lokaal zonder de waarde te kopiëren naar logs, tickets of AI-context. Verplaats het geheim naar de daarvoor goedgekeurde Hiera- of secretbackend en gebruik in het manifest een lookup of parameterverwijzing. `Sensitive` beschermt Puppet-uitvoer maar maakt een hardcoded waarde niet toegestaan. Bij een fout of onvolledige scan herstel je eerst de invoer of parserdependency; omzeil de controle niet met een uitsluiting of een genegeerde exitcode. Laat twijfelgevallen lokaal beoordelen. Gebruik bij vermoede blootstelling de [meld- en herstelprocedure](#gemiste-gegevens-of-een-fout-melden).

Voer na herstel opnieuw `bundle exec rake secrets:puppet` en de standaardtests uit. Bij een onterechte melding voeg je een volledig synthetisch voorbeeld toe aan de bestaande regressietests, pas je de centrale regel aan en controleer je ook de bijbehorende echte positieve gevallen. Een consumer krijgt geen eigen scanner of afwijkende detectieregels.

## Gemiste gegevens of een fout melden

Blijkt dat de scanner gevoelige gegevens heeft gemist, onvolledig heeft gemaskeerd of via een rapport of foutmelding heeft getoond, volg dan de [incidentafspraken](../../CONTRIBUTING.md#openbaarmakingsincidenten). Die vereisen een directe melding aan de gebruiker met hersteladvies, ook als het probleem lokaal is ontdekt voordat iets extern is gedeeld. Een eerdere exitcode 0 of een gemaakte analysekopie neemt die meldplicht niet weg. De scanner kan een patroon dat hij niet herkent niet zelf als gemist rapporteren; deze werkwijze geldt zodra een gebruiker, assistent of aanvullende controle het probleem vaststelt of vermoedt.

Gebruik voor de melding uitsluitend veilige metadata: het soort gegevens, een geanonimiseerde bronverwijzing, zo mogelijk het regelnummer of de herkenningsregel, en waar de gegevens mogelijk terechtkwamen. Maak onderscheid tussen alleen lokaal aangetroffen gegevens, bevestigde externe blootstelling en onbekende of vermoede blootstelling. Neem geen waarde, ongefilterd tekstfragment, fingerprint of oorspronkelijke fouttekst over. Benoem een oorzaak alleen als die is vastgesteld; geef anders aan wat nog onderzocht moet worden.

Geef in dezelfde melding een uitvoerbaar hersteladvies. Stel verdere analyse van de betrokken uitvoer uit en gebruik de bestaande kopieën niet opnieuw. Bij blootgestelde inloggegevens of sleutels omvat de incidentafhandeling ook intrekken of vervangen; alleen de scanner repareren maakt die blootstelling niet ongedaan. Kies de technische correctie op basis van het aangetroffen probleem:

| Probleem | Gericht hersteladvies |
| --- | --- |
| Een veld of patroon wordt gemist. | Maak een lokaal voorbeeld met volledig fictieve gegevens en voeg herkenning en regressiedekking toe aan de gedeelde tool. Beschrijf een resterende beperking als betrouwbare herkenning niet mogelijk is. |
| Een waarde blijft geheel of gedeeltelijk zichtbaar in een analysekopie. | Herstel de afbakening en het maskeren van de volledige waarde, inclusief vervolgregels. Laat de tool kopieën weigeren als die afbakening niet betrouwbaar vaststaat. |
| Een rapport, foutmelding of log toont brongegevens. | Verwijder de ongefilterde uitvoer uit dat uitvoerpad en gebruik veilige metadata of een vaste foutidentificatie. Controleer alle betrokken uitvoervormen op hetzelfde lek. |
| Een aanroeper leest het origineel of deelt uitvoer vóór de scan. | Herstel de aanroepvolgorde zodat de lokale controle en beoordeling vóór het lezen plaatsvinden en de analyse de vrijgegeven kopieën gebruikt. |

De [onderhoudsinstructies](#ontwikkelen-en-testen) regelen de synthetische reproductie, regressietests en reparatie van de gedeelde implementatie. Maak na herstel nieuwe kopieën uit opnieuw gecontroleerde bronnen en beoordeel de betrokken uitvoerpaden opnieuw. Vermeld welke correctie is uitgevoerd, waarmee die is gecontroleerd en welke onzekerheden of vervolgstappen openstaan. Zolang veilige controle of maskering onzeker blijft, blijft lokale menselijke beoordeling nodig voordat de betrokken inhoud extern wordt gebruikt.

## Gebruik in een ander project

Deze stappen zijn bedoeld voor een Puppet-project dat deze repository al als `global-modules/` gebruikt. Voer alle commando's uit vanuit de root van dat afnemende project, waar zijn eigen `Gemfile` staat. Gebruik de bestaande gedeelde scanner; je project stelt alleen de bestandsselectie, taken en CI in. Een geïnstalleerde gem start geen controles en neemt de instructies uit de submodule niet automatisch over.

### Kies de controles voor je project

De tool heeft twee toepassingen. Richt ze afzonderlijk in, omdat ze verschillende invoer en vervolgstappen hebben:

| Toepassing | Aanroep | Wat je ermee controleert |
| --- | --- | --- |
| Vóór AI of externe analyse | `bundle exec project-tools-secrets PATH ...` | De werkelijk te lezen bestanden, waaronder YAML/Hiera, templates, scripts en configuratie. Bij bevindingen geef je inhoud uitsluitend vrij via `prepare`. Volg [Controleren voor het lezen](#controleren-voor-het-lezen). |
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

Before project content enters AI context or external analysis, follow the [shared local inspection procedure](global-modules/.tools/secrets/README.md#controleren-voor-het-lezen) and the [repository Git inspection rules](global-modules/CONTRIBUTING.md#git-inspectie). Run the installed scanner from this project root and withhold content when inspection or masking is incomplete. The agent must follow these rules without a separate AI session or launcher. Use the [practical comparison procedure](global-modules/.tools/secrets/README.md#git-versies-lokaal-controleren-en-vergelijken) for Git versions and command output.
```

Kies de bestanden die je daadwerkelijk nodig hebt en neem toepasselijke Hiera-`lookup_options` in dezelfde scan mee. De scanner ontdekt geen externe Hiera-hiërarchie. Geef niet zonder selectie de volledige projectroot op: `.git`, geïnstalleerde gems, de submodule, binaire bestanden en oude uitvoer vallen dan ook binnen de recursieve scan; `.gitignore` is geen scanneruitsluiting.

Selecteer in het lokale beleid de bestanden die je nodig hebt en neem toepasselijke context mee. Gebruik vervolgens uitsluitend de [analysewerkboomprocedure](#ontwikkelen-met-een-analysewerkboom), ook voor alleen lezen. Controleer het voorbereidingsresultaat vóór inzage en sluit de private waardekoppelingen na gebruik af. Kopieer het synthetische oefenbeleid niet ongewijzigd naar een echt project: de caller bepaalt de werkelijke selectie en bevoegdheden.

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

### Werk de tooling bij

Werk de tooling bij door een goedgekeurde revisie van `global-modules` te kiezen en vanuit de consumerroot `bundle install` uit te voeren. Controleer met `bundle info --path project-tools-secrets` de gebruikte bron en doorloop daarna de lokale voorcontrole, Puppet-gate en eigen kwaliteitscontroles opnieuw. Leg de nieuwe gitlink en lockfile samen ter review voor. Ook na een update blijven onvolledig gecontroleerde bestanden afgeschermd.

## Ontwikkelen en testen

Volg bij onderhoud ook de [gezamenlijke ontwikkelwerkwijze](../../CONTRIBUTING.md), het [testbeleid](../../TESTS.md) en het [gedeelde toolingonderhoud](../README.md#gedeeld-toolingonderhoud).

- Verifieer iedere ondersteunde detectieregel met synthetische positieve, negatieve en meerregelige invoer. Onderscheid waardebevindingen van gevoeligheidsindicatoren en documenteer niet-ondersteunde constructies bij [patronen en beperkingen](#patronen-en-beperkingen).
- Oefen bij detectie- of foutwijzigingen ieder openbaarmakingskanaal: stdout, stderr, JSON, JUnit, paden, Ruby-debugmodus en analysewerkbomen. Toon nooit exceptionteksten of bronfragmenten; verifieer dat onvolledige inspectie kopieën achterhoudt.
- Volg voor gemiste waarden en onveilige uitvoer de [incidentafspraken](../../CONTRIBUTING.md#openbaarmakingsincidenten) en [scannerherstelprocedure](#gemiste-gegevens-of-een-fout-melden). Reproduceer defecten synthetisch en voeg regressiedekking toe voor detectie, maskering en openbaarmaking vóór reparatie van de gedeelde implementatie. Verifieer volledige maskering of achtergehouden kopieën bij onbepaalbare grenzen en werk geraakte patronen en beperkingen bij.
- Verifieer bronbehoud, begrensde waarden, private uitvoerrechten, schrijffouten en weigering bestaande doelen te overschrijven. Houd snapshots lokaal en gebruik dezelfde geïnspecteerde bytes voor maskering.
- Test geïnstalleerde gem en consumerprojecten bij CLI- of packagewijzigingen. Behoud zelfstandige installatie en het [exitcontract](#resultaten-en-exitcodes).
- Houd nieuwe secretdetectie en Puppet-integraties in deze tool. Gebruik de native syntaxboom zonder invoer uit te voeren; behoud veilige lookups en referenties en wijs literals binnen Sensitive-wrappers af. Werk detectietests, consumerintegratietests en deze Nederlandse README samen bij.
- Verifieer de verplichte lokale testprerequisite en stabiele GitHub-status met repositoryintegratietests. Detectie, parserfouten en logs houden hetzelfde metadata-onlyrapportcontract; vervolgdiagnostiek mag na een afgekeurde scan geen bron tonen.
- Beoordeel taakgrenzen en dependencyrichting tegen de [interne verantwoordelijkheden](#interne-verantwoordelijkheden). Scanning, voorbereiding, herstel, diagnostiek en vergelijking gebruiken dezelfde scanner en bronlezer. Review syntax- en contextbehoud tegen het [schrijfcontract](#herstelcontext-en-validatie), inclusief volledige herschrijvingen en kandidaat-Hieracontext.
- Oefen globale markerintegriteit over gewijzigde én ongewijzigde bestanden, expliciete verwijdering, verplaatsing en hergebruik, bron- en contextconflicten, symlinkgrenzen en metadatabehoud. Test [journal en herstel](#conflicten-en-herstel-na-fouten) bij fouten na gedeeltelijk toepassen, abrupte processtop en tussentijdse wijzigingen van een ander proces.
- Voeg geen Git-hooks, opdrachtwrappers, revisieverwerking of AI-sessieframework toe om de [repositorywerkwijze](../../CONTRIBUTING.md#git-inspectie) af te dwingen. Houd de tool onafhankelijk van Git en agentlaunchers; behoud lokale ID-koppelingen en herstelstate voor bewerking. Test geïnstalleerd scannen, voorbereiden, schrijven en vergelijken buiten Git zonder agentstart.
- Oefen bij taakingangwijzigingen de ene executable en alle [ondersteunde subcommando's](#taakingangen-en-migratie), inclusief laadfouten vóór commandobehandeling, argumentfouten, vereiste uitvoer en optionele rapportfouten. Verifieer dat intrekken van voorbereiding zowel boom als mapping verwijdert, terwijl een rapportfout na schrijven de toegepaste uitkomst behoudt.
- Bewijs bij hergebruik van inspectieresultaten gelijkheid van bytes, selectie, context en parsersemantiek. Behoud afzonderlijke controles van gewijzigde invoer en definitieve bronversies; test geaccepteerde en afgewezen Puppet-kandidaten en dezelfde state-/bronlockvolgorde bij schrijven en herstel.

Voeg nieuwe detectie toe in deze bestaande tool: gedeelde signaturen in `patterns.rb`, Puppet-syntaxis in `puppet_scan.rb` en YAML/Hiera in `yaml_scan.rb`. Voeg positieve, negatieve, meerregelige en rapportagegevallen met synthetische waarden toe onder `tests/`; test gewijzigde Rake- en CI-koppelingen onder `../repository-checks/tests/`. Werk deze patroonbeschrijving in dezelfde wijziging bij. De gem bevat de runtimecode, één executable met de beschreven subcommando's, de README en de licentie. De geïnstalleerde-consumertests oefenen ook voorbereiding, writer en veilige diff zonder repositorymetadata. Links naar andere tools, instructies en tests vereisen de bijbehorende checkout.

Voer `bundle exec rake test:secrets` uit voor synthetische tests van herkenning, maskeren, gegevensbescherming, foutafhandeling en zelfstandige installatie. `bundle exec rake test` neemt deze tests mee in de [gezamenlijke suite](../README.md#gezamenlijke-tooltests). Geslaagde tests onderbouwen de geteste afspraken; ze bewijzen niet dat willekeurige bestanden geen onbekende geheimen bevatten.

### Interne verantwoordelijkheden

De executable schakelt Ruby-debuguitvoer uit vóór het laden en vangen laad- en opstartfouten af met een vaste foutmelding en exitcode 2. `Command` bedient de scan; `SessionCommand` verwerkt de expliciet gekozen bewerkingstaak, opties en rapportstatus. Deze commandolagen bevatten geen herstel- of verwijderlogica voor bronbestanden.

`SourceReader` leest begrensde bronversies en behandelt leesfouten zonder de scanner te laden. `Scanner` gebruikt die bronlezer en de bestaande taalparsers. De writer inspecteert herstelde kandidaten eenmaal met hun kandidaatcontext; de Puppet-beleidsbeslissing gebruikt dezelfde documenten. Analyse-invoer, herstelde bytes en versies vlak vóór schrijven of review houden hun eigen controles. Er is geen blijvende inspectiecache.

`MarkdownContext` levert uitsluitend bronintervallen aan `TextScan`. `ValueBounds` gebruikt de bijbehorende bovengrens bij de bestaande expressieanalyse en begrenst shellwoorden met hun quotes en expansies. `ShellContext` gebruikt dezelfde lexicale verwerking om shellcode van geciteerde gegevens, commentaar en heredocs te onderscheiden. Zowel de waardeafbakening als de herkenning van PEM-zoekpatronen gebruikt die context; er zijn geen afzonderlijke detectieregels in deze hulpklasse.

`TextScan` begrenst ook whitespace en vervolgregels; `Context` beoordeelt omringende quotes, bronverwijzingen, metadatawaarden en herkenbare programmaconstructies zoals Rake-taaknamen en shelltaklabels. Ook de bronintervallen van losse PEM-zoekpatronen komen uit `Context`. `Scanner` geeft die aan de bestaande signatuurcontrole in `Patterns` door voordat de tekstscan begint. De detectieregels, overlappende maskeringen in `Document` en markerregistratie in `Analysis` houden hun bestaande verantwoordelijkheid. Er is geen afzonderlijke Markdown- of PEM-scanroute.

`Redaction` deelt afscherming tussen selectie, rapportage en diagnostiek. Padweergave maskeert bekende scanwaarden en herkenbare tokens. Diagnostiek maskeert daarnaast bekende paden en ge-escapete waarden en wordt opnieuw geïnspecteerd. Terminalpresentatie via `Shared::Console` vervangt deze afscherming niet. `Output` presenteert metadata en bouwt JUnit met `Shared::JunitReport`; `Publication` beheert uitsluitend nieuwe private analysewerkbomen. Dit exclusieve publicatiecontract blijft afzonderlijk van overschrijfbare rapporten van andere tools.

`Session` beheert voorbereiding en trekt bij mislukte verplichte uitvoer zowel werkboom als lokale mapping in. `MarkerRegistry` registreert en kloont occurrences zolang de voorbereiding schrijfbaar is. `Store` beheert private state, afsluiten en annuleren. `Writer` deelt voor toepassen en herstel dezelfde lockvolgorde: statelock, actuele state herladen, bronroot vergrendelen. `SourceVersions` deelt de beleidsversiecontrole; writer en review behouden hun eigen selectie van te vergelijken bronversies. `SessionReview` verzorgt diagnostiek en roept `ReviewOutput` aan voor de gecontroleerde diff.
