# AGENTS.md

## Purpose

This file is the project-wide working instruction for AI coding agents in this
repository. Read it before making changes, use it while reviewing your own work,
and check it again before the final handoff.

The root `AGENTS.md` is authoritative for the whole repository. At the time of
this cleanup, no additional `AGENTS.md`, `AGENTS.override.md`, or
`.github/copilot-instructions.md` files exist. If a lower-level instruction file
is added later, read it for that subtree. It may add narrower rules, but it must
not contradict this file unless it explicitly documents the exception.

The root `README.md` is the Dutch-language source of truth for user-facing
project documentation, supported use cases, examples, and monitoring checks.
Always write `README.md` prose in Dutch. Keep long product, architecture, and
operations explanations in `README.md` or another dedicated document instead of
duplicating them here.

## Repository Overview

This repository contains first-party Puppet modules for hardened 64-bit Debian
and Ubuntu servers. Do not broaden supported platforms, releases, or
architecture claims unless the affected `metadata.json` files and `README.md`
are updated in the same change.

First-party modules:

- `basic_settings`
- `docker`
- `gitlab`
- `letsencrypt`
- `mysql`
- `naemon`
- `netplanio`
- `nginx`
- `openitcockpit`
- `php8`
- `proxmox`
- `rabbitmq`
- `ssh`

Vendored Git submodules:

- `concat`
- `debconf`
- `reboot`
- `stdlib`
- `timezone`

Do not treat vendored submodules as the house style for this project. Change
vendored code only when the task is explicitly about that dependency. Vendored
README, changelog, contribution, and generated reference files belong to those
dependencies and are not project-wide instructions.

Important repository paths:

- `README.md`: Dutch user-facing overview, examples, public behavior, and
  monitoring check list.
- `examples/`: Practical Puppet examples that must stay aligned with public
  module behavior when present.
- `<module>/metadata.json`: Supported platforms and module metadata, when the
  module has one.
- `<module>/manifests/`: Puppet classes and defined types.
- `<module>/templates/`: ERB templates rendered by Puppet.
- `<module>/files/`: Static module files served through `puppet:///modules/...`.

`basic_settings` is the foundation module. It provides shared orchestration for
APT repositories, base packages, systemd targets, monitoring plumbing, security
tooling, package hygiene, kernel and network tuning, login policy, timezone, and
Puppet runtime behavior.

Prefer shared helpers from `basic_settings` over one-off resources in service
modules. Common integration points are:

- `basic_settings::systemd_target`
- `basic_settings::systemd_drop_in`
- `basic_settings::systemd_service`
- `basic_settings::systemd_timer`
- `basic_settings::systemd_network`
- `basic_settings::monitoring_service`
- `basic_settings::monitoring_custom`
- `basic_settings::monitoring_timer`
- `basic_settings::monitoring_npm_audit`
- `basic_settings::security_audit`
- `basic_settings::io_logrotate`
- `basic_settings::login_sudo`

The systemd target ladder created by `basic_settings::systemd` is a core module
composition mechanism:

- `${cluster_id}-system`
- `${cluster_id}-storage`
- `${cluster_id}-services`
- `${cluster_id}-production`
- `${cluster_id}-helpers`
- `${cluster_id}-require-services`

Monitoring is centered on the OpenITCOCKPIT agent model. Checks are installed
under `/etc/openitcockpit-agent/plugins`, and `customchecks.ini` is built with
`concat` and `concat::fragment`.

## Working Rules

- Read `README.md` before changing the repository. It explains intended module
  combinations, supported scope, monitoring behavior, and documentation tone.
- Identify whether the change touches a first-party module, a vendored
  submodule, root documentation, examples, or repository maintenance files.
- Inspect the touched module's `metadata.json` when it exists.
- Before changing behavior or structure, read the relevant manifests, templates,
  files, README sections, examples, and related local modules that influence the
  change.
- Keep changes scoped to the request. Do not perform broad refactors,
  formatting sweeps, dependency upgrades, platform expansion, or vendored
  submodule edits unless explicitly requested.
- Preserve existing resource ordering, ownership, modes, `require`, `notify`,
  and `subscribe` patterns unless there is a clear technical reason to change
  them.
