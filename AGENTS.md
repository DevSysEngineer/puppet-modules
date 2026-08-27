# AGENTS.md

## Scope And Authority

- This file is the leading instruction file for coding agents working in this repository.
- Agents must read this file and the root `README.md` before making changes.
- The root `AGENTS.md` is the project-wide baseline. A lower-level `AGENTS.md`, `AGENTS.override.md`, or applicable agent instruction file may add stricter local rules, but it must not weaken or contradict this file.
- The root `README.md` is the central Dutch user guide.
- Puppet Strings comments are the technical source of truth for public Puppet interfaces.
- Expanded configuration scenarios belong in `examples/`.

## Project Constraints

### Supported Scope

- This repository contains first-party Puppet modules for Debian and Ubuntu servers.
- The complete module set primarily targets `amd64`. Individual platform paths may support a narrower or broader set of releases or architectures.
- Support claims for operating systems, releases, architectures, Puppet, or OpenVox must match the implementation, relevant `metadata.json`, available validation, and the Dutch README in the same change.
- Treat all module directories listed in the README as first-party except the vendored Git submodules `concat`, `debconf`, `reboot`, `stdlib`, and `timezone`.
- Changes must remain inside first-party modules unless the task explicitly requires a vendored dependency change.
- Vendored submodules must not be used as project style examples.

### Foundation Architecture

- `basic_settings` is the foundation module for shared packages, APT sources, systemd orchestration, monitoring, login policy, security tooling, package hygiene, kernel and network tuning, timezone, and Puppet runtime behavior.
- Prefer extending an applicable `basic_settings` primitive over introducing parallel project architecture.
- Reuse `basic_settings::systemd_target`, `basic_settings::systemd_drop_in`, `basic_settings::systemd_service`, `basic_settings::systemd_timer`, and `basic_settings::systemd_network` for shared systemd behavior.
- Reuse `basic_settings::monitoring_service`, `basic_settings::monitoring_custom`, `basic_settings::monitoring_timer`, and `basic_settings::monitoring_npm_audit` for monitoring integration.
- Reuse `basic_settings::security_audit`, `basic_settings::io_logrotate`, and `basic_settings::login_sudo` for audit, logrotate, and sudo integration.

### systemd Composition

- Preserve the target ladder `${cluster_id}-system`, `${cluster_id}-storage`, `${cluster_id}-services`, `${cluster_id}-production`, `${cluster_id}-helpers`, and `${cluster_id}-require-services` as a core composition contract.
- A service integrated with `basic_settings` should disable vendor enablement.
- An integrated service should use a `basic_settings::systemd_drop_in`.
- An integrated service should bind to the appropriate shared target.
- An integrated service should add `OnFailure=notify-failed@%i.service` when monitoring is active.
- Systemd changes must account for generated units, local wrappers, vendor-unit drop-ins, direct `service` resources, templates, and static unit files in scope.
- Reports about reviewed systemd units must list final unit names alphabetically.

### Monitoring Architecture

- Monitoring integration must use the OpenITCOCKPIT agent model already centralized in `basic_settings::monitoring`.
- Monitoring plugins belong under `/etc/openitcockpit-agent/plugins`.
- `customchecks.ini` must be composed through `concat` and `concat::fragment`.
- Shared monitoring defined types must register services, timers, and custom checks instead of duplicating registration logic in feature modules.

### Dependencies

- Prefer local module implementation over a new community Puppet module.
- Do not add external Docker, MySQL, Nginx, RabbitMQ, or comparable Puppet modules merely because they provide similar functionality.
- Keep the project dependency set limited to `stdlib`, `concat`, `reboot`, `timezone`, and `debconf` unless a new dependency is justified.
- A new dependency must document why the local modules cannot implement the requirement cleanly.
- Prefer internal implementation when it provides better control over integration, security, systemd behavior, monitoring, or package policy.

## Working With The Existing Codebase

### Preparation

- Check `git status --short` before editing and preserve unrelated user changes.
- Read the root README and the relevant module files before changing behavior or structure.
- Inspect the touched module's `metadata.json` when it exists.
- Inspect related manifests, templates, static files, README sections, examples, and systemd units.
- Check existing integration with `basic_settings`, monitoring, systemd, security audit, `php8::fpm`, `nginx`, and other local modules relevant to the change.
- Check existing ownership, mode, `require`, `notify`, and `subscribe` patterns before adding resources.
- Treat a user's corrective edit as the current preferred pattern. Do not restore an earlier agent approach unless the user explicitly requests it.

### Scope Control

- Keep changes scoped to the requested task and affected module.
- Do not perform unrelated refactors.
- A necessary supporting refactor must remain local and be explained in the final response.

### Impact Review

- Review effects on repository conventions, Puppet abstractions, and reusable wrappers.
- Review effects on systemd ordering, targets, hardening, restart behavior, and failure handling.
- Review effects on privileges, permissions, users, groups, capabilities, sudo, and secrets.
- Review effects on networking, ports, sockets, firewalls, TLS, and service dependencies.
- Review effects on monitoring, logging, alerting, audit rules, and operational diagnostics.
- Review effects on documentation, examples, supported platforms, compatibility, and operational commands.

## Implementation Standards

### Comment Language And Format

- Write code comments in English unless managed software requires another language in generated configuration.
- Do not hard-wrap code comments, Puppet Strings text, generated configuration comments, or inline documentation at an arbitrary width.
- Keep one comment sentence on one physical line. Split only for real structure such as separate sentences, list items, examples, syntax requirements, or a genuinely complex list.
- Unwrap arbitrary line-length breaks when touching nearby comments.
- Comments must explain purpose, context, constraints, side effects, external contracts, fallback behavior, security decisions, or non-obvious control flow.
- Do not add comments that merely restate the code.

