# AGENTS.md

## Purpose

This file is the leading instruction file for AI coding agents working in this
repository. Read it together with the root `README.md` before making changes.
The README is written in Dutch and is the first source of truth for user-facing
module behavior, supported use cases, and examples. This file explains how AI
agents must work safely inside the repository.

At the time of writing there are no nested `AGENTS.md`, `AGENTS.override.md`, or
root `.github/copilot-instructions.md` files. If such files are added later, the
root `AGENTS.md` remains the baseline. Lower-level instruction files may add
stricter local rules, but they must not weaken or contradict this file.

## Repository Overview

This repository contains first-party Puppet modules for Debian and Ubuntu
servers. The modules focus on hardening, systemd-based service orchestration,
OpenITCOCKPIT-oriented monitoring, and controlled APT package management. The
README states that the project targets 64-bit systems. Do not broaden operating
system, release, or architecture support claims without updating the relevant
module metadata and the Dutch README in the same change.

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

Do not treat vendored submodules as project style examples. Keep changes inside
the first-party modules unless the task explicitly asks to update or patch a
vendored dependency.

Important layout:

- Root `README.md`: Dutch user-facing documentation and examples.
- Root `AGENTS.md`: AI-agent workflow, style, validation, and safety rules.
- `<module>/metadata.json`: Puppet Forge metadata where present.
- `<module>/manifests/`: Puppet classes and defined types.
- `<module>/templates/`: ERB templates rendered by Puppet.
- `<module>/files/`: Static files served through `puppet:///modules/...`.
- `examples/`: Example Puppet usage.

`basic_settings` is the foundation module. It provides shared orchestration for
base packages, APT sources, systemd targets, monitoring plumbing, login policy,
security tooling, package hygiene, kernel/network tuning, timezone, and Puppet
runtime behavior. Prefer extending these local helpers over introducing external
architecture.

Shared primitives in `basic_settings` include:

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

The systemd target ladder created by `basic_settings::systemd` is a core
composition mechanism:

- `${cluster_id}-system`
- `${cluster_id}-storage`
- `${cluster_id}-services`
- `${cluster_id}-production`
- `${cluster_id}-helpers`
- `${cluster_id}-require-services`

Service modules that integrate with `basic_settings` usually disable vendor
service enablement, add a `basic_settings::systemd_drop_in`, bind the service to
one of the shared targets, and add `OnFailure=notify-failed@%i.service` when
monitoring is active.

Monitoring is centralized around the OpenITCOCKPIT agent model:

- `basic_settings::monitoring` prepares `/etc/openitcockpit-agent`.
- Checks are installed under `/etc/openitcockpit-agent/plugins`.
- `concat` and `concat::fragment` build `customchecks.ini`.
- Shared monitoring defined types generate service, timer, and custom check
  registration instead of duplicating plugin wiring in each module.

## Working Rules

Before editing files:

- Read `README.md` and the relevant module files first.
- Check `git status --short` and preserve unrelated user changes.
- Identify whether the change touches a first-party module or a vendored
  submodule.
- Inspect the touched module's `metadata.json` when present.
- Read related `manifests/`, `templates/`, `files/`, README sections, examples,
  and systemd units before changing structure or behavior.
- Check whether the module already integrates with `basic_settings`,
  `basic_settings::monitoring`, `basic_settings::systemd`,
  `basic_settings::security_audit`, `php8::fpm`, `nginx`, or another local
  module.
- Look for existing ownership, mode, `require`, `notify`, and `subscribe`
  patterns before adding resources.

For every change, assess whether it affects:

- Repository conventions or coding style.
- Puppet abstractions, wrappers, or reusable patterns.
- systemd units, ordering, targets, hardening, restart behavior, or failure
  handling.
- Linux security behavior, permissions, users, groups, capabilities, sudo, or
  secrets.
- Network behavior, ports, sockets, firewall assumptions, TLS, headers, or
  service dependencies.
- Monitoring, logging, alerting, audit rules, or operational diagnostics.
- Documentation, examples, supported platforms, or operational commands.

Keep edits scoped to the requested task and the affected module. Do not perform
unrelated refactors. If a small refactor is needed to make the change safe or
clear, keep it local and explain it in the final response.

When changing systemd-related code, inspect every generated or modified unit in
scope, including `basic_settings::systemd_service`,
`basic_settings::systemd_drop_in`, vendor-unit drop-ins, direct `service`
resources, templates, files, and wrappers. Sort affected final systemd unit
names alphabetically when reporting review decisions.