- When a module already integrates with `basic_settings`,
  `basic_settings::monitoring`, `basic_settings::systemd`,
  `basic_settings::security_audit`, `php8::fpm`, `nginx`, or another local
  module, extend that integration instead of adding parallel logic.
- Treat the working tree as shared with the user. Do not revert, overwrite, or
  stage unrelated changes.
- Create a commit or pull request only when the user asks for one. Include only
  the files that belong to the task.

## Coding Standards

- Keep Puppet module interfaces explicit with typed parameters.
- Prefer parameterized classes plus small defined types over hidden behavior.
- Keep module responsibilities narrow and composable, for example `php8`,
  `php8::fpm`, and `php8::fpm_pool`.
- Reuse `basic_settings` helpers for systemd units, timers, monitoring,
  logrotate, sudoers, and audit rules.
- Prefer extending the existing local modules over adding community Puppet
  modules. If a new dependency is proposed, justify why the first-party modules
  cannot handle the need cleanly.
- When a defined type depends on a parent class, guard it with
  `defined(Class['...'])` and fail with a clear message when the parent is
  missing.
- When the same `defined(...)` result is needed more than once in one manifest,
  assign it once to a clearly named variable and reuse that variable.
- Use ERB templates through `template(...)`; do not introduce EPP templates
  unless the task requires a migration.
- Use `files/` and `puppet:///modules/...` for static module assets.
- When validating configurable file sources, allow `puppet:///` wherever module
  files are valid input.
- Keep package installation minimal with
  `install_options => ['--no-install-recommends', '--no-install-suggests']`
  unless recommendations or suggestions are required.
- Use `purge => true`, `recurse => true`, and `force => true` only for
  directories the module fully owns.
- Preserve `replace => false` for installer-generated or first-created files
  that must survive later Puppet runs.
- Keep file modes and ownership explicit.
- Keep monitoring and audit wiring close to the managed resource so operational
  visibility changes with the feature.

Puppet class and defined-type parameter lists:

- Put mandatory parameters first. Mandatory means the parameter is not
  `Optional[...]` and has no default value.
- Sort mandatory parameters alphabetically by parameter name.
- Put optional parameters after mandatory parameters. Optional means the
  parameter is `Optional[...]` or has any default value.
- Sort optional parameters alphabetically by parameter name.
- Keep a dependency parameter earlier than the parameter that references it,
  even when that breaks alphabetical order. Add a short trailing comment
  explaining the ordering.
- Align the type column, parameter-name column, `=` signs, and default values
  across the full parameter block.

Puppet implementation patterns:

- For secure defaults with explicit opt-out and custom override, prefer a
  `Variant[Boolean,String]` interface, or a narrower scalar variant such as
  `Variant[Boolean,Integer[0]]`. Resolve `true`, `false`, and scalar values once
  into a clearly named `*_correct` variable near the related logic.
- When a `Variant[Boolean,Scalar]` parameter replaces an older split interface,
  collapse the public API to the single meaningful setting unless backward
  compatibility is explicitly required.
- Prefer one compact resource with precomputed `undef` attributes over
  duplicated resource blocks when only optional attributes differ.
- Use a short guard with `fail(...)` before the main path when that is clearer
  than a large `else` block.
- Do not introduce a variable for a value used only once unless the variable
  adds domain meaning or prevents a real readability problem.
- Add short comments above non-obvious resource groups, non-trivial branches,
  and security-sensitive ordering. Do not add comments that only restate the
  code.
- When a generated file should be created once and then survive later Puppet
  runs, prefer `replace => false`. If an event-driven rebuild is required, use a
  small refresh-only cleanup step and let the normal `file` resource recreate
  the content from `template(...)`; do not generate managed file content inside
  an `exec`.

Shell and `exec` rules:

- Treat new shell scripts and shell templates as POSIX shell by default and use
  `#!/bin/sh`.
- Use Bash only when the existing file or required behavior needs Bash. Current
  known Bash exceptions are `mysql/templates/grant.sh`,
  `mysql/files/automysqlbackup`, `basic_settings/files/network/rxbuffer`, and
  `basic_settings/templates/login/pam/notify`.
