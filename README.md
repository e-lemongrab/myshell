# myshell

`myshell` is a Bash-first hybrid framework for building, bootstrapping, and operating a modular user environment.

It treats the shell runtime as the technical base, then layers optional profiles, user services, and operational modules on top of it. The result is a structured system that aims for two main properties:

- **modularity**: each component has a clear layer, a concrete purpose, and explicit activation
- **reproducibility**: the managed local environment and its modular composition can be reproduced consistently

`myshell` is not intended to look like a classic dotfiles repository, a loose collection of personal scripts, a simple `.bashrc` bootstrap, or a package manager. It is meant to behave like a lightweight, Bash-based framework for managing a stable user environment and exposing reusable operational tooling.

## Scope

`myshell` is designed to:
- bootstrap a Bash-based user environment
- manage shell runtime behavior through a structured core
- load optional profiles and user services explicitly
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

Profiles are opt-in through explicit loader blocks in `.bashrc`.

### Services
Services are optional components loaded from `core/shells/bash/services/`.

Services are also part of the framework core model, but are intended for persistent or service-like integrations that should not live as normal shell profiles.

Typical examples are `systemd --user` units and their companion scripts.

Services are opt-in through explicit loader blocks in `.bashrc`.

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
- activation state is explicit and visible through the corresponding loader blocks

## Stability model

`myshell` aims to keep both of these stable:
- the **structure** of the framework
- the **experience of use**

What may vary:
- which profiles, services, and modules are enabled
- which components are sourced from the official companion repository
- future official external integrations in the `myshell` ecosystem

## Activation model

The framework is designed around explicit, visible activation.

The expected user experience is:
- load a predefined environment
- enable or disable explicit pieces of that environment
- use operational modules on top of a stable base

This is an opt-in modular system, not a hidden auto-magic bootstrap.

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
- `core/shells/bash/services/`
  - optional managed service integrations
- `core/shells/bash/.bash_profile`
  - framework entrypoint
- `core/shells/bash/.bashrc`
  - explicit activation surface for profiles and services
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
- run `myshell` to view available commands

### PowerShell

Once the Bash configuration is active, and if `pwsh` is installed, `myshell` can also set the PowerShell profile at:

- `~/.config/powershell/Microsoft.PowerShell_profile.ps1`

If you want to use the PowerShell profile from Windows:

1. Install a WSL2 distribution.
2. Edit `$PROFILE` with the content from `core/shells/pwsh/Microsoft.PowerShell_profile.ps1`.
3. Set the required values in the `VARIABLE DECLARATION` section.

## Profiles and services

`myshell` loads optional Bash components from `core/shells/bash/profiles/` and `core/shells/bash/services/` through explicit blocks in `core/shells/bash/.bashrc`.

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

### Services currently supported

Examples include:
- `.hyprland-wallpaper`
- `.nvidia-fan`

These are framework-managed service integrations and are activated through `.bashrc` loader blocks.

### Current service behavior

`.hyprland-wallpaper`
- downloads `hypr-wallpaper.service` from `config_files`
- downloads `wallpaper-rotation.sh` from `config_files`
- installs them into local user paths
- runs `systemctl --user daemon-reload`
- runs `systemctl --user enable --now hypr-wallpaper.service` when needed

`.nvidia-fan`
- downloads `nvidia-fan.service` from `config_files`
- downloads `nvidiafan.sh` from `config_files`
- installs them into local user paths
- runs `systemctl --user daemon-reload`
- runs `systemctl --user enable --now nvidia-fan.service` when needed

### Service prerequisites

`.hyprland-wallpaper`
- `hyprpaper`
- `hyprctl`
- a valid `~/.config/hypr/hyprpaper.conf`
- a local wallpaper directory configured in the script through `WALLPAPER_DIR`
- `mpvpaper` if video wallpapers are used
- monitor names and interval may need local adjustment

`.nvidia-fan`
- `nvidia-smi`
- `nvidia-settings`
- `sudo`
- `xhost`
- a deployed script at `~/.config/nvidia/nvidiafan.sh`
- `sudo` for `nvidia-settings` must work non-interactively in the session where the service runs
- the graphical session must be ready; the service definition uses a short startup delay to avoid login-time race conditions

## Companion repository: `config_files`

`config_files` is the official companion repository of `myshell`.

Within the framework model:
- `myshell` is the framework and orchestration layer
- `config_files` is the managed external source of truth for supported configuration artifacts

This relationship is part of the intended architecture of the framework.

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
