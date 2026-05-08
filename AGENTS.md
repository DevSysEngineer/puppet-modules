# AGENTS.md

## Project Overview

This repository is a collection of first-party Puppet modules for Debian and Ubuntu servers, with a strong focus on hardening, systemd-based service orchestration, monitoring, and controlled package management. The root `README.md` is written in Dutch and is the first source of truth for how the project presents itself, which use cases are supported, and how modules are expected to be combined.

Project-owned modules in this repository:

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

Vendored Git submodules in this repository:

- `concat`
- `debconf`
- `reboot`
- `stdlib`
- `timezone`

Do not treat vendored submodules as the house style for this project. Unless the task is explicitly about updating or patching a dependency, keep changes inside the first-party modules listed above.

The first-party module metadata that exists targets Debian and Ubuntu releases, and the README states 64-bit systems. Do not broaden support claims casually. If supported platforms, releases, or architecture assumptions change, update the relevant module metadata and the Dutch README together.

## Start Here Before Making Changes

Read `README.md` first, every time. The README explains the intended module combinations, the hardening posture, the monitoring story, and the documentation tone that the project already uses.

Treat `AGENTS.md` as a living repository instruction file. For every code change, check whether it still describes the current workflow and update it only when the change creates reusable guidance, changed expectations, or new constraints.

Before editing code:

- Identify whether you are changing a first-party module or a vendored submodule.
- Inspect the touched module's `metadata.json` when present.
- Read the relevant `manifests/`, `templates/`, and `files/` in the touched module before changing structure or style.
- Check whether the module already integrates with `basic_settings`, `basic_settings::monitoring`, `basic_settings::systemd`, `basic_settings::security_audit`, `php8::fpm`, `nginx`, or other local modules.
- Look for existing file ownership, mode, `require`, `notify`, and `subscribe` patterns before adding new resources.
- Inspect related code before applying a change, not only the file that appears to need editing. Check related Puppet classes, defined types, templates, files, systemd units, README sections, and existing examples whenever they influence the correct implementation.

For every change, assess whether it affects:

- Repository conventions or coding style.
- Puppet abstractions, wrappers, or reusable patterns.
- systemd unit behavior.
- systemd hardening.
- Linux security behavior.
- Permissions, ownership, users, groups, capabilities, or sudo usage.
- Network behavior, ports, sockets, firewall assumptions, or service dependencies.
- Startup, shutdown, restart, ordering, and failure handling.
- Monitoring, logging, alerting, or operational diagnostics.
- Security-by-design principles used in this repository.

Only apply the code change after the existing structure and behavior are sufficiently understood. The change must fit the current repository design unless there is a clear technical or security reason to improve that design.

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
- `basic_settings::systemd_network`
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

- Disables the vendor service's default enablement.
- Adds a `basic_settings::systemd_drop_in`.
- Binds the service to one of the shared targets above.
- Adds `OnFailure=notify-failed@%i.service` when monitoring is active.

Monitoring is centralized around the OpenITCOCKPIT agent model:

- The `basic_settings::monitoring` class prepares `/etc/openitcockpit-agent`.
- Checks are installed under `/etc/openitcockpit-agent/plugins`.
- The `concat` and `concat::fragment` types are used to build `customchecks.ini`.
- Service and timer checks are generated through shared defined types instead of duplicating plugin registration logic in every module.

Examples of module composition that should guide future changes:

- The `nginx`, `rabbitmq`, `gitlab`, `mysql`, `php8::fpm`, `letsencrypt`, `naemon`, `openitcockpit::agent`, and `openitcockpit::server` modules all hook into shared systemd and monitoring primitives when available.
- The `mysql` module integrates with `php8::fpm` and `puppet` via systemd drop-ins rather than external dependency modules.
- The `openitcockpit::server` class assumes tight local integration with Nginx, PHP-FPM, Naemon paths, and several service-specific systemd drop-ins.
- The `netplanio` module reads network and kernel state from `basic_settings` when present instead of inventing a second configuration source.
- The `ssh`, `login`, `network`, `security`, and `packages` classes add audit coverage through `basic_settings::security_audit` rather than ad hoc audit files.

