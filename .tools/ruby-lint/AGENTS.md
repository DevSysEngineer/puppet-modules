# Ruby Lint Development Instructions

## Scope

Read the [repository instructions](../../AGENTS.md), [tooling instructions](../AGENTS.md), and [Ruby-lint README](README.md). This component maintains the shared RuboCop profile and native CLI and formatter integration.

## Maintenance And Verification

- Preserve the [native usage and correction workflow](README.md#ruby-code-controleren) and [consumer profile integration](README.md#ruby-controleren-in-een-ander-project). Do not add a project CLI wrapper, second formatter or dependencies on Puppet, lintplugins or shared.
- Review profile changes against both repository and consumer selection, including hidden tooling, excluded dependencies and templates. Keep standard RuboCop rules and new checks enabled without generating a suppression list for existing findings.
- Update affected usage and [test contracts](README.md#onderhoud-en-tests) together. Verify independent installation with its own consumerbundle, inherited profile use, clean and failing Ruby input and native JUnit. Preserve native diagnostics, annotations and exit codes when changing CI presentation; involve repository checks for workflow integration.
