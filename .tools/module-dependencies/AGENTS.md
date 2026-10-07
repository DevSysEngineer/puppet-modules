# Module Dependency Development Instructions

## Scope

Read the [repository instructions](../../AGENTS.md), [tooling instructions](../AGENTS.md), and [dependency README](README.md). This component owns dependency analysis against native module selection, modulepath handling and its own CLI and reports.

## Maintenance And Verification

- Preserve the [native selection and coverage contract](README.md#native-selectie-en-dekking). Test first-module choice, reversed paths, Forge identities, symlinks, shadowed and unusable metadata, external requesters, native ranges and empty scans. Do not introduce a separate resolver or select a later module to satisfy a dependency.
- Review modulepath changes with the [shared interface](../shared/README.md#runtimecontracten) and its instructions. Keep dependency selection distinct from lint source-reading limits and metadata selection; keep parser validation and metadata correction with their own tools.
- Verify [root dependency handling](README.md#rootdependencies) from the active working directory, without requiring metadata-tool configuration or VERSION. Test the [runtime boundaries](README.md#runtime-en-veiligheidsgrenzen), including restoration of personal settings after in-process use.
- Update affected contracts and [tool tests](README.md#ontwikkelen-en-testen) together. Preserve native comparisons using `RbConfig.ruby` and `Gem.bin_path('openvox', 'puppet')`, with separate stdout, stderr and status. Verify findings versus execution errors, coverage, report replacement, escaping and independent distribution without lint, RuboCop or development gems. Actual checkout conflicts belong to the separate dependency scan, never a deliberately failing tooltest.
