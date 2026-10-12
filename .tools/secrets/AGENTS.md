# Sensitive Data Tool Development Instructions

## Scope

Read the [repository instructions](../../AGENTS.md), [tooling instructions](../AGENTS.md), and [scanner README](README.md). This component owns local secret detection, source coverage, analysis preparation, controlled restoration and safe review.

## Maintenance And Verification

- Verify each supported detection rule with synthetic positive, negative and multiline inputs. Keep value findings distinguishable from sensitivity indicators and document unsupported constructs at the [pattern contract](README.md#patronen-en-beperkingen).
- Exercise every disclosure channel when changing detection or errors: stdout, stderr, JSON, JUnit, paths, Ruby debug mode and redacted copies. Never expose exception messages or source excerpts; validate that incomplete inspection withholds copies.
- Handle missed values and unsafe output through the [repository incident requirements](../../AGENTS.md#disclosure-incidents) and [scanner recovery procedure](README.md#gemiste-gegevens-of-een-fout-melden). Reproduce defects with synthetic data and add regression coverage for the affected detection, redaction and disclosure paths before repairing the shared implementation. Verify complete masking or withheld copies when boundaries cannot be established, and update the documented patterns or limits when affected.
- Verify source preservation, bounded values, private output permissions, failed writes and refusal to overwrite existing destinations. Keep source snapshots local and use the same inspected bytes for redaction.
- Test both the installed gem and consuming projects when changing the CLI or package. Preserve independent installation and the [exit-status contract](README.md#resultaten-en-exitcodes).

- Keep new secret-detection rules and Puppet integrations in this tool. Use the native syntax tree without evaluating input; preserve safe lookup/reference cases and reject literal values inside Sensitive wrappers. Update detection tests, consumer integration tests and the Dutch README together.
- Verify the mandatory local test prerequisite and the stable GitHub status through repository integration tests. Detection, parser errors and logs must use the same metadata-only reporting contract; never print source through downstream diagnostics after a rejected scan.

- Keep scanning, preparation, restoration, diagnostics and controlled comparisons on the shared scanner and source-reading implementation. Review syntax and context preservation against the [write contract](README.md#herstelcontext-en-validatie), including whole-file rewrites and candidate Hiera context.
- Exercise global marker integrity across changed and unchanged files, explicit deletion, movement and reuse, source and selected-context conflicts, symlink boundaries and metadata preservation. Test the [journal and recovery contract](README.md#conflicten-en-herstel-na-fouten) with failures after partial application, abrupt process exit and intervening changes by another process.
- Do not add Git hooks, command wrappers, revision processing or an AI-session framework to enforce the [repository workflow](../../AGENTS.md#git-inspection). Keep the tool independent of Git and agent launchers. Preserve the local ID mappings and recovery state needed for editing, and test the installed scan, prepare, write and comparison routes outside a Git repository without agent startup.