### Required Local Comments

- Add a short comment above each non-obvious resource group, `exec`, derived-value block, conditional directive list, delegated resource, or cleanup path.
- Add a short comment above shell escaping boundaries, parsing, classification, status aggregation, fallback handling, and output-building blocks.
- Add a short comment above each non-trivial function, helper, wrapper, template logic block, or reusable Puppet resource group.
- State relevant inputs, output format, managed-resource impact, exit-code impact, or preserved external contract when those details prevent misuse.
- Add orienting comments above meaningful groups of defaults, thresholds, state, counters, summaries, perfdata, paths, permissions, commands, derived values, and resource relationships.
- Split long assignment runs into smaller commented groups.
- Add internal comments where a parser, classifier, renderer, resource builder, or validation sequence changes scope or behavior.

### Comment Review

- New or materially changed manifests, shell scripts, shell templates, and generated configurations must match the comment density of comparable well-documented code.
- Review the diff for uncommented non-obvious blocks and for stale, duplicated, unclear, or outdated nearby comments.
- Add missing explanatory comments before final validation when the changed code would otherwise require follow-up explanation.

### Puppet Public Interfaces

- Public classes and defined types must use explicit typed parameters.
- Prefer parameterized classes and small defined types over hidden behavior.
- Keep module responsibilities narrow and composable.
- A defined type that requires a parent class must guard the dependency with `defined(Class['...'])` and fail clearly when the class is absent.
- Reuse one clearly named variable when the same `defined(...)` result is needed more than once in a manifest.
- Public interfaces must use `String`, `Boolean`, `Enum[...]`, `Optional[...]`, `Array[...]`, a stricter built-in type, or an appropriate type alias.

### Templates, Files, And Sources

- Render templates with ERB through `template(...)`; do not introduce EPP.
- Use one ERB template when generated files differ only by a small optional scope.
- Add separate templates only when formats or ownership boundaries differ materially.
- Serve static assets from `files/` through `puppet:///modules/...`.
- Source URI validation must allow `puppet:///` whenever module files are valid input.
- Resource paths and titles must be predictable.

### Packages And Managed Trees

- Package resources must use `install_options => ['--no-install-recommends', '--no-install-suggests']` unless a concrete package requires recommends or suggests.
- Use `purge => true`, `recurse => true`, or `force => true` only for directories fully owned by the module.
- Do not apply an executable numeric mode such as `0700` or `0750` recursively to a mixed file and directory tree.
- A fully private tree containing no executables may use recursive mode `0600`; Puppet supplies directory search bits so directories become traversable as `0700`.
- A tree containing executables must manage directory and regular-file modes separately.
- Preserve `replace => false` for installer-generated or create-once files that must survive later Puppet runs.
- File ownership and modes must be explicit.

### Resource Relationships

- Preserve explicit `require`, `notify`, and `subscribe` relationships; do not rely on implicit autorequires when ordering matters.
- Keep monitoring and audit wiring near the managed resource.
- Diagnose dependency cycles from the actual catalog relationships and containment path.
- Resolve a cycle by removing or narrowing the illogical ordering edge at its source.
- Do not replace an intended Puppet relationship with an ad hoc `systemctl`, `service`, or reload `exec` command merely to avoid a cycle.
- Preserve semantic notifications such as `notify => Service['nginx']` and bind broad ordering to a narrower stable resource when necessary.

### Catalog Dependency Contracts

- Keep dependent code inside the positive `defined(...)` branch when a required class or defined-type resource may be absent.
- Bind `require` only to an accepted resource or documented anchor after its existence check succeeds.
- Put a clear `fail(...)` in the final `else` branch and do not continue after a failed dependency contract.
- Treat `defined(Resource[title])` as current catalog-evaluation visibility, not as a final-catalog query.
- When a wrapper may emit a dependency, check accepted visible anchors in stable order: direct resource, wrapper resource, then parent wrapper.
- A consumer must not reconstruct paths, filenames, ports, unit names, or other values owned by another defined type when the source can expose them through a managed resource, alias, service title, or accepted API.
- Catalog validation must cover the authoritative cross-resource contract.
- If a public-interface expansion is rejected, do not add hidden or undocumented convenience parameters; use an accepted contract or stable external runtime metadata.

### Public Settings

- A configurable hardening value that needs a secure default, explicit opt-out, and custom override should use one `Variant[Boolean, String]` parameter or a narrow scalar variant such as `Variant[Boolean, Integer[0]]`.
- Resolve that parameter once into a clearly named `*_correct` variable near the related logic.
- In this pattern, `true` selects the documented secure default, `false` disables output, and the scalar value is the explicit override.
- Templates must consume the resolved value instead of reimplementing boolean and scalar handling.
- Replace split `*_enable` plus `*_custom`, `*_value`, or `*_max_age` interfaces with one meaningful setting unless backward compatibility is explicitly required.

### Parameter Names And Order

- Name related settings with the main topic first and qualifiers such as fallback, previous, custom, max, min, warning, or critical last.
- Use snake_case names such as `bandwidth_max`, `p95_warning`, and `secret_key_fallback`.
- Do not start a public parameter with a digit unless that syntax is validated for every supported Puppet version; use a readable prefix such as `p95_`.
- List mandatory parameters first and sort them alphabetically.
- A mandatory parameter has no default and is not typed as `Optional[...]`.
- List optional parameters after mandatory parameters and sort them alphabetically.
- An optional parameter is typed as `Optional[...]` or has a default value.
- Keep a left-to-right default dependency out of alphabetical order only when required, and explain it with a short trailing comment.

