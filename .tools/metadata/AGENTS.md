# Metadata Development Instructions

## Scope

Read the [repository instructions](../../AGENTS.md), [tooling instructions](../AGENTS.md), and [metadata README](README.md). This component owns own-metadata selection, validation, synchronization, its CLI and reports.

## Maintenance And Verification

- Review selection changes against [module selection and project boundaries](README.md#metadata-in-modulemappen) and the [root contract](README.md#metadata-in-de-projectroot). Verify both repository and consumer layouts, explicit module locations, exclusions, symlinks, modules without manifests, projects without modules and imported project boundaries.
- Keep version validation and synchronization subordinate to the repository [release policy](../../AGENTS.md#versioning-and-releases). Test the [version-source contract](README.md#versiebron-en-rapportage), including independent consumer versions, invalid or missing sources and execution without Git. Do not make this tool choose releases or obtain a version from metadata or Git.
- For recovery changes, verify the [safe synchronization contract](README.md#metadata-automatisch-herstellen): actual and partial fixes, preservation of unrelated fields and dependencies, refusal when content cannot safely be recovered, and idempotence. Keep incomplete metadata visible.
- Update affected README contracts and the [metadata tests](README.md#exitcodes-en-tests) together. Verify CLI argument errors, findings, report and write failures, and independent installed-gem use without Puppet-lint, OpenVox or RuboCop.