## Security-By-Design Rules

Security is a design requirement in this repository, not an optional extra. When changing Linux services, systemd units, deployment automation, Docker, Puppet, permissions, network configuration, or monitoring, assess security during the design instead of treating it as a final review step. Preserve existing hardening where it is still correct, and improve it when that can be done without breaking the application.

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

## systemd Hardening Guideline

For new, changed, or newly reviewed systemd units, assess hardening per concrete `.service` unit and per option. Do not use existing hardening as the scope filter: a service with no hardening may need it, and an existing option may need an exception or rollback if the application behavior changed. Do not assume an option is safe only because it is already used elsewhere, or unnecessary only because the current unit does not use it yet.

The following options are common candidates in this repository, but none of them is a guaranteed baseline:

- `PrivateDevices=true`
- `PrivateTmp=true`
- `ProtectHome=true`
- `ProtectSystem=full`
- `SystemCallArchitectures=native`
- `RestrictSUIDSGID=true`
- `LockPersonality=true`
- `NoNewPrivileges=true`
- `MemoryDenyWriteExecute=true`
- `ProtectHostname=true`
- `ProtectClock=true`
- `ProtectControlGroups=true`
- `ProtectKernelLogs=true`
- `ProtectKernelModules=true`
- `ProtectKernelTunables=true`
- `ProtectProc=invisible`
- `UMask=0077`

Use this assessment process:

- Mark every candidate option as `apply`, `do not apply`, or `needs more research` in the related analysis.
- Revalidate existing settings when the unit, wrapper, package, runtime user, data paths, service role, runtime language, package version, or deployment model changes.
- Identify the final unit name, Puppet location, template or wrapper, `ExecStart`, `ExecStartPre`, `ExecStartPost`, `ExecReload`, `ExecStop`, runtime `User` and `Group`, supplementary groups, capabilities, writable paths, file and directory creation behavior, device access, temporary directory usage, home directory access, credential paths, network exposure, runtime language, interpreter or VM, dynamically loaded plugins/modules, process introspection requirements, package-management behavior, and whether the unit is vendor-managed or internally generated.
- Add `UMask=0077` explicitly in the relevant service hash, close to other hardening options such as `PrivateTmp`, `ProtectHome`, and `ProtectSystem`. Do not inject it invisibly from a generic wrapper or template.
- If the service needs the normal systemd/Linux default mask of `0022`, omit `UMask`. If it needs a non-default shared-permission mask such as `0027`, set it in that service's hash and document the reason next to the override.

The primary goal is to improve security without breaking applications. Do not add hardening as a blind default. Prefer a documented exception over an unsafe hardening change that causes runtime failures, degraded functionality, or operational surprises.

Check these option-specific risks every time:

- `PrivateDevices=true`: unsafe for units that need real device nodes, storage, hardware, USB, virtualization, container, RTC, GPU, serial, smartcard, tape, scanner, printer, or low-level network device access.
- `PrivateTmp=true`: unsafe when the service intentionally exchanges files with other units through shared `/tmp` or `/var/tmp`.
- `ProtectHome=true`: unsafe when the service must read or write `/home`, `/root`, or `/run/user` paths, including user SSH material, web content, backup sources, or application data.
- `ProtectSystem=full`: unsafe without matching writable path exceptions when the service must write under `/usr`, `/boot`, `/etc`, or other protected locations.
- `SystemCallArchitectures=native`: unsafe for 32-bit, legacy ABI, Wine, QEMU-user, emulation, or `setarch` workloads.
- `RestrictSUIDSGID=true`: unsafe for install, restore, provisioning, package-management, or collaboration workflows that intentionally set SUID/SGID bits or SGID directories.
- `LockPersonality=true`: unsafe for software that changes execution domain, disables ASLR through personality, or uses compatibility modes.
- `NoNewPrivileges=true`: unsafe for units that need `sudo`, `su`, `runuser`, `pkexec`, setuid helpers, file capabilities, or runtime privilege escalation.
- `MemoryDenyWriteExecute=true`: unsafe for software that generates or modifies executable code at runtime. Pay special attention to JIT runtimes and dynamic execution engines such as Java/JVM, Java application servers, Mirth Connect, Elasticsearch/Solr-like JVM services, .NET, Node.js/V8, Chromium/Electron, LuaJIT, Erlang/BEAM with native code, WebAssembly runtimes, database engines or proxies with JIT, scripting engines with JIT, applications using PCRE-JIT, custom plugins, executable stacks, compiler trampolines, runtime code patching, or security/observability agents that inject code. Also treat services using `/dev/shm`, `memfd_create`, dynamic plugins, or unknown binary blobs as higher risk until tested.
- `ProtectHostname=true`: unsafe for services that must set the system hostname/domain name, call hostname-management APIs, run `hostnamectl`, participate in cloud-init or provisioning hostname changes, or dynamically observe host hostname changes after the service has started. It may also be unsafe for monitoring, inventory, licensing, clustering, or registration agents that rely on real-time hostname changes rather than the hostname visible at service start.
- `ProtectClock=true`: unsafe for services that set or adjust the system clock or hardware clock, read or manage RTC devices, perform time synchronization, use `adjtimex`/`clock_adjtime` behavior, manage wake alarms, or inspect kernel time discipline. Treat NTP/chrony/systemd-timesyncd, `hwclock`, VM guest tools, hardware-management agents, monitoring plugins that check time discipline, and backup/scheduling software with RTC/wake-alarm behavior as higher risk.
- `ProtectControlGroups=true`: unsafe for services that manage, create, delegate, or write Linux control groups, including container managers, VM or container runtimes, nested service managers, workload supervisors, and agents that intentionally move processes between cgroups. Treat monitoring, resource-accounting, orchestration, and troubleshooting tools that inspect host cgroup layout as higher risk until their read-only behavior is tested.
- `ProtectKernelLogs=true`: unsafe for services that intentionally read from or write to the kernel log ring buffer through interfaces such as `/dev/kmsg`, `/proc/kmsg`, `dmesg`, kernel-log collectors, low-level security agents, troubleshooting agents, or monitoring plugins that inspect kernel messages directly. This option is usually suitable for normal application services that only write application logs to stdout/stderr, syslog, journald, or application log files. Do not apply it blindly to logging, SIEM, EDR, audit, hardware, hypervisor, container-runtime, kernel-module, or monitoring components until their kernel-log behavior is understood.
- `ProtectKernelModules=true`: unsafe for services that intentionally load or unload kernel modules, call tools such as `modprobe`, `insmod`, `rmmod`, or `modprobe.d`-driven helpers, or require direct access to `/usr/lib/modules`. Treat DKMS, kernel-module build or install workflows, storage, network, virtualization, container, hardware-management, security, and observability agents as higher risk when they depend on explicit module operations, special filesystems, or out-of-tree drivers. Remember that limited automatic module loading can still occur outside this setting, so do not treat it as a system-wide module autoload kill switch.
- `ProtectKernelTunables=true`: unsafe for services that intentionally read or write kernel tunables through `/proc/sys`, `/sys`, `/proc/sysrq-trigger`, `/proc/acpi`, `/proc/fs`, `/proc/irq`, or related kernel API filesystems. Treat sysctl management, provisioning, firewall or network tuning, storage tuning, power or hardware management, container and virtualization setup, low-level security agents, and monitoring plugins that inspect `/proc/kallsyms` or `/proc/kcore` as higher risk until their kernel API access is understood. This option does not prevent indirect tunable changes through other privileged processes or IPC paths, so use it as service isolation rather than a complete host policy.
- `ProtectProc=invisible`: unsafe for services that need to inspect process metadata for other users through `/proc`, such as process supervisors, monitoring plugins, inventory agents, security agents, troubleshooting tools, and applications that discover or manage sibling services by scanning `/proc`. This option is only meaningful when the service does not run as unrestricted `root` and does not retain `CAP_SYS_PTRACE`; prefer combining it with a dedicated `User=` or `DynamicUser=yes` where possible. Because it uses procfs namespacing and implies `MountAPIVFS=yes`, verify services that create host-visible mounts, depend on the host `/proc` layout, or run on kernels without per-mount `hidepid` support.
- `UMask=0077`: unsafe for services that must create group-readable files, group-writable directories, shared Unix sockets, shared logs, web assets, backup artifacts, deployment outputs, or temporary files consumed by other users, groups, or services. The repository preference is `UMask=0077` when a service only needs its own runtime user to read or write generated files, or when Puppet/systemd already manages intentionally shared paths with explicit ownership and modes. Use a less strict non-default value such as `0027` only per service, with a documented reason and explicit ownership, directory modes, socket modes, or application settings that limit sharing to the operational need. Leave `UMask` unset when the correct exception is the normal default mask of `0022`. Check for functional impact such as unreadable logs, inaccessible sockets, failed web serving, broken hand-offs between services, failed backup/restore flows, or installers that expect package-default permissions.

