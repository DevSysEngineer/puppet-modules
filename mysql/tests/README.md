# MySQL-catalogusscenario's

## Inhoudsopgave

- [Versie- en bronkeuze](#versie--en-bronkeuze)

## Versie- en bronkeuze

`standalone.pp` bewaakt de ongewijzigde 8.0-default zonder serverbasis. `with_basic_settings.pp` gebruikt een actieve 8.4-bron en controleert daarmee ook het bestaande LTS-pad.

De map `manifests/mysql97/` voegt drie verschillende selectiepaden toe: 9.7 zonder bronhelper, een actieve 9.7-bron met de standaardversie van de MySQL-class, en een uitgeschakelde bronhelper met een expliciete 9.7-keuze. De scenario's gebruiken respectievelijk impliciet rootwachtwoordbeheer, expliciete caching-SHA2 en socketauthenticatie. Het zelfstandige scenario neemt ook het verwijderen van een native-account zonder wachtwoord en het intrekken van grants mee.

De gedeelde facts zijn compilatie-invoer; zij verklaren het gekozen platform niet geschikt voor een MySQL-installatie. Deze scenario's bewijzen niet dat de server start, dat accounts na herhaalde toepassing de gewenste toestand behouden of dat back-ups kunnen worden hersteld. Negatieve invoer en functionele controles volgen de [tijdelijke validatieroute](../../TESTS.md#onderwerpgebonden-validatie).
