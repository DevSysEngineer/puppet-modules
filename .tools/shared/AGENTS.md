# Shared Library Development Instructions

## Scope

Read the [repository instructions](../../AGENTS.md), [tooling instructions](../AGENTS.md), and [shared README](README.md). This component owns shared runtime functionality and repository test support; general tooling maintenance belongs to the parent instructions.

## Maintenance And Verification

- Add shared code only when concrete consumers need the same technical behavior. Keep metadata correction, selection policy, lintchecks, parser orchestration and dependency findings with their tools, following the [dependency boundaries](README.md#afhankelijkheden-en-onderhoud).
- For changes to [runtime interfaces](README.md#runtimecontracten), identify every affected caller, read its local instructions and contract, and verify its CLI and supported distribution routes. Preserve caller-owned selection, outcome and exit semantics, load-time isolation and the lint JUnit compatibility shim.
- Keep [test support](README.md#testondersteuning) outside the runtimegem. Verify one-time bootstrap and reporter initialization, opt-in JUnit, preservation of other reports and failure status on report-writing errors. Keep lint configuration and expectations in the lint helper.
- Maintain package-test helpers against the existing offline consumer route with separate stdout, stderr and process status. Use [shared tests](README.md#testondersteuning) for library and bootstrap contracts; repository navigation, workflow and test layout assertions belong to repository checks.