Treat timers, sockets, mounts, paths, targets, and daemon configuration drop-ins separately from services. These service-execution options are not meaningful defaults for `.timer`, `.socket`, `.mount`, `.path`, `.target`, `journald.conf`, `resolved.conf`, `timesyncd.conf`, or similar daemon configuration drop-ins. For a timer, socket, or path unit, assess the paired `.service` unit instead.

When changing systemd-related code, inspect all generated and modified units in scope, including existing `basic_settings::systemd_service` resources, `basic_settings::systemd_drop_in` resources, vendor-unit drop-ins, direct `service` resources, templates, files, and wrappers. Include units that do not currently contain any hardening options. Sort the resulting unit list alphabetically by final systemd unit name before reporting or making broad decisions.

When the repository contains wrappers or templates that generate systemd units, inspect the wrapper itself and every known consumer. A generic wrapper such as `basic_settings::systemd_service` or `basic_settings::systemd_drop_in` may only add a new default when every current consumer is validated, or when the wrapper supports explicit per-service opt-outs with documented technical reasons.

Known lower-risk categories are simple internally generated oneshot services that execute a known native binary or root-only script without shared `/tmp`, shared generated files, shared sockets, shared logs, device access, protected-path writes, `sudo`, `su`, `runuser`, `pkexec`, setuid helpers, file capabilities, 32-bit binaries, Wine, QEMU-user, `setarch`, compatibility tooling, JIT/runtime code generation, hostname management, clock management, RTC access, wake alarms, kernel-log access, kernel-module operations, kernel-tunable writes, cgroup management, cross-user process introspection, dynamic plugin loading, or unknown third-party binary behavior. Even then, keep the hardening in the most specific service declaration and document the technical basis in the related analysis or review.

Known higher-risk categories include package-management and provisioning units, Puppet agent/server units, GitLab omnibus supervision, certbot renewals with arbitrary hooks, SSH login/session units, monitoring executors that may run local plugins, OpenITCOCKPIT server components that include `sudo_server`, backup or restore services that preserve permissions, services creating files for web servers or deployment users, services creating shared Unix sockets or group-readable logs, services using file capabilities, services using hardware or device nodes, services using RTC/time/clock APIs, services that read kernel logs or run `dmesg`, services that manage or observe hostname changes, services that load kernel modules or tune kernel parameters, services that manage cgroups or run nested workloads, services that inspect other users' processes through `/proc`, Java/JVM services, .NET services, Node.js/V8 services, browser/Electron-based services, database engines with JIT, services using PCRE-JIT, plugin-based runtimes, and any service that may call `sudo`, `su`, `runuser`, `pkexec`, or application-specific helper binaries.

