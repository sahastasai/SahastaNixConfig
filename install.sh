#!/bin/sh
set -eu

say() {
  printf '%s\n' "$*"
}

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

command -v nix >/dev/null 2>&1 || fail "Nix is not installed"
command -v nixos-rebuild >/dev/null 2>&1 || fail "This installer must run on NixOS"
command -v sudo >/dev/null 2>&1 || fail "sudo is required for system activation"

if [ "$(id -u)" -eq 0 ]; then
  target_user=${TARGET_USER:-${SUDO_USER:-}}
  [ -n "$target_user" ] || fail "Run as the target user, or set TARGET_USER"
else
  target_user=${TARGET_USER:-$(id -un)}
fi

passwd_entry=$(getent passwd "$target_user" || true)
[ -n "$passwd_entry" ] || fail "User '$target_user' is not in the passwd database"

target_home=$(printf '%s\n' "$passwd_entry" | cut -d: -f6)
full_name=$(printf '%s\n' "$passwd_entry" | cut -d: -f5 | cut -d, -f1)
[ -n "$full_name" ] || full_name=$target_user
host_name=$(hostname -s)

case $(uname -m) in
  x86_64) target_system=x86_64-linux ;;
  aarch64|arm64) target_system=aarch64-linux ;;
  *) fail "Unsupported architecture: $(uname -m)" ;;
esac

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
install_dir=${NIX_CONFIG_DIR:-$target_home/.config/nixos}
timestamp=$(date +%Y%m%d-%H%M%S)
keepass_path="$target_home/.config/keepassxc/keepassxc.ini"
keepass_backup=

if [ -f "$keepass_path" ]; then
  keepass_backup="$target_home/.local/state/nixos-migration/keepassxc-$timestamp.ini"
  mkdir -p "$(dirname "$keepass_backup")"
  cp -L "$keepass_path" "$keepass_backup"
  chmod 600 "$keepass_backup"
fi

if [ "$script_dir" != "$install_dir" ]; then
  parent_dir=$(dirname "$install_dir")
  mkdir -p "$parent_dir"
  if [ -e "$install_dir" ]; then
    backup_dir="$install_dir.backup-$timestamp"
    say "Saving existing configuration as $backup_dir"
    mv "$install_dir" "$backup_dir"
  fi
  say "Installing configuration in $install_dir"
  mkdir -p "$install_dir"
  cp -a "$script_dir/." "$install_dir/"
fi

escape_nix_string() {
  printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/\${/\\${/g'
}

identity_tmp="$install_dir/identity.nix.tmp"
cat >"$identity_tmp" <<EOF
{
  username = "$(escape_nix_string "$target_user")";
  fullName = "$(escape_nix_string "$full_name")";
  homeDirectory = "$(escape_nix_string "$target_home")";
  hostName = "$(escape_nix_string "$host_name")";
  system = "$target_system";
  timeZone = "America/Los_Angeles";
  systemStateVersion = "26.05";
  homeStateVersion = "25.11";
}
EOF
mv "$identity_tmp" "$install_dir/identity.nix"

if [ "${DRY_RUN:-0}" = 1 ]; then
  say "Validating the adapted flake without activating it"
  nix flake check "path:$install_dir"
  say "Dry run complete. Adapted configuration: $install_dir"
  exit 0
fi

if [ "${KEEP_HARDWARE_CONFIG:-0}" != 1 ]; then
  say "Generating hardware configuration for this machine"
  hardware_tmp="$install_dir/hosts/main/hardware-configuration.nix.tmp"
  sudo nixos-generate-config --show-hardware-config >"$hardware_tmp"
  mv "$hardware_tmp" "$install_dir/hosts/main/hardware-configuration.nix"
fi

if [ "$(id -u)" -eq 0 ]; then
  chown -R "$target_user" "$install_dir"
fi

say "Validating the flake"
nix flake check "path:$install_dir"

say "Activating NixOS and integrated Home Manager"
sudo nixos-rebuild switch --flake "path:$install_dir#sahasta"

if [ -n "$keepass_backup" ]; then
  mkdir -p "$(dirname "$keepass_path")"
  if [ -L "$keepass_path" ]; then
    rm "$keepass_path"
  elif [ -e "$keepass_path" ]; then
    mv "$keepass_path" "$keepass_path.pre-flake-$timestamp"
  fi
  cp "$keepass_backup" "$keepass_path"
  chmod 600 "$keepass_path"
  say "Preserved local KeePassXC preferences outside Git management"
fi

hm_path="$target_home/.config/home-manager"
hm_target="$install_dir/home"
if [ -L "$hm_path" ]; then
  current_target=$(readlink -f "$hm_path" || true)
  if [ "$current_target" != "$hm_target" ]; then
    rm "$hm_path"
    ln -s "$hm_target" "$hm_path"
  fi
elif [ -e "$hm_path" ]; then
  hm_backup="$hm_path.standalone-backup-$timestamp"
  say "Saving standalone Home Manager source as $hm_backup"
  mv "$hm_path" "$hm_backup"
  ln -s "$hm_target" "$hm_path"
else
  mkdir -p "$(dirname "$hm_path")"
  ln -s "$hm_target" "$hm_path"
fi

archive=${CODEX_ARCHIVE:-}
if [ -z "$archive" ]; then
  for candidate in \
    "$script_dir/codex-backup/codex-chats.tar.zst" \
    "$script_dir/../codex-backup/codex-chats.tar.zst"
  do
    if [ -f "$candidate" ]; then
      archive=$candidate
      break
    fi
  done
fi

if [ -n "$archive" ] && [ "${RESTORE_CODEX:-1}" != 0 ]; then
  say "Restoring Codex chats from $archive"
  sh "$install_dir/scripts/restore-codex-chats.sh" "$archive" "$target_home"
fi

say "Setup complete. Reboot if the kernel or display-manager generation changed."
