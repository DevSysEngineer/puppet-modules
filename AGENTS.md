# AGENTS.md

## Project Overview

This repository is a collection of first-party Puppet modules for Debian and Ubuntu servers, with a strong focus on hardening, systemd-based service orchestration, monitoring, and controlled package management. The root `README.md` is written in Dutch and is the first source of truth for how the project presents itself, which use cases are supported, and how modules are expected to be combined.

Project-owned modules in this repository:

- `basic_settings`
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

Vendored Git submodules in this repository:

- `concat`
- `debconf`
- `reboot`
- `stdlib`
- `timezone`

Do not treat vendored submodules as the house style for this project. Unless the task is explicitly about updating or patching a dependency, keep changes inside the first-party modules listed above.

The current metadata and README target 64-bit Debian/Ubuntu systems. Do not broaden support claims casually. If you change supported platforms, update module metadata and the Dutch README together.

## Start Here Before Making Changes

Read `README.md` first, every time. The README explains the intended module combinations, the hardening posture, the monitoring story, and the documentation tone that the project already uses.

Before editing code:

- Identify whether you are changing a first-party module or a vendored submodule.
- Inspect the touched module's `metadata.json` when present.
- Read the relevant `manifests/`, `templates/`, and `files/` in the touched module before changing structure or style.
- Check whether the module already integrates with `basic_settings`, `basic_settings::monitoring`, `basic_settings::systemd`, `basic_settings::security_audit`, `php8::fpm`, `nginx`, or other local modules.
- Look for existing file ownership, mode, `require`, `notify`, and `subscribe` patterns before adding new resources.

## Architecture And Module Interaction

`basic_settings` is the foundation module. It is not just another module: it is the shared orchestration layer for base packages, APT sources, systemd targets, monitoring plumbing, login policy, security tooling, package hygiene, kernel/network tuning, timezone, and Puppet runtime behavior.

Important architectural patterns in this repository:

- Modules are usually usable standalone, but many of them opportunistically integrate with `basic_settings` when its classes are present.
- Service modules often check `defined(Class['basic_settings::...'])` or `defined(Package['systemd'])` and then bind themselves into shared systemd targets instead of relying on default vendor enablement.
- Defined types commonly enforce parent inclusion with explicit guard clauses and `fail(...)` messages. Keep that pattern when a defined type depends on a base class.

Shared primitives live in `basic_settings`, especially:
- `basic_settings::systemd_target`
- `basic_settings::systemd_drop_in`
- `basic_settings::systemd_service`
- `basic_settings::systemd_timer`
- `basic_settings::monitoring_service`
- `basic_settings::monitoring_custom`
- `basic_settings::monitoring_timer`
- `basic_settings::monitoring_npm_audit`
- `basic_settings::security_audit`
- `basic_settings::io_logrotate`
- `basic_settings::login_sudo`

The systemd target ladder created by `basic_settings::systemd` is a core composition mechanism:

- `${cluster_id}-system`
- `${cluster_id}-storage`
- `${cluster_id}-services`
- `${cluster_id}-production`
- `${cluster_id}-helpers`
- `${cluster_id}-require-services`

When a service module integrates with `basic_settings`, it usually:

- disables the vendor service's default enablement
- adds a `basic_settings::systemd_drop_in`
- binds the service to one of the shared targets above
- adds `OnFailure=notify-failed@%i.service` when monitoring is active

Monitoring is centralized around the OpenITCOCKPIT agent model:

- `basic_settings::monitoring` prepares `/etc/openitcockpit-agent`
- checks are installed under `/etc/openitcockpit-agent/plugins`
- `concat` and `concat::fragment` are used to build `customchecks.ini`
- service and timer checks are generated through shared defined types instead of duplicating plugin registration logic in every module

Examples of module composition that should guide future changes:

- `nginx`, `rabbitmq`, `gitlab`, `mysql`, `php8::fpm`, `letsencrypt`, `naemon`, `openitcockpit::agent`, and `openitcockpit::server` all hook into shared systemd and monitoring primitives when available.
- `mysql` integrates with `php8::fpm` and `puppet` via systemd drop-ins rather than external dependency modules.
- `openitcockpit::server` assumes tight local integration with Nginx, PHP-FPM, Naemon paths, and several service-specific systemd drop-ins.
- `netplanio` reads network/kernel state from `basic_settings` when present instead of inventing a second configuration source.
- `ssh`, `login`, `network`, `security`, and `packages` add audit coverage through `basic_settings::security_audit` rather than ad hoc audit files.

## Security-By-Design Rules

Security is a design requirement in this repository, not an optional extra. Future changes must preserve and improve the repo's hardening posture.

For every change to Puppet code, templates, scripts, services, timers, configs, or generated files, check all of the following:

- Can this run with less privilege?
- Can this run as a more constrained service user instead of root?
- Can this be isolated further with systemd sandboxing such as `PrivateTmp`, `PrivateDevices`, `ProtectHome`, `ProtectSystem`, `ReadWritePaths`, `LimitNOFILE`, or tighter target binding?
- Are ownership and file modes as restrictive as possible for the operational need?
- Are secrets, credentials, and sensitive config values kept out of world-readable files?
- Is `Sensitive[...]` or `Sensitive.new(...)` needed for file content or `exec` commands?
- Is execute permission granted only to true executables?
- Is world-read or group-write access justified, or is it a leftover convenience that should be removed?
- Does the change introduce a new trust boundary, sudo path, writable path, or privilege assumption?
- Can the design be simplified to reduce attack surface?
- Does a new dependency add avoidable risk or unnecessary complexity?
- If the module already applies audit coverage or monitoring, does the new sensitive surface need matching coverage?

Prefer the safer design when it still fits the project. Do not preserve an unsafe pattern just because it already exists once.

Repository-specific security conventions to preserve:

- Config files are commonly `0600`.
- Root-only scripts are commonly `0700`.
- Sudoers files are `0440`.
- SSH homes and `.ssh` paths are tightly permissioned.
- Systemd unit files are usually `0644` only where systemd requires it.
- Many services are explicitly hardened with systemd drop-ins instead of trusting package defaults.
- Package installs usually use `--no-install-recommends` and `--no-install-suggests`.
- Sensitive operations often add audit rules through `basic_settings::security_audit`.

If you must weaken a permission, sandbox, or trust model, document the reason in the code and update the README when the operational expectation changes.

## Puppet Style

Derive style from the first-party modules already in this repository.

Follow these Puppet conventions:

- Keep module interfaces explicit with typed parameters.
- Prefer parameterized classes plus small defined types over hidden behavior.
- Keep module responsibilities narrow and composable, as in `php8`, `php8::fpm`, `php8::fpm_pool` or `rabbitmq` plus `rabbitmq::management`.
- Reuse `basic_settings` shared defined types instead of creating one-off service, timer, logrotate, sudoers, monitoring, or audit resources in every module.
- Preserve explicit `require`, `notify`, and `subscribe` relationships. This codebase relies on visible ordering more than implicit resource autorequires.
- When a defined type requires a parent class, guard it with `defined(Class['...'])` and fail clearly if the class is missing.
- Use ERB templates via `template(...)`. This repository currently uses `templates/` plus ERB, not EPP.
- Use `files/` plus `puppet:///modules/...` for static assets.
- Prefer predictable paths and resource titles. Do not introduce surprising naming schemes.
- Keep package installation minimal with `install_options => ['--no-install-recommends', '--no-install-suggests']` unless there is a concrete reason not to.
- When a module fully owns a config directory, the existing style often uses `purge => true`, `recurse => true`, and `force => true`. Only do that for trees the module truly owns.
- When installer-generated files must survive, the existing style uses `replace => false`. Preserve that behavior where it matters.
- Keep file modes and ownership explicit.
- Keep monitoring and audit wiring close to the managed resource so operational visibility changes with the feature.
- Keep parameter lists and similar aligned assignments vertically when the surrounding module already uses that style, including aligning the `=` signs into one visual column.
- Add a short comment above non-obvious Puppet resource blocks or grouped resource changes when the purpose is not immediately clear from the resource title alone.
- This is especially important for `exec`, `file`, `package`, and other mixed resource sequences that bootstrap repositories, handle temporary files, manipulate permissions, or enforce security-sensitive ordering.