### Parameter Formatting And Documentation Order

- Align type columns, parameter-name columns, `=` signs, and default values across the complete parameter block.
- Keep Puppet Strings `@param` entries in the same order as the class or defined-type parameter block.

### Puppet Resource Structure

- Use one resource with precomputed `undef` attributes when resources differ only by optional attributes.
- Use that pattern only when mutually exclusive attributes such as `source` and `content` cannot both be non-`undef`.
- Put one shared outer guard around optional resources with the same condition, then keep resource-specific checks inside it.
- Keep monitoring-specific configuration resources near the manifest's monitoring section unless the file belongs to the daemon's runtime configuration.
- Combine arrays with stdlib `concat(...)`, not the `+` operator.
- Generated configuration order must remain explicit and reviewable.

### Puppet Control Flow

- Put the main resource path in the positive branch of guard-style control flow.
- Put exceptional `fail(...)`, `warning(...)`, or fallback behavior in the final `else` branch.
- Put a large dependent path before its smaller failure branch for parent-class, defined-type, and resource-contract guards.
- Put a substantive parsing, normalization, validation, resource-construction, or multi-assignment branch before a trivial fallback assignment.
- Branch on value presence first when a present value requires substantive work.
- Do not lead with a trivial `undef`, `false`, or empty-list assignment when the alternate branch contains the meaningful work.

### Puppet Validation Flow

- Represent optional-feature validation failure as a short named value such as `$threshold_fail_text`, or `undef` when valid.
- Emit guarded resources under `if ($validation_fail_text == undef)` and call `fail($validation_fail_text)` in the final `else`.
- Do not place standalone `fail(...)` calls in the middle of derived-value setup or resource construction.
- Validate an optional setting only when that feature is emitted or inherited into generated output.
- Do not reject an unset optional value.
- Resolve inherited or defaulted values into clearly named `*_correct` variables.
- Templates may use a raw parameter to decide whether a local override line exists, but must emit the resolved value when inheritance applies.

### Shell Commands In Puppet

- Escape runtime shell variables and substitutions inside double-quoted Puppet strings, including `\$tmpdir`, `\$1`, and `\$(...)`.
- Never interpolate a raw Puppet value into an `exec` `command`, `onlyif`, or `unless`.
- Precompute dynamic shell words with `stdlib::shell_escape(...)`, suffix their variable names with `_shell`, and use them as unquoted shell words.
- A `/bin/sh -c` or `/usr/bin/bash -c` command must have one escaping boundary.
- Pass a script assembled from pre-escaped `*_shell` words as one quoted `-c` argument; do not shell-escape the assembled script a second time.
- A fully static script may instead be escaped once as the complete `-c` argument.

### Shell Content And Permissions In Puppet

- Preserve intentional trailing semicolons in SQL statements.
- Escape the complete SQL string and use `provider => shell` when semicolons or shell guards would otherwise be parsed as separate commands.
- Prefer `/usr/bin/printf %s ${value_shell}` for dynamic shell content.
- Represent intended line breaks inside one shell word as literal `\n`, escape the value once, and decode it only at the controlled output boundary with a command such as `/usr/bin/printf %b ${value_shell}`.
- Do not use backslash decoding for arbitrary runtime or user-provided multiline content; use a `file` resource or template.
- Do not use recursive executable `chmod` modes on mixed-content trees.
- Normalize directories and regular files with separate `find ... -type d` and `find ... -type f` passes so directory search permissions do not make regular files executable.
- For exported application source trees, normalize directories and files separately; use modes such as `0750` for directories and `0640` for regular files unless the application requires another explicit mode.

### Local Readability

- Do not introduce a local variable used only once unless its name adds domain meaning or removes a real readability problem.

## Shell Scripts And Monitoring Checks

### Shell Baseline

- New shell scripts and shell templates must be POSIX `sh` with `#!/bin/sh` unless the implementation requires Bash features.
- Monitoring checks must be POSIX `sh` and return Nagios-compatible exit codes.
- Monitoring checks must not use arrays, `[[ ... ]]`, `(( ... ))`, `function name`, process substitution, here-strings, `pipefail`, `read -d`, or Bash-specific parameter expansion.
- `basic_settings/templates/login/pam/notify` and `mysql/files/automysqlbackup` are known Bash exceptions.
- When touching an existing Bash script, keep Bash only if required features remain.
- The final response must state why a touched script remains Bash-only.

### Monitoring Check Reuse

- Inspect comparable checks before adding or changing a monitoring check.
- Follow the closest check's section order, state variables, helper placement, and output style unless a technical difference requires deviation.
- Reuse an existing pattern for parsing, rendering, severity aggregation, long-output buffering, truncation, perfdata, and interpretation.
- Introduce a new monitoring pattern only when existing patterns cannot meet the check's scope.
- Document a material deviation in code or in the final response.

### Commands And Quoting

- Discover command dependencies with direct `command -v` assignments such as `TAIL=$(command -v tail 2>/dev/null) || die "tail not available"`.
- Invoke command-path variables directly in command position, such as `$AWK ...`; do not quote the command word.
- Quote command arguments, data variables, tests, and assignments consistently.
- Use shell builtins directly.
- Use `printf`, not non-portable `echo`.
- Keep command dependencies explicit.

### Setup And Options