- Use `printf` instead of non-portable `echo` behavior.
- Quote shell variables consistently and keep command dependencies explicit.
- Only mark true executables as executable.
- Do not embed literal line breaks inside shell variables, quoted strings,
  Puppet interpolations, or concatenations. Use `printf` formatting with escaped
  `\n`.
- In Puppet `exec` resources, never interpolate raw Puppet values into
  `command`, `onlyif`, or `unless`. Precompute dynamic arguments with
  `stdlib::shell_escape(...)`, name those variables with a `_shell` suffix, and
  use the escaped value as an unquoted shell word.
- Add a short comment above each block that prepares shell-escaped values so the
  protected command or guard is clear to reviewers.
- When embedding runtime shell variables or command substitutions inside
  double-quoted Puppet strings, escape them, for example `\$tmpdir`, `\$1`, and
  `\$(...)`.
- When an `exec` uses `/bin/sh -c` or `/usr/bin/bash -c`, escape every dynamic
  argument first, then pass the whole script through `stdlib::shell_escape(...)`
  before appending it after `-c`.
- When SQL statements intentionally use trailing semicolons, preserve them.
  Escape the full SQL string and use `provider => shell` on the related `exec`
  when escaped semicolons, guard pipelines, or shell scripts would otherwise be
  validated by Puppet as separate commands.

Monitoring output conventions:

- Emit one natural, operator-readable summary line plus optional perfdata or
  long output.
- Do not embed perfdata-style `key=value` fragments in the summary text.
- Keep summary text cause-oriented and avoid duplicating raw numeric counters
  that are already present in perfdata.
- When a check emits multiple long-output sections, print the most
  diagnostically important section first.
- Long monitoring detail sections should have a configurable line limit and must
  say explicitly when output was truncated.

## Documentation Standards

- Write code comments, Puppet Strings comments, inline technical documentation,
  template comments, generated config comments, and this `AGENTS.md` in English.
- Write `README.md` prose in Dutch. This is the explicit exception to the
  English technical-documentation rule.
- When modifying existing code, check whether nearby comments or documentation
  are missing, outdated, duplicated, or unclear.
- Update documentation in the same change when behavior, parameters, templates,
  defaults, security settings, operational commands, public examples, or
  monitoring checks change.
- Do not add obvious comments that only repeat the code. Comments must explain
  purpose, context, constraints, side effects, or non-obvious decisions.
- Keep documentation close to the code it describes, unless the topic belongs in
  `README.md` or a dedicated architecture or operations document.
- Update `README.md` in Dutch when a public module interface, supported
  platform, installation flow, usage example, monitoring check, or security
  expectation changes.
- Keep generated config comments and template comments in English unless the
  managed software requires another language.
- Keep documentation concise and consistent with existing terminology.

## Puppet Documentation Standards

- Document public Puppet classes and defined types with Puppet Strings-style
  comments.
- Use `@summary` for a short one-line purpose.
- Add a short description when the class or defined type has operational impact,
  security impact, dependencies, or non-obvious behavior.
- Document parameters with `@param`, including expected values, defaults, and
  operational effect where relevant.
- Add an `@example` for reusable classes or defined types where usage is not
  immediately obvious.
- Use `@api public` for public entry points and `@api private` for internal
  helpers where that distinction matters.
- When changing a Puppet class, defined type, function, or template, verify
  whether its documentation still matches the implementation.
- When documentation is missing or stale in a changed area, update it in the same
  change. Do not perform unrelated documentation sweeps.

## Validation And Testing

The first-party modules at the repository root currently do not have a shared
root `Gemfile`, `Rakefile`, or first-party spec suite. Vendored submodules have
their own test setup, but that is not the default validation path for
first-party changes.

Run targeted checks for the files you changed. Use these commands when the
corresponding tools are installed:

- Changed Puppet manifests:
  `puppet parser validate <changed .pp files>`
- Changed Puppet manifests, lint:
  `puppet-lint <changed .pp files>`
- Changed ERB templates, Ruby syntax only:
  `erb -x -T '-' <changed .erb file> | ruby -c`
- Changed POSIX shell scripts or rendered shell templates:
  `sh -n <changed or rendered script>`
- Changed Bash-only scripts or rendered Bash templates:
  `bash -n <changed or rendered script>`
