# Tooling Agent Instructions

## Scope And Reading Route

Read the [repository instructions](../AGENTS.md), including their inspection bootstrap, and this file before maintaining tooling. Actually read and apply the [shared tooling README](README.md), especially [maintenance and integration](README.md#gedeeld-toolingonderhoud), alongside [CONTRIBUTING](../CONTRIBUTING.md) and [TESTS](../TESTS.md). This route also covers root Gemfile, Rakefile, `.github/` and consumer examples.

Open each affected component's local instructions below and read its README. For shared interfaces, identify actual callers and read their instructions and contracts too. Follow the parent chain without rereading unchanged material already read in this task.

| Component | Responsibility | Development instructions |
| --- | --- | --- |
| `catalog` | Fixed catalog compilation scenarios and runner | [Catalog](catalog/AGENTS.md) |
| `lint` | Puppet-lint checks, profiles, detection, autofix and lint documentation | [Lint](lint/AGENTS.md) |
| `metadata` | Own-metadata selection, validation and safe synchronization | [Metadata](metadata/AGENTS.md) |
| `module-dependencies` | Native module selection and declared dependency analysis | [Module dependencies](module-dependencies/AGENTS.md) |
| `repository-checks` | Repository documentation, CI configuration, distribution integration and test layout | [Repository checks](repository-checks/AGENTS.md) |
| `ruby-lint` | Native RuboCop integration and shared Ruby profile | [Ruby lint](ruby-lint/AGENTS.md) |
| `secrets` | Local sensitive-data detection, prepared analysis, controlled writes and safe review | [Sensitive data](secrets/AGENTS.md) |
| `shared` | Actually shared runtime behavior and repository test support | [Shared library](shared/AGENTS.md) |
| `syntax` | Native parser validation and report integration | [Syntax](syntax/AGENTS.md) |


Apply the [general code norms](lint/docs/CODE_RULES.md#algemene-ontwerpregels) to every component and the applicable documentation and operational norms selected by root. Applying norms under lint does not itself require lint development instructions; editing those norms does. Shared maintenance belongs to the shared README, and component maintenance to the owning README.
