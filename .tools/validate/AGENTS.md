# Parser Validator Development Instructions

## Scope

Read the [repository instructions](../../AGENTS.md), [tooling instructions](../AGENTS.md), and [validator README](README.md). This component owns parser validation and report integration; repository task integration also requires repository-checks instructions.

## Maintenance And Verification

- Preserve the [native runtime and package boundaries](README.md#runtime-en-packagegrenzen): parser execution through `RbConfig.ruby` and `Gem.bin_path('openvox', 'puppet')`, separate process arguments without shell interpretation, and the same API and CLI results. Do not add a syntaxparser, catalog application or lint configuration dependency.
- Verify changes against [manifest selection](README.md#puppet-manifests-valideren) and [native validation and exit contracts](README.md#exitcodes-van-validate-junit), including empty selections, invalid inputs, duplicate and unusual paths, warnings, parser failures, continuation after a failure, startup or signal errors, source preservation and report-writing failures.
- Update affected README contracts and [tool tests](README.md#ontwikkelen-en-testen) together. Verify independent packaged and path installation without lint or projectmetadata, and the joint Git-source route with its documented local override. Keep test support and development gems outside the runtime package.
- Keep full first-party syntax validation separate from synthetic tooltests and their dependencies, as required by the root test scope. Review changes to root or consumer Rake selection with repository checks.
