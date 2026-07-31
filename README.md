# myshell

`myshell` is a Bash-first hybrid framework for building, bootstrapping, and operating a modular user environment.

It treats the shell runtime as the technical base, then layers optional profiles and operational modules on top of it. The result is a structured system that aims for two main properties:

- **modularity**: each component has a clear layer, a concrete purpose, and explicit activation
- **reproducibility**: the managed local environment and its modular composition can be reproduced consistently

`myshell` is not intended to look like a classic dotfiles repository, a loose collection of personal scripts, a simple `.bashrc` bootstrap, or a package manager. It is meant to behave like a lightweight, Bash-based framework for managing a stable user environment and exposing reusable operational tooling.

## Scope

`myshell` is designed to:
- bootstrap a Bash-based user environment
- manage shell runtime behavior through a structured core
- load optional profiles explicitly
- expose operational modules through a stable framework structure
- integrate official external companion repositories such as `config_files`

`myshell` is **not** designed to:
- manage arbitrary local state outside its declared managed components
- behave like a package manager
- present itself as a generic framework without a concrete user-environment use case

## Core model

`myshell` is organized around the following layers:

### Core
The core is the runtime base of the framework. It provides the shell entrypoints and the structure through which the rest of the system is loaded.

This includes:
- `.bash_profile`
- `.bashrc`
- aliases
- functions
- jobs

### Profiles

Profiles are optional environment components loaded from `core/shells/bash/profiles/`.

Profiles are part of the framework core model. They are used for shell environment setup, bootstrap behavior, and managed configuration deployment.

Every profile is enabled on a new installation to preserve the complete default environment. Its state can then be changed explicitly with `myshell`.

### Modules

Modules are operational tooling components. They expose commands and workflows on top of the stable user-environment base provided by the framework.

Modules are part of the core identity of `myshell`, not an afterthought.

### Optional components
PowerShell support exists as an optional layer. It is supported, but it is not part of the primary identity of the framework.

### Official external companion repositories
`myshell` supports official companion repositories that are external in storage but functionally part of the framework ecosystem.

The primary companion repository is:
- `config_files`

`config_files` is not treated as a secondary integration. It is the official companion repository for managed external configuration consumed by `myshell`.

## Managed vs unmanaged behavior

A core principle of `myshell` is explicit control.

When a component is active and managed by the framework, the framework is authoritative for that component.

When a component is disabled, it stops being managed.

This means:
- active managed components are expected to follow framework-defined behavior
- disabled components are outside the authority of the framework
- activation state is explicit and visible through `myshell status`
- a state change takes effect after reloading or opening the shell

## Stability model

`myshell` aims to keep both of these stable:
- the **structure** of the framework
- the **experience of use**

What may vary:
- which profiles and modules are enabled
- which components are sourced from the official companion repository
- future official external integrations in the `myshell` ecosystem

## Activation model

The framework is designed around explicit, visible activation state.

The expected user experience is:
- load a predefined environment
- start with every module and profile enabled, including the base aliases such as `cls`
- enable or disable explicit pieces of that environment
- use operational modules on top of a stable base

State is stored with complete module IDs such as `help/git` and `utils/git`, so modules with the same basename do not collide. Existing basename-only state is migrated automatically.

## Why Bash-first matters

`myshell` is Bash-first by design.

Bash is not just the implementation language; it is part of the framework identity. The framework is intended to stay technically direct, operational, and readable while still being powerful.

The target is **power within visible simplicity**:
- the internal system can grow
- but the user model and framework structure should remain understandable and explicit

## Repository structure

Current top-level structure relevant to the framework model:

- `core/`
  - framework runtime and shell entrypoints
- `core/shells/bash/profiles/`
  - optional managed environment components
- `core/shells/bash/.bash_profile`
  - framework entrypoint
- `core/shells/bash/.bashrc`
  - explicit activation surface for profiles
- `modules/`
  - operational toolkit components
- `core/shells/pwsh/`
  - optional PowerShell support

## Installation

### Bash

1. Back up your current `$HOME/.bash_profile` if needed.
2. Clone the repository.
3. Copy the framework entrypoint to your home.
4. Set `project_path`.
5. Reload the shell session.

```bash
git clone git@github.com:e-lemongrab/myshell.git
cp -rfv myshell/core/shells/bash/.bash_profile "$HOME"
sed -i 's|$HOME/Documents/myshell|'"$(pwd)"'/myshell|g' "$HOME/.bash_profile"
exec -l "$SHELL"
```