## Coding Standards

### Puppet

- Use explicit typed parameters for public classes and defined types.
- Prefer parameterized classes plus small defined types over hidden behavior.
- Keep module responsibilities narrow and composable, as in `php8`,
  `php8::fpm`, `php8::fpm_pool`, `rabbitmq`, and `rabbitmq::management`.
- Reuse `basic_settings` helpers for systemd units, timers, sudoers, logrotate,
  monitoring, and audit resources before creating one-off implementations.
- Preserve explicit `require`, `notify`, and `subscribe` relationships. This
  repository relies on visible ordering more than implicit autorequires.
- When a defined type requires a parent class, guard it with
  `defined(Class['...'])` and fail clearly if the class is missing.
- When the same `defined(...)` check is needed multiple times in one manifest,
  assign it once to a clearly named variable and reuse that variable.
- Use ERB templates through `template(...)`. This repository uses `templates/`
  plus ERB, not EPP.
- Use `files/` and `puppet:///modules/...` for static assets.
- When validating file source URI schemes, include `puppet:///` wherever module
  files are valid input, not only `file:///` and HTTPS.
- Prefer predictable paths and resource titles.
- Keep package installation minimal with
  `install_options => ['--no-install-recommends', '--no-install-suggests']`
  unless a concrete package needs recommends or suggests.
- Use `purge => true`, `recurse => true`, and `force => true` only for
  directories the module fully owns.
- Preserve `replace => false` for installer-generated or first-create files that
  must survive later Puppet runs.
- Keep file ownership and modes explicit.
- Keep monitoring and audit wiring close to the managed resource.

For configurable hardening values that need a secure default, explicit opt-out,
and custom override, prefer a single `Variant[Boolean, String]` parameter, or a
narrow scalar variant such as `Variant[Boolean, Integer[0]]` for numeric values.
Resolve it once into a clearly named `*_correct` variable near related logic:
`true` means the named secure default, `false` disables the emitted setting, and
the scalar value is the explicit override. Templates must consume the resolved
value rather than reimplementing boolean/scalar handling.

When replacing older split interfaces such as `*_enable` plus `*_custom`,
`*_value`, or `*_max_age`, collapse the public API to the single meaningful
setting name unless backwards compatibility is explicitly required.

Parameter ordering and formatting:

- In class and defined-type parameter lists, put mandatory parameters first and
  sort them alphabetically by parameter name.
- Mandatory means the parameter is not typed as `Optional[...]` and has no
  default.
- After mandatory parameters, put all optional parameters alphabetically.
  Optional means the parameter is typed as `Optional[...]` or has any default
  value.
- If Puppet's left-to-right default evaluation requires a parameter to stay
  before another parameter, keep that dependency order and add a short trailing
  comment explaining why.
- Align the type column, parameter-name column, `=` signs, and default values
  across the full parameter block.

Control flow and resource structure:

- When a resource differs only by optional attributes, prefer one resource with
  precomputed `undef` values over duplicated resource blocks. Use this only when
  mutually exclusive attributes such as `source` and `content` cannot both be
  non-`undef`.
- Do not hide the main code path behind a large `else` block after a tiny guard.
  Use a short validation guard with `fail(...)` before the main resource path.
- Add short comments above non-obvious resource groups, `exec` resources, and
  security-sensitive branches. Comments must explain the decision, not restate
  the syntax.

Shell in Puppet:

- Escape shell variables and command substitutions meant for the runtime shell
  inside double-quoted Puppet strings, for example `\$tmpdir`, `\$1`, and
  `\$(...)`.
- Never interpolate raw Puppet values into `exec` `command`, `onlyif`, or
  `unless`.
- Precompute shell-safe dynamic values with `stdlib::shell_escape(...)`, name
  them with a `_shell` suffix, and use them as unquoted shell words.
- Add a short comment above each block that prepares escaped values so reviewers
  can see which later `exec`, guard, or shell script the escaping protects.
- When an `exec` uses `/bin/sh -c` or `/usr/bin/bash -c`, escape every dynamic
  argument first, then pass the whole script through `stdlib::shell_escape(...)`
  before appending it after `-c`.
- When SQL statements intentionally use trailing semicolons, preserve them.
  Escape the full SQL string and use `provider => shell` when escaped semicolons
  or shell guards would otherwise be parsed as separate commands.
- Prefer `/usr/bin/printf %s ${value_shell}` for dynamic shell content.

