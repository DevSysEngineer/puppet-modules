# Ruby-lint

`project-tools-ruby-lint` levert RuboCop en het gedeelde profiel `config/rubocop.yml`. Gebruik de native `rubocop`-CLI en zijn JUnit-formatter. Het pakket installeert geen Puppet, lintplugins of shared-library en heeft geen eigen wrapper. Kies je gembron volgens de [installatiehandleiding](../README.md#importeren-en-distribueren).

Voor links buiten deze gem lees je de handleiding in de bijbehorende repositorycheckout.

## Inhoudsopgave

- [Inhoudsopgave](#inhoudsopgave)
- [Ruby-code controleren](#ruby-code-controleren)
- [Ruby controleren in een ander project](#ruby-controleren-in-een-ander-project)
- [Onderhoud en tests](#onderhoud-en-tests)

## Ruby-code controleren

RuboCop controleert de eigen Ruby-code op de [Ruby-stijlregels van RuboCop](https://docs.rubocop.org/rubocop/). De [projectconfiguratie](../../.rubocop.yml) neemt ook de verborgen map `.tools/` mee, naast onder meer de Gemfile, het Rakefile en Ruby-code in modules. Vendored submodules en geïnstalleerde gems vallen buiten de scan. Templates zijn eveneens uitgesloten: render die eerst en valideer de resulterende code afzonderlijk.

RuboCop wordt met `bundle install` geïnstalleerd. Voer de scan uit vanuit de repositoryroot:

**Werkmap:** Repositoryroot. **Shell:** POSIX shell. **Vereisten:** Ontwikkelbundle. **Invoer:** Eigen Ruby-code via .rubocop.yml. **Wijzigt bestanden:** Alleen cache. **Verwacht resultaat:** Exitcode 0 zonder offenses.

```sh
bundle exec rubocop --config .rubocop.yml
```

De configuratie gebruikt de standaardregels en schakelt nieuwe checks in. Er is geen gegenereerde uitzonderingenlijst voor bestaande meldingen. Daardoor geeft de scan een foutcode zolang er afwijkingen zijn. Herstel meldingen binnen de scope van je wijziging en vermeld de resterende meldingen in de review; een uitgevoerd commando betekent nog geen geslaagde controle.

Begin met een gewone scan voordat je automatisch corrigeert. Kies daarna de bestanden die bij je wijziging horen. Bijvoorbeeld:

**Werkmap:** Repositoryroot. **Shell:** POSIX shell. **Vereisten:** Ontwikkelbundle en voorafgaande RuboCop-scan. **Invoer:** De benoemde Ruby-bron voor fix; daarna volledige checks. **Wijzigt bestanden:** Ja, de geselecteerde Ruby-bron en testrapporten. **Verwacht resultaat:** Veilige correctie gevolgd door hercontrole en diffreview.

```sh
bundle exec rubocop --config .rubocop.yml --force-exclusion --autocorrect .tools/lint/lib/project_lint/ast.rb
bundle exec rubocop --config .rubocop.yml
bundle exec rake test
git diff --check
git diff
```

`--force-exclusion` respecteert de uitgesloten paden ook wanneer je een bestand expliciet opgeeft. [`--autocorrect`](https://docs.rubocop.org/rubocop/usage/autocorrect.html) gebruikt alleen correcties die RuboCop als veilig aanmerkt. Beoordeel de diff en voer de tests opnieuw uit. Controleer gewijzigde Ruby-code in modules ook met tijdelijke functionele controles buiten de repository; de tooltests dekken dat gedrag niet. `--autocorrect-all` bevat ook mogelijk gedragsveranderende correcties en hoort niet bij deze veilige correctiestap.

RuboCop beoordeelt statische eigenschappen zoals opmaak, mogelijke fouten en complexiteit. De tooltests en inhoudelijke review blijven nodig om vast te stellen of de gecontroleerde Ruby-code correct werkt.

## Ruby controleren in een ander project

Bundler installeert RuboCop automatisch als dependency van `project-tools-ruby-lint`. Maak in de hoofdmap van je eigen project een `.rubocop.yml` die het gedeelde profiel erft met de [native `inherit_gem`-optie](https://docs.rubocop.org/rubocop/latest/configuration.html):

```yaml
inherit_gem:
  project-tools-ruby-lint: config/rubocop.yml

inherit_mode:
  merge:
    - Include
    - Exclude

AllCops:
  Include:
    - '.tools/**/*.rb'
    - '.tools/**/*.rake'
    - '.tools/**/*.gemspec'
  Exclude:
    - 'global-modules/**/*'
    - 'vendor/**/*'
    - '**/templates/**/*'
```

Het gedeelde profiel gebruikt de standaardregels van RuboCop en schakelt nieuwe checks in. Met `inherit_mode` voeg je de eigen bestandsselectie toe aan de standaardselectie, zodat ook gewone Ruby-bestanden, Gemfile en Rakefile gecontroleerd blijven. De scan neemt eigen tools onder `.tools/` mee en slaat `global-modules/` over. Pas de uitgesloten dependency- en templatemappen aan je eigen project aan; templates valideer je na renderen. De Ruby-configuratie laadt geen Puppet-checks. Voer vanuit je projectroot de gewone CLI uit:

**Werkmap:** Consumerroot. **Shell:** POSIX shell. **Vereisten:** Eigen bundle en de hierboven getoonde .rubocop.yml. **Invoer:** Eigen Ruby-code. **Wijzigt bestanden:** Alleen cache. **Verwacht resultaat:** RuboCopstatus 0 zonder offenses.

```sh
bundle exec rubocop --config .rubocop.yml
```

Voor veilige lokale correcties volg je de [RuboCop-werkwijze](#ruby-code-controleren), met de `.rubocop.yml` van je eigen project. Voor console-uitvoer en JUnit XML uit één uitvoering gebruik je de [rapportaanroep](../README.md#rapporten-en-artifacts-in-je-project). Voer de Ruby-scan ook in je eigen CI uit. Puppet-lint en RuboCop hebben afzonderlijke commando's: een Puppet-lintscan voert geen Ruby-scan uit.

## Onderhoud en tests

De gem bevat het profiel, deze README en de licentie. Native RuboCop bepaalt de exitcodes en maakt JUnit met `--format junit --out REPORT.xml`; de [gezamenlijke gids](../README.md#rapporten-en-artifacts-in-je-project) beschrijft CI en rapportpaden. Exitcode 0 is schoon, 1 betekent offenses en uitvoerings- of configuratiefouten leveren een foutstatus op.

Voer vanuit de repositoryroot `bundle exec rake test:ruby_lint` uit voor onafhankelijke installatie, profielgebruik, schone/falende Ruby-invoer en native JUnit. De tests gebruiken een eigen consumerbundle zonder Puppet-tools. `bundle exec rake test` controleert alle tools samen.