Use local modules as integration points instead of importing foreign architecture. For example, if a service needs a systemd unit, timer, sudo rule, OpenITCOCKPIT check, or logrotate config, prefer the existing `basic_settings` helpers over adding a new external abstraction.

If you add a new first-party module, follow the existing module layout:

- `manifests/`
- `templates/`
- `files/` when needed
- `metadata.json` aligned with the rest of the first-party modules

## Shell Script Rules

Project rule: treat `.sh` files as POSIX shell scripts and use `#!/bin/sh` by default.

Do not assume Bash features unless the repository clearly and explicitly requires them for that file. Existing Bash-based files in this repository are legacy exceptions, not the rule. Known exceptions currently include:

- `mysql/templates/grant.sh`
- `mysql/files/automysqlbackup`
- `basic_settings/files/network/rxbuffer`
- `basic_settings/templates/login/pam/notify`

When touching an existing Bash script:

- keep Bash only if the implementation truly needs it
- otherwise prefer a safe migration to POSIX syntax
- do not copy Bash-only idioms into new scripts
- if a Bash-only exception must remain, keep the reason explicit in the code review or final handoff

Shell conventions already visible in this repository:

- monitoring checks generally use `#!/bin/sh`
- dependencies are discovered with `command -v`
- error helpers are small and direct
- scripts are operationally minimal and avoid unnecessary layers
- monitoring checks should return standard Nagios-style status codes
- checks often emit a single summary line and optional perfdata / long output

Shell safety requirements:

- Quote variables consistently.
- Use `printf` instead of relying on non-portable `echo` behavior.
- Keep command dependencies explicit.
- Keep scripts readable; these files are operational tooling, not generic libraries.
- Only mark real executables as executable.
- Match file modes to actual need: root-only scripts should stay root-only unless a non-root runtime is required.

## Dependency Guidance

This repository prefers tight internal Puppet integration over introducing large external Puppet libraries.

Follow these rules:

- Prefer extending the existing local modules over adding community modules.
- Do not default to external Docker, MySQL, Nginx, RabbitMQ, or similar Puppet modules just because they exist.
- Use the current small dependency set only where it already fits: `stdlib`, `concat`, `reboot`, `timezone`, and `debconf`.
- If a new dependency is proposed, justify why the project's own modules cannot handle the need cleanly.
- Prefer internal implementation when it gives better control over integration, security, systemd behavior, monitoring, and package policy.

This repo already manages package repositories, keys, systemd policy, monitoring plugins, logrotate, and audit rules in-house. Preserve that architectural preference.

## README And Documentation

README maintenance is mandatory.

Whenever you add a new module or make a meaningful change to an existing module, you must review and update `README.md` in the same change.

Meaningful changes include:

- new functionality
- removed functionality
- changed behavior
- new parameters users are expected to set
- changed integration points between modules
- changed operational assumptions
- new monitoring checks
- changed security expectations
- changed install or usage flow

README rules for this repository:

- Write README updates in Dutch.
- Match the current README's tone, structure, and sectioning.
- Keep the style consistent with the existing `##` sections and `### Voorbeeld` / `### Voorbeelden` pattern.
- Add or update example Puppet snippets when behavior changes materially.
- If you add or rename a monitoring check, update the `## Checks` section.
- Do not paste in generic English boilerplate or documentation written in a different style.

README updates are part of the implementation, not optional follow-up work.

## Validation Before Finishing

There is no first-party test suite or CI structure in the custom modules at the root of this repository. Validation still matters, so run targeted checks for the files you touched.

At minimum:

- validate changed Puppet manifests for syntax and obvious relationship errors
- verify changed class / defined-type guards still match actual inclusion order
- syntax-check changed shell scripts with `sh -n` when they are POSIX
- syntax-check changed Bash exceptions with `bash -n` only when Bash is intentionally required
- review file modes, ownership, and `Sensitive` handling for every touched resource
- verify monitoring, sudoers, logrotate, audit, and systemd paths still line up with the generated filenames and service names
- review whether a README update was required and completed

If you could not run an important validation step, say so explicitly in your final handoff.