- Order monitoring-check setup as fail helper, binary checks, default variables, option parsing, helper functions, and main logic.
- Parse CLI options with one POSIX `while getopts '<flags>' opt; do ... done` block.
- Give every supported option one explicit `case` arm that assigns `OPTARG` where applicable.
- Use one final `*) die "Usage: $0 [...]" ;;` arm for help and invalid options, including `-h` when it appears in the option string.
- Long output must be enabled by default.
- Do not add `--long-output` or `--no-long-output` switches unless the user explicitly requests them.

### Puppet-Managed Inputs

- Do not add a monitoring configuration file or parser unless the task explicitly requires it or the module already uses that pattern.
- A check that needs Puppet-resolved data must live under `templates/` and render that data directly into shell assignments.
- Keep ERB in a shell check limited to direct variable insertion.
- Keep Puppet preparation limited to defaults, serialization, and shell-safe values.

### Effective Monitoring Configuration

- Validate threshold syntax, sizes, ordering, and runtime meaning in the shell check.
- Give each threshold or managed value one authoritative input path.
- Do not expose the same managed value through CLI flags and a configuration file unless backward compatibility requires both.
- Keep CLI flags for runtime filters and for thresholds not managed through configuration.
- Prefer a daemon's effective configuration output, such as `vnstat --showconfig`, over duplicate flags, sysfs fallbacks, or parallel check-only settings.

### Data And Temporary Storage

- Do not use temporary files or `TMPDIR` only to collect perfdata, long output, counters, or sort-order buffers.
- Prefer shell variables and direct `printf` for bounded data.
- Use `mktemp` only when an external command requires a file or the data is too large or unsafe for shell variables.
- Do not create shell assignments containing literal blank lines inside quoted strings.
- Represent embedded line breaks through `printf` formats and escaped `\n`.
- Use explicit sentinel tokens for serialized command-substitution metadata instead of newline-marker tricks.
- Store shell lists as comma-separated values and split them deliberately.

### Helpers And Branches

- Do not add a wrapper function that only hides one `printf`, assignment, or append operation.
- Add a function only when its name captures domain meaning, it centralizes validation or formatting, or it removes meaningful duplication.
- Keep single-use shell logic inline unless a helper materially improves readability.
- Put the main shell path in the positive `if` branch and smaller exceptional fallbacks in the final `else`.

### Monitoring Output Sanitization

- Inspect the actual output path before adding a normalizer, sanitizer, or blank-line collapsing helper.
- Add normalization only when runtime data, external output, or intentional section separators can produce unsafe pipes or unwanted blank lines.
- Explain a non-obvious need for normalization in a nearby comment.
- Sanitize raw `|` characters where dynamic values or external output enter long output because Nagios-style parsers can interpret pipes on continuation lines as perfdata separators.
- Do not pipe fixed literal text through a sanitizer when it cannot contain `|`.
- Do not emit consecutive, leading, or trailing blank lines.
- Use exactly one blank line between distinct output sections when separation improves readability.

### Monitoring Audience And Scope

- Monitoring output must be actionable for operators who may see only OpenITCOCKPIT or a wallboard.
- A deliberately limited check must state its scope in the output.
- Distinguish configuration errors, runtime failures, contextual warnings, and unknown or inconclusive states when those categories are present.
- Contextual findings may appear in detail output but must not affect the exit code unless they are in the check's defined scope.

### Summary Line Format

- Emit one natural, operator-readable summary line with optional perfdata and long output.
- The first line must identify the checked service, unit, module, interface, or resource.
- The first line must state the direct cause of a non-healthy result and indicate whether escalation is likely needed.
- The first line must not begin with `OK`, `WARNING`, `CRITICAL`, or `UNKNOWN`; the Nagios exit code carries machine state.
- Do not label short-output cause lists with Nagios state names.
- Check-owned text must remain cause-specific when a monitoring UI adds its own state prefix.

### Summary Line Content

- A WARNING, CRITICAL, or UNKNOWN summary must name the primary affected object and direct cause.
- Long output must support diagnosis rather than hide the primary cause.
- Keep summary text cause-oriented and put detailed counters in perfdata or long output.
- Do not list zero-count status categories.
- If there are no findings, state that the target is healthy or running as expected.
- Do not print threshold values, threshold inventories, final decision labels, or decision rationale in operator-readable output.
- Put useful thresholds in perfdata instead of summary or long output.
- Do not embed perfdata-style `key=value` fragments in summary text.

### Detail Output

- Detail output must explain the summary with the affected component, observed state, and likely cause when known.
- Detail output must state whether the issue is actionable by the check and give a useful next step or escalation path when applicable.
- Print the most diagnostically important section first.
- For non-trivial long output, make `Interpretation:` the final section.
- `Interpretation:` must explain displayed data, scope, contextual findings, and the next inspection or escalation step.
- `Interpretation:` must remain factual and must not repeat perfdata.

### Long-Output Limits

- Each check must use one truncation method for its diagnostic body.
- Do not combine line, item, block, and character caps on the same diagnostic path.
- A separate cap is allowed for another output surface only when it does not also truncate the same diagnostics.
- Long detail must have one configurable size limit and explicitly state when truncation occurs.
- When UI limits are relevant, cap total diagnostic characters above `Interpretation:`.
- Emit the truncation marker before `Interpretation:` so final guidance remains visible.

### Perfdata

- Perfdata labels must start with a lowercase letter and contain only lowercase letters, digits, and underscores.
- Labels must be compact, stable snake_case names such as `memory_used`.
- Do not encode units in labels with forms such as `pct_`, `bytes_`, `seconds_`, `mbit_`, `bps_`, or matching suffixes.
- Put units in the UOM field, such as `%`, `B`, `s`, or `Mbps`.
- Do not pad absent optional fields with empty semicolons; include semicolons only through the last populated field.
- Use `c` for monotonic counters that increase until the source resets.
- Do not use `c` for gauges, bounded inventory counts, current utilization, high-water marks, rates, or scheduled period totals.

