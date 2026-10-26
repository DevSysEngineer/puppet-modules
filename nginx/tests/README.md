# nginx catalog scenarios

These minimal scenarios check whether the public `nginx` class compiles on its own and together with the server baseline. The [catalog guide](../../.tools/catalog/README.md#voorbeeld-nginx-alleen-en-samen) explains the same pattern for other modules. Follow the [module test policy](../../TESTS.md#moduletests-eenvoudig-houden) when considering additional coverage.

## Contents

- [Contents](#contents)
- [Scenarios](#scenarios)
- [Execution](#execution)

## Scenarios

| Manifest | Compilation coverage |
| --- | --- |
| [standalone.pp](manifests/standalone.pp) | Loads `nginx` with defaults, without declaring the `basic_settings` main class. |
| [with_basic_settings.pp](manifests/with_basic_settings.pp) | Loads `basic_settings` before `nginx` to catch conflicts in their combined resource declarations and dependencies. |

Both scenarios use one [synthetic Debian 13 facts file](facts/debian-13.json), including the facts needed by the server baseline. The standalone scenario still needs the module sources and their dependencies on the modulepath: nginx uses shared defined types from `basic_settings` internally. It does not require declaring that module's main class.

The combined scenario belongs here because it adds nginx to the baseline. The baseline's own tests already cover its configuration without nginx. No vhosts, certificate overrides or additional application modules are needed for these two entry-point checks.

## Execution

Run the existing `catalog:compile` task after the Puppet inspection gate, following the [execution instructions](../../.tools/catalog/README.md#uitvoeren). The runner automatically finds both manifests and combines each with the facts file. No runner or CI registration is required. The same discovery applies to an imported checkout on a consumer's modulepath.

Success means that both catalogs compile. The runner does not apply them: it does not install nginx, start a webserver or send HTTP requests.
