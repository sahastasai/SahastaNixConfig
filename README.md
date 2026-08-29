# SahastaNixConfig

Portable NixOS configuration with Home Manager integrated as a flake input.
It contains the system configuration, user packages, services, desktop setup,
Hyprland configuration, Fish configuration, cursor theme, and wallpaper.

## Install or restore

On NixOS, clone or copy this repository and run:

```sh
sh install.sh
```

The installer detects the invoking user, passwd-database home directory,
hostname, architecture, and current hardware. It installs a working copy at
`~/.config/nixos`, writes `identity.nix`, regenerates the target machine's
`hardware-configuration.nix`, validates the flake, and runs `nixos-rebuild`.

The flake output name remains `sahasta` on every machine:

```sh
sudo nixos-rebuild switch --flake "path:$HOME/.config/nixos#sahasta"
```

Set `NIX_CONFIG_DIR` to choose another installation directory. Set
`KEEP_HARDWARE_CONFIG=1` only when deliberately reusing the checked-in hardware
configuration. A Codex chat archive can be restored in the same run with:

```sh
CODEX_ARCHIVE=/path/to/codex-chats.tar.zst sh install.sh
```

Use `DRY_RUN=1` to generate and validate an adapted copy without changing the
running system. The installer preserves any existing KeePassXC preferences as
local, mode-0600 state because that file can contain a private sharing key.

## Layout

- `flake.nix`: pinned NixOS, Home Manager, and Codex Desktop inputs.
- `identity.nix`: machine/user values rewritten by `install.sh`.
- `hosts/main`: host entry point and generated hardware configuration.
- `modules/nixos`: system, desktop, package, and user modules.
- `home`: integrated Home Manager configuration and versioned dotfiles.
- `scripts`: portable Codex chat restoration and path migration tools.

## Secrets

No authentication material is committed. In particular, the repository omits
GitHub tokens, Codex authentication, browser cookies, SaiMail credentials, and
the KeePassXC sharing private key found in the original local preferences.
Those must be restored separately through their applications or a secure secret
manager. The Codex chat archive is also separate from Git because chat content
is private and can be very large.