### Monitoring Contracts

- Do not change exit-code semantics without documenting the operational reason.
- Preserve exit codes, summary shape, perfdata keys, option flags, generated paths, and registration names unless the task explicitly changes the external contract.

## Documentation

### Ownership And Language

- Write technical documentation in English, including Puppet Strings, examples outside the root README, changelog entries, and this file.
- Keep the root README in Dutch unless the user explicitly requests another language.
- Keep developer workflow and review policy in `AGENTS.md`.
- Keep implementation documentation beside the class, defined type, script, or template it describes.
- Do not copy project-wide policy into code comments.
- Keep one authoritative location for each technical fact.
- When a fact must appear in more than one layer, keep one complete source and use concise summaries with pointers elsewhere.

### Documentation Layers

- Use the README for the project introduction, capabilities, compatibility, installation, quick start, major security choices, module overviews, and navigation.
- Use `examples/` for expanded and combined configurations.
- Use Puppet Strings for parameters, defaults, dependencies, security behavior, fallbacks, and generated resources.
- Use script and template comments for local implementation contracts.
- Do not create a `docs/` tree or manual `REFERENCE.md` for information Puppet Strings can generate.
- Use an ADR for architecture choices, considered alternatives, trade-offs, and lasting design decisions when such a record is requested or already established.
- Use automated tests for concrete behavior, regressions, edge cases, and machine-verifiable contracts when the repository has an applicable test path.

### README Content

- Apply progressive disclosure in this order: purpose, standard usage, main properties, risks and limitations, compact example, then expanded examples or Puppet Strings.
- Keep the README complete enough for operator decisions without turning it into an exhaustive parameter or implementation reference.
- Do not duplicate complete parameter lists, fallback chains, internal script behavior, per-check output contracts, or developer-only detail in the README.
- Put security- and compatibility-critical operational expectations in the README when users must know them before use.
- Keep placeholder hostnames, replacement values, Hiera guidance, and `Sensitive(...)` handling near the quick start.
- Maintain a `## Inhoudsopgave` near the top with main-section links and nested module links.
- Do not label the table of contents `Legenda`.
- Add a README detail only when users need it before use, it changes a security or compatibility decision, or the basic example requires it.

### README Module Sections

- Each main module section must explain its purpose before internal detail.
- Include no more than five to eight important properties.
- State pre-use conditions, operational risks, and limitations.
- Include one compact basic example.
- Link to a relevant scenario in `examples/` and point to Puppet Strings.
- Move expanded variants and authoritative parameter detail to their proper layer when a section grows.
- Maintain a bottom-level list of expanded examples.

### README Style

- Match the current direct, practical, infrastructure-focused tone.
- Write ordinary, accessible Dutch around exact code identifiers.
- Explain unavoidable metadata or implementation terminology before using it.
- Preserve intentional author viewpoints, warnings, and project context when reorganizing content.
- Do not replace concrete operational language with generic boilerplate, stock transitions, or uncommon synonyms.
- Start README prose list items with a capital letter.
- Preserve the case of identifiers, module names, class names, paths, and literals.
- Do not shorten the README at the expense of operational knowledge.

### Examples

- Reuse an existing scenario file before creating another example.
- Add an example file only when the subject does not fit an existing scenario and is substantial enough to stand alone.
- Examples must be syntactically valid, executable for the scenario, aligned with public interfaces, and limited to parameters needed for understanding.
- Use `example.org`, documentation address ranges, and `replace-with-...` placeholders.
- Do not use internal hostnames, addresses, usernames, domains, real secrets, or other organization data in examples.
- Use `Sensitive(...)` whenever the public datatype supports it.
- Retrieve secrets for legacy String interfaces from protected Hiera data instead of embedding them in manifests.
- Do not duplicate the same large code block in the README and `examples/`.

### Puppet Strings

- Document every public class and defined type directly above its declaration with Puppet Strings comments.
- Add a one-line `@summary` and a useful description of purpose, behavior, dependencies, configuration impact, security choices, and generated resources where applicable.
- Document every public parameter with `@param`.
- Parameter documentation must cover the datatype contract, default meaning, special `undef`, `true`, or `false` behavior, and constraints not expressed by the type.
- Document security and compatibility impact when relevant.
- Add a simple `@example` to every public class and defined type.
- Mark new classes, defined types, and functions as `@api public` or `@api private` where applicable.
- Do not copy complete Puppet Strings parameter documentation into the README.

### Markdown

- Do not hard-wrap prose in Markdown files.
- Keep each prose paragraph or list item on one physical line unless Markdown syntax, a table, or a code block requires line breaks.
- Keep documentation professional, concrete, and focused on operational impact and risk.

### Documentation Synchronization

- Check nearby documentation whenever behavior is modified.
- Update affected documentation in the same change when behavior, parameters, templates, defaults, security, checks, examples, commands, build flows, or public APIs change.
- Update examples when public classes, defined types, parameters, relationships, defaults, or required composition change.
- Update the README `## Checks` section when a monitoring check is added, renamed, or removed.
- A user-facing change to functionality, integration, operational assumptions, security expectations, installation, or usage requires an appropriate README update.
- For each modified `.pp` file, verify parameter documentation, defaults, examples, API markings, and nearby stale or duplicate documentation.
- Update only the documentation layers affected by the change.

## Validation And Testing

### Test Model

