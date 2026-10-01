# Puppet-modules

Dit project bevat Puppet-modules voor het inrichten en beheren van Debian- en Ubuntu-servers. Je kunt er een veilige serverbasis, pakketbronnen, netwerkconfiguratie, web- en databaseservices, containers, certificaten en monitoring mee beheren.

De modules kiezen veilige standaardinstellingen en zijn zo opgebouwd dat Puppet steeds dezelfde voorspelbare configuratie oplevert. Je kunt ze los gebruiken of combineren. `basic_settings` richt de serverbasis in en zorgt ervoor dat andere modules daarop kunnen aansluiten.

> [!IMPORTANT]
> **Perforce zet Puppet-open-sourcecode achter een betaalmuur:** In 2025 heeft Perforce, het bedrijf achter Puppet, besloten om de open-sourcecode van Puppet achter een gesloten omgeving te plaatsen. Deze omgeving blijft gratis tot 25 nodes. Heb je er meer, dan moet je betalen. Vind jij, net als ik, dat opensourcesoftware vrij toegankelijk moet blijven? Stap dan over naar [Vox Pupuli](https://voxpupuli.org/). OpenVox van Vox Pupuli is een drop-invervanger voor Puppet. Dat betekent dat je het Puppet-pakket kunt vervangen door het OpenVox-pakket zonder je bestaande Puppet-configuratie aan te passen.

> [!CAUTION]
> **Compatibiliteit:** Dit project is ontworpen voor 64-bits besturingssystemen. De volledige combinatie van modules is gericht op `amd64`.

## Inhoudsopgave

- [Inhoudsopgave](#inhoudsopgave)
- [Belangrijkste mogelijkheden](#belangrijkste-mogelijkheden)
- [Ondersteuning en compatibiliteit](#ondersteuning-en-compatibiliteit)
- [Technische uitgangspunten](#technische-uitgangspunten)
- [Beveiliging en afwijkende standaardinstellingen](#beveiliging-en-afwijkende-standaardinstellingen)
- [Monitoring](#monitoring)
- [Installatie](#installatie)
- [Quick start](#quick-start)
- [Gebruik van voorbeelden en parameterdocumentatie](#gebruik-van-voorbeelden-en-parameterdocumentatie)
- [Modules](#modules)
  - [`basic_settings`](#basic_settings)
  - [`docker`](#docker)
  - [`gitlab`](#gitlab)
  - [`letsencrypt`](#letsencrypt)
  - [`mysql`](#mysql)
  - [`naemon`](#naemon)
  - [`netplanio`](#netplanio)
  - [`nginx`](#nginx)
  - [`openitcockpit`](#openitcockpit)
  - [`php8`](#php8)
  - [`proxmox`](#proxmox)
  - [`rabbitmq`](#rabbitmq)
  - [`ssh`](#ssh)
  - [`vnstat`](#vnstat)
- [Beschikbare checks](#beschikbare-checks)
- [Uitgebreide voorbeelden](#uitgebreide-voorbeelden)
- [Contributie](#contributie)

## Belangrijkste mogelijkheden

| Onderdeel | Doel |
| --- | --- |
| `basic_settings` | Algemene serverconfiguratie, hardening, APT-bronnen, netwerk, gebruikers, systemd en monitoringbasis. |
| `docker` | Docker CE en beheerde Compose-stacks, inclusief optionele Nginx-proxy en monitoring. |
| `gitlab` | GitLab EE-installatie, omnibusconfiguratie en koppeling met lokale services. |
| `letsencrypt` | Certbot-instellingen en beheerde certificaataanvragen. |
| `mysql` | MySQL-server, databases, gebruikers, grants en versleutelbare back-ups. |
| `naemon` | Naemon-engine en host- en hostgroupconfiguratie voor OpenITCOCKPIT. |
| `netplanio` | Netplan-configuratie voor ethernet en WiFi. |
| `nginx` | Webservers, TLS, PHP-FPM-koppelingen en reverse proxies. |
| `openitcockpit` | OpenITCOCKPIT-agent, servercomponenten en specifieke agentchecks. |
| `php8` | PHP 8 CLI, extensies, PHP-FPM en afzonderlijke FPM-pools. |
| `proxmox` | Proxmox VE-installatie en de overstap naar een Proxmox-kernel. |
| `rabbitmq` | RabbitMQ, TLS, managementplugin, vhosts, exchanges, queues en gebruikers. |
| `ssh` | Gehard OpenSSH-serverbeheer, alternatieve poorten, audit en monitoring. |
| `vnstat` | Verkeersregistratie en capaciteitsmonitoring per netwerkinterface. |
| Monitoring | Nagios-compatibele checks die automatisch voor OpenITCOCKPIT kunnen worden ingesteld. |

## Ondersteuning en compatibiliteit

De platformselectie van `basic_settings` bevat Debian 12, Debian 13, Ubuntu 22.04 LTS, Ubuntu 23.04, Ubuntu 24.04 LTS en Ubuntu 26.04 LTS. De [rootmetadata](metadata.json) beschrijven die projectbrede selectie. Sommige individuele modulemetadata noemen ook Debian 11, maar `basic_settings` heeft daarvoor geen platformmapping: het kiest `unknown` als releasenaam en schakelt aanvullende pakketbronnen uit. Gebruik Debian 11 daarom niet als ondersteunde basis voor de volledige combinatie. Gebruik voor nieuwe servers bij voorkeur een release die nog reguliere beveiligingsupdates ontvangt. Sommige platformonderdelen hebben een beperktere ondersteuning; controleer daarom altijd de aandachtspunten bij de betreffende module.

De volledige combinatie is gemaakt voor `amd64`. Een deel van `basic_settings` werkt ook op andere 64-bits architecturen, maar pakketbronnen voor bijvoorbeeld MySQL en RabbitMQ worden daar niet altijd ingeschakeld. Test daarom iedere gewenste combinatie zelf wanneer je geen `amd64` gebruikt.

De huidige dependencies stellen hogere eisen dan de ondergrens van Puppet 5.5 die nog in individuele modulemetadata staat: `concat` 10 vereist Puppet 8 en `debconf` 8 vermeldt OpenVox vanaf 8.19 binnen majorversie 8. De rootmetadata volgen deze dependencygrenzen. `basic_settings` kan de pakketbron en pakketten voor OpenVox 8 beheren. Er is geen centrale testset die iedere combinatie van Puppet- of OpenVox-versie en besturingssysteem controleert, dus test een upgrade altijd eerst buiten productie.

Dit project gebruikt `concat`, `debconf`, `reboot`, `stdlib` en `timezone`. Deze modules worden als Git-submodules meegeleverd en moeten daarom tijdens de installatie ook worden opgehaald.

De timezone-submodule komt uit de [DevSysEngineer-fork](https://github.com/DevSysEngineer/puppet-timezone), vastgelegd op een commit uit `patch-1` die `stm-debconf` 8 toestaat. De module heet in zijn metadata nog `saz-timezone`; ook het pakket- en toetsenbordbeheer in `basic_settings` gebruikt de debconf-module.

De meegeleverde moduleversies voldoen aan de gedeclareerde dependencygrenzen. Een geslaagde dependency-, metadata- of syntaxcontrole bewijst geen werkende uitrol; de projectbrede platformlijst is evenmin een geteste matrix van alle modules en dependencies.

> [!CAUTION]
> Verschillende modules nemen bestaande configuratiebestanden of pakketkeuzes over. Pas een nieuwe catalogus eerst toe in een testomgeving, controleer wat Puppet wil wijzigen en test daarna de betreffende services. Je hoeft niet alle modules op iedere host te gebruiken.

## Technische uitgangspunten

- **Vaste opstartvolgorde:** `basic_settings` maakt systemd-targets voor systeem-, opslag-, service-, productie- en helperprocessen. Andere modules kunnen hun services hieraan koppelen.
- **Gedeelde instellingen:** Declareer `basic_settings` vóór de modules die zijn instellingen en voorzieningen gebruiken. Zo kunnen zij onder meer monitoring, logrotate, audit en systemd overnemen. Controleer bij los gebruik de voorwaarden van de betreffende module.
- **Beheerde externe bronnen:** Gebruik HTTPS of `puppet:///` voor aangeleverde bestanden. Modules die externe inhoud accepteren weigeren plain HTTP waar dat een onnodig integriteitsrisico vormt.

## Beveiliging en afwijkende standaardinstellingen

Deze modules gebruiken bewust strengere beveiligingsinstellingen dan veel standaardpakketten. Dat kan software of beheerprocedures breken die uitgaan van brede bestandstoegang, schrijfbare systeemmappen, zwakke TLS-instellingen of onbeperkte serviceprocessen. Test wijzigingen met de echte toepassing en controleer logs, sockets, certificaten en gedeelde bestanden voordat je productiehosts omzet.

| Wijziging | Mogelijke impact | Vooraf controleren | Aanpassen |
| --- | --- | --- | --- |
| systemd-hardening en afgeschermde omgevingen | Een service kan geen apparaten, home-directory's, tijdelijke bestanden of beschermde systeempaden meer gebruiken. | De paden, hooks, plugins, sockets en hulpmiddelen die de service gebruikt. | Pas alleen de systemd-instelling aan die de service werkelijk in de weg zit. |
| Strikte umask en bestanden voor alleen root | Bestanden die een webserver, back-upproces of beheergroep moet lezen kunnen te privé worden. | Eigenaar, groep en bestandsrechten van certificaten, logs, sockets, exports en back-ups. | Geef alleen de benodigde groep lees- of schrijfrechten en leg in de code uit waarom dit nodig is. |
| Kernel-, netwerk- en GRUB-instellingen | Lockdown, sysctlwaarden of netwerkkeuzes kunnen drivers, virtualisatie en netwerkverkeer van applicaties beïnvloeden. | Secure Boot, kernelmodules, routing, firewall, congestion control en hersteltoegang. | Gebruik de betreffende `basic_settings`-parameters; met `false` kun je veel optionele hardening uitschakelen. |
| SSH-hardening | Wachtwoordlogin, rootlogin, algoritmen of poorten kunnen bestaande toegang blokkeren. | Een werkende sleutel, toegestane gebruikers, firewall en een tweede beheersessie. | Pas `allow_users`, `password_authentication_users`, `permit_root_login` en de poorten aan. |
| TLS en security headers | Oude clients, zelfondertekende certificaten of webapplicaties kunnen niet meer verbinden of onderdelen van een pagina blokkeren. | Certificaatketen, SNI, ondersteunde protocollen, CSP en TLS naar de achterliggende applicatie. | Geef alleen afwijkende protocollen, headers of certificaatcontrole op als daar een duidelijke reden voor is. |
| Auditlogging en monitoring | Extra events en checks kunnen opslag, rechten en meldingsvolume beïnvloeden. | Auditregels, logrotatie, checktimeouts en monitoringontvangers. | Schakel alleen de controles in die je nodig hebt en pas waar nodig intervallen en limieten aan. |

> [!WARNING]
> `basic_settings` kan `/etc/hosts`, sudoers-inhoud, APT-bronnen, netwerkconfiguratie en andere belangrijke serverinstellingen beheren. Schakel een onderdeel uit wanneer die configuratie al ergens anders wordt beheerd. Gebruik bij een bestaande sudo-configuratie in eerste instantie `sudoers_dir_enable => false`.

Bij Secure Boot blijft `integrity` de minimale waarde voor kernel-lockdown, ook met `kernel_security_lockdown => false`. Zie de [kernelinstellingen](basic_settings/manifests/kernel.pp) voor de beschikbare keuzes.

## Monitoring

OpenITCOCKPIT is het monitoringsysteem dat dit project automatisch kan instellen. Gebruik in `basic_settings` `monitoring_package => 'openitcockpit'`. Zet ook `monitoring_package_install => true` wanneer Puppet het agentpakket moet installeren. Declareer `basic_settings` of `basic_settings::monitoring` vóór de serviceclasses waarvoor je monitoring wilt gebruiken. Die classes bepalen bij hun evaluatie of ze checks toevoegen.

De checks werken ook met een Nagios-compatibele executor. Gebruik `-h` bij een geïnstalleerde check voor de opties en raadpleeg bij los gebruik de vereisten in de [scripts en templates](#beschikbare-checks). Pas bij langere looptijden ook de timeout van de executor aan: een instelling in het script verandert die niet.

Met `basic_settings::monitoring_custom` kun je een eigen script in de OpenITCOCKPIT-pluginmap plaatsen en registreren. De defined types `monitoring_service`, `monitoring_timer` en `monitoring_npm_audit` zijn bedoeld voor veelvoorkomende systemd- en npm-controles. De checks zelf staan onder `files/` en `templates/`; zie ook [Beschikbare checks](#beschikbare-checks) en [`examples/monitoring.pp`](examples/monitoring.pp).

Laat bij het uitschakelen van de hele monitoring `basic_settings::monitoring` aanwezig met `package => 'none'`: Puppet leegt dan zijn bestaande checkregistratie en herstart een actieve systemd-agent om de oude checks uit het geheugen te verwijderen. Andere pluginbestanden blijven staan.

## Installatie

Voer de volgende stappen uit vanuit de hoofdmap van je Puppet-project.

1. Voeg dit project toe als Git-submodule. Vervang `<repository-url>` door de Git-URL van de repository die je gebruikt:

   ```sh
   git submodule add '<repository-url>' global-modules
   ```

2. Haal ook de modules op waarvan dit project afhankelijk is:

   ```sh
   git submodule sync --recursive
   git submodule update --init --recursive
   ```

   De eerste opdracht neemt gewijzigde submodule-URL's over in een bestaande checkout.

3. Voeg in de gewenste Puppet environment een `environment.conf` toe. De extra `modulepath` maakt de modules uit `global-modules` zichtbaar naast de environmentmodules en de standaardmodulepaden:

   ```ini
   modulepath=$codedir/global-modules:$codedir/modules:$basemodulepath
   manifest=./manifests
   ```

   Bij deze inrichting staat `global-modules` naast `environments` en `modules` onder de codedir:

   ```text
   Puppet/
   ├── environments/
   │   ├── development/
   │   │   ├── environment.conf
   │   │   └── manifests/
   │   └── production/
   │       ├── environment.conf
   │       └── manifests/
   ├── global-modules/
   ├── modules/
   └── .gitmodules
   ```

4. Controleer vanuit de juiste environment of Puppet de modules vindt:

   ```sh
   puppet module list --environment development
   ```

Gebruik de [toolinghandleiding voor je eigen project](.tools/README.md#importeren-en-distribueren) om de gedeelde controles voor je eigen Puppet- en Ruby-code in te richten.

Het [versiebeleid](AGENTS.md#versioning-and-releases) beschrijft hoe het project compatibiliteit bij updates beoordeelt.

## Quick start

Dit voorbeeld richt een geharde basis in, activeert OpenITCOCKPIT-monitoring en beheert SSH. Zorg vooraf dat de gekozen beheerder bestaat en met een sleutel kan inloggen; het voorbeeld maakt dat account niet aan. Een profiel met gebruikersbeheer staat in [`examples/site.pp`](examples/site.pp).

```puppet
node 'server01.example.org' {
  class { 'basic_settings':
    monitoring_package         => 'openitcockpit',
    monitoring_package_install => true,
    openitcockpit_enable       => true,
    server_fdqn                => 'server01.example.org',
  }

  # Restrict administrative SSH access after preparing the host baseline.
  class { 'ssh':
    allow_users       => ['admin'],
    permit_root_login => false,
    require           => Class['basic_settings'],
  }

  include openitcockpit

  class { 'openitcockpit::agent':
    push_apikey => Sensitive('replace-with-openitcockpit-api-key'),
    push_enable => true,
    push_url    => 'https://monitoring.example.org',
    require     => Class['basic_settings'],
  }
}
```

Vervang de hostnaam, beheerder en API-key. Compileer eerst de catalogus en pas deze in een testomgeving toe; controleer daarna SSH-toegang en de agentregistratie voordat je dezelfde basis breder uitrolt.

## Gebruik van voorbeelden en parameterdocumentatie

Voorbeelden gebruiken `example.org`, IP-adressen die voor documentatie zijn gereserveerd en waarden die met `replace-with-...` beginnen. Vervang deze waarden door gegevens uit je eigen profielen of Hiera. Gebruik `Sensitive(...)` waar dat wordt ondersteund en bewaar wachtwoorden voor oudere String-parameters versleuteld in Hiera.

De README geeft per module één eenvoudig voorbeeld. In [`examples/`](examples/) staan grotere configuraties waarin je ook ziet hoe classes en resources met elkaar samenwerken. De comments direct boven een Puppet-class of defined type bevatten de volledige lijst met parameters, datatypes, standaardwaarden, aangemaakte bestanden, afhankelijkheden en de betekenis van `true`, `false` en `undef`.

## Modules

### `basic_settings`

#### Doel

`basic_settings` bouwt de gedeelde serverbasis voor Debian en Ubuntu. De class beheert onder meer APT-bronnen, minimale pakketten, standaardinstellingen voor kernel en netwerk, taal, tijdzone, gebruikers, inloggen, beveiliging, Puppet en de systemd-targets waarop andere modules kunnen aansluiten.

Onderliggende classes en defined types kunnen ook los worden gebruikt. Dat is handig wanneer je bijvoorbeeld alleen gebruikers, `/etc/hosts`, een systemd-service, logrotate of een monitoringcheck wilt beheren.

#### Belangrijkste eigenschappen

- Beheert basispakketten en optionele APT-bronnen voor de andere modules.
- Maakt gedeelde systemd-targets en hulpmiddelen voor services, timers, netwerken en drop-ins.
- Beheert instellingen voor de kernel, het netwerk, inloggen, beveiliging, taal, opslag en Puppet.
- Kan OpenITCOCKPIT-monitoring, auditregels, logrotate en meldingen bij mislukte services instellen.
- Beheert optioneel `/etc/hosts` met vaste localhostrecords en aanvullende entries.
- Ondersteunt Puppet- en OpenVox-pakketbronnen en serverinrichting.

#### Belangrijke aandachtspunten

De class kan belangrijke serverconfiguratie en conflicterende pakketten vervangen. Controleer vooral sudoers, firewall, netwerk, bootloader, APT-bronnen, automatische updates en de gekozen bron voor Puppet Server.

Niet ieder pakket is voor iedere Linux-versie en architectuur beschikbaar; de class schakelt een niet-ondersteunde pakketbron daarom uit. Controleer of de benodigde pakketbronnen op jouw platform worden ingeschakeld.

Interactieve Bash-shells sluiten na 15 minuten zonder invoer aan de prompt in `production`, en na 30 minuten in andere serveromgevingen. Hiervoor telt `basic_settings::environment`, niet de Puppet-codeomgeving. Open na een wijziging een nieuwe login-shell en controleer de werking bij afwijkende shells of profielen. Gestarte scripts kunnen deze timeout via `TMOUT` erven; de [login-documentatie](basic_settings/manifests/login.pp) beschrijft hoe je daarmee omgaat.

Puppet stopt standaard de ontdekte tekst- en seriële consoles; kioskmodus houdt ze aan. Controleer vóór de uitrol of je hersteltoegang behouden blijft. Dit beleid blokkeert heractivering door systemd of een herstart niet. Reserveer consoles die een andere toepassing beheert volgens de [getty-instellingen](basic_settings/manifests/login.pp); een reservering stopt of maskeert de console zelf niet.

#### Basisvoorbeeld

```puppet
class { 'basic_settings':
  hosts_enable            => true,
  server_fdqn             => 'server01.example.org',
  systemd_ntp_extra_pools => ['ntp.example.org'],
}
```

Meer gecombineerde basisconfiguratie staat in [`examples/site.pp`](examples/site.pp); `/etc/hosts`-varianten staan in [`examples/hosts.pp`](examples/hosts.pp). De Puppet Strings bij [`basic_settings`](basic_settings/manifests/init.pp) en [`basic_settings::login_user`](basic_settings/manifests/login_user.pp) beschrijven de instellingen voor de serverbasis en gebruikers, inclusief bestandsrechten en toegestane bronnen voor home- en sleutelbestanden.

### `docker`

#### Doel

`docker` installeert Docker CE. Met `docker::compose` beheer je een applicatiestack onder `/opt/docker/<naam>`; `docker::compose_proxy` publiceert die via Nginx. Voor Authentik, Twenty, Nextcloud AIO en GitLab Runner zijn er kant-en-klare configuraties.

#### Belangrijkste eigenschappen

- Installeert Docker CE; de officiële APT-bron kan via `basic_settings` worden beheerd.
- Accepteert Compose-bronnen via `puppet:///`, `file:///` of HTTPS en ondersteunt SHA256-controle voor downloads.
- Beheert per stack een eigen projectmap, `.env`, mappen voor bind mounts en een systemd-service.
- Kan containerstatus, healthchecks, toegestane eenmalige containers, orphans en databaseback-ups monitoren.
- Publiceert applicaties desgewenst via een Nginx reverse proxy, standaard met HTTPS naar de applicatie.
- Levert Authentik en Twenty met `Sensitive` geheimen en dagelijkse PostgreSQL-back-ups.
- Beheert Nextcloud AIO met optionele beheerproxy, SMTP en benoemde S3-objectstores.
- Levert GitLab Runner met optionele eenmalige registratie en behoud van de actieve runnerconfiguratie.

#### Belangrijke aandachtspunten

Declareer `docker` vóór Compose-resources en zorg dat de Docker-pakketbron beschikbaar is. Voor het starten en beheren van stacks als systemd-service is ook `basic_settings::systemd` nodig. Bij ingeschakelde databaseback-ups, waaronder Authentik en Twenty, is deze class verplicht. Het basisvoorbeeld richt beide voorzieningen in via `basic_settings`.

Een start of herstart kan nieuwe images ophalen, ook tijdens een serverstart. Compose hergebruikt standaard aanwezige images, behalve bij `latest`. Twenty en GitLab Runner halen bij `image_tag => 'latest'` altijd images op; bij Twenty geldt dat ook voor PostgreSQL en Redis. Houd dus rekening met upgrades en bereikbaarheid van de registry. Kies een andere updatewijze volgens de [Puppet Strings over `pull`](docker/manifests/compose.pp); `never` vereist dat alle images lokaal aanwezig zijn.

Geef `.env`-inhoud met geheimen door als `Sensitive(...)` en gebruik voor gedownloade Compose-bestanden HTTPS met een checksum.

Declareer voor `docker::compose_proxy` ook `nginx`; kies alleen HTTP naar de achterliggende applicatie als die geen TLS ondersteunt.

`docker::authentik` verwijdert standaard de eerste beheerder `akadmin`. Maak een eigen beheerder aan zoals in het [Authentik-scenario](examples/docker.pp#L121), of zet `akadmin_remove => false` om het account te behouden.

Authentik en Nextcloud nemen zonder eigen relay de SMTP-relay over uit de gedeclareerde `basic_settings`. Controleer de transportbeveiliging: standaard gebruikt Authentik geen TLS en Nextcloud alleen STARTTLS als de relay dat aanbiedt. Verplichte versleuteling vraagt dus een expliciete keuze; zie de SMTP-contracten bij [Authentik](docker/manifests/authentik.pp) en [Nextcloud](docker/manifests/nextcloud.pp).

Bij `ensure => absent` verwijdert Compose de volledige projectmap, inclusief back-ups en lokale bind-mountgegevens, zonder zelf de applicatiecontainers te stoppen. Kopieer benodigde gegevens eerst naar een andere locatie. Ontkoppel de stack van het systemd-target, herlaad systemd en stop de stack terwijl de projectbestanden nog bestaan; stop en deactiveer ook de back-uptimer en -service. Laat vervallen unitbestanden door het centrale mapbeheer opruimen en herlaad systemd daarna opnieuw. Docker named volumes blijven bestaan. Zie het [verwijdervoorbeeld](examples/docker.pp#L46) en het [`ensure`-contract](docker/manifests/compose.pp).

#### Basisvoorbeeld

Plaats het Compose-bestand in je eigen profielmodule op het hieronder genoemde pad en vervang het voorbeeldgeheim door een waarde uit je beveiligde configuratie. Puppet maakt de projectmap en start de stack als `docker-compose-example.service`.

```puppet
class { 'basic_settings':
  docker_enable => true,
}

# Install the runtime after preparing the Docker package source.
class { 'docker':
  require => Class['basic_settings'],
}

# Deploy the application with its managed Compose definition and environment.
docker::compose { 'example':
  compose_source => 'puppet:///modules/profile/example/docker-compose.yml',
  env_content    => Sensitive("COMPOSE_PROJECT_NAME=example\nAPP_SECRET=replace-with-secret\n"),
  require        => Class['docker'],
}
```

Uitgewerkte scenario's staan in `examples/docker.pp`: [Compose met monitoring en initialisatie](examples/docker.pp#L4), [Nginx-proxy](examples/docker.pp#L58), [Authentik met eigen beheerder](examples/docker.pp#L121) en [Twenty met S3-opslag](examples/docker.pp#L184). Zie de Puppet Strings voor de interfaces van [`docker::compose`](docker/manifests/compose.pp), [`docker::compose_proxy`](docker/manifests/compose_proxy.pp) en aanvullende opdrachten via [`docker::compose_exec`](docker/manifests/compose_exec.pp).

#### Databaseback-ups en herstel

Authentik en Twenty maken dagelijks om 05:00 uur in de lokale servertijd een PostgreSQL-back-up, met zeven dagen retentie. Bij deze wrappers kun je de back-up niet uitschakelen. Gebruik voor een eigen project het [Compose-scenario met databaseback-up](examples/docker.pp#L4). De [Compose Strings](docker/manifests/compose.pp) beschrijven de serviceselectie, planning en retentie; dezelfde instellingen zijn beschikbaar via `docker::compose_proxy`.

De back-up werkt met één draaiende PostgreSQL-container; externe databases vallen erbuiten. Controleer de [containervereisten bij `backup_service`](docker/manifests/compose.pp) en of de applicatie daadwerkelijk de geselecteerde database gebruikt. Voer databasewijzigingen en wachtwoordrotaties ook in PostgreSQL door; initialisatievariabelen wijzigen een bestaande database niet.

De exports staan in `/opt/docker/<project>/backup`, alleen toegankelijk voor root, en bevatten clusterbrede globals (rollen en tablespaces) en de applicatiedatabase met alle schemas. Houd ook ruimte vrij voor een tijdelijke ongecomprimeerde export. Applicatiebestanden, secrets, externe kopieën en herstel naar een gekozen tijdstip (PITR) vallen erbuiten. Voor Nextcloud gebruik je de afzonderlijke [AIO-back-ups](#aio-back-ups).

Start na inrichting zelf een back-up en controleer de timer en het log; vervang `example` door de projectnaam:

```sh
sudo systemctl start docker-compose-example-backup.service
sudo systemctl status docker-compose-example-backup.timer
sudo journalctl -u docker-compose-example-backup.service
```

Bij actieve monitoring meldt de systemd-integratie uitvoeringsfouten. `check_compose` controleert ouderdom en verlopen bestanden, geen SQL-inhoud of herstelbaarheid. Een mislukte poging kan samengaan met een nog recente vorige back-up. De ouderdomsgrens is 24 uur: langere runs, timervertraging en de wintertijdwisseling kunnen tijdelijk een alarm geven. Een gemiste timerstart wordt ingehaald, zonder historische snapshots te reconstrueren.

Na het stoppen van de hosttaak kan de export nog doorlopen tot zijn eigen limiet van 3.500 seconden. Blokkeert `/tmp/puppet-compose-backup` in de databasecontainer een volgende run, verwijder die map dan pas nadat je hebt vastgesteld dat er geen export meer draait.

Stop en deactiveer bij het uitschakelen van back-ups ook de timer en service en laat vervallen units opruimen volgens de Compose-verwijderprocedure. Bestaande back-ups blijven staan.

##### Herstel controleren

Herstel eerst in een afzonderlijke, lege testcluster met dezelfde PostgreSQL-hoofdversie en de benodigde extensies. Maak daarin een beheerrol met een eigen onderhoudsdatabase die niet in de export voorkomen, bijvoorbeeld beide met de naam `restore_admin`. Het SQL-bestand maakt de oorspronkelijke rollen en applicatiedatabase zelf aan; bestaande namen kunnen het herstel laten mislukken.

Gebruik de beveiligde authenticatieroute van de testcontainer en een root-shell met beperkte bestandsrechten. Vervang het bestandspad en de containernaam; de voltooiingstijd in de bestandsnaam is in Unix-seconden:

```sh
sudo -i
umask 077
gzip -dc '/opt/docker/example/backup/postgresql-<voltooiingstijd>-<run-id>.sql.gz' > /root/restore.sql
docker exec -i restore-test psql -X -v ON_ERROR_STOP=1 -U restore_admin -d restore_admin < /root/restore.sql
```

Controleer na herstel schemas, data, rollen, eigenaarschap en extensies voordat je op de back-up vertrouwt.

#### Nextcloud AIO

##### Installatie en bereikbaarheid

Gebruik het [Nextcloud-scenario](examples/docker.pp#L238) om [`docker::nextcloud`](docker/manifests/nextcloud.pp) achter een HTTPS-proxy op dezelfde host te installeren. Met `server_name` maakt Puppet die proxy; declareer ook `nginx` en lever een geldig certificaat met sleutel. Zonder `server_name` verzorg je de HTTPS-proxy zelf. Voer dezelfde applicatiedomeinnaam in de AIO-interface in en rond de domeinvalidatie en installatie af. De eerste Puppet-run die een voltooide installatie herkent, past de applicatie-instellingen toe.

AIO vereist vaste container- en volumenamen: er kan maar één installatie per Docker-daemon draaien, ook met andere resourcetitels of poorten. Deze wrapper gebruikt de lokale rootful daemon; gebruik voor meer installaties [afzonderlijke VM's of Docker-daemons](https://github.com/nextcloud/all-in-one/blob/main/multiple-instances.md). Compose-monitoring ziet alleen de mastercontainer. Regel afzonderlijk toezicht op Nextcloud, de database en AIO-back-ups, en bij Talk ook de bereikbaarheid van de Talk-poort.

De [AIO-proxyopzet](https://github.com/nextcloud/all-in-one/blob/main/reverse-proxy.md#external-using-aio-with-an-external-reverse-proxy-eg-caddy-nginx-cloudflare-proxy) gebruikt lokaal HTTP naar de applicatie. De door Puppet gemaakte proxies vereisen [Multipath TCP-ondersteuning](#nginx); hun socketinstellingen gelden ook voor vhosts op hetzelfde luisteradres en dezelfde poort. Controleer voor de applicatieproxy met `nginx -V` bovendien of de build [`--with-threads`](https://nginx.org/en/docs/http/ngx_http_core_module.html#aio) bevat.

Met `server_name` benaderen de AIO-containers de domeinnaam via het Docker-hostadres. Deze hostmapping vereist de standaard Docker-opslag onder `/var/lib/docker/containers/`. Nieuwe of opnieuw aangemaakte containers krijgen haar bij de volgende Puppet-run; voer die ook na installatie en AIO-updates uit. De [Nextcloud Strings](docker/manifests/nextcloud.pp) beschrijven de voorwaarden en foutafhandeling.

##### Beheerstoegang en onderhoud

De admininterface en applicatie-upstream zijn alleen op `127.0.0.1` bereikbaar. Open beheer zonder adminproxy via een SSH-tunnel: standaard `ssh -L 8080:127.0.0.1:8080 admin@cloud.example.org`, gevolgd door `https://127.0.0.1:8080`. De admininterface gebruikt een zelfondertekend certificaat. Bij een aangepaste `admin_port` vervang je de laatste poort in de tunnelmapping.

Met `admin_server_name` publiceer je beheer via Nginx op HTTPS-poort 443, met redirect vanaf poort 80. Declareer `nginx` en lever een certificaat met sleutel dat alle publieke namen dekt. Beperk toegang met `admin_whitelist_ips`, op basis van de clientadressen die Nginx ziet. Een lege lijst geeft geen IP-beperking; de lijst beschermt uitsluitend de adminproxy. De admininterface heeft via de Docker-socket vergaande hosttoegang, ook met een read-only socketmount. Bescherm daarom ook lokale beheer- en Dockertoegang.

Stop de AIO-containers en daarna de mastercontainer met `systemctl stop docker-compose-<naam>.service`; start ze weer met `systemctl start docker-compose-<naam>.service`. Containers en netwerk blijven bestaan. Deze acties maken geen back-up en vereisen een afgeronde eerste inrichting via AIO.

Bij een waarschuwing over mimetype-migraties start Puppet na installatie automatisch `maintenance:repair --include-expensive`. Dit voert alle expensive repair steps uit, met een timeout van één uur, en kan de Puppet-run aanzienlijk verlengen. De [Nextcloud Strings](docker/manifests/nextcloud.pp) beschrijven de uitvoeringsvoorwaarden.

Met [`docker::nextcloud_occ`](docker/manifests/nextcloud_occ.pp) voer je aanvullende beheeropdrachten uit. Beperk de uitvoering volgens de voorbeelden in de Strings: opdrachten kunnen anders bij iedere Puppet-run terugkomen. OCC-wijzigingen worden overgeslagen zolang de container niet draait of de installatie niet als voltooid kan worden gelezen.

Activeer `allow_local_remote_servers` alleen voor benodigde lokale integraties, zoals federatieve shares of webcal: deze functies krijgen daarmee toegang tot lokale diensten. Standaard staat dit uit.

##### AIO-back-ups

Puppet maakt `/opt/docker/<naam>/backup` aan met eigenaar `root:root` en rechten `0700`. Dit activeert nog geen back-ups. Vul het volledige hostpad eenmalig in bij **Local backup location** in de AIO-interface, zonder afsluitende slash of `/borg`. Voor het voorbeeld is dat `/opt/docker/nextcloud-aio/backup`; AIO plaatst de Borg-repository daaronder in `borg`. Je kunt ook een hostpad buiten de projectmap of een externe Borg-repository kiezen.

Start **Create backup**, bewaar de encryptiesleutel en stel na de eerste geslaagde back-up de dagelijkse planning in volgens de [AIO-back-upinstructies](https://github.com/nextcloud/all-in-one#backup). AIO beheert de bestemming en planning zelf.

Bij `ensure => absent` verdwijnt de hele projectmap, inclusief deze lokale back-ups. Kopieer ze eerst naar een andere locatie en volg daarna de Compose-verwijderprocedure bij de belangrijke aandachtspunten. Stop daarbij de Compose-systemd-service zodat ook de AIO-containers stoppen. AIO's named volumes blijven bestaan.

##### S3-opslag kiezen en wijzigen

Gebruik het [voorbeeld met twee stores](examples/docker.pp#L238) om S3-opslag aan een geïnstalleerde AIO-deployment toe te voegen. Registratie alleen activeert geen primaire opslag; het voorbeeld laat ook die keuze zien. De gekozen stores moeten bestaan of via Puppet worden aangemaakt. De [S3 Strings](docker/manifests/nextcloud_s3.pp) en [Nextcloud Strings](docker/manifests/nextcloud.pp) beschrijven de configuratie en opslagkeuzes. Een ingestelde keuze weglaten behoudt de opgeslagen selectie.

Gebruik per store een eigen bucket waar alleen deze Nextcloud-installatie toegang toe heeft. Het wijzigen van primaire opslag migreert geen bestanden en kan bestaande data ontoegankelijk maken. Regel vooraf de migratie en back-ups van zowel de database als de objectdata; volg de [Nextcloud-handleiding voor primaire objectopslag](https://docs.nextcloud.com/server/stable/admin_manual/configuration_files/primary_storage.html).

Lever het secret als `Sensitive` uit beveiligde configuratie; ook access keys en proxy-URL's kunnen gevoelig zijn. Puppet schermt OCC-uitvoer af, maar beheerders kunnen geheimen in procesargumenten zien. Beperk Docker- en procestoegang en bescherm de Nextcloud-configuratie, logs en profiler. Dit geldt ook voor andere OCC-opdrachten met geheimen.

Verwijder een store pas nadat je de data hebt gemigreerd en opslagselecties en gebruikers niet meer naar die store verwijzen. `ensure => absent` verwijdert alleen de registratie; buckets en objecten blijven bestaan. Alleen de Puppet-resource weghalen laat de registratie in Nextcloud staan. De [S3 Strings](docker/manifests/nextcloud_s3.pp) beschrijven alle opslagopties en het effect van weggelaten waarden.

#### GitLab Runner

Gebruik het [Runner-scenario](examples/docker.pp#L295) op een aparte host of VM voor vertrouwde builds. De manager heeft via de Docker-socket vergaande hosttoegang. Nieuwe automatische registraties geven jobs geen socket of runnerconfiguratie en activeren geen privileged mode. Controleer bij bestaande registraties zelf de executorinstellingen: Puppet beheert de inhoud van `config.toml` niet.

Beperk welke projecten de runner mogen gebruiken. De vaste jobpolicy `if-not-present` kan gecachte private images zonder nieuwe registry-autorisatie hergebruiken en houdt veranderlijke tags niet vanzelf actueel.

Maak de runner eerst in GitLab aan en volg het registratievoorbeeld met een token uit beveiligde configuratie. Een bestaand `config.toml` voorkomt registratie, ook als het beschadigd is. Volg na een onderbroken of mislukte poging eerst de [herstelinstructies bij `auto_register`](docker/manifests/gitlab_runner.pp). Na succesvolle registratie kun je het bootstrap-token en de verplichte lookup uit je profiel weghalen; de actieve registratie blijft behouden.

Een hostmapping voor de manager geldt niet voor job- en helpercontainers. Die moeten GitLab zelf kunnen bereiken voor checkout en artifact-upload. Controleer bij afwijkende DNS de [netwerkvoorwaarden bij `runner_ip`](docker/manifests/gitlab_runner.pp).

Pauzeer de runner in GitLab en laat jobs afronden vóór onderhoud of verwijdering: de eindige stoptijd kan langere jobs afbreken. Volg bij verwijdering de procedure bij `ensure` in de Strings; de GitLab-registratie en systemd-service moeten afzonderlijk worden opgeruimd.

### `gitlab`

#### Doel

`gitlab` installeert GitLab EE en koppelt de omnibusservice aan lokale systemd-, monitoring- en auditvoorzieningen. `gitlab::config` beheert `/etc/gitlab/gitlab.rb` en voert `gitlab-ctl reconfigure` uit wanneer de configuratie wijzigt.

#### Belangrijkste eigenschappen

- Installeert GitLab EE met een initiële rootgebruiker.
- Kan `/opt/gitlab` naar een afzonderlijke installatielocatie verplaatsen.
- Beheert HTTPS-, SSH-, SMTP-, Puma-, Sidekiq- en PostgreSQL-instellingen via `gitlab::config`.
- Kan meldingen bij een mislukte service, auditregels en een GitLab-monitoringcheck instellen.
- Kan de service aan het gedeelde `services`-target binden.

#### Belangrijke aandachtspunten

De GitLab APT-bron moet vóór de installatie beschikbaar zijn, bijvoorbeeld via `basic_settings` met `gitlab_enable => true`.

Het eerste rootwachtwoord is nog een parameter van het type String. Haal dit wachtwoord uit versleutelde Hiera-data en zet het niet rechtstreeks in een manifest.

Het verplaatsen van `/opt/gitlab` en het uitvoeren van `gitlab-ctl reconfigure` kunnen veel wijzigen; controleer daarom eerst opslag, back-ups en het onderhoudsvenster.

#### Basisvoorbeeld

Het basisvoorbeeld laat GitLab zelf een Let's Encrypt-certificaat aanvragen; zorg voor passende DNS en bereikbaarheid voor de domeinvalidatie.

```puppet
class { 'basic_settings':
  gitlab_enable => true,
}

# Install GitLab with the administrator password supplied through Hiera.
class { 'gitlab':
  root_password => lookup('gitlab::root_password'),
  server_fdqn   => 'gitlab.example.org',
  require       => Class['basic_settings'],
}

# Enable HTTPS for the installed GitLab service.
class { 'gitlab::config':
  https   => true,
  require => Class['gitlab'],
}
```

Het [GitLab-profiel](examples/site.pp#L146) combineert GitLab met de serverbasis. De Puppet Strings bij [`gitlab`](gitlab/manifests/init.pp) en [`gitlab::config`](gitlab/manifests/config.pp) beschrijven installatie en configuratie.

### `letsencrypt`

#### Doel

`letsencrypt` installeert Certbot en beheert de algemene Certbot-instellingen. Met `letsencrypt::certificate` vraag je één certificaat voor één of meer domeinen aan via een gekozen Certbot-plugin.

#### Belangrijkste eigenschappen

- Beheert `/etc/letsencrypt/cli.ini`, dat alleen door root kan worden gelezen, met het e-mailadres en de loginstellingen.
- Stelt de systemd-prioriteit in en kan een melding sturen wanneer Certbot mislukt.
- Gebruikt logrotate voor Certbotlogs wanneer logrotate door `basic_settings` wordt beheerd.
- Kan certificaten aanvragen en verwijderen.

#### Belangrijke aandachtspunten

De gekozen Certbot-plugin moet geïnstalleerd en bruikbaar zijn. Voor de standaardplugin `nginx` declareer je eerst `letsencrypt` en daarna `nginx`, zoals in het voorbeeld. Zo installeert Nginx ook de benodigde Certbot-plugin. Controleer DNS, poort 80 en 443 en de route die Certbot voor de controle gebruikt.

Certbot kan bij het vernieuwen van een certificaat extra commando's uitvoeren; test daarom ook het herladen van services en de toegang tot certificaatbestanden.

#### Basisvoorbeeld

```puppet
class { 'letsencrypt':
  mail_to => 'security@example.org',
}

# Provide the webserver used by the certificate validation plugin.
class { 'nginx':
  securitytxt_contacts => ['mailto:security@example.org'],
  require              => Class['letsencrypt'],
}

# Request a certificate covering both public application names.
letsencrypt::certificate { 'app.example.org':
  domains => ['app.example.org', 'www.app.example.org'],
  plugin  => 'nginx',
  require => Class['letsencrypt', 'nginx'],
}
```

Een volledige Nginx-, PHP- en certificaatcombinatie staat in [`examples/web.pp`](examples/web.pp). Zie de Puppet Strings bij [`letsencrypt`](letsencrypt/manifests/init.pp) en [`letsencrypt::certificate`](letsencrypt/manifests/certificate.pp) voor de instellingen en certificaataanvragen.

### `mysql`

#### Doel

`mysql` installeert en configureert de MySQL-server en maakt automatisch lokale back-ups. Met defined types beheer je databases, gebruikers en rechten. De module kan samenwerken met PHP-FPM, monitoring, systemd, logrotate en auditd.

#### Belangrijkste eigenschappen

- Beheert MySQL-serverinstellingen boven op een geharde standaardset.
- Levert defined types voor databases, gebruikers en rechten.
- Configureert `automysqlbackup` met een systemd-service en timer.
- Maakt gecomprimeerde, versleutelde back-ups.
- Registreert een MySQL-check wanneer monitoring actief is.
- Kan de pakketversie en pakketbron van `basic_settings::package_mysql` overnemen.

#### Belangrijke aandachtspunten

`automysqlbackup_password` is verplicht en heeft het type `Sensitive[String]`. Voeg bij een overstap vanaf versie 2.0.0 deze parameter toe aan bestaande `mysql`-declaraties en lever het back-upwachtwoord als `Sensitive(...)` uit beveiligde configuratie, zoals in het basisvoorbeeld. Zonder die aanpassing kan Puppet de catalogus niet compileren. De root- en applicatiewachtwoorden zijn nog gewone String-parameters en horen daarom uit versleutelde Hiera-data te komen.

Gebruik je MySQL zonder `basic_settings::package_mysql`, stem dan `package_version` af op de geïnstalleerde versie. Met die pakketbron neemt de module de versie daarvan over; zie de [Puppet Strings bij `mysql`](mysql/manifests/init.pp).

De module gebruikt vaste bufferinstellingen voor MySQL. Controleer of die bij het beschikbare RAM passen.

Met de systemd-inrichting uit het voorbeeld plant Puppet lokale, versleutelde back-ups. Bewaar het back-upwachtwoord buiten de server en test het terugzetten voordat je op de back-ups vertrouwt.

#### Basisvoorbeeld

```puppet
class { 'basic_settings':
  mysql_enable  => true,
  mysql_version => 8.0,
}

# Configure database administration and backup credentials after preparing packages.
class { 'mysql':
  automysqlbackup_password => Sensitive('replace-with-backup-password'),
  root_password            => lookup('mysql::root_password'),
  require                  => Class['basic_settings'],
}

# Create the application schema after the database service is available.
mysql::database { 'app':
  ensure  => present,
  require => Class['mysql'],
}
```

Databases, gebruikers, grants en back-upinstellingen staan in [`examples/data-services.pp`](examples/data-services.pp). Zie de Puppet Strings bij [`mysql`](mysql/manifests/init.pp), [`database`](mysql/manifests/database.pp), [`user`](mysql/manifests/user.pp) en [`grant`](mysql/manifests/grant.pp) voor de bijbehorende interfaces.

### `naemon`

#### Doel

`naemon` installeert de OpenITCOCKPIT-variant van Naemon en beheert hosts en hostgroepen. De module is bedoeld als onderdeel van een OpenITCOCKPIT-server en niet als algemene zelfstandige Naemon-module.

#### Belangrijkste eigenschappen

- Installeert `openitcockpit-naemon` nadat het OpenITCOCKPIT-pakket beschikbaar is.
- Beheert de directory met Naemon-configuratiefragmenten.
- Levert defined types voor hosts en hostgroepen.
- Koppelt de service aan het gedeelde helpers-target en kan een melding sturen wanneer de service mislukt.
- Past systemd-hardening toe en maakt waar nodig de koppeling `nagios.service` voor software die die oude servicenaam verwacht.

#### Belangrijke aandachtspunten

Richt eerst de OpenITCOCKPIT-server in en zorg dat `Package['openitcockpit']` in de Puppet-catalogus staat.

De module beheert de volledige configuratiemap en verwijdert bestanden die niet door Puppet worden beheerd. Zet daarom geen handmatig gemaakte Naemon-configuratie in die map.

#### Basisvoorbeeld

```puppet
include naemon

naemon::host { 'web01':
  address  => '192.0.2.10',
  friendly => 'Webserver 01',
}
```

De [serveropbouw](examples/monitoring.pp#L80) staat in `examples/monitoring.pp`. Zie de Puppet Strings bij [`naemon`](naemon/manifests/init.pp), [`host`](naemon/manifests/host.pp) en [`hostgroup`](naemon/manifests/hostgroup.pp) voor de voorwaarden en configuratie.

### `netplanio`

#### Doel

`netplanio` installeert Netplan en maakt netwerkconfiguratie voor ethernet en WiFi. De module gebruikt de DHCP- en IPv6-instellingen van `basic_settings::network` wanneer die class aanwezig is.

#### Belangrijkste eigenschappen

- Installeert `netplan.io` en beheert de module-eigen configuratiebestanden.
- Ondersteunt DHCP, statische adressen, nameservers en routes per ethernetinterface.
- Ondersteunt WiFi-accesspoints en optionele interface-instellingen.
- Kan standaardinstellingen van `basic_settings::network` overnemen.
- Past wijzigingen met Netplan toe nadat Puppet de benodigde bestanden en pakketten heeft klaargezet.

#### Belangrijke aandachtspunten

Een fout netwerkplan kan de beheerverbinding verbreken. De module verwijdert `/etc/netplan/50-cloud-init.yaml`; neem benodigde instellingen daaruit vooraf over. Controleer interfacenamen, renderer, routes, gateway en nameservers en regel consoletoegang voordat Puppet de configuratie toepast.

WiFi-hashes kunnen wachtwoorden bevatten; lever die data vanuit afgeschermde Hiera aan.

Declareer `netplanio` vóór de interfaces.

#### Basisvoorbeeld

```puppet
include netplanio

netplanio::ethernet { 'primary':
  addresses   => ['192.0.2.20/24'],
  interface   => 'ens18',
  nameservers => { 'addresses' => ['192.0.2.53'] },
  routes      => { 'default' => { 'via' => '192.0.2.1' } },
}
```

Het [netwerkprofiel](examples/site.pp#L134) staat in `examples/site.pp`. De Puppet Strings bij [`netplanio`](netplanio/manifests/init.pp), [`ethernet`](netplanio/manifests/ethernet.pp) en [`wifi`](netplanio/manifests/wifi.pp) beschrijven de geërfde netwerkinstellingen en interfaceconfiguratie.

### `nginx`

#### Doel

`nginx` installeert en configureert de Nginx-service. `nginx::server` beheert een website of reverse proxy met TLS, security headers, locations en optionele PHP-FPM-koppeling.

#### Belangrijkste eigenschappen

- Beheert algemene Nginx-, events- en HTTP-instellingen en gebruikt strenge TLS-instellingen.
- Levert vhosts voor statische sites, PHP-applicaties en reverse proxies.
- Ondersteunt HTTP/2, HTTP/3, HTTPS-forcering en certificate chains.
- Beheert security headers en de gegevens in `security.txt`.
- Werkt samen met Certbot, PHP-FPM, monitoring, auditd, logrotate en de gedeelde systemd-targets.
- Controleert bij actieve OpenITCOCKPIT-monitoring de lokale certificaatketen, DNS-namen, sleutel en geldigheid van geconfigureerde HTTPS-vhosts.

#### Belangrijke aandachtspunten

Declareer `nginx` vóór de vhosts. Voeg bij een vhost of een wrapper die Nginx-configuratie wijzigt geen `require => Class['nginx']` toe: dat kan een afhankelijkheidscyclus veroorzaken. Gebruik voor aanvullende afhankelijkheden de betreffende pakket- of bestandsresource; `nginx::server` regelt zijn pakket- en configuratieafhankelijkheden zelf.

De module verwijdert Apache en neemt de Nginx-configuratie over. Controleer bestaande vhosts, document roots, certificaatrechten en gebruikte poorten. In `conf.d` worden bestanden met `.conf` binnen `http {}` ingelezen en bestanden met `.main` op hoofdniveau; geef eigen HTTP-configuratie daarom de extensie `.conf`.

Bij HTTPS met TLS 1.3 activeert de module standaard HTTP/3. Controleer daarvoor de [netwerkondersteuning](#netwerkondersteuning-controleren); zet `http3_enable => false` als de host niet aan die voorwaarden voldoet.

Gebruik voor reverse proxies bij voorkeur HTTPS naar de achterliggende applicatie. Schakel certificaatcontrole alleen uit voor een lokale of self-signed verbinding waarvoor dat echt nodig is. Gebruik HTTP alleen als de achterliggende applicatie geen TLS ondersteunt.

Gebruik voor WebSockets het [proxyvoorbeeld](examples/web.pp#L156). Puppet levert daarbij automatisch de benodigde `$connection_upgrade`-map. Gebruik vanuit externe include-bestanden vraagt aanvullende inrichting volgens de [Puppet Strings](nginx/manifests/server.pp).

#### Basisvoorbeeld

```puppet
class { 'nginx':
  securitytxt_contacts => ['mailto:security@example.org'],
}

# Serve the static application with an explicit document root and server name.
nginx::server { 'app.example.org':
  docroot        => '/var/www/app.example.org',
  php_fpm_enable => false,
  server_name    => 'app.example.org',
}
```

TLS-, PHP-FPM-, monitoring-, security-header- en reverse-proxyvarianten staan in [`examples/web.pp`](examples/web.pp). De Puppet Strings bij [`nginx::server`](nginx/manifests/server.pp) en [`nginx::monitoring_cert`](nginx/manifests/monitoring_cert.pp) beschrijven de instellingen, drempels en beperkingen.

#### Netwerkondersteuning controleren

HTTP/3 vereist hier een Nginx-build met HTTP/3 en QUIC BPF, Linux 5.7 of nieuwer en UDP-segmentatieondersteuning. Houd de HTTPS-poort ook voor UDP bereikbaar en stel `reuseport => true` in op minstens één vhost per gedeeld luisteradres en poort. De vast ingeschakelde QUIC-opties en overige socketinstellingen staan in de [Puppet Strings](nginx/manifests/server.pp).

De Nginx-master moet BPF-programma's mogen laden, ook binnen containers of aanvullende servicebeperkingen. Daarvoor hoef je de bestaande kernelbeveiliging `kernel.unprivileged_bpf_disabled = 1` en `net.core.bpf_jit_harden = 2` niet uit te schakelen. Controleer de servicestart: `nginx -t` test het laden van BPF niet. Zie ook de [NGINX QUIC-voorwaarden](https://nginx.org/en/docs/http/ngx_http_v3_module.html).

Multipath TCP vereist Nginx 1.29.7 of nieuwer met die ondersteuning en Linux 5.6 of nieuwer. De optie staat standaard uit. Bij toevoegen of verwijderen activeert Nginx ook `SO_REUSEPORT`; beoordeel de [beveiligingsgevolgen](https://nginx.org/en/docs/http/ngx_http_core_module.html#listen). Socketinstellingen gelden voor alle vhosts op hetzelfde luisteradres, poort en transport. Gebruik daarvoor dezelfde schrijfwijze en stem afwijkende waarden af volgens de Strings.

### `openitcockpit`

#### Doel

Met `openitcockpit::agent` installeer en configureer je de OpenITCOCKPIT-agent; `openitcockpit::server` richt de monitoringsserver in. Alleen `include openitcockpit` installeert geen onderdelen.

#### Belangrijkste eigenschappen

- Beheert een agent in pull- of push-mode met selecteerbare ingebouwde metrics.
- Gebruikt standaard `127.0.0.1` als agentadres, uitgeschakelde Prometheus-export en servercertificaatcontrole in push-mode.
- Levert een Mirth Connect-agentcheck.
- Kan de server koppelen aan Nginx, PHP-FPM, Naemon, Grafana en de gedeelde systemd-targets.
- Slaat gevoelige Grafana- en pakketbrongegevens op in bestanden die alleen root kan lezen wanneer de betreffende parameter dit ondersteunt.
- Sluit aan op de custom-checkregistratie van `basic_settings`.

#### Belangrijke aandachtspunten

Het basisvoorbeeld gebruikt push-mode: de agent maakt zelf verbinding met de opgegeven monitoringsserver. Lever de API-key uit beveiligde configuratie en zorg dat de agent de HTTPS-server kan bereiken.

Maak de pull- of Prometheuspoorten alleen bereikbaar als de firewall en TLS goed zijn ingesteld.

De serverclass gebruikt lokale onderdelen van Nginx, PHP-FPM, Naemon en Docker. Test een upgrade daarom voor de hele OpenITCOCKPIT-server en niet alleen voor één los onderdeel.

#### Basisvoorbeeld

```puppet
class { 'basic_settings':
  openitcockpit_enable => true,
}

include openitcockpit

class { 'openitcockpit::agent':
  push_apikey => Sensitive('replace-with-openitcockpit-api-key'),
  push_enable => true,
  push_url    => 'https://monitoring.example.org',
  require     => Class['basic_settings'],
}
```

Pull-, push-, server- en maatwerkcheckscenario's staan in [`examples/monitoring.pp`](examples/monitoring.pp). Zie de Puppet Strings bij [`agent`](openitcockpit/manifests/agent.pp) en [`server`](openitcockpit/manifests/server.pp) voor de instellingen.

### `php8`

#### Doel

`php8` installeert een gekozen PHP 8 minorversie en extensies. `php8::cli` beheert CLI-instellingen en Composer; `php8::fpm` en `php8::fpm_pool` beheren de FPM-service en afzonderlijke applicatiepools.

#### Belangrijkste eigenschappen

- Installeert alleen de PHP-extensies die je zelf inschakelt.
- Beheert module-eigen INI-bestanden voor CLI en FPM.
- Ondersteunt Composer voor CLI-workloads.
- Levert meerdere FPM-pools met eigen gebruiker, socket en process-managerinstellingen.
- Koppelt FPM aan Nginx, monitoring, systemd en de ingestelde tijdzone.
- Voorkomt dat instellingen die de module zelf beheert via een vrije INI-hash worden overschreven.

#### Belangrijke aandachtspunten

Zorg dat de gekozen PHP-versie in de ingestelde APT-bron beschikbaar is, bijvoorbeeld via Sury in `basic_settings`.

PHP-FPM neemt de poolmap over en verwijdert onbeheerde pools, inclusief de distributiepool. Declareer daarom minstens één `php8::fpm_pool`, zoals in het voorbeeld. De gebruiker, groep en socketrechten moeten bij de webserver passen; anders kan die geen PHP-verzoeken doorgeven.

Stem geheugenlimieten en het aantal PHP-processen af op het beschikbare geheugen en de applicatie.

#### Basisvoorbeeld

```puppet
class { 'basic_settings':
  sury_enable => true,
}

# Install the PHP runtime and application extensions from the prepared source.
class { 'php8':
  curl          => true,
  mbstring      => true,
  minor_version => 3,
  require       => Class['basic_settings'],
}

# Enable PHP-FPM after its runtime is available.
class { 'php8::fpm':
  require => Class['php8'],
}

# Provide a pool after the package has created the FPM directory layout.
php8::fpm_pool { 'app':
  require => Package['php8.3-fpm'],
}
```

Dit voorbeeld levert een pool op `/run/php/php-fpm.sock`. De [webconfiguratie](examples/web.pp) laat de koppeling met Nginx zien. Zie de Puppet Strings bij [`php8`](php8/manifests/init.pp), [`cli`](php8/manifests/cli.pp), [`fpm`](php8/manifests/fpm.pp) en [`fpm_pool`](php8/manifests/fpm_pool.pp) voor de instellingen.

### `proxmox`

#### Doel

`proxmox` installeert Proxmox VE op een host waarvan `basic_settings` de platformcontext heeft bepaald. De class beheert ook de overgang naar de Proxmox-kernel en verwijdert conflicterende generieke kernelpakketten.

#### Belangrijkste eigenschappen

- Installeert de Proxmox VE- en iSCSI-pakketten.
- Installeert op het ondersteunde platform de verwachte PVE-kernel.
- Plant een reboot na de kernelovergang.
- Werkt GRUB bij na packagewijzigingen.
- Verwijdert generieke Linux-imagepakketten en `os-prober` na de Proxmox-installatie.

#### Belangrijke aandachtspunten

Deze class wijzigt de kernel- en bootconfiguratie en kan daardoor een server onbruikbaar maken als er iets misgaat. Zorg voor consoletoegang, een recente back-up en een onderhoudsvenster voordat je haar toepast. Gebruik de class uitsluitend op Debian 12 (`bookworm`) met `basic_settings`.

`proxmox_enable => true` schakelt de Proxmox-pakketbron op dit moment niet in. `basic_settings` verwijdert bovendien de bron- en sleutelbestanden die zijn eigen Proxmox-helper zou gebruiken. Beheer de pakketbron daarom voorlopig in een apart profiel met andere bestandspaden.

#### Basisvoorbeeld

```puppet
include basic_settings

# The profile must provide the repository without reusing paths owned by basic_settings.
class { 'proxmox':
  require => Class['basic_settings'],
}
```

De plaats van Proxmox in een [serverprofiel](examples/site.pp#L166) staat in `examples/site.pp`; ook daar moet je de pakketbron zelf aanleveren. Zie de [Puppet Strings](proxmox/manifests/init.pp) voor de platformvoorwaarden.

### `rabbitmq`

#### Doel

`rabbitmq` installeert en configureert RabbitMQ Server. Aanvullende classes en defined types beheren AMQP/TLS-listeners, de managementplugin, vhosts, exchanges, queues, bindings, gebruikers en permissies.

#### Belangrijkste eigenschappen

- Installeert Erlang en RabbitMQ en koppelt de service aan de gedeelde systemd-targets.
- Beheert het maximale aantal open bestanden, de procesprioriteit en toegestane verouderde RabbitMQ-functies.
- Ondersteunt TLS-listeners en kan plain AMQP uitschakelen zodra certificaten compleet zijn.
- Beheert de managementplugin, vhosts, exchanges, queues, bindings, gebruikers en rechten met Puppet.
- Slaat gevoelige lokale gegevens op in configuratiebestanden die alleen root of de RabbitMQ-gebruiker kan lezen.
- Registreert een RabbitMQ-check met queue- en brokerdiagnose.

#### Belangrijke aandachtspunten

Regel de RabbitMQ APT-bron vóór de installatie.

`rabbitmq::tcp` houdt de gewone TCP-poort ingeschakeld zolang niet alle drie de certificaatpaden zijn opgegeven, ook met `tcp_enable => false`. Geef daarom het CA-certificaat, servercertificaat en de privésleutel op en zorg dat die bestanden beschikbaar zijn voordat je onversleuteld verkeer uitschakelt. De TLS-listener vereist ook een geldig clientcertificaat.

De wachtwoorden voor de managementplugin zijn nog String-parameters en horen uit versleutelde Hiera-data te komen.

#### Basisvoorbeeld

```puppet
class { 'basic_settings':
  rabbitmq_enable => true,
}

# Install the broker after preparing the RabbitMQ package source.
class { 'rabbitmq':
  require => Class['basic_settings'],
}

# Require TLS for client connections and disable the plain TCP listener.
class { 'rabbitmq::tcp':
  ssl_ca_certificate  => '/etc/rabbitmq/ssl/ca.pem',
  ssl_certificate     => '/etc/rabbitmq/ssl/cert.pem',
  ssl_certificate_key => '/etc/rabbitmq/ssl/key.pem',
  tcp_enable          => false,
}
```

Vhosts, exchanges, queues, bindings en gebruikers staan in het [RabbitMQ-scenario](examples/data-services.pp#L63). Zie de Puppet Strings bij [`rabbitmq`](rabbitmq/manifests/init.pp), [`tcp`](rabbitmq/manifests/tcp.pp) en [`management`](rabbitmq/manifests/management.pp) voor de configuratie.

### `ssh`

#### Doel

`ssh` installeert en beheert een geharde OpenSSH-server. De class schrijft de loginbanner en SSH-configuratie, ondersteunt een tweede poort en kan auditregels en een SSH-controle instellen.

#### Belangrijkste eigenschappen

- Beheert toegestane gebruikers, rootlogin en gebruikersspecifieke wachtwoordauthenticatie.
- Genereert ontbrekende hostkeys lokaal op basis van `host_key_algorithms`, met een eigen sleutel per ECDSA-curve.
- Behoudt bestaande private sleutels, herstelt ontbrekende publieke sleutels en configureert idle timeouts.
- Ondersteunt een alternatieve poort met een afzonderlijke gebruikerslijst.
- Houdt rekening met socket activation op Ubuntu-versies die dit gebruiken.
- Registreert auditregels en een check die configuratie en sessiegedrag beoordeelt.
- Beheert `/etc/ssh/sshd_config.d` als module-eigen configuratieboom.

#### Belangrijke aandachtspunten

De module vervangt `/etc/ssh/sshd_config` en verwijdert onbekende bestanden in `/etc/ssh/sshd_config.d`. Bestaande instellingen in het hoofdbestand en onbeheerde drop-ins verdwijnen. Neem instellingen die je wilt behouden vooraf over in de door Puppet beheerde configuratie.

Houd een tweede root- of consoleverbinding open en controleer sleutels, `allow_users`, firewall en eventuele socket activation vóór de eerste herstart, zodat je de toegang niet verliest. Neem bestaande hostkeys vooraf over volgens [Hostidentiteit behouden](#hostidentiteit-behouden); ontbrekende sleutels worden nieuw aangemaakt.

#### Basisvoorbeeld

```puppet
class { 'ssh':
  allow_users                   => ['admin', 'deploy'],
  password_authentication_users => [],
  permit_root_login             => false,
}
```

SSH in een gecombineerd webhostprofiel staat in [`examples/site.pp`](examples/site.pp). De [Puppet Strings bij `ssh`](ssh/manifests/init.pp) beschrijven de beschikbare instellingen.

#### Hostidentiteit behouden

Zet bestaande lokale hostkeys en hun bijbehorende `.pub` vóór de uitrol over naar `/etc/ssh/host_keys`, zonder bestaande doelbestanden te overschrijven. Gebruik eigenaar `root`, modus `0700` voor de map en `0600` voor private sleutels. Zo behouden clients de bekende fingerprints.

Ed25519 en RSA behouden hun bestandsnamen. ECDSA gebruikt `ssh_host_ecdsa_nistp256_key`, `ssh_host_ecdsa_nistp384_key` of `ssh_host_ecdsa_nistp521_key`. Bepaal voor een bestaande `ssh_host_ecdsa_key` de curve met:

```sh
sudo ssh-keygen -y -f /etc/ssh/ssh_host_ecdsa_key | ssh-keygen -lf -
```

Selecteer de gewenste sleuteltypen volgens de [Puppet Strings](ssh/manifests/init.pp). Niet-geselecteerde sleutels blijven op schijf, maar zijn niet actief. Ontbrekende sleutels krijgen een nieuwe identiteit; bestaande sleutels worden behouden, ook als andere servers dezelfde gebruiken. Maak serverimages daarom zonder hostkeys en vervang gedeelde sleutels zelf.

Controleer na de uitrol de configuratie, actieve sleuteltypen en lokale fingerprints. De laatste opdracht gebruikt een root-shell om de afgeschermde map te kunnen doorlopen:

```sh
sudo sshd -t
sudo sshd -T | grep -Ei '^(hostkey|hostkeyalgorithms)'
sudo sh -c 'for key in /etc/ssh/host_keys/ssh_host_*_key.pub; do ssh-keygen -lf "$key"; done'
```

Vergelijk de fingerprints per actief sleuteltype op twee afzonderlijk ingerichte testservers; ze moeten verschillen.

### `vnstat`

#### Doel

`vnstat` installeert vnStat voor lokale verkeersregistratie en capaciteitsmonitoring. Met `vnstat::ethernet` stel je per netwerkinterface de bandbreedte en drempels voor het 95e percentiel in.

#### Belangrijkste eigenschappen

- Beheert vnStatconfiguratie en laat nieuwe interfaces standaard automatisch ontdekken.
- Ondersteunt één technische maximumsnelheid voor alle interfaces en een afwijkende waarde per interface.
- Ondersteunt algemene p95-drempels en afwijkende drempels per interface.
- Koppelt de daemon aan logrotate en de systemd-targets van `basic_settings` wanneer die beschikbaar zijn.
- Registreert een controle die de werkelijke vnStatconfiguratie met het gemeten netwerkgebruik combineert.

#### Belangrijke aandachtspunten

Standaard ontdekt vnStat interfaces automatisch, zonder algemene bandbreedtelimiet of ingestelde p95-alarmdrempels. Gebruik bij een eigen limiet de technische interfacesnelheid in Mbit/s; een databundel of waarschuwingsgrens is daarvoor ongeschikt. Kies alarmdrempels afzonderlijk volgens de Puppet Strings bij [`vnstat`](vnstat/manifests/init.pp) en [`vnstat::ethernet`](vnstat/manifests/ethernet.pp).

#### Basisvoorbeeld

```puppet
class { 'vnstat':
  bandwidth_max => 1000,
  p95_critical  => 900,
  p95_warning   => 700,
}

# Monitor the selected network interface using the shared traffic settings.
vnstat::ethernet { 'wan':
  interface => 'ens192',
  require   => Class['vnstat'],
}
```

Meerdere interfaces en verschillende capaciteiten staan in het [vnStat-scenario](examples/data-services.pp#L173).

## Beschikbare checks

De checks worden automatisch door relevante modules geregistreerd wanneer OpenITCOCKPIT-monitoring actief is. Je kunt ze ook los vanuit een Nagios-compatibele executor gebruiken. De script- en templatecomments zijn de technische bron voor argumenten, commandodependencies, drempels, exitcodes, perfdata en diagnose-uitvoer.

- [`check_apt`](basic_settings/templates/monitoring/check_apt)
- [`check_audit`](basic_settings/templates/monitoring/check_audit)
- [`check_compose`](docker/files/check_compose)
- [`check_eset`](basic_settings/templates/monitoring/check_eset)
- [`check_gitlab`](gitlab/files/check_gitlab)
- [`check_memory_pressure`](basic_settings/templates/monitoring/check_memory_pressure)
- [`check_mirth_connect`](openitcockpit/templates/agent/check_mirth_connect)
- [`check_mysql`](mysql/templates/check_mysql)
- [`check_network`](basic_settings/templates/monitoring/check_network)
- [`check_nginx_cert`](nginx/templates/check_nginx_cert)
- [`check_nftables`](basic_settings/templates/monitoring/check_nftables)
- [`check_npm_audit`](basic_settings/files/monitoring/check_npm_audit)
- [`check_puppet_agent`](basic_settings/templates/monitoring/puppet/check_agent)
- [`check_rabbitmq`](rabbitmq/templates/check_rabbitmq)
- [`check_ssh`](ssh/templates/check_ssh)
- [`check_systemd_config`](basic_settings/files/monitoring/check_systemd_config)
- [`check_systemd_service`](basic_settings/files/monitoring/check_systemd_service)
- [`check_systemd_timer`](basic_settings/files/monitoring/check_systemd_timer)
- [`check_systemd_timesyncd`](basic_settings/files/monitoring/check_systemd_timesyncd)
- [`check_usb`](basic_settings/templates/monitoring/check_usb)
- [`check_vnstat_interfaces`](vnstat/files/check_vnstat_interfaces)

## Uitgebreide voorbeelden

De map `examples/` bevat grotere, herkenbare scenario's. Houd environment-specifieke waarden in profielen of Hiera en neem voorbeeldgeheimen nooit letterlijk over.

- [`examples/site.pp`](examples/site.pp): Gecombineerde basisinstellingen, webserver, PHP, SSH, Docker, MySQL en profielopbouw.
- [`examples/docker.pp`](examples/docker.pp): Compose, monitoring, Nginx-proxy, Authentik, Twenty, Nextcloud AIO met meerdere S3-objectstores en een aparte GitLab Runner-host met eenmalige registratie.
- [`examples/web.pp`](examples/web.pp): Nginx, PHP-FPM, Let's Encrypt, TLS, security headers en reverse proxies.
- [`examples/data-services.pp`](examples/data-services.pp): MySQL, RabbitMQ en vnStat.
- [`examples/monitoring.pp`](examples/monitoring.pp): OpenITCOCKPIT-agent, eigen checks en monitoringinstellingen.
- [`examples/hosts.pp`](examples/hosts.pp): Beheer van `/etc/hosts` via de hoofdclass, networkclass en losse entries.

## Contributie

Pull requests en meldingen zijn welkom. Begin bij [`AGENTS.md`](AGENTS.md) voor het werkproces en de reviewverantwoordelijkheden. De [leeswijzer](.tools/lint/README.md#leeswijzer) wijst je naar de code-, documentatie- en operationele regels die op je wijziging van toepassing zijn.

Richt de [ontwikkelomgeving](.tools/README.md#installatie) in en volg de [werkwijze van beginscan tot oplevering](.tools/lint/README.md#werkwijze-bij-een-wijziging). De [gezamenlijke toolinghandleiding](.tools/README.md) beschrijft de afzonderlijke gems voor Puppet- en Ruby-lint, [metadata](.tools/metadata/README.md), [parservalidatie](.tools/validate/README.md) en [dependencycontrole](.tools/module-dependencies/README.md), plus hun installatie en consumermigratie. Modulegedrag en documentatievoorbeelden vragen daarnaast [afzonderlijke validatie](.tools/lint/README.md#aanvullende-validatie). De [CI-uitleg](.tools/README.md#ci-van-deze-repository) beschrijft waar je de rapporten vindt.
