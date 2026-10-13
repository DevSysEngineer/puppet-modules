# Tooling Development Instructions

## Scope And Reading Route

Read the [repository instructions](../AGENTS.md) and this file before maintaining tooling, then open the affected component instructions below and its README. These instructions also apply to tooling integration in the root Gemfile, Rakefile, `.github/`, and consumer examples. Follow the root instruction chain without rereading unchanged sources already read in this task.

| Component | Responsibility | Development instructions |
| --- | --- | --- |
| `lint` | Puppet-lint checks, profiles, detection, autofix and lint documentation | [Lint](lint/AGENTS.md) |
| `metadata` | Own-metadata selection, validation and safe synchronization | [Metadata](metadata/AGENTS.md) |
| `module-dependencies` | Native module selection and declared dependency analysis | [Module dependencies](module-dependencies/AGENTS.md) |
| `repository-checks` | Repository documentation, CI configuration, distribution integration and test layout | [Repository checks](repository-checks/AGENTS.md) |
| `ruby-lint` | Native RuboCop integration and shared Ruby profile | [Ruby lint](ruby-lint/AGENTS.md) |
| `secrets` | Local sensitive-data detection, prepared analysis, controlled writes and safe review | [Sensitive data](secrets/AGENTS.md) |
| `shared` | Actually shared runtime behavior and repository test support | [Shared library](shared/AGENTS.md) |
| `validate` | Native parser validation and report integration | [Validator](validate/AGENTS.md) |

Read multiple local instruction files when a change crosses their responsibilities. For a shared interface, identify the actual callers and read their instructions and contracts as well as shared's. Apply the [general code rules](lint/docs/CODE_RULES.md#algemene-ontwerpregels) to every tooling component. Reading code norms under `lint/docs/` does not itself require linter development instructions; editing those norms does.

The [tooling README](README.md) owns installation, package selection, modulepath settings, CLI and reporting contracts, CI usage, distribution, and joint test commands. This file governs maintenance of those contracts; [shared's instructions](shared/AGENTS.md) govern the shared library and test support specifically.

## Responsibility And Integration Review

- Apply the repository's [reuse and shared abstraction review](../AGENTS.md#reuse-and-shared-abstractions) and the [general design criteria](lint/docs/CODE_RULES.md#algemene-ontwerpregels) across affected tools and their actual consumers. Review executable entry points, command handling, tool-owned processing and shared runtime behavior against the [responsibility boundaries](README.md#verantwoordelijkheden-gescheiden-houden) and [CLI and reporting contract](README.md#cli-en-rapportage), including independent installation and consuming projects.
- For changes to task entry points, verify that each distinct user task has a clear subcommand within the tool's single executable and delegates substantive behavior to its owning library. Apply the repository consolidation rule when replacing a workflow; consumers must migrate instead of retaining parallel routes. Update installed executables, lint coverage, relevant integrations and consumer migration together; do not introduce another implementation behind a new command.
- Keep each independent control's CLI, runtime dependencies, configuration, corrections, reports and behavior tests with its owner. Review package boundaries against the [package contracts](README.md#pakketten-en-commandos); a shared development bundle does not justify dependencies between independent tools or a new runtime package for repository checks.
- Keep development dependencies and orchestration in the root Gemfile and Rakefile. Use the same Bundler, Rake and native CLI routes locally and in CI; do not add a second development bundle inside a toolgem.
- When moving responsibilities, update consumer installation, CI, reports and documentation together. Keep shared settings, tasks and report locations neutrally named and tool-specific settings with their owner.
- Verify the CLI and reporting contract with tool behavior tests: successful and rejected checks with and without reports, recovery without a report where supported, no report changes without a request, and preserved failure status on reporting errors. Check the installed CLI and update examples, CI and consumer migration together when a command changes.

## Tool Test Structure

- Apply the tooling guide's [test location and task contracts](README.md#gezamenlijke-tooltests) when adding or moving repository tool tests. The repository-wide [test restrictions](../AGENTS.md#test-scope) remain applicable.
- Apply the repository-wide [test scenario review](../AGENTS.md#test-scenario-review) when adding or changing tool tests.
- Correct misplaced tests by moving them to the owning tool. Do not broaden test discovery or document an exception merely to accommodate their existing placement.
- Use fixtures and supporting functionality in tool tests only when they help verify a tool contract.
- Keep tool-specific helpers and fixtures with that tool's tests.
- Introduce shared test helpers only when multiple tools actually need them.

### Test Structure Maintenance

- Update test discovery, path resolution, task definitions, CI, and affected documentation together when changing the test structure.
- Remove superseded test directories, duplicate files, unused support data, obsolete tasks, and stale references after migration.
- Preserve relevant regression coverage.
- Report any intentionally removed tests.
- Verify that the expected tests are discovered and executed; a successful command with no applicable tests is not sufficient validation.

## CI Jobs And Reports

- Apply and verify the [CI and reporting procedures](README.md#ci-van-deze-repository) when changing tooling or pipelines. Preserve the documented secrets gate before independent diagnostic jobs, and preserve selections, thresholds, exit codes and report publication contracts.
- Review changed reporters and CI calls against the [job log contract](README.md#joblogs). Inspect representative console output for a clean run, one finding among many clean inputs, multiple findings within and across inputs, and incomplete execution combining findings with multiple execution errors. Keep these cases in the owning tool's behavior tests and record the manual readability review; use of the shared console alone does not establish compliance. Keep execution and presentation responsibilities separate and validate the affected tool and repository integration tests.

## Tooling Documentation

- Keep general coding principles in [CODE_RULES.md](lint/docs/CODE_RULES.md); link to them from component documentation without restating the norm. Keep public installation, usage, configuration, concrete architecture, interfaces, exit codes, reports, examples and supported integrations in the owning README. Keep maintenance obligations in the narrowest applicable instruction file and link to the public contract instead of copying it.
- The shared tooling, shared library, metadata, Ruby-lint, repository-checks, validator and dependency-tool READMEs own their separate interfaces and usage procedures; they must not duplicate lint norms. Follow [lint documentation maintenance](lint/AGENTS.md#lint-documentation-maintenance) for the four central lint documents and their limits.
- Keep tool-specific test instructions in the owning tooling guide. Do not create separate test READMEs.
- Review packaged documentation links when relocating information. Normal use must remain understandable from the distributed README and rule documents; links to development instructions require the corresponding checkout. Change gem contents only when a supported distribution route requires it, preserving package boundaries and licenses.