- The first-party modules have no root CI, root `Gemfile`, root `Rakefile`, or project-wide Puppet test suite.
- Vendored submodule tooling must not be treated as validation for first-party modules.
- Do not add an automated test directory, fixture harness, or generated test framework unless the user explicitly requests tests.
- Run targeted validation for every touched file.
- If required tooling is unavailable, state that in the final response and report the fallback checks performed.

### Change Discovery

Run the applicable discovery and whitespace checks:

```sh
git diff --name-only
git diff --name-only -- '*.pp'
git diff --name-only -- 'metadata.json' '*/metadata.json'
git diff --check
```

### Puppet Manifests

When Puppet tooling is available, run:

```sh
puppet parser validate <changed-manifest.pp> [...]
puppet-lint <changed-manifest.pp> [...]
```

### Templates

- Validate ERB syntax with `erb -P -x -T '-' <template-file> | ruby -c`.
- Treat the ERB command as Ruby and ERB syntax validation only.
- Render representative output for each changed shell-template branch or mode.
- Run `sh -n` or `bash -n` on the rendered shell output as appropriate.

### Shell Scripts And Metadata

- Validate POSIX scripts with `sh -n <changed-posix-script>`.
- Validate Bash scripts with `bash -n <changed-bash-script>`.
- Validate metadata with `ruby -rjson -e 'ARGV.each { |f| JSON.parse(File.read(f)); puts f }' <metadata.json> [...]`.

### Functional Review

- Verify that changed class and defined-type guards match actual inclusion order.
- Verify file modes, ownership, and `Sensitive[...]` or `Sensitive.new(...)` handling.
- Verify monitoring, sudoers, logrotate, audit, and systemd paths against generated filenames and service names.
- Exercise at least one representative success path and one practical error path for shell parsing, monitoring output, or status-handling changes.
- Verify that changed public interfaces remain consistent across Puppet Strings, examples, and the README.

## Security And Privacy

### Security Baseline

- Treat security as a design requirement from the start of every change.
- Preserve correct existing hardening.
- Improve hardening only when application and operational behavior remain correct.
- Preserve the strongest applicable rule when consolidating security guidance.
- Do not silently remove an unclear, outdated, or incorrect security rule; replace it with the corrected rule and report the reason.
- When a security requirement cannot be resolved from repository evidence, preserve the safer behavior and report the uncertainty for review.

### External Disclosure

- Treat every transfer outside an organization-controlled or explicitly approved environment as external disclosure.
- External disclosure includes search queries, AI prompts, pasted text, uploads, screenshots, code snippets, forums, vendor portals, external issue trackers, code-sharing services, chat, email, and browser tools.
- Approval to use an external service does not authorize every data type.
- Data classification, least disclosure, and minimum-necessary rules apply to every approved external service.
- Reduce an external question to the minimum technical facts required to understand the problem.
- Prefer a generic description or minimal reproducible example containing only synthetic data.

### Secrets And Authentication Material

- Never disclose a password, passphrase, API key, access token, refresh token, session identifier, cookie, backup code, or credential-bearing connection string externally.
- Never disclose a private key, certificate material, CSR, certificate chain, keystore, truststore, secret file, token file, kubeconfig, or `.env` content externally.
- Remove secrets completely before external use.
- Partial masking, prefixes, suffixes, fingerprints, hashes, and encoded variants are not acceptable when they can identify or validate the original value.
- Never put real secrets or credentials in code, comments, documentation, examples, tests, fixtures, logs, commits, tickets, prompts, or troubleshooting material.
- Use clearly synthetic authentication values in every example and reproduction.

### Operational And Confidential Data

- Do not disclose raw operational, personal, medical, customer, employee, organization, or commercially confidential data outside the approved environment.
- Treat logs, stack traces, HL7, FHIR, EDI, database records, exports, configuration files, packet captures, screenshots, source fragments, headers, and query parameters as potentially sensitive.
- Treat hostnames, IP addresses, internal URLs, filenames, usernames, tenant identifiers, project identifiers, and metadata as potentially sensitive.
- Do not upload a complete repository, database dump, configuration set, message archive, or log collection when a smaller synthetic reproduction is sufficient.

### Anonymization And Synthetic Data

- Anonymize or replace all data with synthetic values before it leaves the approved environment.
- Replace real names, identifiers, addresses, numbers, timestamps, domains, hostnames, and environment-specific values.
- Preserve only relationships needed to reproduce the issue.
- Use consistent synthetic placeholders when correlation matters, but never reuse production values.
- Evaluate combinations of remaining fields for re-identification risk.
- Do not call partially masked or pseudonymized data anonymous when re-identification remains reasonably possible.

### Outbound Review

- Inspect the complete outbound content before sharing it.
- Review logs, stack traces, shell history, command output, request and response headers, URLs, query strings, comments, filenames, metadata, screenshots, diffs, archives, and copied surrounding context.
- Share only the smallest sanitized fragment required to solve the problem.
- Do not disclose information when safe sanitization cannot be demonstrated with sufficient confidence.
- Use approved internal documentation, tooling, colleagues, or secure support channels when external sharing is unsafe.

### Disclosure Incidents

- Stop further sharing immediately when a secret or confidential value is disclosed accidentally.
- Do not repeat the exposed value in follow-up communication.
- Treat exposed credentials and key material as compromised.
- Revoke or rotate compromised credentials and key material where applicable.
- Follow the applicable security-incident procedure.

### Privilege And Isolation Review

- Check whether changed code can run with less privilege or under a more constrained service identity.
- Check whether systemd isolation can be tightened without breaking behavior.
- Identify new trust boundaries, sudo paths, writable paths, exposed ports, capabilities, or privilege assumptions.
- Prefer the simpler design when it reduces attack surface without violating requirements.