- Changed Puppet Strings documentation:
  `puppet strings generate --format markdown --out /tmp/puppet-modules-reference.md <changed module dirs>`
- Changed metadata JSON:
  `ruby -rjson -e 'ARGV.each { |path| JSON.parse(File.read(path)) }' <changed metadata.json files>`
- Markdown-only changes:
  `git diff --check -- <changed markdown files>`

For ERB templates that generate shell scripts, render a representative output
before running `sh -n` or `bash -n`; template syntax checks alone do not validate
the generated script.

When a shell change affects parsing, monitoring output, or status handling, run
at least one representative functional check with synthetic or stubbed input.
Include an error-path check when practical.

If a validation command cannot run locally because the tool or dependency is
missing, state that in the final response and explain what was checked instead.

## Security And Safety Boundaries

Security is a design requirement in this repository. For Puppet code, templates,
scripts, services, timers, configs, and generated files, check whether the
change affects:

- Privilege level, runtime user, groups, capabilities, or sudo usage.
- File ownership, file modes, parent directory traversal, and secret exposure.
- Use of `Sensitive[...]` or `Sensitive.new(...)`.
- Network behavior, ports, sockets, firewall assumptions, or service
  dependencies.
- Startup, shutdown, restart, ordering, and failure handling.
- Monitoring, logging, alerting, audit rules, or operational diagnostics.
- Package repositories, package installation options, or dependency trust.

Security information preservation:

- This project relies heavily on security by design. Do not remove, simplify, or
  shorten security-related instructions if doing so would remove important
  context, rationale, risks, constraints, or operational safeguards.
- When cleaning up duplicated or unclear security instructions, preserve the
  strongest applicable security requirement.
- Keep the reason behind security-sensitive rules when that reason helps prevent
  mistakes.
- Merge duplicated security rules carefully so no requirement is weakened or
  lost.
- Keep explicit warnings for secrets, credentials, permissions, TLS, headers,
  systemd hardening, infrastructure changes, input validation, and dependency
  changes where relevant.
- If a security rule appears outdated or incorrect, do not remove it silently.
  Replace it with the corrected rule and briefly document why the change was
  made.
- If there is uncertainty about a security requirement, keep the safer
  instruction and mark the point as needing review.

Repository security conventions:

- Config files are commonly `0600`.
- Root-only scripts are commonly `0700`.
- Sudoers files are `0440`.
- SSH homes and `.ssh` paths must stay tightly permissioned.
- Systemd unit files are `0644` only where systemd requires it.
- Prefer root ownership for integrity, then grant the service runtime group only
  the read or traverse access it needs.
- Public HTTP exposure does not imply that local users should be able to read
  the same files from disk.

External systems and data sanitization:

- Before using any external system, internet search, browser tool, issue
  tracker, paste service, external AI system, e-mail, or vendor support channel,
  sanitize the material first.
- Do not send raw code, configs, logs, stack traces, screenshots, secrets, keys,
  tokens, certificates, internal hostnames, internal IP addresses, private URLs,
  personal data, tenant IDs, customer data, `.env` files, kubeconfigs, database
  dumps, or production configuration files outside the local workspace.
- Share the smallest possible rewritten or synthetic example. Re-check the final
  sanitized version before sending it.

Systemd hardening:

- For new, changed, or reviewed `.service` units, assess hardening per concrete
  unit and per option. Do not add hardening blindly or as a default in a generic
  wrapper unless every current consumer has been validated or has an explicit
  opt-out.
- For each affected service, identify the final unit name, Puppet location,
  template or wrapper, `Exec*` commands, runtime `User` and `Group`,
  supplementary groups, capabilities, writable paths, device access, temporary
  directory use, home directory access, credential paths, network exposure,
  runtime language, dynamic plugins, process inspection needs,
  package-management behavior, and whether the unit is vendor-managed or
  internally generated.
- Assess these common candidates as `apply`, `do not apply`, or
  `needs more research`: `PrivateDevices=true`, `PrivateTmp=true`,
  `ProtectHome=true`, `ProtectSystem=full`,
  `SystemCallArchitectures=native`, `RestrictSUIDSGID=true`,
  `LockPersonality=true`, `NoNewPrivileges=true`,
  `MemoryDenyWriteExecute=true`, `ProtectHostname=true`, `ProtectClock=true`,
  `ProtectControlGroups=true`, `ProtectKernelLogs=true`,
  `ProtectKernelModules=true`, `ProtectKernelTunables=true`,
  `ProtectProc=invisible`, and `UMask=0077`.