Do not introduce a local variable for a value used only once unless the variable
name adds domain meaning or removes a real readability problem.

### Shell Scripts And Monitoring Checks

Treat new shell scripts and shell templates as POSIX shell by default and use
`#!/bin/sh`. Use Bash only when the implementation requires Bash features. Known
Bash exceptions are:

- `mysql/templates/grant.sh`
- `mysql/files/automysqlbackup`
- `basic_settings/files/network/rxbuffer`
- `basic_settings/templates/login/pam/notify`

When touching an existing Bash script, keep Bash only if the implementation
still needs it. State the reason in the final response when a Bash-only
exception remains.

Shell conventions:

- Monitoring checks generally use `#!/bin/sh` and Nagios-style exit codes.
- Discover dependencies with direct `command -v` assignments, for example
  `TAIL=$(command -v tail 2>/dev/null) || die "tail not available"`.
- Use shell builtins such as `printf` directly.
- Keep monitoring check setup in this order: fail helper, binary checks,
  default/config variables, option parsing, helper functions, then main logic.
- Quote variables consistently and keep command dependencies explicit.
- Use `printf`, not non-portable `echo`.
- Represent embedded line breaks with `printf` formatting and escaped `\n`.
- Use explicit sentinel tokens for serialized command-substitution metadata
  instead of newline-marker tricks.
- Store shell lists as comma-separated values and split them deliberately.
- Keep single-use shell logic inline unless a function materially improves reuse
  or readability.
- Prefer the main path in `if` branches and put smaller exceptional fallbacks in
  `else`.
- Only mark real executables as executable.

Monitoring output conventions:

- Emit one natural, operator-readable summary line plus optional perfdata or
  long output.
- Do not embed perfdata-style `key=value` fragments in the summary text.
- Keep summary text cause-oriented; put detailed counters in perfdata or long
  output.
- Print the most diagnostically important long-output section first.
- Long detail sections must have a configurable line limit and state explicitly
  when output was truncated.

When changing monitoring checks, preserve the external contract unless the task
explicitly changes it. The contract includes exit codes, summary-line shape,
perfdata keys, option flags, generated path names, and registration names.

### Dependencies

This repository prefers tight internal Puppet integration over large external
Puppet libraries.

- Prefer extending local modules over adding community modules.
- Do not add external Docker, MySQL, Nginx, RabbitMQ, or similar Puppet modules
  only because they exist.
- Keep the current dependency set small: `stdlib`, `concat`, `reboot`,
  `timezone`, and `debconf`.
- Justify any new dependency by explaining why local modules cannot handle the
  need cleanly.
- Prefer internal implementation when it gives better control over integration,
  security, systemd behavior, monitoring, and package policy.

## Documentation Standards

- Write all code comments and technical documentation in English.
- Keep the root `README.md` in Dutch unless the user explicitly asks otherwise.
- When modifying existing code, check whether nearby comments or documentation
  are missing, outdated, duplicated, or unclear.
- Update documentation in the same change when behavior, parameters, templates,
  defaults, security settings, monitoring checks, examples, or operational
  commands change.
- Do not add obvious comments that only repeat the code. Comments must explain
  purpose, context, constraints, side effects, or non-obvious decisions.
- Keep documentation close to the code it describes, unless the topic belongs in
  the root README or a separate architecture/operations document.
- Match the current README tone, structure, and sectioning. Use the existing
  `##` sections and `### Voorbeeld` / `### Voorbeelden` pattern.
- Start README prose list items with a capital letter. Keep exact code
  identifiers, module names, class names, paths, and literals in their original
  case.
- Add or update example Puppet snippets when behavior changes materially.
- If you add, rename, or remove a monitoring check, update the README `## Checks`
  section.

Meaningful README updates are required for new functionality, removed
functionality, changed behavior, new user-facing parameters, changed module
integration, changed operational assumptions, new monitoring checks, changed
security expectations, or changed install/usage flow.

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
- When changing a Puppet class, defined type, function, or template, verify
  whether its documentation still matches the implementation.
- Keep generated config comments and inline config comments in English unless
  the managed software requires another language.

## Validation And Testing

There is no root first-party CI, root `Gemfile`, root `Rakefile`, or project-wide
Puppet test suite for the custom modules. The vendored submodules have their own
tooling; do not use those Rakefiles as validation for first-party modules.

Run targeted checks for the files you touched. If a required command is not
installed locally, state that clearly in the final response and explain what you
checked instead.

