# Repository Check Development Instructions

## Scope

Read the [repository instructions](../../AGENTS.md), [tooling instructions](../AGENTS.md), and [repository-checks README](README.md). This component is a development suite for repository documentation, CI configuration, distribution integration and test layout; it is not a runtimegem.

## Maintenance And Verification

- Update the corresponding tests here when workflows, package layout, instructions or documentation links change. Keep tool behavior assertions with the relevant tool and share helpers only according to the parent instructions.
- Extend the existing [link tests](tests/guide_links_test.rb) and shared link support for documentation navigation. Include new uncommitted Markdown files, relative targets and anchors, and the instruction route from root through tooling to each component and back to parents and its README. Prove changed checks with temporary synthetic missing-file and broken-link cases.
- Preserve the [test discovery checks](tests/test_structure_test.rb) when test layout changes. Verify both the joint task and affected targeted tasks discover and execute their intended tests.
- Review distribution tests against the [documented independent consumer routes](../README.md#importeren-en-distribueren), retaining the local Bundler override for current workfiles without commits. Do not present this as remote availability or installation of an unpublished revision.
- Preserve the [verification boundaries](README.md#onderhoud): YAML checks validate configuration, synthetic parser-Rake tests validate task selection and status, and Bash log regressions validate presentation and original process status. They do not execute hosted CI or prove its rendered UI. Keep console and reporter behavior tests with the responsible tool; check failure and error presentation on the actual platform after human publication.
