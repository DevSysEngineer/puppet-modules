# Sensitive Data Tool Development Instructions

## Scope

Read the [repository instructions](../../AGENTS.md), [tooling instructions](../AGENTS.md), and [scanner README](README.md). This component owns local secret detection, source coverage, redaction boundaries and metadata-only reporting.

## Maintenance And Verification

- Verify each supported detection rule with synthetic positive, negative and multiline inputs. Keep value findings distinguishable from sensitivity indicators and document unsupported constructs at the [pattern contract](README.md#patronen-en-beperkingen).
- Exercise every disclosure channel when changing detection or errors: stdout, stderr, JSON, JUnit, paths, Ruby debug mode and redacted copies. Never expose exception messages or source excerpts; validate that incomplete inspection withholds copies.
- Handle missed values and unsafe output through the [repository incident requirements](../../AGENTS.md#disclosure-incidents) and [scanner recovery procedure](README.md#gemiste-gegevens-of-een-fout-melden). Reproduce defects with synthetic data and add regression coverage for the affected detection, redaction and disclosure paths before repairing the shared implementation. Verify complete masking or withheld copies when boundaries cannot be established, and update the documented patterns or limits when affected.
- Verify source preservation, bounded values, private output permissions, failed writes and refusal to overwrite existing destinations. Keep source snapshots local and use the same inspected bytes for redaction.
- Test both the installed gem and consuming projects when changing the CLI or package. Preserve independent installation and the [exit-status contract](README.md#resultaten-en-exitcodes).

- Keep new secret-detection rules and Puppet integrations in this tool. Use the native syntax tree without evaluating input; preserve safe lookup/reference cases and reject literal values inside Sensitive wrappers. Update detection tests, consumer integration tests and the Dutch README together.
- Verify the mandatory local test prerequisite and the stable GitHub status through repository integration tests. Detection, parser errors and logs must use the same metadata-only reporting contract; never print source through downstream diagnostics after a rejected scan.