### Files, Permissions, And Runtime Identities

- Set ownership and modes as restrictively as operational behavior permits.
- Identify the runtime identity that reads each generated file.
- Grant parent-directory traversal only to identities that require it.
- Keep secrets and sensitive configuration out of world-readable files.
- Use `Sensitive[...]` or `Sensitive.new(...)` when file content or command data requires redaction in Puppet reports.
- Grant execute permission only to actual executables.
- Justify world-readable or group-writable access.

### Repository File-Mode Conventions

- Config files should use mode `0600` unless another runtime identity needs access.
- Static daemon-readable fallback files should use root ownership and service-group access, such as directory mode `0710` and file mode `0640`, instead of world-readable modes.
- Root-only scripts should use mode `0700`.
- Sudoers files must use mode `0440`.
- SSH homes and `.ssh` paths must remain tightly permissioned.
- Systemd unit files should use mode `0644` where systemd requires it.
- Public HTTP exposure does not justify local filesystem read access for every user.

### Dependencies, Audit, And Monitoring

- Review new dependencies for avoidable risk and complexity.
- Add audit or monitoring coverage when a new sensitive surface requires it.
- Put a short comment above each changed audit-exclusion group.
- An audit-exclusion comment must state the benign runtime behavior, suppressed audit key or syscall family, and scoping boundary.
- Check nearby audit exclusions for overlap before adding another rule.

### Encrypted Transport

- Reverse proxies and internal service-to-service upstreams must default to encrypted transport whenever the upstream supports it, including loopback and local Docker traffic.
- Plain HTTP is an explicit opt-out and must document why the upstream cannot support encrypted transport.
- Do not disable encryption merely to bypass certificate-trust problems.
- For local or self-signed upstream certificates, prefer encrypted transport with verification disabled only when proper trust cannot be established within scope.
- A weakened permission, sandbox, or trust model must be explained in code.
- Update the README when a weakened security model changes an operational expectation.

## systemd Hardening

### Applicability

- Review service-execution hardening for each concrete `.service` unit.
- Do not apply service-execution options as generic defaults to `.timer`, `.socket`, `.mount`, `.path`, `.target`, `journald.conf`, `resolved.conf`, or `timesyncd.conf`.
- For a timer, socket, or path unit, review the paired `.service` unit.
- Do not add hardening blindly.
- Prefer a documented exception over a setting that causes runtime failures or operational surprises.

### Required Service Analysis

- Identify the final unit name and Puppet location.
- Identify the template, wrapper, or vendor unit being modified.
- Inspect `ExecStart`, `ExecStartPre`, `ExecStartPost`, `ExecReload`, and `ExecStop`.
- Inspect `User`, `Group`, supplementary groups, capabilities, sudo, and setuid use.
- Inspect writable paths, generated files, directories, sockets, logs, and temporary-file behavior.
- Inspect devices, home directories, credentials, network exposure, and package-management behavior.
- Inspect runtime languages, interpreters, VMs, plugins, JIT or code generation, and process-introspection needs.
- Record each candidate option as `apply`, `do not apply`, or `needs more research` in the related analysis.

### UMask

- Set `UMask=0077` explicitly in the service-specific hash near `PrivateTmp`, `ProtectHome`, and `ProtectSystem` when private output is required.
- Do not inject `UMask` invisibly from a generic wrapper or template.
- Omit `UMask` when the service requires the normal Linux default `0022`.
- Set a shared non-default mask such as `0027` per service and document the reason beside the override.

### Candidate Option Review

| Option | Do not apply until these risks are checked |
| --- | --- |
| `PrivateDevices=true` | Real device nodes, storage, hardware, USB, virtualization, containers, RTC, GPU, serial, smartcard, tape, scanner, printer, or low-level network devices. |
| `PrivateTmp=true` | Intentional exchange with other units through shared `/tmp` or `/var/tmp`. |
| `ProtectHome=true` | Required access to `/home`, `/root`, or `/run/user`, including SSH material, web content, backups, or application data. |
| `ProtectSystem=full` | Writes under `/usr`, `/boot`, `/etc`, or other protected paths without matching writable exceptions. |
| `SystemCallArchitectures=native` | 32-bit or legacy ABIs, Wine, QEMU-user, emulation, `setarch`, or compatibility workloads. |
| `RestrictSUIDSGID=true` | Installation, restore, provisioning, package management, or workflows that set SUID or SGID bits or create SGID directories. |
| `LockPersonality=true` | Execution-domain changes, ASLR changes through personality, or compatibility modes. |
| `NoNewPrivileges=true` | `sudo`, `su`, `runuser`, `pkexec`, setuid helpers, file capabilities, or runtime privilege escalation. |
| `MemoryDenyWriteExecute=true` | JIT or runtime code generation, executable stacks, trampolines, runtime patching, security or observability injection, `/dev/shm`, `memfd_create`, plugins, or unknown binaries. This includes JVM, .NET, Node.js/V8, Chromium/Electron, LuaJIT, Erlang/BEAM native code, WebAssembly, database JIT, and PCRE-JIT. |
| `ProtectHostname=true` | Hostname or domain changes, `hostnamectl`, provisioning workflows, or agents that need live hostname changes for monitoring, inventory, licensing, clustering, or registration. |
| `ProtectClock=true` | System or hardware clock changes, RTC access, `adjtimex` or `clock_adjtime`, time synchronization, wake alarms, backup or scheduling behavior, NTP, chrony, `systemd-timesyncd`, `hwclock`, or VM guest tools. |
| `ProtectControlGroups=true` | Container or VM runtimes, nested service managers, supervisors, resource-accounting agents, orchestration, troubleshooting, or intentional cgroup inspection. |
| `ProtectKernelLogs=true` | `/dev/kmsg`, `/proc/kmsg`, `dmesg`, kernel-log collectors, low-level security agents, troubleshooting agents, or monitoring plugins that inspect kernel messages. |
| `ProtectKernelModules=true` | `modprobe`, `insmod`, `rmmod`, DKMS, module builds, direct `/usr/lib/modules` access, or storage, network, virtualization, container, hardware, security, and observability agents that manage modules. |
| `ProtectKernelTunables=true` | Sysctl, firewall, network, storage, power, hardware, container, virtualization, or provisioning changes. Also check inspection of `/proc/kallsyms`, `/proc/kcore`, `/proc/sys`, `/sys`, `/proc/sysrq-trigger`, `/proc/acpi`, `/proc/fs`, and `/proc/irq`. |
| `ProtectProc=invisible` | Cross-user process inspection, supervisors, monitoring, inventory, security, troubleshooting, `/proc` scanning, `CAP_SYS_PTRACE`, host-visible mounts, host `/proc` assumptions, or kernels without per-mount `hidepid`. |
| `UMask=0077` | Group-readable files, group-writable directories, shared sockets, logs, web assets, backups, deployment output, temporary hand-offs, or package behavior requiring `0022` or a documented shared mask such as `0027`. |

