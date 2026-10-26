# basic_settings catalog scenarios

These scenarios compile the public `basic_settings` class with synthetic facts and the real module dependencies. The [catalog runner](../../.tools/catalog/README.md) discovers this directory automatically. Each facts file is combined with each scenario manifest; no central registration is needed.

## Contents

- [Contents](#contents)
- [Scenarios](#scenarios)
- [Running and maintaining the tests](#running-and-maintaining-the-tests)

## Scenarios

| Facts | Default configuration | Monitoring enabled |
| --- | --- | --- |
| [Debian 13](facts/debian-13.json) | [default.pp](manifests/default.pp) | [monitoring.pp](manifests/monitoring.pp) |
| [Ubuntu 24.04](facts/ubuntu-noble.json) | [default.pp](manifests/default.pp) | [monitoring.pp](manifests/monitoring.pp) |

Both manifests load development through the public class. The default scenario uses the standard configuration without a monitoring backend. The monitoring scenario selects `openitcockpit`, including the NCSC check and its Python dependency. A duplicate declaration of `Package['python3']` causes these monitoring compilations to fail.

The facts describe an amd64 Linux VM with two processors and eight GiB of memory. The runner does not collect facts from the machine running the tests or apply the compiled resources.

## Running and maintaining the tests

Use the repository's `catalog:compile` task after the Puppet inspection gate, following the [execution instructions](../../.tools/catalog/README.md#uitvoeren). The same runner supports a checkout imported by a consumer project. Dependencies must be available on the selected modulepath, including the repository's submodules.

Maintain facts and manifests here when supported configurations require additional coverage. A new change does not automatically require a new scenario. Compilation covers the combinations in this directory; exact resource values, standalone classes, declaration order and runtime behavior may need additional validation under the [test policy](../../TESTS.md#scenarios-kiezen).