Useful discovery commands:

```sh
git diff --name-only
git diff --name-only -- '*.pp'
git diff --name-only -- 'metadata.json' '*/metadata.json'
git diff --check
```

Puppet checks, when Puppet tooling is available:

```sh
puppet parser validate <changed-manifest.pp> [...]
puppet-lint <changed-manifest.pp> [...]
```

Template checks:

```sh
erb -P -x -T '-' <template-file> | ruby -c
```

The ERB syntax check only validates Ruby/ERB syntax. For shell templates, render
representative output for the changed branch or mode and then run `sh -n` or
`bash -n` on the rendered script.

Shell checks:

```sh
sh -n <changed-posix-script>
bash -n <changed-bash-script>
```

JSON metadata checks:

```sh
ruby -rjson -e 'ARGV.each { |f| JSON.parse(File.read(f)); puts f }' <metadata.json> [...]
```

For functional changes, also verify:

- Changed class and defined-type guards still match actual inclusion order.
- File modes, ownership, and `Sensitive[...]` / `Sensitive.new(...)` handling are
  appropriate.
- Monitoring, sudoers, logrotate, audit, and systemd paths still match generated
  filenames and service names.
- Shell changes that affect parsing, monitoring output, or status handling have
  at least one representative success-path check and one practical error-path
  check.
- Required README and AGENTS updates were considered.

## Security And Safety Boundaries

Security is a design requirement in this repository. Assess security during
design, not only at final review. Preserve existing hardening where it is still
correct, and improve it when that can be done without breaking the application.

### Security Information Preservation

This project relies heavily on security by design. Do not remove, simplify, or
shorten security-related instructions if doing so would remove important
context, rationale, risks, constraints, or operational safeguards.

When cleaning up duplicated or unclear security instructions:

- Preserve the strongest applicable security requirement.
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

### Security Review Checklist

For every change to Puppet code, templates, scripts, services, timers, configs,
or generated files, check:

- Can this run with less privilege or as a more constrained service user?
- Can systemd isolation be tighter without breaking behavior?
- Are ownership and file modes as restrictive as the operational need allows?
- Which runtime identity reads each generated file, and do parent directories
  grant only the needed traverse access?
- Are secrets and sensitive config values kept out of world-readable files?
- Is `Sensitive[...]` or `Sensitive.new(...)` needed for file content or `exec`
  commands?
- Is execute permission granted only to true executables?
- Is world-read or group-write access justified?
- Does the change introduce a trust boundary, sudo path, writable path, exposed
  port, capability, or privilege assumption?
- Can the design be simplified to reduce attack surface?
- Does a new dependency add avoidable risk or complexity?
- Does the new sensitive surface need matching audit or monitoring coverage?

Repository-specific security conventions:

- Config files are commonly `0600`.
- Static daemon-readable fallback files should prefer root ownership with
  service-group read access, such as directory mode `0710` and file mode `0640`,
  instead of world-readable files.
- Root-only scripts are commonly `0700`.
- Sudoers files are `0440`.
- SSH homes and `.ssh` paths are tightly permissioned.
- Systemd unit files are usually `0644` where systemd requires it.
- Many services are hardened with systemd drop-ins instead of trusting package
  defaults.
- Package installs usually use `--no-install-recommends` and
  `--no-install-suggests`.
- Sensitive operations often add audit rules through
  `basic_settings::security_audit`.

Public HTTP exposure does not imply every local user should have filesystem read
access to the same file. If you must weaken a permission, sandbox, or trust
model, document the reason in code and update the README when the operational
expectation changes.

### Data Sanitization Before External Use

Before using any external system, the internet, or a tool outside the local IDE
or repository context, treat the material as potentially sensitive.

Never send raw code, configuration, logs, stack traces, screenshots, or
operational data externally before checking whether they contain sensitive
information. Remove, mask, or anonymize sensitive information first. Apply this
rule to web searches, browser tools, external AI services, issue trackers, paste
services, chat, email, vendor support, documentation sites, and any other
external system.

Sensitive information includes at minimum:

- Passwords, API keys, access tokens, session tokens, and private keys.
- SSH keys, certificates, certificate material, token files, kubeconfigs, and
  `.env` files.
- Connection strings and database credentials.
- Internal hostnames, internal IP addresses, private URLs, usernames, tenant
  identifiers, and internal project identifiers that are not required for the
  question.
- Customer data, patient data, and personal data.