### Lower-Risk Categories

- Lower-risk candidates are internally generated oneshot services that run a known native binary or root-only script and use none of the shared, privileged, compatibility, JIT, kernel, device, process-inspection, or plugin behaviors in the candidate matrix.

### Higher-Risk Categories

- Treat package-management, provisioning, Puppet, GitLab omnibus, hooked Certbot renewal, SSH session, monitoring executor, OpenITCOCKPIT server, backup, and restore units as higher risk.
- Treat services that create shared files or use capabilities or devices as higher risk.
- Treat JIT and plugin runtimes as higher risk.
- Treat processes that may invoke `sudo`, `su`, `runuser`, `pkexec`, setuid helpers, file capabilities, or application-specific helpers as higher risk.

### Generic Wrapper Hardening

- A generic wrapper change must inspect the wrapper and every known consumer.
- Add a wrapper hardening default only after validating every consumer or providing explicit per-service opt-outs with documented technical reasons.

## Completion Checklist

### Context And Scope

- Confirm that relevant README sections, metadata, manifests, templates, files, examples, and generated units were inspected.
- Confirm that changes remain scoped to first-party modules unless dependency work was explicitly requested.
- Confirm that unrelated user changes were preserved.

### Code And Documentation

- Confirm that centralized comment, implementation, and documentation rules were followed.
- Confirm that nearby affected documentation is accurate, non-duplicative, and unambiguous.
- Confirm that Puppet Strings matches changed public interfaces.
- Confirm that required user-facing README changes are in Dutch.

### Security And Operations

- Confirm that permissions, secrets, systemd, monitoring, logging, audit, network exposure, and operational impact were reviewed for the touched area.
- Confirm that no secret, credential, certificate, or key material was shared externally.
- Confirm that externally used data was minimal and synthetic or sufficiently anonymized.
- Confirm that logs, screenshots, headers, URLs, filenames, and metadata were reviewed before external use.
- Confirm that no external disclosure occurred when safe sanitization could not be demonstrated.

### Validation And Reporting

- Run relevant validation commands and report unavailable tooling plus fallback checks.
- Require `git diff --check` to pass.
- In the final response, list changed files or paths, relevant security and systemd review decisions, README and `AGENTS.md` documentation decisions, validation performed, and unresolved assumptions or required follow-up.

## Maintaining AGENTS.md

### Content And Placement

- Store only durable project-wide engineering rules; do not record task, ticket, bug, feature, or prompt history.
- Identify the underlying objective, required behavior, scope, and necessary exceptions before adding a rule.
- Keep feature-specific implementation detail in code, tests, documentation, specifications, or ADRs unless it is a lasting project-wide constraint.
- Keep exact technical detail only when it is a required contract, constraint, exception, compatibility requirement, or security requirement.
- Keep one authoritative location for every rule.
- Place each rule in the narrowest relevant section.
- Place each exception directly with the rule it modifies.
- Leave this file unchanged when existing policy already covers the requested behavior completely and unambiguously.

### Maintenance Triggers

- Update this file when a repository-wide convention, architecture constraint, validation command, security requirement, coding standard, or operational workflow changes.
- Convert recurring review findings, production issues, security findings, test failures, tooling changes, and repeated agent mistakes into durable rules only when they generalize beyond one task.
- Record the reusable behavior and constraint, not the event or prompt that revealed it.

### Editing Rules

- Check whether an existing rule covers the behavior wholly or partly before adding content.
- Update, broaden, or clarify the authoritative rule before creating a new one.
- Add a new rule only for necessary durable behavior that is not already covered.
- Remove duplicate and weaker variants when consolidating rules.
- Use one primary requirement, prohibition, or decision per bullet.
- Split independent topics into separate bullets or subsections.
- Do not compress several requirements into dense prose to reduce line or bullet count.
- Do not let a lower-level instruction weaken or duplicate project-wide policy.

### Final Review

- Verify that every change to this file is necessary, reusable, scannable, non-duplicative, unambiguous, and consistent with the rest of the document.
- Verify that no obligation, prohibition, exception, compatibility contract, or security safeguard was weakened or lost.
- Resolve contradictions when repository evidence determines the correct rule.
- Preserve the safer existing behavior and report the ambiguity when a contradiction cannot be resolved from repository evidence.