## Data Sanitization Before External Use

Before using any external system, the internet, or any tool outside the IDE or local repository context, treat the material as potentially sensitive first.

Mandatory rule:

- Never send raw code, configuration, logs, stack traces, screenshots, or operational data externally before checking whether they contain sensitive information.
- Remove, mask, or anonymize sensitive information before sharing anything outside the local workspace.
- Apply this rule to web searches, browser-based tools, external AI services, issue trackers, paste services, chat tools, e-mail, vendor support portals, documentation sites, and any other external system.

Sensitive information that must never be shared in raw form includes at minimum:

- Passwords
- API keys
- Access tokens
- Session tokens
- Private keys
- SSH keys
- Certificates and certificate material
- Secrets from `.env` files
- Connection strings
- Database credentials
- Internal hostnames
- Internal IP addresses
- Private URLs
- Customer or patient data
- Personal data
- Tenant identifiers
- Internal project identifiers that are not needed for the question

Required working method before sending anything outside the IDE:

- Review the exact content that will be shared.
- Remove all secrets, credentials, keys, tokens, certificates, and identifying values.
- Anonymize names, domains, hostnames, IP addresses, usernames, IDs, and business-specific details where they are not strictly required.
- Reduce the shared material to the smallest possible reproducible example.
- Prefer a rewritten or synthetic example over real production data.
- Re-check the final sanitized version before sending it.

Hard rules:

- Never share raw `.env` files, private certificates, private keys, token files, kubeconfigs, database dumps, or production configuration files externally.
- Never copy full logs externally without first checking them for secrets and identifying information.
- Never assume a technical or incomplete snippet is safe by default.
- If there is any doubt whether content is sensitive, do not send it until it has been sanitized.

Default to caution. Sanitization is mandatory before any external sharing.

## Puppet Style

Derive style from the first-party modules already in this repository.

Follow these Puppet conventions:

- Keep module interfaces explicit with typed parameters.
- Prefer parameterized classes plus small defined types over hidden behavior.
- Keep module responsibilities narrow and composable, as in `php8`, `php8::fpm`, `php8::fpm_pool` or `rabbitmq` plus `rabbitmq::management`.
- Reuse `basic_settings` shared defined types instead of creating one-off service, timer, logrotate, sudoers, monitoring, or audit resources in every module.
- Preserve explicit `require`, `notify`, and `subscribe` relationships. This codebase relies on visible ordering more than implicit resource autorequires.
- When a defined type requires a parent class, guard it with `defined(Class['...'])` and fail clearly if the class is missing.
- When the same `defined(...)` check for a class, package, or other resource would be used multiple times in one manifest, evaluate it once into a clearly named variable and reuse that variable instead of repeating the call.
- Use ERB templates via `template(...)`. This repository currently uses `templates/` plus ERB, not EPP.
- Use `files/` plus `puppet:///modules/...` for static assets.
- When validating source URI schemes for Puppet-managed files, include `puppet:///` wherever module files are valid input, not only `file:///` and remote HTTPS.
- Prefer predictable paths and resource titles. Do not introduce surprising naming schemes.
- When a new helper extends an existing class or defined type, use the existing name as the prefix and the purpose as the suffix, for example `docker::compose_monitoring` for monitoring support around `docker::compose`.
- Inside a module's own `files/`, `templates/`, and manifest filenames, do not repeat the module name as a prefix unless the generated target path is outside the module namespace and needs a globally unique name.
- Keep package installation minimal with `install_options => ['--no-install-recommends', '--no-install-suggests']` unless there is a concrete reason not to.
- When a module fully owns a config directory, the existing style often uses `purge => true`, `recurse => true`, and `force => true`. Only do that for trees the module truly owns.
- When installer-generated files must survive, the existing style uses `replace => false`. Preserve that behavior where it matters.
- Keep file modes and ownership explicit.
- Keep monitoring and audit wiring close to the managed resource so operational visibility changes with the feature.
- Keep Puppet class and defined-type parameter lists vertically aligned across the full parameter block: align the type column, parameter-name column, `=` signs, and default values. When adding a longer parameter name, re-align the surrounding parameter list so one long line does not break the visual columns.
- When a resource only differs by optional attributes, prefer one compact resource with precomputed `undef` values over duplicated resource blocks. Do this only when mutually exclusive attributes, such as `source` and `content`, cannot both become non-`undef`.
- Do not invert control flow so a tiny branch is followed by a large `else` block. Keep the main resource declaration path in the first branch, or use a separate short validation guard with `fail(...)` before the main path. Large `else` blocks are only acceptable when both branches contain comparable real behavior.
- Add a short comment above non-obvious resource blocks or grouped resource changes when the purpose is not immediately clear from the resource title alone. This is especially important for `exec`, `file`, `package`, and other mixed resource sequences that bootstrap repositories, handle temporary files, manipulate permissions, or enforce security-sensitive ordering.
- Add a short comment above every non-trivial `if`/`elsif`/`else` branch. The comment should state why the branch exists and what decision is being made, especially when resolving precedence between vhost parameters, class defaults, monitoring values, generated values, or cleanup behavior.
- Add short comments in templates above non-obvious generated blocks, locations, handlers, redirects, security-sensitive directives, or conditionally rendered sections. Use the target config's comment syntax when the explanation is useful in the generated file, and ERB comments only when the note is purely about template mechanics.
- When generated file content contains dynamic values but should not change every Puppet run, prefer a native first-create pattern such as `replace => false`. If an event-driven rebuild is explicitly required, use a small refresh-only cleanup step and let the normal `file` resource recreate the content from `template()`; do not generate content inside an `exec`, and do not claim `subscribe` or `notify` will refresh `file` content.
- When embedding shell snippets inside double-quoted strings, always escape shell variables and command substitutions meant for the runtime shell, such as `\$tmpdir`, `\$1`, and `\$(...)`, so Puppet does not treat them as interpolation.
- In `exec` resources, never interpolate raw Puppet values into `command`, `onlyif`, or `unless`. Precompute shell-safe arguments with `stdlib::shell_escape(...)`, name them with a `_shell` suffix, and use the escaped value unquoted in the command string. This applies to paths, URLs, usernames, passwords, grep patterns, SQL strings passed with `mysql -e`, redirection targets, `name=value` CLI arguments, and values inside `Sensitive.new(...)`.
- Add a short comment above each block that prepares `stdlib::shell_escape(...)` values so reviewers can see which later `exec` command, guard, or shell script the escaped values protect.
- When an `exec` uses `/bin/sh -c` or `/usr/bin/bash -c`, escape every dynamic argument inside the script first, then pass the whole script through `stdlib::shell_escape(...)` before appending it after `-c`. Do not place escaped dynamic values inside a single-quoted `-c` string, because shell-escaped single quotes can break the outer quoting.
- Prefer `/usr/bin/printf %s ${value_shell}` for dynamic content in shell commands. Do not embed dynamic content inside shell quotes such as `"${value}"` or `'${value}'`; `stdlib::shell_escape` output is intended to be used as an unquoted shell word.
- Do not introduce a variable for a value that is used only once in the local code path, unless the variable name adds real domain meaning or avoids a demonstrable readability problem. Prefer applying one-off values directly in the resource or expression so the operational effect stays visible at the point of use.

Use local modules as integration points instead of importing foreign architecture. For example, if a service needs a systemd unit, timer, sudo rule, OpenITCOCKPIT check, or logrotate config, prefer the existing `basic_settings` helpers over adding a new external abstraction.