Prefer a rewritten or synthetic example over real production data. If there is
any doubt whether content is sensitive, do not send it externally until it has
been sanitized.

### systemd Hardening

Review systemd hardening per concrete `.service` unit. These service-execution
options are not meaningful defaults for `.timer`, `.socket`, `.mount`, `.path`,
`.target`, `journald.conf`, `resolved.conf`, `timesyncd.conf`, or similar daemon
configuration drop-ins. For a timer, socket, or path unit, review the paired
`.service` unit.

For every new, changed, or newly reviewed service, identify:

- Final unit name and Puppet location.
- Template, wrapper, or vendor unit being modified.
- `ExecStart`, `ExecStartPre`, `ExecStartPost`, `ExecReload`, and `ExecStop`.
- Runtime `User`, `Group`, supplementary groups, capabilities, and sudo or
  setuid usage.
- Writable paths, generated files, directories, sockets, logs, and temporary
  file behavior.
- Device access, home directory access, credential paths, network exposure, and
  package-management behavior.
- Runtime language, interpreter or VM, plugins, JIT/code generation, and process
  introspection needs.

Mark every candidate option as `apply`, `do not apply`, or `needs more research`
in the related analysis. Do not add hardening blindly. Prefer a documented
exception over a hardening change that causes runtime failures or operational
surprises.

Add `UMask=0077` explicitly in the relevant service hash, close to other
hardening options such as `PrivateTmp`, `ProtectHome`, and `ProtectSystem`. Do
not inject it invisibly from a generic wrapper or template. If a service needs
the normal Linux default mask `0022`, omit `UMask`. If it needs a shared
non-default mask such as `0027`, set it per service and document the reason next
to the override.

Candidate options and required risk checks:

| Option | Do not apply until these risks are checked |
| --- | --- |
| `PrivateDevices=true` | Real device nodes, storage, hardware, USB, virtualization, containers, RTC, GPU, serial, smartcard, tape, scanner, printer, or low-level network devices. |
| `PrivateTmp=true` | Intentional file exchange with other units through shared `/tmp` or `/var/tmp`. |
| `ProtectHome=true` | Required access to `/home`, `/root`, or `/run/user`, including SSH material, web content, backups, or application data. |
| `ProtectSystem=full` | Writes under `/usr`, `/boot`, `/etc`, or other protected paths without matching writable exceptions. |
| `SystemCallArchitectures=native` | 32-bit, legacy ABI, Wine, QEMU-user, emulation, `setarch`, or compatibility workloads. |
| `RestrictSUIDSGID=true` | Install, restore, provisioning, package-management, or workflows that intentionally set SUID/SGID bits or SGID directories. |
| `LockPersonality=true` | Software that changes execution domain, disables ASLR through personality, or uses compatibility modes. |
| `NoNewPrivileges=true` | `sudo`, `su`, `runuser`, `pkexec`, setuid helpers, file capabilities, or runtime privilege escalation. |
| `MemoryDenyWriteExecute=true` | JIT or runtime executable code: JVM, .NET, Node.js/V8, Chromium/Electron, LuaJIT, Erlang/BEAM native code, WebAssembly, database JIT, PCRE-JIT, plugins, executable stacks, trampolines, runtime patching, security/observability injection, `/dev/shm`, `memfd_create`, or unknown binary blobs. |
| `ProtectHostname=true` | Hostname/domain changes, `hostnamectl`, cloud-init/provisioning hostname workflows, or agents that need real-time hostname changes for monitoring, inventory, licensing, clustering, or registration. |
| `ProtectClock=true` | System or hardware clock changes, RTC access, time synchronization, `adjtimex`/`clock_adjtime`, wake alarms, time-discipline monitoring, backup/scheduling RTC behavior, NTP, chrony, `systemd-timesyncd`, `hwclock`, or VM guest tools. |
| `ProtectControlGroups=true` | Container managers, VM/container runtimes, nested service managers, workload supervisors, resource-accounting agents, orchestration, troubleshooting tools, or services that manage or intentionally inspect cgroups. |
| `ProtectKernelLogs=true` | `/dev/kmsg`, `/proc/kmsg`, `dmesg`, kernel-log collectors, low-level security agents, troubleshooting agents, or monitoring plugins that inspect kernel messages. |
| `ProtectKernelModules=true` | `modprobe`, `insmod`, `rmmod`, DKMS, kernel module build/install workflows, direct `/usr/lib/modules` access, storage, network, virtualization, container, hardware-management, security, or observability agents that depend on module operations. |
| `ProtectKernelTunables=true` | Sysctl management, provisioning, firewall/network tuning, storage tuning, power or hardware management, container/virtualization setup, low-level security agents, or monitoring that inspects `/proc/kallsyms`, `/proc/kcore`, `/proc/sys`, `/sys`, `/proc/sysrq-trigger`, `/proc/acpi`, `/proc/fs`, or `/proc/irq`. |
| `ProtectProc=invisible` | Cross-user process inspection, process supervisors, monitoring plugins, inventory agents, security agents, troubleshooting tools, applications that scan `/proc`, unrestricted root services, services retaining `CAP_SYS_PTRACE`, host-visible mount behavior, host `/proc` assumptions, or kernels without per-mount `hidepid` support. |
| `UMask=0077` | Group-readable files, group-writable directories, shared Unix sockets, shared logs, web assets, backup artifacts, deployment outputs, temporary hand-offs, or package defaults that require `0022` or a documented shared mask such as `0027`. |