- Add `UMask=0077` explicitly in the relevant service hash when it is safe.
  Omit `UMask` when the service needs the normal default mask of `0022`. Use a
  less strict non-default value such as `0027` only per service, with a comment
  explaining the shared-file, shared-socket, shared-log, or web-serving need.
- Treat timers, sockets, mounts, paths, targets, and daemon configuration
  drop-ins separately from services. For those unit types, assess the paired
  `.service` unit instead.
- Use extra care before hardening package management, provisioning, Puppet,
  GitLab omnibus supervision, certbot renewals with hooks, SSH sessions,
  monitoring executors, OpenITCOCKPIT server components with sudo behavior,
  backup or restore services, shared sockets or logs, device services, cgroup
  managers, kernel or process inspectors, and JIT or plugin-based runtimes.
- Re-check option-specific risks before applying hardening. `PrivateDevices`
  can break hardware, virtualization, storage, USB, GPU, serial, and similar
  access. `PrivateTmp` can break intentional shared temporary-file handoffs.
  `ProtectHome` can block required `/home`, `/root`, or `/run/user` access.
  `ProtectSystem=full` requires explicit writable-path exceptions for writes
  under protected paths. `NoNewPrivileges` can break `sudo`, setuid helpers, and
  file capabilities. `MemoryDenyWriteExecute` can break JIT, plugin, and dynamic
  runtime behavior. `ProtectHostname`, `ProtectClock`, kernel, cgroup, and
  `ProtectProc` restrictions can break provisioning, monitoring, inventory,
  time, kernel, process-inspection, and nested workload tools.

## Definition Of Done

An AI-generated change is complete only when:

- The changed area and related local code have been inspected.
- The change is scoped to the request and does not modify vendored code unless
  explicitly requested.
- Code comments and technical documentation are in English, while `README.md`
  prose remains Dutch.
- Puppet Strings comments, README examples, and monitoring check lists were
  updated when affected.
- Security, permissions, systemd behavior, monitoring, audit, and operational
  impact were reviewed where relevant.
- Relevant validation commands were run, or unavailable commands are listed in
  the final response with the reason they could not run.
- The final response names the changed files or code paths, the validation that
  ran, documentation updates, and any remaining assumptions or open points.

## Maintenance Of This File

Keep this file current whenever repository conventions, documentation rules,
validation commands, security requirements, coding standards, or operational
workflows change.

When modifying this file:

- Preserve the current intent of existing rules unless there is an explicit
  reason to change them.
- Do not weaken existing documentation, validation, security, or review
  requirements without clearly documenting why.
- Remove or merge duplicated instructions instead of adding another similar
  rule.
- Resolve contradictions immediately so the file always contains one clear
  instruction.
- Keep instructions concrete, compact, and understandable for AI agents that
  have no additional context.
- Process new insights into `AGENTS.md` when they affect how AI agents should
  work in this repository. This includes insights from code reviews, production
  issues, security findings, linting or test failures, recurring mistakes,
  changed tooling, changed architecture, or improved project conventions.
- Treat `AGENTS.md` as a living document: when better instructions are
  discovered, add or refine them in a compact and non-duplicated way.

Maintenance rule for AI agents: whenever an AI agent modifies a file, it must
also check whether documentation is missing, outdated, duplicated, unclear, or no
longer aligned with current insights in the changed area. If documentation is
affected, update it in the same change. If no documentation update is needed, no
extra documentation should be added.

Regression-prevention rule: when a user corrects an AI mistake or a task exposes
a repeated failure mode, add or adjust the concrete instruction that would have
prevented it, if that instruction is reusable for future agents. Name the
forbidden future behavior and the required check. For example, do not translate
`README.md` to English; before finishing documentation-rule edits, verify that
this file still says `README.md` prose must remain Dutch.

Keep project-wide rules in this root file. Put directory-specific rules in a
lower-level `AGENTS.md` only when the rule truly applies only to that subtree.