If you add a new first-party module, follow the existing module layout:

- `manifests/`
- `templates/`
- Include `files/` when needed.
- Keep `metadata.json` aligned with the rest of the first-party modules.

## Shell Script Rules

Treat new shell scripts and shell templates as POSIX shell by default and use `#!/bin/sh`. Do not assume Bash features unless the file clearly and explicitly requires them. Known Bash shebang exceptions currently are:

- `mysql/templates/grant.sh`
- `mysql/files/automysqlbackup`
- `basic_settings/files/network/rxbuffer`
- `basic_settings/templates/login/pam/notify`

When touching an existing Bash script, keep Bash only if the implementation still needs it. Otherwise prefer a safe migration to POSIX syntax. Do not copy Bash-only idioms into new scripts, and state the reason in the final handoff when a Bash-only exception remains.

Shell conventions already visible in this repository:

- Monitoring checks generally use `#!/bin/sh` and return standard Nagios-style status codes.
- Dependencies are discovered with direct `command -v` assignments, for example `TAIL=$(command -v tail 2>/dev/null) || die "tail not available"`. Do not introduce a generic lookup helper such as `find_bin` when direct checks are enough.
- Use shell builtins such as `printf` directly instead of resolving them with `command -v`.
- Keep monitoring check setup in this order: fail helper, binary checks, default/config variables, option parsing, helper functions, then main logic.
- Bundle related shell variables together, place a short comment above each variable block, and keep global/default variable blocks above non-fail helper functions.
- Place a short comment above each shell function.
- Quote variables consistently and keep command dependencies explicit.
- Use `printf` instead of relying on non-portable `echo` behavior.
- Represent embedded line breaks with direct `printf` formatting and escaped `\n`. Do not embed literal line breaks inside shell variables, quoted strings, Puppet interpolations, or concatenations.
- When command-substitution metadata needs serialization, use explicit sentinel tokens instead of newline-marker tricks such as `NL=$(printf '\n_'); NL=${NL%_}`.
- Store shell lists as comma-separated values and split them deliberately where needed; do not use literal multiline variable blocks.
- Keep single-use shell logic inline unless a function materially improves reuse or readability.
- Prefer the mainline shell path in `if` and keep the smaller exceptional fallback in `else`.
- Keep error helpers small and direct.
- Keep scripts operationally minimal and readable; these files are tooling, not generic libraries.
- Only mark real executables as executable.
- Match file modes to actual need: root-only scripts should stay root-only unless a non-root runtime is required.

Monitoring output conventions:

- Emit one natural, operator-readable summary line plus optional perfdata or long output.
- Do not embed perfdata-style `key=value` fragments in the summary text.
- Keep summary text cause-oriented and avoid duplicating raw numeric counters that are already present in perfdata.
- When a check emits multiple long-output sections, print the most diagnostically important section first.
- Long monitoring detail sections should have a configurable line limit and must say explicitly when output was truncated.

Shell refactoring expectations:

- When touching a shell script, also review nearby logic for duplication, brittle state, or avoidable complexity.
- Prefer a bounded refactor when it leaves the script materially simpler, clearer, or easier to extend.
- Collapse repeated parsing of the same input where practical, without making the parser harder to trust.
- Prefer validating the real source of truth over proxy checks that can create false negatives.
- Preserve the external contract unless the task explicitly asks to change it. For monitoring checks this includes exit codes, summary-line shape, perfdata keys, option flags, and generated path names.
- Keep data collection, status evaluation, perfdata generation, and long-output rendering as distinct steps.
- Remove stale variables, helper functions, and intermediate formats when they no longer pay for their complexity.
- Prefer deterministic output ordering when the script emits lists, sections, or perfdata.
- For monitoring checks, keep the summary line compact and move diagnostic detail to long output unless the alert needs the detail immediately.
- When a script change exposes a deeper structural weakness, leave the file in a better shape if the rewrite can still be kept well-bounded and well-validated.