Known lower-risk candidates are simple internally generated oneshot services that
execute a known native binary or root-only script and do not use shared temp
files, shared generated files, shared sockets, shared logs, device access,
protected-path writes, privilege escalation, compatibility ABIs, JIT/code
generation, hostname or clock management, kernel logs/modules/tunables, cgroup
management, cross-user process inspection, dynamic plugins, or unknown
third-party binary behavior.

Known higher-risk categories include package-management and provisioning units,
Puppet agent/server units, GitLab omnibus supervision, certbot renewals with
hooks, SSH login/session units, monitoring executors, OpenITCOCKPIT server
components, backup/restore services, services creating files for web servers or
deployment users, services creating shared sockets or logs, services using file
capabilities or devices, Java/JVM, .NET, Node.js/V8, browser/Electron,
database-JIT, PCRE-JIT, plugin-based runtimes, and any service that may call
`sudo`, `su`, `runuser`, `pkexec`, or application-specific helper binaries.

When changing a generic systemd wrapper such as
`basic_settings::systemd_service` or `basic_settings::systemd_drop_in`, inspect
the wrapper and every known consumer. Add a wrapper default only when every
current consumer is validated, or when the wrapper supports explicit per-service
opt-outs with documented technical reasons.

## Definition Of Done

An AI-generated change is complete only when:

- The relevant README, module metadata, manifests, templates, files, and examples
  were inspected.
- Changes are scoped to first-party modules unless dependency work was explicitly
  requested.
- Duplicate, unclear, or outdated nearby documentation was fixed when affected.
- Code comments and technical documentation are in English.
- User-facing README changes, when required, are in Dutch.
- Puppet Strings documentation still matches changed public classes and defined
  types.
- Security, permissions, secrets, systemd behavior, monitoring, logging, audit,
  and operational impact were reviewed for the touched area.
- Relevant validation commands were run, or unavailable commands are clearly
  reported with the fallback checks that were performed.
- `git diff --check` passes.
- The final response lists changed files or code paths, security/systemd review
  notes, README/AGENTS documentation decisions, validation run, and any open
  assumptions or follow-up input needed.

## Maintenance Of This File

Keep this `AGENTS.md` file up to date whenever repository conventions,
documentation rules, validation commands, security requirements, coding
standards, or operational workflows change.

When modifying this file:

- Preserve the current intent of existing rules unless there is an explicit
  reason to change them.
- Do not weaken existing documentation, validation, security, or review
  requirements without clearly documenting why.
- Remove or merge duplicated instructions instead of adding another similar
  rule.
- Resolve contradictions immediately so the file always contains one clear
  instruction.
- Keep instructions concrete, compact, and understandable for AI agents that have
  no additional context.
- If a repeated AI mistake is found during development or review, update
  `AGENTS.md` so the same mistake is less likely to happen again.
- Process new insights into `AGENTS.md` when they affect how AI agents should
  work in this repository. This includes insights from code reviews, production
  issues, security findings, linting or test failures, recurring mistakes,
  changed tooling, changed architecture, or improved project conventions.
- Treat `AGENTS.md` as a living document: when better instructions are
  discovered, add or refine them in a compact and non-duplicated way.

Whenever an AI agent modifies a file, it must also check whether documentation is
missing, outdated, duplicated, unclear, or no longer aligned with current
insights in the changed area. If documentation is affected, update it in the same
change. If no documentation update is needed, no extra documentation should be
added.
