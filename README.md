# Puppet-modules

Dit project bevat Puppet-modules voor het inrichten en beheren van Debian- en Ubuntu-servers. Je kunt er een veilige serverbasis, pakketbronnen, netwerkconfiguratie, web- en databaseservices, containers, certificaten en monitoring mee beheren.

De modules kiezen veilige standaardinstellingen en zijn zo opgebouwd dat Puppet steeds dezelfde voorspelbare configuratie oplevert. Je kunt ze los gebruiken of combineren. `basic_settings` richt de serverbasis in en zorgt ervoor dat andere modules daarop kunnen aansluiten.

> [!IMPORTANT]
> **Vrij toegankelijke opensourcesoftware:** Vind jij, net als ik, dat opensourcesoftware vrij toegankelijk moet blijven? Gebruik dan [OpenVox van Vox Pupuli](https://voxpupuli.org/openvox/), de door de gemeenschap onderhouden voortzetting van Puppet. Raadpleeg bij een overstap de [installatie- en migratiehandleiding](https://voxpupuli.org/openvox/install/) voor de pakketvervanging en voorwaarden bij je bestaande installatie, en test de overstap eerst buiten productie.

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
  - [`nvidia`](#nvidia)
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
| `nvidia` | Gepinde open headless GPU-driver voor Ubuntu 24.04 ARM64, met automatische GPU-integratie in Docker. |
| `openitcockpit` | OpenITCOCKPIT-agent, servercomponenten en specifieke agentchecks. |
| `php8` | PHP 8 CLI, extensies, PHP-FPM en afzonderlijke FPM-pools. |
| `proxmox` | Proxmox VE-installatie en de overstap naar een Proxmox-kernel. |
| `rabbitmq` | RabbitMQ, TLS, managementplugin, vhosts, exchanges, queues en gebruikers. |
| `ssh` | Gehard OpenSSH-serverbeheer, alternatieve poorten, audit en monitoring. |
| `vnstat` | Verkeersregistratie en capaciteitsmonitoring per netwerkinterface. |
| Monitoring | Nagios-compatibele checks die automatisch voor OpenITCOCKPIT kunnen worden ingesteld. |

## Ondersteuning en compatibiliteit

De [rootmetadata](metadata.json) beschrijven de projectbrede platformselectie; de [platformmapping van `basic_settings`](basic_settings/manifests/init.pp) bepaalt de bijbehorende pakketbronnen en mogelijkheden. Sommige individuele modulemetadata noemen ook Debian 11, maar `basic_settings` heeft daarvoor geen platformmapping: het kiest `unknown` als releasenaam en schakelt aanvullende pakketbronnen uit. Gebruik Debian 11 daarom niet als ondersteunde basis voor de volledige combinatie. Gebruik voor nieuwe servers bij voorkeur een release die nog reguliere beveiligingsupdates ontvangt. Sommige platformonderdelen hebben een beperktere ondersteuning; controleer daarom altijd de aandachtspunten bij de betreffende module.

De volledige combinatie is gemaakt voor `amd64`. Een deel van `basic_settings` werkt ook op andere 64-bits architecturen, maar pakketbronnen voor bijvoorbeeld MySQL en RabbitMQ worden daar niet altijd ingeschakeld. Test daarom iedere gewenste combinatie zelf wanneer je geen `amd64` gebruikt.

De huidige dependencies stellen hogere eisen dan de ondergrens van Puppet 5.5 die nog in individuele modulemetadata staat: `concat` 10 vereist Puppet 8 en `debconf` 8 vermeldt OpenVox vanaf 8.19 binnen majorversie 8. De rootmetadata volgen deze dependencygrenzen. `basic_settings` kan de OpenVox-pakketbron voor major 8 of expliciet major 9 kiezen. Deze bronkeuze is geen automatische package-upgrade en bewijst geen compatibiliteit van de volledige moduleset met OpenVox 9. Er is geen centrale testset die iedere combinatie van Puppet- of OpenVox-versie en besturingssysteem controleert, dus test een upgrade altijd eerst buiten productie.

Dit project gebruikt `concat`, `debconf`, `reboot` en `stdlib` als externe modules. Ze worden als Git-submodules meegeleverd en moeten tijdens de installatie ook worden opgehaald. Het tijdzonebeheer is onderdeel van `basic_settings`; het pakket- en toetsenbordbeheer gebruikt de debconf-module.

Controleer de geïnstalleerde moduleversies met de [dependencycontrole](.tools/module-dependencies/README.md). Een geslaagde dependency-, metadata- of syntaxcontrole bewijst geen werkende uitrol; de projectbrede platformlijst is evenmin een geteste matrix van alle modules en dependencies.

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
> `basic_settings` kan `/etc/hosts`, sudoers-inhoud, APT-bronnen, netwerkconfiguratie en andere belangrijke serverinstellingen beheren. Controleer vóór ingebruikname welke onderdelen elders worden beheerd en wat uitschakelen doet: sommige opties verwijderen dan juist bestaande configuratie. Zie de [voorwaarden voor de serverbasis](#basic_settings). Gebruik bij een bestaande sudo-configuratie in eerste instantie `sudoers_dir_enable => false`.

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

Het [versiebeleid](CONTRIBUTING.md#compatibiliteit-en-versies) beschrijft hoe het project compatibiliteit bij updates beoordeelt.

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

Deze README geeft per module een basisvoorbeeld en gerichte links naar de publieke interface en [uitgebreide scenario’s](#uitgebreide-voorbeelden). Puppet Strings direct boven de publieke class, het defined type of de functie beschrijven parameterbetekenis, voorwaarden en gevolgen. De declaratie geeft type en standaardwaarde; bij berekende defaults legt de toelichting de keuze uit. Wat parameterhulp hiervan toont hangt af van de editor. De bron blijft rechtstreeks leesbaar.

## Modules

### `basic_settings`

<a id="doel"></a>

`basic_settings` bouwt de gedeelde serverbasis voor Debian en Ubuntu. De class beheert onder meer APT-bronnen, minimale pakketten, standaardinstellingen voor kernel en netwerk, taal, tijdzone, gebruikers, inloggen, beveiliging, Puppet en de systemd-targets waarop andere modules kunnen aansluiten.

Onderliggende classes en defined types kunnen ook los worden gebruikt. Dat is handig wanneer je bijvoorbeeld alleen gebruikers, `/etc/hosts`, een systemd-service, logrotate of een monitoringcheck wilt beheren.

<a id="belangrijkste-eigenschappen"></a>

- Maakt gedeelde systemd-targets en hulpmiddelen voor services, timers, netwerken en drop-ins.
- Kan OpenITCOCKPIT-monitoring, auditregels, logrotate en meldingen bij mislukte services instellen.
- Beheert optioneel `/etc/hosts` met vaste localhostrecords en aanvullende entries.
- Ondersteunt Puppet- en OpenVox-pakketbronnen en serverinrichting.

#### Belangrijke aandachtspunten

De class kan belangrijke serverconfiguratie en conflicterende pakketten vervangen. Controleer vooral sudoers, firewall, netwerk, bootloader, APT-bronnen, automatische updates en de gekozen bron voor Puppet Server.

Hostforwarding staat standaard uit. Zet voor een router of Docker-host expliciet `ip_forwarding => true`, laad eerst je eigen firewallbeleid en volg bij Docker de [firewallvoorwaarden](#docker). De families en gevolgen staan bij de publieke parameter in [`basic_settings`](basic_settings/manifests/init.pp).

Uitgeschakelde of niet-ondersteunde repositoryopties laten bestaande configuratie niet ongemoeid: zij verwijderen hun bronbestanden en, afhankelijk van de helper, sleutels of pakketten. Vooral `mongodb_enable => false` en `nodejs_enable => false` verwijderen ook de beheerde server- respectievelijk runtimepackage. Controleer vóór invoering de betreffende publieke `*_enable`-parameter in de [serverbasis](basic_settings/manifests/init.pp). Bewaar onafhankelijke APT-bronnen onder andere bestandsnamen.

Op agentnodes beheert `basic_settings` standaard het volledige `puppet.conf` vanuit het [agenttemplate](basic_settings/templates/puppet/agent.conf), met `[main] certname` en `server_list`, en `[agent] environment`. `certname` volgt `server_fdqn` (standaard de FQDN uit Facter) en moet overeenkomen met het bestaande agentcertificaat. De defaults voor de serverlijst en environment zijn `puppet` en `production`; alle namen uit `puppetserver_names` komen in dezelfde volgorde kommagescheiden in `server_list`, inclusief eventuele poorten, bijvoorbeeld `server_list = puppet01.example.org:8141,puppet02.example.org`. De array wordt zonder blokhaken geschreven, volgens de [OpenVox-configuratiesyntax](https://docs.openvoxproject.org/openvox/9.x/config_file_main.html#lists-of-words). Stel vóór uitrol de bereikbare server en de gewenste environment in: actief beheer vervangt de volledige bestandsinhoud; overige handmatige instellingen en secties verdwijnen. Met `puppet_conf_enable => false` blijft het hele bestand inclusief metadata ongemoeid, ook na eerder actief beheer. Met `puppetserver_enable => true` blijft dit agentconfiguratiebeheer altijd uit. De schakelaar verandert het bestaande servicebeheer niet. Zie de [Puppet Strings](basic_settings/manifests/puppet.pp) voor het contract bij zelfstandig gebruik.

Voor een nieuwe agent moet de eerste serververbinding al werken voordat hij deze catalogus kan ontvangen. OpenVox 9 vereist een expliciete serverlocatie of een ondersteunde alternatieve vindmethode; zie de [upgradehandleiding](https://docs.openvoxproject.org/openvox/latest/upgrade_major.html). Het [OpenVox-voorbeeld](examples/site.pp) toont een expliciete bronkeuze voor major 9 en afzonderlijk het buiten beheer laten van agentconfiguratie. Zonder versieoverride blijft een ingeschakelde Vox Pupuli-bron major 8 gebruiken.

Bij servergebruik kiest de effectief ingeschakelde Vox Pupuli-bron `openvox-server` met de upstreamindeling onder `/etc/puppetlabs` en `/opt/puppetlabs`. Zonder die bron kiest de module `puppetserver`; Ubuntu 22.04 en Debian 11 behouden de legacyserver `puppet-master`. De class controleert pakketbeschikbaarheid en platform-/majorcompatibiliteit niet vooraf. De pakketindeling en Java-voorwaarden staan bij het [servercontract](basic_settings/manifests/puppet.pp). De gedeelde Java-inrichting kiest voor JVM-servers een passende JDK en stelt `/usr/bin/java` daarop in; die keuze gaat vóór `openjdk_version` en geldt ook voor andere gebruikers van dat executable. Een bronwissel migreert bestaande CA- of serverdata niet. Bereid die gegevensoverdracht afzonderlijk voor voordat je een bestaande server omzet.

Een Debian Forky-agent zonder actieve Vox Pupuli-bron gebruikt `/usr/bin/puppet` en `/etc/puppet`, ook met het Debian-pakket `openvox-agent`. Bij aangevraagd distro-servergebruik kiest de class ook daar `puppetserver`, zonder te controleren of Debian een passend pakket levert. Dit is geen volledige Forky-ondersteuning: de serverbasis heeft nog geen Forky-platformmapping. De class installeert of upgradet zelf geen agentpakket.

De standaard `nvidia_dgx_enable => false` verwijdert beide DGX/CUDA-bronnen en beide ondertekeningssleutels. Zet de optie vóór uitrol op `true` wanneer die moeten blijven en controleer of andere bronnen dezelfde sleutelpaden gebruiken. Activeren vereist Ubuntu 24.04 ARM64; niet-lege sleutels worden niet automatisch geroteerd. De [publieke parameter](basic_settings/manifests/init.pp) benoemt alle beheerde paden en grenzen; het [Spark-scenario](examples/nvidia_dgx_spark.pp) combineert bronnen, kernel en driver.

Interactieve Bash-shells sluiten na 15 minuten zonder invoer aan de prompt in `production`, en na 30 minuten in andere serveromgevingen. Hiervoor telt `basic_settings::environment`; bij actief agentconfiguratiebeheer wordt dezelfde waarde als de gevraagde Puppet-agentomgeving geschreven. De waarde wordt niet afgeleid van de Puppet-codeomgeving waarin deze catalogus wordt gecompileerd. Open na een wijziging een nieuwe login-shell en controleer de werking bij afwijkende shells of profielen. Gestarte scripts kunnen deze timeout via `TMOUT` erven; de [login-documentatie](basic_settings/manifests/login.pp) beschrijft hoe je daarmee omgaat.

Puppet stopt standaard de ontdekte tekst- en seriële consoles; kioskmodus houdt ze aan. Controleer vóór de uitrol of je hersteltoegang behouden blijft. Dit beleid blokkeert heractivering door systemd of een herstart niet. Reserveer consoles die een andere toepassing beheert volgens de [getty-instellingen](basic_settings/manifests/login.pp); een reservering stopt of maskeert de console zelf niet.

#### Basisvoorbeeld

Dit voorbeeld configureert de algemene serverbasis met een hostnaam, de te gebruiken Puppet-server en een extra NTP-pool. Neem de waarden op in je bestaande classdeclaratie wanneer je `basic_settings` al gebruikt.

```puppet
class { 'basic_settings':
  hosts_enable            => true,
  puppetserver_names      => ['puppet01.example.org'],
  server_fdqn             => 'server01.example.org',
  systemd_ntp_extra_pools => ['ntp.example.org'],
}
```

Meer gecombineerde basisconfiguratie staat in [`examples/site.pp`](examples/site.pp); `/etc/hosts`-varianten staan in [`examples/hosts.pp`](examples/hosts.pp). De Puppet Strings bij [`basic_settings`](basic_settings/manifests/init.pp) en [`basic_settings::login_user`](basic_settings/manifests/login_user.pp) beschrijven de instellingen voor de serverbasis en gebruikers, inclusief bestandsrechten en toegestane bronnen voor home- en sleutelbestanden.

#### Een NVIDIA DGX Spark-kernel kiezen

Gebruik `kernel_flavor => 'nvidia'` voor een NVIDIA DGX Spark of ASUS Ascent GX10 met Ubuntu 24.04 (`noble`) op ARM64. De keuze geldt ook wanneer de host vóór de eerste herstart nog een `-generic`-kernel draait. Andere besturingssystemen, Ubuntu-versies en architecturen geven bij deze expliciete keuze een compilatiefout. Controleer op de doelhost `facter os.architecture` en `dpkg --print-architecture`: Facter mag `aarch64` of `arm64` melden, APT gebruikt `arm64`. Beide factwaarden worden ook door de DGX-repositoryhelper geaccepteerd.

De [publieke `kernel_flavor`-parameter](basic_settings/manifests/init.pp) beschrijft de profielen, pakketkeuze en gevolgen; bij los gebruik geldt het [kernelcontract](basic_settings/manifests/kernel.pp). Het NVIDIA-profiel behoudt generieke kernels voor herstel en gebruikt Ubuntu-pakketbronnen. Het [headless Spark-voorbeeld](examples/nvidia_dgx_spark.pp) combineert dit met de afzonderlijke NVIDIA-bronnen, [driver](#nvidia) en Docker. De gewone serverbasis blijft actief; CUDA-applicaties draaien in containers. Het scenario vraagt geen desktop of volledige DGX-platformstack aan.

Controleer vóór installatie de beschikbare pakketten en voer op de testhost `sudo apt-get --simulate install linux-nvidia-hwe-24.04 linux-tools-nvidia-hwe-24.04` uit. Ga niet verder bij onverwachte verwijderingen van kernel-, firmware- of bootpakketten. Controleer na installatie de APT-uitvoer, beschikbare kernels en bootconfiguratie en plan zelf een gecontroleerde herstart; dit kernelprofiel triggert geen reboot en kiest geen bootentry. Bevestig daarna met `uname -r` het suffix `-nvidia`, controleer met `dpkg-query -W linux-nvidia-hwe-24.04 linux-tools-nvidia-hwe-24.04 linux-tools-common` de pakketten en controleer dat een tweede Puppet-run geen nieuwe pakketacties voor dit profiel uitvoert.

#### Puppet Server controleren

##### Inrichten en controleren

Met `server_enable => true` in `basic_settings::puppet` en ingeschakelde monitoring wordt `check_puppet_server` aanvullend geregistreerd. De bestaande agent- en servicechecks blijven actief. De nieuwe check inspecteert lokaal de daemon, CA-keten, volledige CRL, server- en agentcertificaten en opgeslagen reports. Zij draait iedere 600 seconden met een executortimeout van 90 seconden. De check zelf reserveert standaard maximaal 80 seconden voor inspectie.

Deze controle vereist een lokale Puppet Server- of OpenVox Server-CA, `reports = store` (eventueel naast andere processors) op de server en ingeschakelde reporting op de agents. De check verandert die instellingen niet. Controleer vóór ingebruikname de effectieve serverconfiguratie en laat agents reports insturen. De legacyvariant `puppet-master`, ontbrekende lokale CA-bestanden en niet-ondersteunde ketens geven UNKNOWN. Een externe CA zonder betrouwbare lokale inventaris is hiermee niet te controleren.

De paden komen uit `puppet config print cacert cacrl signeddir hostcert certname reportdir reports report --section server`, met de configuratie- en serverdatamap van de module expliciet als `--confdir` en `--vardir`. De moderne distributieroute gebruikt `/usr/bin/puppet`, `/etc/puppet` en `/var/lib/puppetserver`; de legacyroute gebruikt `/var/lib/puppet` als datamap. Als `basic_settings::package_voxpupuli` vóór `basic_settings::puppet` is gedeclareerd met `enable => true`, gebruikt zij `/opt/puppetlabs/bin/puppet`, `/etc/puppetlabs/puppet` en `/opt/puppetlabs/server/data/puppetserver`. De hoofdclass `basic_settings` verzorgt deze declaratievolgorde. De reportdirectory volgt de effectieve `reportdir`, inclusief de bestaande symlink. Houd afwijkende JRuby `server-conf-dir`/`server-var-dir` consistent met deze inrichting; de agent-CLI leest geen HOCON-overrides. De [Puppet-uitleg over serverinstellingen](https://help.puppet.com/core/current/Content/PuppetCore/server/puppet_conf_setting_diffs.htm) beschrijft die scheiding.

De gebruikelijke OpenITCOCKPIT-agent draait als root. Dat is hier nodig voor de afgeschermde CA- en reportmappen en de eigen state. Controleer op de doelhost de effectieve servicegebruiker en voer de geregistreerde opdracht ook onder die identiteit uit. Een aangepaste, onprivileged agent voldoet niet aan dit contract; de check verruimt geen rechten en voegt geen sudo-regel toe. Er worden geen netwerkverzoeken gedaan, privésleutels gelezen of Puppet-taken gestart. De check gebruikt systemd alleen als de manager werkelijk actief is en anders `ps`; een gestopte systemd-service blijft een fout.

Een check-in betekent een door de `store`-processor opgeslagen report, niet iedere verbinding of catalogusaanvraag. De nieuwste `mtime` van een regulier, niet-leeg report met de door `store` gebruikte naam `YYYYMMDDHHMM.yaml` benadert het ontvangsttijdstip. De check deserialiseert geen YAML en beoordeelt geen reportinhoud; kopiëren of herstellen kan de gemeten tijd beïnvloeden. Alleen agents met een uitgegeven, niet-ingetrokken certificaat tellen mee. Het eigen servercertificaat en CA-certificaten vallen erbuiten; pending aanvragen zijn nog geen agents. Een verlopen agent blijft meetellen, een ingetrokken of uit de CA opgeschoond certificaat verdwijnt uit de actieve scope.

##### Historie behouden en verplaatsen

De snapshot `/etc/openitcockpit-agent/state/puppet_server/last_seen` bewaart uitsluitend eerder waargenomen reporttijden. `basic_settings::monitoring_custom` beheert de statemap met modus `0700` voordat de check wordt geregistreerd. De snapshot heeft modus `0600`; beide zijn van root. Een lock voorkomt overlappende updates en vervanging gebeurt atomisch. Bestaande dagelijkse report-cleanup verwijdert deze administratie niet. Alleen na een volledige CA- en reportinspectie verdwijnen records van niet meer actieve agents. Bij eerste ingebruikname is gewiste historie niet terug te halen: zonder waargenomen report verschijnt `never reported`. Dit bewijst niet dat de agent vóór installatie nooit heeft gerapporteerd. Oude agents krijgen geen nieuwe inregelperiode; uitsluitend certificaten met een `notBefore` binnen de laatste 24 uur krijgen respijt. Die geldigheidsstart is een benadering van uitgifte, geen gegarandeerd uitgiftetijdstip.

Bij het verplaatsen van een bestaande snapshot moeten alle aanroepen voor die state gestopt zijn. Maak de nieuwe statemap aan als root met modus `0700` en neem de bestaande `last_seen` met zijn eigenaar en rechten mee voordat de check daar draait; anders begint hij zonder eerder waargenomen historie. Dit geldt ook bij een expliciete `STATE_DIR`/`-S`-wijziging.

##### Meldingen beoordelen

Eén agent met een report ouder dan het stale-venster geeft WARNING; precies op de grens nog niet. Langere inactiviteit geeft op zichzelf geen CRITICAL. Certificaatdrempels gelden voor CA, server en actieve agents; de [checkhulp](basic_settings/templates/monitoring/puppet/check_server) beheert de opties en defaults. Ongeldige of ingetrokken servercertificaten, verlopen actieve certificaten, ongeldige CA/CRL en een gestopte daemon geven CRITICAL. De CRL heeft een onafhankelijk waarschuwingsvenster vóór `nextUpdate`; stem dit op de CA-vernieuwingscyclus af. De check beoordeelt één root, eventuele intermediates en precies één volledige CRL per CA, inclusief intrekking van intermediates. Een infrastructure-only CRL is geen vervanging voor `cacrl`; delta-CRLs en indirecte of beperkte CRLs geven UNKNOWN.

De ondersteunde agentidentiteit is een subject `CN=<certname>`, gelijk aan de naam in de signed-directory en reportdirectory. Certnames bevatten uitsluitend letters, cijfers, punten, underscores en koppeltekens; paden daarnaast slashes. Afwijkende identiteiten of paden geven UNKNOWN. Dit voorkomt dat onduidelijke identiteitskoppelingen als betrouwbare agenttotalen worden gepubliceerd.

Pas zo nodig de optionele `monitoring_server_*`-parameters aan op de bestaande classdeclaratie of via Hiera. De [Puppet Strings](basic_settings/manifests/puppet.pp) beschrijven de overrides; `undef` laat de scriptdefault intact. Bij los gebruik toont `check_puppet_server -h` alle CLI-opties, omgevingsvariabelen en defaults. Iedere registratie die hetzelfde executable zelfstandig aanroept moet bij een andere server ook diens eigen paden en statedirectory gebruiken.

De uitvoer is begrensd, met de hoofdoorzaak vooraan en `Interpretation:` als laatste sectie. Afwijkende agents staan op oudste check-in gesorteerd; bij ruimtegebrek verschijnt een melding dat volledige records zijn weggelaten. CRITICAL gaat vóór UNKNOWN, UNKNOWN vóór WARNING. Ontbrekende rechten, reporting, onleesbare bestanden, een onvolledige snapshot of een uitgeput tijdbudget blijven herkenbaar; niet betrouwbaar gemeten perfdata worden weggelaten.

| Perfdata | Betekenis |
| --- | --- |
| `nodes_total` | Actieve, uitgegeven en niet-ingetrokken agentcertificaten, inclusief verlopen certificaten. |
| `nodes_today` | Unieke actieve agents met een report sinds lokale middernacht tot het meetmoment, met de tijdzone van de server. |
| `nodes_stale` | Actieve agents met te oude reports of zonder waargenomen report na de eerste inregelperiode. |
| `certs_expiring` | Actieve agentcertificaten binnen de waarschuwingstermijn die nog niet verlopen zijn. |
| `ca_days_left` | Resterende hele dagen van het eerst aflopende certificaat in de CA-keten. |

Deze waarden zijn gauges zonder `c`-eenheid. Een echte nul blijft nul; ontbrekende metingen verschijnen niet als nul. Lees de hoofdoorzaak en de afsluitende `Interpretation:` samen met de exitcode.

#### Tijdzone en NTP

`basic_settings::timezone` beheert de systeemtijdzone rechtstreeks. Via `basic_settings` geef je de gewenste zone met `server_timezone` door. Je kunt de onderliggende class ook los gebruiken:

```puppet
class { 'basic_settings::timezone':
  timezone => 'Europe/Amsterdam',
}
```

De class installeert `tzdata`, valideert het gekozen tijdzonebestand op de host en beheert `/etc/localtime` als symlink. `/etc/timezone` bevat dezelfde naam voor bestaande toepassingen en auditregels. Ongeldige invoer stopt de compilatie; ontbrekende of ongeldige tijdzonedata blokkeert bij apply beide bestandsresources. Een onverwachte directory op `/etc/localtime` wordt niet geforceerd verwijderd.

Tijdzonebeheer werkt onafhankelijk van NTP. Wanneer `Package['systemd']` vóór deze class is gedeclareerd, beheert zij ook systemd-timesyncd, verwijdert zij concurrerende NTP-pakketten en registreert zij de bestaande check wanneer monitoring actief is. Declareer de class daarom niet nogmaals als `basic_settings` haar al aanroept. De [Puppet Strings](basic_settings/manifests/timezone.pp) beschrijven de interface en voorwaarden.

Controleer vóór uitrol het gedrag na installatie en een `tzdata`-update op de gebruikte release, inclusief het behoud van de tijdzone en het uitblijven van configuratievragen. Distributies kunnen `/etc/timezone` opruimen. Een noop installeert geen ontbrekende tijdzonedata en bewijst daarom niet dat de controle na installatie zal slagen.

### `docker`

<a id="doel-1"></a>

`docker` installeert Docker CE. Met `docker::compose` beheer je een applicatiestack onder `/opt/docker/<naam>`; `docker::compose_proxy` publiceert die via Nginx. Voor Authentik, Twenty, Nextcloud AIO, vLLM en GitLab Runner zijn er kant-en-klare configuraties.

<a id="belangrijkste-eigenschappen-1"></a>

- Accepteert Compose-bronnen via `puppet:///`, `file:///` of HTTPS en ondersteunt SHA256-controle voor downloads.
- Beheert per stack een eigen projectmap, `.env`, mappen voor bind mounts en een systemd-service.
- Kan containerstatus, healthchecks, toegestane eenmalige containers, orphans en databaseback-ups monitoren.
- Publiceert applicaties desgewenst via een Nginx reverse proxy, standaard met HTTPS naar de applicatie.
- Levert Authentik en Twenty met `Sensitive` geheimen en dagelijkse PostgreSQL-back-ups.
- Beheert Nextcloud AIO met optionele beheerproxy, SMTP en benoemde S3-objectstores.
- Levert afzonderlijke vLLM-servers voor tekst en transcriptie met officiële CPU- of NVIDIA-images.
- Levert GitLab Runner met optionele eenmalige registratie en behoud van de actieve runnerconfiguratie.

#### Belangrijke aandachtspunten

Declareer `docker` vóór Compose-resources en zorg dat de Docker-pakketbron beschikbaar is. Voor het starten en beheren van stacks als systemd-service is ook `basic_settings::systemd` nodig. Bij ingeschakelde databaseback-ups, waaronder Authentik en Twenty, is deze class verplicht. Het basisvoorbeeld richt beide voorzieningen in via `basic_settings`.

Voor GPU-toegang declareer je eerst `basic_settings`, daarna [`nvidia`](#nvidia) en daarna `docker`, elk eenmaal. Docker detecteert alleen een class die tijdens zijn evaluatie al is gedeclareerd; een `require` of relatiepijl vervangt die volgorde niet. De beschikbare module alleen activeert niets. Het [Spark-voorbeeld](examples/nvidia_dgx_spark.pp) toont de volledige samenstelling.

Docker beheert het volledige `/etc/docker/daemon.json` via één template en file-resource. Met `daemon_config` overschrijf je de standaardinstellingen; geneste hashes worden samengevoegd, zodat bijvoorbeeld een andere `log-opts.max-size` de standaard `max-file` behoudt. Neem vóór ingebruikname alle bestaande afwijkende instellingen in deze hash over: lokale bestandsinhoud wordt vervangen. De [Docker Strings](docker/manifests/init.pp) beschrijven het configuratiecontract.

Docker erft de firewallkeuze van een eerder gedeclareerde netwerkclass en beheert standaard zelf zijn containerregels. De geërfde IP-keuze bepaalt ook IPv6 op de standaardbridge; eigen netwerken kiezen dat afzonderlijk. Expliciete `daemon_config`-waarden gaan voor. Controleer vóór ingebruikname het [publieke configuratiecontract](docker/manifests/init.pp), vooral bij vervangend firewallbeheer of bestaande IPv6-instellingen.

De native nftables-backend is volgens de [Docker-documentatie](https://docs.docker.com/engine/network/firewall-nftables/) beschikbaar vanaf Engine 29.0.0, experimenteel en niet ondersteund in Swarm-modus. Controleer deze voorwaarden voor de werkelijk geïnstalleerde Engine-versie. De backend schakelt hostforwarding niet zelf in. Stel expliciet `ip_forwarding => true` in; bij `ip_version => 'all'` forwarden beide families en bij `'4'` alleen IPv4. Dit geeft geen algemene toestemming voor verkeer: het consumerproject blijft eigenaar van zijn forward-filter. Bij zelfstandig Docker-gebruik moet de consumer ook de host-sysctls verzorgen.

Verwerk bij gebruik van de nftables-backend eventuele `DOCKER-USER`-regels in je eigen firewallbeleid. Controleer achtergebleven iptables-`FORWARD`-policies; die kunnen verkeer blijven blokkeren. Beheer eigen nftables-regels in aparte tabellen en behoud Docker-tabellen bij het herladen van je firewall.

Laad bij de eerste omschakeling het eigen forward-filter vóór `Exec['kernel_sysctl_reload']` en vóór activering van de Docker-configuratie. `File['/etc/sysctl.d/90-network.conf']` meldt wijzigingen aan deze refresh-only exec, die `sysctl --system` uitvoert; bij hugepages gaat de bestaande hugepage-service daaraan vooraf. `File['/etc/docker/daemon.json']` valideert de volledige kandidaat met `dockerd --validate` en meldt wijzigingen aan `Service['docker']`. Borg in je consumer de volgorde firewall laden, sysctls toepassen, Docker omschakelen, en de overeenkomstige systemd-opstartvolgorde. Alleen de pakket- of servicedeclaratie van nftables bewijst niet dat je eigen filter geladen is. Een forwardingwijziging op zichzelf meldt geen Docker-herstart.

De bestaande sysctlconfiguratie wordt bij het opstarten opnieuw geladen. Test op de integratiehost ook na een reboot de sysctlwaarden, nieuwe bridges, uitgaand containerverkeer, gepubliceerde poorten en geblokkeerd verkeer tussen hostinterfaces. Controleer dat een ongewijzigde tweede Puppet-run geen configuratie schrijft of services herstart. `dockerd --validate` bewijst alleen configuratiegeldigheid. Behoud het bestaande RA-beleid; eventuele benodigde Router Advertisements op een IPv6-uplink stem je af via het bestaande interfacebeheer.

Wanneer `nvidia` is gedeclareerd, voegt Docker de runtime toe aan diezelfde configuratie. Andere opgegeven runtimes blijven behouden en de integratie verandert de default-runtime niet. Laat de NVIDIA-runtime buiten je eigen hash als de automatische integratie hem beheert. Laat je de class later weg, dan verdwijnt de automatisch toegevoegde runtime; driver- en toolkitpakketten blijven geïnstalleerd. Zorg eerst dat geen container of ingestelde default-runtime meer van die vermelding afhankelijk is. Ook gewone Docker-hosts krijgen de centraal beheerde daemonconfiguratie, zonder automatische GPU-aanvulling.

Gebruik de standaardconfiguratielocatie en controleer vooraf met `systemctl cat docker.service` dat startopties en daemonconfiguratie geen dubbele instellingen bevatten. Laat geen andere voorziening, zoals `nvidia-ctk` of een eigen file-resource, hetzelfde bestand schrijven. De nieuwe configuratie wordt vóór vervanging met `dockerd --validate` gecontroleerd; een wijziging herstart alleen een actieve Docker-daemon en kan containers onderbreken. Plan de eerste activering daarom in een onderhoudsmoment.

Een start of herstart kan nieuwe images ophalen, ook tijdens een serverstart. Compose hergebruikt standaard aanwezige images, behalve bij `latest`. Twenty en GitLab Runner halen bij `image_tag => 'latest'` altijd images op; bij Twenty geldt dat ook voor PostgreSQL en Redis. Houd dus rekening met upgrades en bereikbaarheid van de registry. Kies een andere updatewijze volgens de [Puppet Strings over `pull`](docker/manifests/compose.pp); `never` vereist dat alle images lokaal aanwezig zijn.

Geef `.env`-inhoud met geheimen door als `Sensitive(...)` en gebruik voor gedownloade Compose-bestanden HTTPS met een checksum.

Declareer voor `docker::compose_proxy` ook `nginx`; kies alleen HTTP naar de achterliggende applicatie als die geen TLS ondersteunt.

`docker::authentik` verwijdert standaard de eerste beheerder `akadmin`. Maak een eigen beheerder aan zoals in het [Authentik-scenario](examples/docker.pp#L126), of zet `akadmin_remove => false` om het account te behouden.

Authentik en Nextcloud nemen zonder eigen relay de SMTP-relay over uit de gedeclareerde `basic_settings`. Controleer de transportbeveiliging: standaard gebruikt Authentik geen TLS en Nextcloud alleen STARTTLS als de relay dat aanbiedt. Verplichte versleuteling vraagt dus een expliciete keuze; zie de SMTP-contracten bij [Authentik](docker/manifests/authentik.pp) en [Nextcloud](docker/manifests/nextcloud.pp).

Bij `ensure => absent` verwijdert Compose de volledige projectmap, inclusief back-ups en lokale bind-mountgegevens, zonder zelf de applicatiecontainers te stoppen. Kopieer benodigde gegevens eerst naar een andere locatie. Ontkoppel de stack van het systemd-target, herlaad systemd en stop de stack terwijl de projectbestanden nog bestaan; stop en deactiveer ook de back-uptimer en -service. Laat vervallen unitbestanden door het centrale mapbeheer opruimen en herlaad systemd daarna opnieuw. Docker named volumes blijven bestaan. Zie het [verwijdervoorbeeld](examples/docker.pp#L49) en het [`ensure`-contract](docker/manifests/compose.pp).

#### Basisvoorbeeld

Plaats het Compose-bestand in je eigen profielmodule op het hieronder genoemde pad en lever de volledige environment-inhoud via `profile::example::environment` als `Sensitive[String]` uit beveiligde Hiera-data. Puppet maakt de projectmap en de systemd-service `docker-compose-example.service`.

```puppet
class { 'basic_settings':
  docker_enable => true,
  ip_forwarding => true,
}

# Install the runtime after preparing the Docker package source.
class { 'docker':
  daemon_config => {
    'log-opts' => { 'max-size' => '20m' },
  },
  require       => Class['basic_settings'],
}

# Deploy the application with its managed Compose definition and environment.
docker::compose { 'example':
  compose => 'puppet:///modules/profile/example/docker-compose.yml',
  env     => lookup('profile::example::environment', Sensitive[String]),
  require => Class['docker'],
}
```

Start de stack na de eerste inrichting met `sudo systemctl start docker-compose-example.service`. Bij het opstarten van de server verzorgt het gekoppelde systemd-target de start. Puppet laat een gestopte stack gestopt; wijzigingen aan het Compose-bestand of `.env` herstarten alleen een al actieve service. Dit geldt ook voor de applicatiewrappers.

Uitgewerkte scenario's staan in `examples/docker.pp`: [Compose met monitoring en initialisatie](examples/docker.pp#L6), [Nginx-proxy](examples/docker.pp#L62), [Authentik met eigen beheerder](examples/docker.pp#L126) en [Twenty met S3-opslag](examples/docker.pp#L190). Zie de Puppet Strings voor de interfaces van [`docker::compose`](docker/manifests/compose.pp), [`docker::compose_proxy`](docker/manifests/compose_proxy.pp) en aanvullende opdrachten via [`docker::compose_exec`](docker/manifests/compose_exec.pp).

Met `systemd_service` en `systemd_unit` kun je via `docker::compose` en `docker::compose_proxy` de gegenereerde systemd-secties aanpassen. Bijvoorbeeld `systemd_service => { 'TimeoutStartSec' => '3600' }`. De opgegeven directives vervangen hun volledige standaardwaarde; overige instellingen blijven behouden. Behoud de benodigde Compose-commando’s, afhankelijkheden en hardening, en plaats geen geheimen in de publiek leesbare unit. Wijzigingen laden systemd opnieuw; de nieuwe instellingen gelden bij de volgende start. Zie de [Compose Strings](docker/manifests/compose.pp) voor het contract.

Met `proxy_routes` kunnen [`docker::compose_proxy`](docker/manifests/compose_proxy.pp) en [`docker::proxy`](docker/manifests/proxy.pp) meerdere URL-paden naar verschillende poorten sturen. Elke route bevat een `port` en optioneel een `uri` die het gematchte padvoorvoegsel vervangt. Zonder `uri` blijft het verzoekpad behouden; afsluitende slashes bepalen de vervanging volgens [Nginx `proxy_pass`](https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_pass). Host, protocol, headers, timeouts en TLS-verificatie gelden voor alle routes. `proxy_port` blijft de backend voor `/`; zonder die parameter retourneert de rootlocatie 404. Geef voor een aanwezige proxy minstens één backend op. Het routevoorbeeld staat in de [Compose-proxy Strings](docker/manifests/compose_proxy.pp).

#### vLLM gebruiken

Met [`docker::vllm`](docker/manifests/vllm.pp) beheer je tekstgeneratie, transcriptie of beide in één Compose-project. Lever per gewenste dienst een geteste officiële image-tag en de modelinstellingen vanuit je deploymentdata. Een weggelaten tag schakelt die dienst uit; minstens één dienst moet ingeschakeld zijn. De [Strings](docker/manifests/vllm.pp) tonen de interface en voorbeelden met alleen LLM of alleen STT.

Declareer eerst Docker en de gedeelde systemd-inrichting. vLLM volgt Dockers GPU-integratie via `docker::gpu_hardware`: met een vooraf gedeclareerde `nvidia`-class is die waarde `'nvidia'` en gebruikt het `vllm/vllm-openai`; zonder GPU-integratie is zij `undef` en gebruikt het `vllm/vllm-openai-cpu`. Houd voor GPU-hosts de volgorde hostvoorbereiding, `nvidia`, `docker`, `docker::vllm` aan. Het [Spark-voorbeeld](examples/nvidia_dgx_spark.pp) combineert beide diensten met hostbeheer en HTTPS. De platformbeperkingen van de driverclass blijven gelden; de vLLM-wrapper zelf legt geen Compose-platform vast en voegt geen AMD- of Intel-GPU-ondersteuning toe.

Kies tags volgens de [officiële Docker-handleiding](https://docs.vllm.ai/en/stable/deployment/docker/) en voor de CPU-route de [CPU-handleiding](https://docs.vllm.ai/en/stable/getting_started/installation/cpu/). Controleer vóór uitrol het image-entrypoint (`vllm serve`), de hostarchitectuur en de modelafhankelijkheden voor iedere exacte tag. Tags worden letterlijk gebruikt; de CPU- en CUDA-repositories kunnen verschillende tags hebben. De interface accepteert geen volledige imagereferenties of digests. Docker kiest uit het aangeboden manifest zelf de architectuur, zonder afgedwongen emulatie.

Lever één willekeurig token van 64 hextekens als `Sensitive[String]` via beveiligde Hiera-data. De ingeschakelde API's gebruiken dit token en zijn op de host alleen via loopback bereikbaar. Met `server_name` en de TLS-certificaatpaden publiceert de wrapper via `docker::compose_proxy` en `docker::proxy`; declareer daarvoor eerst `nginx`. Alleen ingeschakelde diensten krijgen `/llm/v1/` of `/stt/v1/`. De proxy behoudt de Authorization-header en geeft voor andere applicatiepaden, waaronder `/invocations` en `/stt/invocations`, 404. Zonder `server_name` wordt geen proxy ingericht. De consumer beheert DNS, certificaatbestanden en firewalltoegang.

IP-filtering is optioneel: zonder `whitelist_ips` voegt deze resource geen toegangsregels toe. Geef toegestane adressen expliciet op als je clients wilt beperken; `[]` weigert alle API-clients. Andere centraal beheerde Nginx- en firewallregels blijven gelden. De API-sleutel blijft ook zonder IP-filtering verplicht.

vLLM haalt ontbrekende modellen zelf op. De bestanden blijven onder `/opt/docker/nextcloud-ai/hf-cache` bewaard wanneer je containers vervangt; iedere ingeschakelde service krijgt daarnaast een eigen enginecache. Uitschakelen van een dienst laat haar bestaande cache staan. Een actieve stack wordt via de gedeelde Compose-service vernieuwd; daarbij verwijdert `--remove-orphans` de uitgeschakelde container. Een gestopte stack blijft gestopt en verwerkt de nieuwe selectie bij de volgende start. Zorg voor voldoende schijfruimte en uitgaande downloadtoegang. Start na provisioning met `sudo systemctl start docker-compose-nextcloud-ai.service` en wacht totdat alle ingeschakelde services healthy zijn. De eerste download kan veel langer duren dan een start vanuit cache; kies daarvoor passende timeouts volgens de [Strings](docker/manifests/vllm.pp). Bij verwijdering verdwijnen ook deze caches: volg eerst de Compose-stop- en verwijderprocedure hierboven. Daarna volstaan `ensure => absent` en de bestaande Docker-prerequisite, zonder oude sleutel of modelinstellingen.

vLLM gebruikt `startup_timeout` voor de startlimiet van de Compose-unit, de healthcheck-startperioden en de monitoringgrace. Kies één passende termijn voor downloads en koude starts. Images volgen het standaardpullbeleid van de gedeelde Compose-integratie.

De geheugen-, dtype- en audiokeuzes in het Spark-voorbeeld vereisen validatie op die GPU-host en zijn geen CPU-defaults. Test echte tekst- en transcriptieaanvragen, bij twee diensten ook gelijktijdig binnen het beschikbare geheugen, en herhaal dit na een reboot en Docker-herstart. Alleen als beide services actief zijn, wacht STT bij de eerste Compose-start op een healthy LLM; deze volgorde geldt niet voor iedere zelfstandige containerherstart. Compose-monitoring bewaakt uitsluitend de ingeschakelde services met de ingestelde opstartgrace. Een geslaagde healthcheck bewijst nog geen geslaagde transcriptie of voldoende modelcontext. Controleer volgens de [transcriptiehandleiding](https://docs.vllm.ai/en/stable/serving/online_serving/speech_to_text/) WAV, MP3 en het werkelijke consumerformaat (voor het Talk-voorbeeld ook MP4), rechtstreeks en via HTTPS, met representatieve uploadgroottes en decodegrenzen. Ontbrekende audio-afhankelijkheden vragen een afzonderlijk beoordeelde imagekeuze; de wrapper installeert niets bij containerstart.

#### Databaseback-ups en herstel

Authentik en Twenty maken dagelijks om 05:00 uur in de lokale servertijd een PostgreSQL-back-up, met zeven dagen retentie. Bij deze wrappers kun je de back-up niet uitschakelen. Gebruik voor een eigen project het [Compose-scenario met databaseback-up](examples/docker.pp#L6). De [Compose Strings](docker/manifests/compose.pp) beschrijven de serviceselectie, planning en retentie; dezelfde instellingen zijn beschikbaar via `docker::compose_proxy`.

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

Gebruik het [Nextcloud-scenario](examples/docker.pp#L244) om [`docker::nextcloud`](docker/manifests/nextcloud.pp) achter een HTTPS-proxy op dezelfde host te installeren. Met `server_name` maakt Puppet die proxy; declareer ook `nginx` en lever een geldig certificaat met sleutel. Zonder `server_name` verzorg je de HTTPS-proxy zelf. Voer dezelfde applicatiedomeinnaam in de AIO-interface in en rond de domeinvalidatie en installatie af. De eerste Puppet-run die een voltooide installatie herkent, past de applicatie-instellingen toe.

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

##### Bitrate voor Talk beheren

Geef in een bestaande `docker::nextcloud`-declaratie bijvoorbeeld `talk_max_stream_bitrate => 10485760` op voor een maximale camerabitrate van ongeveer 10,5 Mbit/s. Met `talk_max_screen_bitrate` stel je de bitrate voor schermdelen in. Beide parameters gebruiken bit/s. De standaard `undef` laat de betreffende instelling ongemoeid, ook als je een eerder ingestelde waarde weer weglaat. De [Nextcloud Strings](docker/manifests/nextcloud.pp) beschrijven de controles en uitvoeringsvoorwaarden.

Puppet controleert de ingestelde bitrates tijdens iedere run en corrigeert afwijkingen in beide secties van de Talk-configuratie. Bij een wijziging herstart het eenmaal de service `signaling`. Een ontbrekende of gestopte Talk-container wordt overgeslagen. AIO genereert de configuratie bij iedere containerstart opnieuw; deze oplossing herstelt de gewenste waarden pas tijdens de volgende Puppet-run.

De herstart van `signaling` kan actieve gesprekken verstoren. Voer de eerste integratietest daarom buiten actieve gesprekken uit. Controleer daarna ook een ongewijzigde Puppet-run, `--noop` en herstel na een containerstart.

##### Aanvullende apps en OIDC beheren

Gebruik [`docker::nextcloud_app`](docker/manifests/nextcloud_app.pp) om een aanvullende app te installeren, haar activatiestatus te beheren en opgegeven appinstellingen bij te houden. De app-id is de resourcenaam. Puppet werkt geïnstalleerde apps niet automatisch bij. Een weggelaten instelling blijft behouden; een weggelaten resource laat de app ongemoeid. Met `disable => true` blijft de app geïnstalleerd en uitgeschakeld. Met `ensure => false` verwijdert OCC de app indien aanwezig; daarbij kan appdata verloren gaan.

Voor OIDC gebruik je de afzonderlijke [`docker::nextcloud_user_oidc`](docker/manifests/nextcloud_user_oidc.pp)-class bij je bestaande AIO-deployment, zoals in het [Nextcloud-voorbeeld](examples/docker.pp#L244). De class installeert `user_oidc` indien nodig en houdt de app standaard globaal actief. Declareer daarnaast niet zelf dezelfde `docker::nextcloud_app`-resource. Richt de provider afzonderlijk in en controleer de werking voordat je login laat doorsturen:

```puppet
class { 'docker::nextcloud_user_oidc':
  compose_name                 => 'nextcloud-aio',
  allow_multiple_user_backends => false,
}
```

Met `allow_multiple_user_backends => true` sta je meerdere inlogmethoden toe. Zonder deze optie blijft de bestaande logininstelling behouden.

OCC voert wijzigingen alleen uit wanneer Nextcloud is geïnstalleerd. Aanwezige appbestanden zonder registratiesleutel geven een fout en blokkeren verdere configuratie. Er is geen containerherstart nodig. De [Puppet Strings](docker/manifests/nextcloud_app.pp) beschrijven de voorwaarden, instellingstypen en verwijdergevolgen.

Controleer vooraf je hersteltoegang met een werkend beheerdersaccount. Via `/login?direct=1` kun je de normale loginpagina bereiken zolang die route beschikbaar blijft, zoals beschreven in de [user_oidc-documentatie](https://github.com/nextcloud/user_oidc#disable-other-login-methods). Deze instelling bepaalt het inloggedrag en maakt niet alle alternatieve authenticatiemethoden technisch onmogelijk.

##### Talk-opnamen transcriberen en samenvatten

Het [Nextcloud-scenario](examples/docker.pp) koppelt Nextcloud 35 en Talk 35 met `integration_openai` 5.0.0 aan de twee Spark-API's. Gebruik een werkende AIO Talk-opnameserver en test eerst beide HTTPS-routes vanuit de Nextcloud-container. Controleer de versies bij een update; oudere Talk-versies gebruiken een ander taaktype voor samenvattingen. De wrapper werkt apps niet automatisch bij.

Gebruik [`docker::nextcloud_integration_openai`](docker/manifests/nextcloud_integration_openai.pp) bij je bestaande AIO-deployment en gebruik dezelfde secretlookup als op Spark. De class beheert de app, de opgegeven tekst- en transcriptie-instellingen en beide API-sleutels met Nextclouds native sensitive- en lazy-vlaggen. Declareer daarnaast niet zelf dezelfde `docker::nextcloud_app`-resource. Het voorbeeld toont beide endpoints en modelnamen; de [Puppet Strings](docker/manifests/nextcloud_integration_openai.pp) beschrijven de parameters en wat weglaten of leegmaken betekent. Een bestaande persoonlijke integratiesleutel kan de beheerderssleutel voor tekstaanvragen vervangen; controleer die bij gebruikersgebonden authenticatiefouten. Voor deze integratie hoef je `allow_local_remote_servers` niet globaal in te schakelen.

Activeer transcriptie en samenvatting met `talk_call_recording_transcription => true` en `talk_call_recording_summary => true` in je `docker::nextcloud`-declaratie. Met `undef` blijven de bestaande Talk-instellingen behouden; de [Nextcloud Strings](docker/manifests/nextcloud.pp) beschrijven de voorwaarden.

Geef de Nederlandse verslaginstructie door met `talk_call_recording_summary_prompt`; het voorbeeld leest die uit `profile::nextcloud_ai::talk_summary_prompt`. Een bruikbaar vertrekpunt is:

> Maak een Nederlands vergaderverslag op basis van uitsluitend het transcript. Gebruik de koppen Samenvatting, Besluiten, Actiepunten en Openstaande vragen. Vermeld bij een actiepunt alleen een eigenaar of deadline als die expliciet uit het transcript blijkt. Schrijf anders “niet genoemd”. Verzin geen namen, besluiten of afspraken. Markeer onduidelijke passages als onzeker. Houd het verslag beknopt en behoud belangrijke nuances.

Controleer in AI-beheer dat `core:audio2text` de provider `integration_openai-audio2text` gebruikt en `core:text2text` de provider `integration_openai-text2text`. Bij één geschikte provider is doorgaans geen keuze nodig. Activeer eerder uitgeschakelde taaktypen gericht; vervang geen volledige voorkeuren-JSON. Alleen `core:text2text:summary` configureren volstaat niet voor deze Talk-versie.

AIO beheert de ingebouwde `taskprocessing-worker` naast cron. Voeg geen extra hostworker toe. Controleer bij een AIO-image met dinit de dienst met `docker exec nextcloud-aio-nextcloud dinitctl --system status taskprocessing-worker`. Controleer voor grote opnamen ook de effectieve CLI-PHP-geheugenlimiet: de integratie leest het opnamebestand volledig in. Pas bij een aangetoond tekort de bestaande AIO-instelling `NEXTCLOUD_MEMORY_LIMIT` aan; een aparte worker met andere PHP-vlaggen is daarvoor niet nodig.

Test de volledige keten met een echte Talk-MP4: de integratie verstuurt die als multipart-bestand `file.mp3`, met model `whisper-1` en `response_format=verbose_json`. Controleer eerst audio-imports en MP4-decodering in de STT-image, daarna het transcript en het Nederlandse verslag bij de opname-eigenaar. Test zowel een opname langer dan tien minuten en groter dan 25 MiB als de langste gebruikelijke vergadering. Uploadlimiet, PHP-geheugen, decodebuffer, verwerkingstimeout en LLM-context moeten allemaal passen; Talk geeft het volledige transcript als één teksttaak door. Kijk het verslag inhoudelijk na en controleer daarna een tweede Puppet-run, noop en normale herstarts.

Zet voor terugzetten `talk_call_recording_transcription` en `talk_call_recording_summary` op `false` en laat bestaande AI-taken afronden vóór je de backend terugzet. Laat de gedeelde AIO-worker actief. Alleen de appresource weglaten herstelt eerdere instellingen niet; `ensure => false` verwijdert de app en kan appdata verwijderen.

##### AIO-back-ups

Puppet maakt `/opt/docker/<naam>/backup` aan met eigenaar `root:root` en rechten `0700`. Dit activeert nog geen back-ups. Vul het volledige hostpad eenmalig in bij **Local backup location** in de AIO-interface, zonder afsluitende slash of `/borg`. Voor het voorbeeld is dat `/opt/docker/nextcloud-aio/backup`; AIO plaatst de Borg-repository daaronder in `borg`. Je kunt ook een hostpad buiten de projectmap of een externe Borg-repository kiezen.

Start **Create backup**, bewaar de encryptiesleutel en stel na de eerste geslaagde back-up de dagelijkse planning in volgens de [AIO-back-upinstructies](https://github.com/nextcloud/all-in-one#backup). AIO beheert de bestemming en planning zelf.

Bij `ensure => absent` verdwijnt de hele projectmap, inclusief deze lokale back-ups. Kopieer ze eerst naar een andere locatie en volg daarna de Compose-verwijderprocedure bij de belangrijke aandachtspunten. Stop daarbij de Compose-systemd-service zodat ook de AIO-containers stoppen. AIO's named volumes blijven bestaan.

##### S3-opslag kiezen en wijzigen

Gebruik het [voorbeeld met twee stores](examples/docker.pp#L244) om S3-opslag aan een geïnstalleerde AIO-deployment toe te voegen. Registratie alleen activeert geen primaire opslag; het voorbeeld laat ook die keuze zien. De gekozen stores moeten bestaan of via Puppet worden aangemaakt. De [S3 Strings](docker/manifests/nextcloud_s3.pp) en [Nextcloud Strings](docker/manifests/nextcloud.pp) beschrijven de configuratie en opslagkeuzes. Een ingestelde keuze weglaten behoudt de opgeslagen selectie.

Gebruik per store een eigen bucket waar alleen deze Nextcloud-installatie toegang toe heeft. Het wijzigen van primaire opslag migreert geen bestanden en kan bestaande data ontoegankelijk maken. Regel vooraf de migratie en back-ups van zowel de database als de objectdata; volg de [Nextcloud-handleiding voor primaire objectopslag](https://docs.nextcloud.com/server/stable/admin_manual/configuration_files/primary_storage.html).

Lever het secret als `Sensitive` uit beveiligde configuratie; ook access keys en proxy-URL's kunnen gevoelig zijn. Puppet schermt OCC-uitvoer af, maar beheerders kunnen geheimen in procesargumenten zien. Beperk Docker- en procestoegang en bescherm de Nextcloud-configuratie, logs en profiler. Dit geldt ook voor andere OCC-opdrachten met geheimen.

Schakel met `monitoring_enable => true` in de S3-resource de alleen-lezen controle in, zoals in het [voorbeeld](examples/docker.pp#L244). Daarvoor moet de centrale monitoring actief zijn en moet de host curl met native SigV4-ondertekening leveren. Voor HTTPS is curl 7.88 of nieuwer met OpenSSL-certificaatondersteuning nodig; oudere distributiepakketten voldoen niet altijd. De check gebruikt de bestaande Nextcloud-instellingen en bewaakt metadata-toegang en responstijd, bij HTTPS ook TLS en certificaatverval. Zorg dat de storecredentials `HeadBucket` mogen uitvoeren (`s3:ListBucket` bij AWS), of kies bewust één bestaand object voor `HeadObject` met de bijbehorende leesrechten. Een geweigerde operatie bewijst op zichzelf geen verkeerd wachtwoord.

Deze controle verstuurt geen schrijfverzoeken en downloadt geen objectinhoud. Zij meet vanaf de monitoringhost en gebruikt bij HTTPS diens CA-verzameling, dus niet het Nextcloud-netwerk of PHP's certificaatbasis. Bij `use_ssl => false` gebruikt ook de check onbeveiligd HTTP: alleen metadata-toegang en responstijd worden beoordeeld; TLS- en certificaatchecks worden overgeslagen. Een TLS-fout bij HTTPS leidt niet tot terugvallen op HTTP. Uploads, decryptie en de volledige bestandsketen worden niet getest. Niet-ondersteunde runtime- of configuratievormen geven `UNKNOWN`. Raadpleeg de [S3 Strings](docker/manifests/nextcloud_s3.pp) voor voorwaarden en overrides en de [checkinterface](docker/templates/nextcloud/check_nextcloud_s3) voor runtimegrenzen. Uitschakelen of weglaten van één monitoringregistratie behoudt de overige checks en de gedeelde executable.

Verwijder een store pas nadat je de data hebt gemigreerd en opslagselecties en gebruikers niet meer naar die store verwijzen. `ensure => absent` verwijdert alleen de registratie; buckets en objecten blijven bestaan. Alleen de Puppet-resource weghalen laat de registratie in Nextcloud staan. De [S3 Strings](docker/manifests/nextcloud_s3.pp) beschrijven alle opslagopties en het effect van weggelaten waarden.

#### GitLab Runner

Gebruik het [Runner-scenario](examples/docker.pp#L400) op een aparte host of VM voor vertrouwde builds. De manager heeft via de Docker-socket vergaande hosttoegang. Nieuwe automatische registraties geven jobs geen socket of runnerconfiguratie en activeren geen privileged mode. Controleer bij bestaande registraties zelf de executorinstellingen: Puppet beheert de inhoud van `config.toml` niet.

Beperk welke projecten de runner mogen gebruiken. De vaste jobpolicy `if-not-present` kan gecachte private images zonder nieuwe registry-autorisatie hergebruiken en houdt veranderlijke tags niet vanzelf actueel.

Maak de runner eerst in GitLab aan en volg het registratievoorbeeld met een token uit beveiligde configuratie. Een bestaand `config.toml` voorkomt registratie, ook als het beschadigd is. Volg na een onderbroken of mislukte poging eerst de [herstelinstructies bij `auto_register`](docker/manifests/gitlab_runner.pp). Na succesvolle registratie kun je het bootstrap-token en de verplichte lookup uit je profiel weghalen; de actieve registratie blijft behouden.

Een hostmapping voor de manager geldt niet voor job- en helpercontainers. Die moeten GitLab zelf kunnen bereiken voor checkout en artifact-upload. Controleer bij afwijkende DNS de [netwerkvoorwaarden bij `runner_ip`](docker/manifests/gitlab_runner.pp).

Pauzeer de runner in GitLab en laat jobs afronden vóór onderhoud of verwijdering: de eindige stoptijd kan langere jobs afbreken. Volg bij verwijdering de procedure bij `ensure` in de Strings; de GitLab-registratie en systemd-service moeten afzonderlijk worden opgeruimd.

### `gitlab`

<a id="doel-2"></a>

`gitlab` installeert GitLab EE en koppelt de omnibusservice aan lokale systemd-, monitoring- en auditvoorzieningen. `gitlab::config` beheert `/etc/gitlab/gitlab.rb` en voert `gitlab-ctl reconfigure` uit wanneer de configuratie wijzigt.

<a id="belangrijkste-eigenschappen-2"></a>

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

Het [GitLab-profiel](examples/site.pp#L150) combineert GitLab met de serverbasis. De Puppet Strings bij [`gitlab`](gitlab/manifests/init.pp) en [`gitlab::config`](gitlab/manifests/config.pp) beschrijven installatie en configuratie.

### `letsencrypt`

<a id="doel-3"></a>

`letsencrypt` installeert Certbot en beheert de algemene Certbot-instellingen. Met `letsencrypt::certificate` vraag je één certificaat voor één of meer domeinen aan via een gekozen Certbot-plugin.

<a id="belangrijkste-eigenschappen-3"></a>

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

<a id="doel-4"></a>

`mysql` installeert en configureert de MySQL-server en maakt automatisch lokale back-ups. Met defined types beheer je databases, gebruikers en rechten. De module kan samenwerken met PHP-FPM, monitoring, systemd, logrotate en auditd.

<a id="belangrijkste-eigenschappen-4"></a>

- Beheert MySQL-serverinstellingen boven op een geharde standaardset.
- Configureert `automysqlbackup` met een systemd-service en timer.
- Maakt gecomprimeerde, versleutelde back-ups.
- Registreert een MySQL-check wanneer monitoring actief is.
- Kan de pakketversie en pakketbron van `basic_settings::package_mysql` overnemen.

#### Belangrijke aandachtspunten

`automysqlbackup_password` is verplicht en heeft het type `Sensitive[String]`. Lever het back-upwachtwoord uit beveiligde configuratie, zoals in het basisvoorbeeld. Zonder deze parameter kan Puppet de catalogus niet compileren.

`root_password` accepteert `Optional[Sensitive[String]]`; de parameter `password` van `mysql::user` gebruikt `Sensitive[String]` voor wachtwoordauthenticatie. Lever deze waarden vanuit afgeschermde Hiera-data met de juiste typeconversie en geef ze zonder `.unwrap` door. `Sensitive` schermt waarden af in Puppet-uitvoer, maar versleutelt de Hiera-data niet.

Met `root_authentication => 'auth_socket'` beheer je `root@localhost` via de lokale Unix-socket als OS-gebruiker root. De plugin moet al geladen zijn. `root_password` wordt dan genegeerd en de beheerde clientconfiguraties en account-SQL bevatten geen rootwachtwoord. De `.cnf`-bestanden blijven nodig voor de gebruikersnaam, socket en serverinstellingen.

Voor expliciete wachtwoordauthenticatie kies je `root_authentication => 'caching_sha2_password'` en lever je `root_password` als `Sensitive[String]`. Beide expliciete keuzes ondersteunen MySQL 8.0 en 8.4. Zonder deze optie geldt de versieafhankelijke wachtwoordkeuze; zonder beide rootparameters blijft root onbeheerd.

Een overstap vereist werkende bestaande beheertoegang of een al werkende login met de gewenste methode. Puppet controleert de accountidentiteit en plugin, past de authenticatie aan en publiceert daarna de beheerconfiguratie. Pas externe rootclients aan bij een overstap; `auth_socket` biedt geen rootlogin via TCP of als een andere OS-gebruiker. De lokale back-upservice draait als root en gebruikt dezelfde beheerconfiguratie.

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
  root_authentication      => 'caching_sha2_password',
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

<a id="doel-5"></a>

`naemon` installeert de OpenITCOCKPIT-variant van Naemon en beheert hosts en hostgroepen. De module is bedoeld als onderdeel van een OpenITCOCKPIT-server en niet als algemene zelfstandige Naemon-module.

<a id="belangrijkste-eigenschappen-5"></a>

- Installeert `openitcockpit-naemon` nadat het OpenITCOCKPIT-pakket beschikbaar is.
- Beheert de directory met Naemon-configuratiefragmenten.
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

<a id="doel-6"></a>

`netplanio` installeert Netplan en maakt netwerkconfiguratie voor ethernet en WiFi. De module gebruikt de DHCP- en IPv6-instellingen van `basic_settings::network` wanneer die class aanwezig is.

<a id="belangrijkste-eigenschappen-6"></a>

- Installeert `netplan.io` en beheert de module-eigen configuratiebestanden.
- Ondersteunt DHCP, statische adressen, nameservers en routes per ethernetinterface.
- Ondersteunt WiFi-accesspoints en optionele interface-instellingen.
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

Het [netwerkprofiel](examples/site.pp#L138) staat in `examples/site.pp`. De Puppet Strings bij [`netplanio`](netplanio/manifests/init.pp), [`ethernet`](netplanio/manifests/ethernet.pp) en [`wifi`](netplanio/manifests/wifi.pp) beschrijven de geërfde netwerkinstellingen en interfaceconfiguratie.

### `nginx`

<a id="doel-7"></a>

`nginx` installeert en configureert de Nginx-service. `nginx::server` beheert een website of reverse proxy met TLS, security headers, locations en optionele PHP-FPM-koppeling.

<a id="belangrijkste-eigenschappen-7"></a>

- Beheert algemene Nginx-, events- en HTTP-instellingen en gebruikt strenge TLS-instellingen.
- Ondersteunt HTTP/2, HTTP/3, HTTPS-forcering en certificate chains.
- Beheert security headers en de gegevens in `security.txt`.
- Werkt samen met Certbot, PHP-FPM, monitoring, auditd, logrotate en de gedeelde systemd-targets.
- Toont een vormgegeven storingspagina in het Nederlands en Engels wanneer PHP-FPM of een proxybackend niet bereikbaar is, met een eigen pagina per website als optie.
- Controleert bij actieve OpenITCOCKPIT-monitoring de lokale certificaatketen, DNS-namen, sleutel en geldigheid van geconfigureerde HTTPS-vhosts.

#### Belangrijke aandachtspunten

Declareer `nginx` vóór de vhosts. Voeg bij een vhost of een wrapper die Nginx-configuratie wijzigt geen `require => Class['nginx']` toe: dat kan een afhankelijkheidscyclus veroorzaken. Gebruik voor aanvullende afhankelijkheden de betreffende pakket- of bestandsresource; `nginx::server` regelt zijn pakket- en configuratieafhankelijkheden zelf.

De module verwijdert Apache en neemt de Nginx-configuratie over. Controleer bestaande vhosts, document roots, certificaatrechten en gebruikte poorten. In `conf.d` worden bestanden met `.conf` binnen `http {}` ingelezen en bestanden met `.main` op hoofdniveau; geef eigen HTTP-configuratie daarom de extensie `.conf`.

Bij HTTPS met TLS 1.3 activeert de module standaard HTTP/3. Controleer daarvoor de [netwerkondersteuning](#netwerkondersteuning-controleren); zet `http3_enable => false` als de host niet aan die voorwaarden voldoet.

Gebruik voor reverse proxies bij voorkeur HTTPS naar de achterliggende applicatie. Schakel certificaatcontrole alleen uit voor een lokale of self-signed verbinding waarvoor dat echt nodig is. Gebruik HTTP alleen als de achterliggende applicatie geen TLS ondersteunt.

Bij een verbindingsfout of timeout toont Nginx de beheerde pagina uit `/etc/nginx/errors/unavailable.html` met HTTP-status 503. Voor een eigen pagina accepteert `unavailable_page` bij `nginx::server` een absoluut pad of een pad relatief aan de `docroot`, zoals in het [webvoorbeeld](examples/web.pp). Dezelfde stringparameter accepteert een `puppet://`-bron, HTML of de uitvoer van `template()` of `epp()`. HTML wordt herkend aan `<` als eerste teken na eventuele witruimte. Puppet beheert een bron of HTML als een statisch bestand per website. Zorg dat de pagina en haar opmaak zonder PHP of backend werken. De [Puppet Strings](nginx/manifests/server.pp) bevatten voorbeelden, bestandsrechten, locatie-overrides en de grenzen van deze foutafhandeling.

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

### `nvidia`

<a id="doel-8"></a>

`nvidia` installeert een expliciet gepinde open headless GPU-driver voor Ubuntu 24.04 ARM64 op een DGX Spark. De module beheert de driverselectie; `basic_settings` blijft eigenaar van pakketbronnen, kernel en headers. Docker installeert zijn Container Toolkit automatisch wanneer de driverclass vóór Docker is gedeclareerd.

<a id="belangrijkste-eigenschappen-8"></a>

- Installeert de headless DKMS-driver en `nvidia-modprobe`, zonder aanbevolen of voorgestelde pakketten.
- Laat verplichte dependencies van de gekozen driverbranch intact.
- Installeert geen host-CUDA-toolkit, desktop, volledige DGX-platformstack of applicatieframework.

#### Belangrijke aandachtspunten

Gebruik een headless Ubuntu 24.04-basis met ARM64, de NVIDIA-pakketbron en de geselecteerde kernel inclusief headers. Dit is een selectieve installatie, geen volledige DGX OS-inrichting of claim dat iedere Spark-workload is gevalideerd. Bestaande desktop- en CUDA-pakketten worden niet opgeschoond. De pakketbron moet voor de gekozen branch zowel `nvidia-driver-pinning-<branch>` als `nvidia-headless-<branch>-open` aanbieden.

Kies de driverbranch volgens de [publieke `pinning`-parameter](nvidia/manifests/init.pp). Binnen een branch worden bestaande drivers niet automatisch bijgewerkt. Beoordeel bij een branchwissel het APT-plan, controleer DKMS voor de bedoelde bootkernel en plan zo nodig een handmatige herstart. Secure Boot blijft ongewijzigd.

Controleer vóór de driverinstallatie op de doelhost het APT-pakketplan nadat de gekozen pin daadwerkelijk is geïnstalleerd. NVIDIA's [pakketindex](https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/sbsa/) toont de beschikbare pakketten. Controleer na installatie de driver en de benodigde utilities zoals beschreven bij [GPU-toegang controleren](#gpu-toegang-controleren).

#### Basisvoorbeeld

Voeg de driver tussen de bestaande platform- en Docker-declaraties in. Het volledige [Spark-hostvoorbeeld](examples/nvidia_dgx_spark.pp) bereidt beide pakketbronnen en de kernel voor:

```puppet
class { 'nvidia':
  pinning => 580,
  require => [
    Class['basic_settings::kernel', 'basic_settings::package_nvidia_dgx'],
    Exec['basic_settings_source_reload'],
  ],
}
```

De [Puppet Strings](nvidia/manifests/init.pp) beschrijven pinning, installatieopties, prerequisites en updategedrag. Alleen deze driverclass gebruiken installeert geen Docker of Container Toolkit.

#### GPU-toegang controleren

Controleer na installatie en de geplande herstart eerst `uname -r`, `dkms status` en `nvidia-smi`. De draaiende kernel moet de gekozen `-nvidia`-kernel zijn en de geladen driver moet overeenkomen met de geïnstalleerde bibliotheken. Test vervolgens expliciete GPU-toegang zonder de normale Docker-runtime te veranderen:

```sh
sudo docker info --format '{{json .Runtimes}}'
sudo docker run --rm --runtime=nvidia --gpus all \
  -e NVIDIA_DRIVER_CAPABILITIES=compute,utility ubuntu:24.04 nvidia-smi
```

Gebruik bij Compose `runtime: nvidia` en een GPU-reservering met `driver: nvidia`, `count: all` en `capabilities: [gpu]`; combineer `count` niet met `device_ids`. Het [Docker Compose GPU-voorbeeld](https://docs.docker.com/compose/how-tos/gpu-support/) beschrijft de structuur. Deze controles vereisen geen privileged-container, Docker-socketmount of gepubliceerde poort.

`nvidia-smi` bewijst apparaattoegang, maar nog geen CUDA-berekening. Voer ook een berekening uit in een voor ARM64, Spark en de gekozen driver geschikte frameworkcontainer en leg de image-digest vast. Test een gewone container, een ongewijzigde Puppet-run, noop, herstel van de runtimevermelding en het weglaten van de driverclass. Controleer GPU-toegang tevens na de normale projectroute voor `systemctl daemon-reload`: NVIDIA beschrijft voor bepaalde systemd/cgroup-combinaties [verlies van GPU-toegang](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html). Pas cgroups of hardening alleen aan wanneer de gebruikte combinatie dat aantoonbaar vereist.

### `openitcockpit`

<a id="doel-9"></a>

Met `openitcockpit::agent` installeer en configureer je de OpenITCOCKPIT-agent; `openitcockpit::server` richt de monitoringsserver in. Alleen `include openitcockpit` installeert geen onderdelen.

<a id="belangrijkste-eigenschappen-9"></a>

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

<a id="doel-10"></a>

`php8` installeert een gekozen PHP 8 minorversie en extensies. `php8::cli` beheert CLI-instellingen en Composer; `php8::fpm` en `php8::fpm_pool` beheren de FPM-service en afzonderlijke applicatiepools.

<a id="belangrijkste-eigenschappen-10"></a>

- Installeert alleen de PHP-extensies die je zelf inschakelt.
- Beheert module-eigen INI-bestanden voor CLI en FPM.
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

<a id="doel-11"></a>

`proxmox` installeert Proxmox VE op een host waarvan `basic_settings` de platformcontext heeft bepaald. De class beheert ook de overgang naar de Proxmox-kernel en verwijdert conflicterende generieke kernelpakketten.

<a id="belangrijkste-eigenschappen-11"></a>

- Installeert de Proxmox VE- en iSCSI-pakketten.
- Installeert op het ondersteunde platform de verwachte PVE-kernel.
- Plant een reboot na de kernelovergang.
- Werkt GRUB bij na packagewijzigingen.
- Verwijdert generieke Linux-imagepakketten en `os-prober` na de Proxmox-installatie.

#### Belangrijke aandachtspunten

Deze class wijzigt de kernel- en bootconfiguratie en kan daardoor een server onbruikbaar maken als er iets misgaat. Zorg voor consoletoegang, een recente back-up en een onderhoudsvenster voordat je haar toepast. Gebruik de class uitsluitend op Debian 12 (`bookworm`) met `basic_settings`.

De [platformmapping](basic_settings/manifests/init.pp) schakelt de Proxmox-pakketbron niet in, ook niet met `proxmox_enable => true`. `basic_settings` verwijdert bovendien de bron- en sleutelbestanden die zijn eigen Proxmox-helper zou gebruiken. Beheer bij gebruik van Proxmox de pakketbron in een apart profiel met andere bestandspaden.

#### Basisvoorbeeld

```puppet
include basic_settings

# The profile must provide the repository without reusing paths owned by basic_settings.
class { 'proxmox':
  require => Class['basic_settings'],
}
```

De plaats van Proxmox in een [serverprofiel](examples/site.pp#L170) staat in `examples/site.pp`; ook daar moet je de pakketbron zelf aanleveren. Zie de [Puppet Strings](proxmox/manifests/init.pp) voor de platformvoorwaarden.

### `rabbitmq`

<a id="doel-12"></a>

`rabbitmq` installeert en configureert RabbitMQ Server. Aanvullende classes en defined types beheren AMQP/TLS-listeners, de managementplugin, vhosts, exchanges, queues, bindings, gebruikers en permissies.

<a id="belangrijkste-eigenschappen-12"></a>

- Installeert Erlang en RabbitMQ en koppelt de service aan de gedeelde systemd-targets.
- Beheert het maximale aantal open bestanden, de procesprioriteit en toegestane verouderde RabbitMQ-functies.
- Ondersteunt TLS-listeners en kan plain AMQP uitschakelen zodra certificaten compleet zijn.
- Slaat gevoelige lokale gegevens op in configuratiebestanden die alleen root of de RabbitMQ-gebruiker kan lezen.
- Registreert een RabbitMQ-check met queue- en brokerdiagnose.

#### Belangrijke aandachtspunten

Regel de RabbitMQ APT-bron vóór de installatie.

Vanaf `3.0.0` heeft `rabbitmq::management::admin_password` geen ingebouwd wachtwoord meer. Lever bij ingeschakeld beheer de eigen Hiera-waarde `rabbitmq::management::admin_password` of geef `admin_password => lookup('rabbitmq::admin_password')` door. Wie bewust geen beheeraccount gebruikt, behoudt `admin_enable => false` zonder wachtwoord. Pas bestaande deployments met de oude default vóór de upgrade aan en roteer die standaardcredential.

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

<a id="doel-13"></a>

`ssh` installeert en beheert een geharde OpenSSH-server. De class schrijft de loginbanner en SSH-configuratie, ondersteunt een tweede poort en kan auditregels en een SSH-controle instellen.

<a id="belangrijkste-eigenschappen-13"></a>

- Beheert toegestane gebruikers, rootlogin en gebruikersspecifieke wachtwoordauthenticatie.
- Genereert ontbrekende hostkeys lokaal op basis van `host_key_algorithms`, met een eigen sleutel per ECDSA-curve.
- Behoudt bestaande private sleutels, herstelt ontbrekende publieke sleutels en configureert idle timeouts.
- Ondersteunt een alternatieve poort met een afzonderlijke gebruikerslijst.
- Houdt rekening met socket activation op Ubuntu-versies die dit gebruiken.
- Beheert `/etc/ssh/sshd_config.d` als module-eigen configuratieboom.

#### Belangrijke aandachtspunten

De module vervangt `/etc/ssh/sshd_config` en verwijdert onbekende bestanden in `/etc/ssh/sshd_config.d`. Bestaande instellingen in het hoofdbestand en onbeheerde drop-ins verdwijnen. Neem instellingen die je wilt behouden vooraf over in de door Puppet beheerde configuratie.

Houd een tweede root- of consoleverbinding open en controleer sleutels, `allow_users`, firewall en eventuele socket activation vóór de eerste herstart, zodat je de toegang niet verliest. Neem bestaande hostkeys vooraf over volgens [Hostidentiteit behouden](#hostidentiteit-behouden); ontbrekende sleutels worden nieuw aangemaakt.

De SSH-check koppelt actuele rootprocessen aan geregistreerde loginterminals zonder sudo of auditd nodig te hebben. Voer hem uit met zicht op alle hostprocessen. De melding toont een procesverband, geen volledige geschiedenis van gebruikerswisselingen; ook consoles en extra pseudo-terminals kunnen in de sessietelling staan. De [checkuitleg](ssh/templates/check_ssh) beschrijft de reikwijdte en uitvoer.

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

<a id="doel-14"></a>

`vnstat` installeert vnStat voor lokale verkeersregistratie en capaciteitsmonitoring. Met `vnstat::ethernet` stel je per netwerkinterface de bandbreedte en drempels voor het 95e percentiel in.

<a id="belangrijkste-eigenschappen-14"></a>

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

Eigen status en caches worden beheerd via [`basic_settings::monitoring_custom`](basic_settings/manifests/monitoring_custom.pp), volgens de [opslagafspraak van het centrale agentmodel](.tools/lint/docs/OPERATIONAL_RULES.md#monitoring-via-het-centrale-agentmodel-registreren). Vraag met `state => true` een privémap per registratie aan. Puppet maakt deze root-owned aan met modus `0700`. Templates krijgen de locatie tijdens het renderen; bij `check` en registraties van een gedeeld script via `script` krijgt de opdracht haar als `STATE_DIR` mee.

De centrale monitoringclass kiest de basislocatie bij de ingestelde `package`: `/etc/openitcockpit-agent/state` voor `openitcockpit` en `/var/cache` in de defaulttak. Met `package => 'none'` blijven registratie en aanmaak van checkmappen uitgeschakeld; `/var/cache` wordt dan niet door monitoring beheerd.

Met `template` laat je het type zelf een ERB-template laden. Daarin is de afgeleide map beschikbaar als `@state_dir`; overige invoer geef je expliciet mee via `template_data`, beschikbaar als `@template_data`. Geef met `check` een bron-URL (`puppet:///`, `file:///` of HTTPS) of de scriptinhoud door, eventueel als resultaat van `template()` of `epp()`. Gebruik `check` of `template` voor het executable. Een registratie die via `script` een bestaand executable hergebruikt geeft geen van beide mee.

```puppet
basic_settings::monitoring_custom { 'application_health':
  state         => true,
  template      => 'profile/check_application_health',
  template_data => { 'service' => 'application.service' },
}
```

De eigen template `profile/templates/check_application_health` kan de locatie bijvoorbeeld lezen met `STATE_DIR=${STATE_DIR:-<%= @state_dir %>}`. De runtimewaarde blijft zo bruikbaar wanneer een andere registratie hetzelfde executable gebruikt. De scripts verwachten een bestaande schrijfbare map. Bij los gebruik of een expliciete `STATE_DIR`/`-S`-override moet de operator die vooraf aanmaken en afschermen. Het uitschakelen van een registratie bewaart de state.

Bij `package => 'openitcockpit'` zijn de locaties onder `/etc/openitcockpit-agent/state`:

| Check | Eigen status of cache |
| --- | --- |
| APT | `apt/<source>_<version>.txt` |
| NCSC-adviezen | `ncsc_advisories/state.json` en NCSC-broncache |
| Mirth Connect | `mirth_connect/mirth_queue_state.txt` |
| Docker Compose | `docker_compose_<registratienaam>/docker_compose_<registratienaam>.state` |
| Puppet Server | `puppet_server/last_seen` |

Onderbreek bij het verplaatsen van bestaande statusbestanden alle betrokken checkaanroepen. Maak de doelmappen aan en behoud root als eigenaar en modus `0600` voor de bestanden voordat de checks worden hervat. Zo blijven de wachtrijduur en restarttellers behouden. Voor de Puppet-snapshot gelden de voorwaarden bij [Puppet Server-monitoring](#puppet-server-controleren).

Ontbrekende APT-changelogs worden bij een volgende controle van security-updates opgehaald; deze aanvullende diagnose verandert de statusberekening niet.

De [NCSC-check](basic_settings/templates/monitoring/check_ncsc_advisories) koppelt nieuws en CSAF-adviezen aan geïnstalleerde dpkg-pakketten en relevant APT-aanbod. Zij begint met de laatste 90 dagen, bewaart bevindingen en episode-/duurtellers in de eigen statemap en kan begrensd pakketlijsten verversen. `apt_current` betekent operationeel afgehandeld volgens de NCSC/APT-policy; een CVE-reparatie is daarmee niet onafhankelijk bewezen. `basic_settings::packages` registreert de check automatisch wanneer monitoring actief is, met de standaardwaarden van het script. De hoofdclass declareert `packages` al. Controleer bij uitrol ook de bestaande ontvangers, herhaalintervallen en acknowledgements: een nieuwe CVE kan dezelfde exitcode houden. Voor de uitvoeringsafspraken zie [monitoring en dataverzameling](.tools/lint/docs/OPERATIONAL_RULES.md#monitoring-onafhankelijk-van-de-waargenomen-taak-houden).

Algemene Linux-metingen gebruiken waar mogelijk de actieve kernelstatus. Specifieke checks behouden hun toepassingsgebied: APT beoordeelt APT-updates, audit gebruikt de actieve auditregels en de beschikbare historie, en de Nginx-certificaatcheck beoordeelt lokale bestanden. Systemd-checks vereisen een aantoonbaar actieve systemd-manager. Zonder geschikte meetbron of bij een niet-toepasbare controle volgt UNKNOWN (exitcode 3) met de reden; ontbrekende aanvullende diagnosegegevens bewijzen geen storing. Dit verbreedt de platformondersteuning van de Puppet-modules zelf niet.

Wanneer de aanroepende class `systemd_enable = true` doorgeeft, verwachten de monitoringtemplates ook een draaiende systemd-manager: ontbreken geeft CRITICAL, een onleesbare status UNKNOWN. Bij `false` renderen daemonchecks direct hun eigen `ps`-controle; de systemd-helper en systemd-diagnostiek worden niet opgenomen. Alleen zonder deze variabele kiezen zij automatisch op basis van de runtime, met dezelfde procescontrole als fallback. Nftables controleert de geladen kernelregels omdat er geen permanent daemonproces is. De monitoringregistratie borgt de packages voor het gekozen pad. De aanvullende Puppet Server-check kiest zijn meetmethode steeds op basis van het actieve init-systeem en behoudt daarbij de bestaande afzonderlijke servicecheck.

Servicecontroles verwachten standaard dat de bewaakte service bestaat en actief is. Een ontbrekende vereiste systemd-unit geeft CRITICAL. Een expliciet optionele aanvullende meting kan een ontbrekende unit toestaan; onleesbare status blijft onbekend en een aanwezige unit wordt nog steeds beoordeeld.

Monitoringtemplates delen de systemd-inspectie via een tijdens compilatie ingevoegd [helperfragment](basic_settings/templates/monitoring/_systemd_service_status). Hiervoor moet `basic_settings` op het modulepath staan; je hoeft de class `basic_settings` niet te declareren of een helperbestand op de host te installeren. De registratie blijft verantwoordelijk voor de runtimevereisten van het gegenereerde script. De algemene ontwerpafspraken staan bij [gedeelde helpers](.tools/lint/docs/OPERATIONAL_RULES.md#shellhelpers-op-een-herkenbare-taak-afbakenen), [runtimebronkeuze](.tools/lint/docs/OPERATIONAL_RULES.md#actuele-hosttoestand-uit-kernelgegevens-bepalen) en [inspectiestatus](.tools/lint/docs/OPERATIONAL_RULES.md#vastgestelde-afwijkingen-en-onvolledige-inspecties-onderscheiden).

Alle onderstaande eigen checks gebruiken ook de tijdens compilatie ingevoegde [presentatiehelper](basic_settings/templates/monitoring/_output). De [centrale uitvoernorm](.tools/lint/docs/OPERATIONAL_RULES.md#pipes-en-lege-regels-in-lange-uitvoer-veilig-maken) beschrijft de onderwerpblokken, records, witruimte en veilige dynamische tekst. Nieuwe of aangepaste plugins nemen deze helper op; metingen, prioriteiten, exitcodes en perfdata blijven in de check.

De eerder statisch uitgerolde checks worden nu vanuit `templates/` gerenderd. Registraties, CLI-opties en paden op de host blijven gelijk. Eigen profielen die een hieronder genoemde check rechtstreeks vanuit `puppet:///modules/…` uitrollen, moeten `template => 'module/checknaam'` bij `monitoring_custom` gebruiken, of `content => template('module/checknaam')` bij een `file`-resource. Voor de basischecks is het templatepad `basic_settings/monitoring/checknaam`. Voor de Docker-checks gebruik je `docker/compose/check_compose` en `docker/nextcloud/check_nextcloud_s3`. Kopieer geen ongerenderde template naar een host. `basic_settings` moet op het modulepath staan; de helper voegt geen runtimebestand of Ruby-/Python-afhankelijkheid toe.

Dit vereenvoudigde voorbeeld toont letterlijke long output; de waarden zijn illustratief:

```text
Connections:
- Current: 10 / 1000
- Historical peak: 13 / 1000
- Running threads: 2

Workload:
- Uptime: 27923 s
- Slow queries: 0

Interpretation:
- Current connections and the historical peak are evaluated separately.
- The slow-query count is cumulative.
```

- [`check_apt`](basic_settings/templates/monitoring/check_apt)
- [`check_audit`](basic_settings/templates/monitoring/check_audit)
- [`check_compose`](docker/templates/compose/check_compose)
- [`check_eset`](basic_settings/templates/monitoring/check_eset)
- [`check_gitlab`](gitlab/templates/check_gitlab)
- [`check_memory_pressure`](basic_settings/templates/monitoring/check_memory_pressure)
- [`check_mirth_connect`](openitcockpit/templates/agent/check_mirth_connect)
- [`check_mysql`](mysql/templates/check_mysql)
- [`check_network`](basic_settings/templates/monitoring/check_network)
- [`check_nextcloud_s3`](docker/templates/nextcloud/check_nextcloud_s3)
- [`check_nginx_cert`](nginx/templates/check_nginx_cert)
- [`check_nftables`](basic_settings/templates/monitoring/check_nftables)
- [`check_npm_audit`](basic_settings/templates/monitoring/check_npm_audit)
- [`check_puppet_agent`](basic_settings/templates/monitoring/puppet/check_agent)
- [`check_puppet_server`](basic_settings/templates/monitoring/puppet/check_server)
- [`check_rabbitmq`](rabbitmq/templates/check_rabbitmq)
- [`check_ssh`](ssh/templates/check_ssh)
- [`check_systemd_config`](basic_settings/templates/monitoring/check_systemd_config)
- [`check_systemd_service`](basic_settings/templates/monitoring/check_systemd_service)
- [`check_systemd_timer`](basic_settings/templates/monitoring/check_systemd_timer)
- [`check_systemd_timesyncd`](basic_settings/templates/monitoring/check_systemd_timesyncd)
- [`check_usb`](basic_settings/templates/monitoring/check_usb)
- [`check_vnstat_interfaces`](vnstat/templates/check_vnstat_interfaces)

## Uitgebreide voorbeelden

De map `examples/` bevat grotere, herkenbare scenario's. Houd environment-specifieke waarden in profielen of Hiera en neem voorbeeldgeheimen nooit letterlijk over.

- [`examples/site.pp`](examples/site.pp): Gecombineerde basisinstellingen, webserver, PHP, SSH, Docker, MySQL en profielopbouw.
- [`examples/docker.pp`](examples/docker.pp): Compose, monitoring, Nginx-proxy, Authentik, Twenty, vLLM, Nextcloud AIO met Talk-AI en meerdere S3-objectstores en een aparte GitLab Runner-host met eenmalige registratie.
- [`examples/web.pp`](examples/web.pp): Nginx, PHP-FPM, Let's Encrypt, TLS, security headers en reverse proxies.
- [`examples/data-services.pp`](examples/data-services.pp): MySQL, RabbitMQ en vnStat.
- [`examples/monitoring.pp`](examples/monitoring.pp): OpenITCOCKPIT-agent, eigen checks en monitoringinstellingen.
- [`examples/hosts.pp`](examples/hosts.pp): Beheer van `/etc/hosts` via de hoofdclass, networkclass en losse entries.
- [`examples/nvidia_dgx_spark.pp`](examples/nvidia_dgx_spark.pp): Headless DGX Spark / ASUS Ascent GX10 met Ubuntu 24.04 ARM64, NVIDIA-pakketbronnen en kernel, gepinde GPU-driver, automatische Docker-GPU-integratie en vLLM met twee HTTPS-routes.

## Contributie

Pull requests en meldingen zijn welkom. Begin bij [CONTRIBUTING.md](CONTRIBUTING.md) voor voorbereiding, wijzigingsscope, veilig werken, review, versiebeleid en oplevering. Daar vind je de directe leesroutes naar [TESTS.md](TESTS.md), de code-, documentatie- en operationele normen en de [toolhandleidingen](.tools/README.md#gedeeld-toolingonderhoud). Menselijke ontwikkelaars en agents gebruiken dezelfde inhoudelijke afspraken.

Richt de [ontwikkelomgeving](.tools/README.md#installatie) in en volg de [verplichte controlevolgorde](TESTS.md#controlevolgorde-en-verplichte-eindcontroles), inclusief de secretsvoorcontrole. De toolhandleidingen beschrijven de concrete commando's en rapporten; een geslaagde `bundle exec rake test` vervangt de overige eindcontroles en functionele validatie niet.