## Dependency Guidance

This repository prefers tight internal Puppet integration over introducing large external Puppet libraries.

Follow these rules:

- Prefer extending the existing local modules over adding community modules.
- Do not default to external Docker, MySQL, Nginx, RabbitMQ, or similar Puppet modules just because they exist.
- Use the current small dependency set only where it already fits: `stdlib`, `concat`, `reboot`, `timezone`, and `debconf`.
- If a new dependency is proposed, justify why the project's own modules cannot handle the need cleanly.
- Prefer internal implementation when it gives better control over integration, security, systemd behavior, monitoring, and package policy.

This repo already manages package repositories, keys, systemd policy, monitoring plugins, logrotate, and audit rules in-house. Preserve that architectural preference.

## Documentation Maintenance

Documentation maintenance is part of implementation, not optional follow-up work. Review `README.md` and `AGENTS.md` whenever a change affects behavior, workflows, security expectations, Linux or systemd behavior, module integration, or reusable project patterns.

Update `README.md` in the same change when you add a new module or make a meaningful change to an existing module.

Meaningful changes include:

- New functionality
- Removed functionality
- Changed behavior
- New parameters users are expected to set
- Changed integration points between modules
- Changed operational assumptions
- New monitoring checks
- Changed security expectations
- Changed install or usage flow

README rules:

- Write README updates in Dutch.
- Keep generated config files, config templates, and inline config comments in English unless the managed software clearly requires another language.
- Match the current README's tone, structure, and sectioning.
- Start prose list items with a capital letter for consistency. If a list item is only an exact code identifier, module name, class name, path, or other literal, keep its original case.
- Keep the style consistent with the existing `##` sections and `### Voorbeeld` / `### Voorbeelden` pattern.
- Add or update example Puppet snippets when behavior changes materially.
- If you add or rename a monitoring check, update the `## Checks` section.
- Do not paste in generic English boilerplate or documentation written in a different style.

Update `AGENTS.md` only when the change introduces reusable guidance, adjusted workflows, changed security expectations, or relevant Linux/systemd insights that future agents or developers need to know. First determine where the instruction fits best. Prefer extending an existing relevant section over adding a loose or duplicate section.

When editing `AGENTS.md`, make sure new or changed text has:

- Clear sentence structure.
- Correct spelling.
- Consistent terminology.
- Precise technical wording.
- No duplicate rules.
- No contradictions with existing instructions.
- No outdated references.
- No vague wording that future agents could misinterpret.

## Validation Before Finishing

There is no first-party test suite or CI structure in the custom modules at the root of this repository. Validation still matters, so run targeted checks for the files you touched.

At minimum:

- Validate changed Puppet manifests for syntax and obvious relationship errors.
- Verify changed class and defined-type guards still match actual inclusion order.
- Syntax-check changed shell scripts with `sh -n` when they are POSIX.
- Syntax-check changed Bash exceptions with `bash -n` only when Bash is intentionally required.
- Render changed ERB shell templates in the relevant modes before syntax-checking them so the validation covers the actual generated script, not only the template source.
- When a shell change affects parsing, monitoring output, or status handling, run at least one small representative functional check with synthetic or stubbed input, and include an error-path check when practical.
- Review file modes, ownership, and `Sensitive` handling for every touched resource.
- Verify monitoring, sudoers, logrotate, audit, and systemd paths still line up with the generated filenames and service names.
- Confirm required `README.md` and `AGENTS.md` updates were considered and completed.

Finish every change with a short summary that states:

- Which files or code paths changed.
- Which relevant security, Linux, or systemd aspects were reviewed, or why they were not applicable.
- Whether `README.md` required an update and whether it was updated.
- Whether `AGENTS.md` was checked and either updated or left unchanged because the existing instructions were sufficient.
- Which validation ran, and which important validation step could not run.