After that:
- run `checks` to list compatibility information
- run `myshell status` to inspect the active environment
- run `myshell list` to view module commands
- run `myshell` for the interactive manager

The non-interactive state commands are:

```bash
myshell enable help/git
myshell disable help/git
myshell profile-enable .completion
myshell profile-disable .completion
reload_shell
# Equivalent: exec -l "$SHELL"
```

All components are enabled if no prior state exists. A disabled module no longer loads its aliases on the next shell. Base aliases that are not tied to an operational module remain available.

### PowerShell

Once the Bash configuration is active, and if `pwsh` is installed, `myshell` can also set the PowerShell profile at:

- `~/.config/powershell/Microsoft.PowerShell_profile.ps1`

If you want to use the PowerShell profile from Windows:

1. Install a WSL2 distribution.
2. Edit `$PROFILE` with the content from `core/shells/pwsh/Microsoft.PowerShell_profile.ps1`.
3. Set the required values in the `VARIABLE DECLARATION` section.

## Profiles and modules

`myshell` loads enabled Bash components from `core/shells/bash/profiles/` in a stable order.

### Profiles currently loaded by default blocks in `.bashrc`

Examples include:
- `.git-configs`
- `.appearance`
- `.completion`
- `.history`
- `.path`
- `.pwsh`
- `.software`
- `.config_files`
- `.ssh`

The public-IP refresh, `config_files` synchronization, SSH agent setup, and AWS prompt identity lookup remain enabled by default:

- public IP refresh is asynchronous, singleton, and cached for 10 minutes
- companion configuration synchronization is asynchronous, atomic, and cached for one hour
- a valid SSH agent is reused instead of starting one per terminal
- `aws sts get-caller-identity` runs at most once per profile every five minutes and only supplies the role/session shown in the prompt

## Companion repository: `config_files`

`config_files` is the official companion repository of `myshell`.

Within the framework model:
- `myshell` is the framework and orchestration layer
- `config_files` is the managed external source of truth for supported configuration artifacts

This relationship is part of the intended architecture of the framework.

## Operational safety

Commands that erase broad local state show a preview and require an explicit confirmation. This applies to Docker cleanup, child-repository hard resets, Terraform reinitialization, Git hard reset, and disk formatting.

The ext4 formatter excludes every physical disk backing `/`, refuses devices with mounted descendants, shows the selected layout, and requires the exact device path before writing. It also supports device names that require a `p1` suffix, such as NVMe and MMC devices.

The repository does not provide or load a VPN alias; VPN tooling is managed outside this project.

## Docker baseline

Docker build definitions use a single canonical `Dockerfile` per module. Compose references, workflow references, `COPY` sources, and build contexts are checked by `tests/validate.bash`.

Base images now use explicit version tags instead of floating `latest` tags. These versions form the repository baseline; changing one is a compatibility decision and should be followed by a build and service-level smoke test. The publish workflow builds only `linux/amd64` for the custom MongoDB image because its configured MongoDB package repository is architecture-specific.

The MySQL 5, MySQL 8, MongoDB, and Node examples include health checks. MongoDB startup preserves `/data/db`; initialization and destructive reset are deliberately separate concerns.

Credentials committed in the example Compose and database configuration files are dummy values for local execution. They are not production or staging credentials.

## Personal configuration inventory

The repository intentionally still contains user-specific or environment-specific material:

- PowerShell aliases/history under `core/shells/pwsh/`
- SSH/Ansible inventory, an authorized public key, and local user-management settings under `modules/utils/user_ssh/`
- local host lists in `modules/utils/user_ssh/hosts.txt` and `hosts2.txt`
- workstation-specific paths in PowerShell helpers

These files were reported, not generalized or removed. Review them before sharing the repository or applying the configuration on another workstation.

## Validation

Run the same validation gate used by CI:

```bash
bash tests/validate.bash
```

It checks shell syntax, ShellCheck findings, loader and alias targets, activation defaults and migration, the interactive `cls` case, YAML/Compose models, Docker build inputs and version policy, and immutable GitHub Action references.

## Extension model

`myshell` is modular, but that modularity is structured.

In practice, new functionality should fit one of the framework layers:
- core runtime behavior
- profile
- service
- module
- official external companion integration

If a new component does not clearly fit one of those layers, it should not be added until its role is defined.

## Summary

`myshell` should be understood as:
- a Bash-first hybrid framework
- a structured user-environment manager
- a modular shell and services system
- a reproducible local environment framework
- a lightweight operational platform built on top of Bash
