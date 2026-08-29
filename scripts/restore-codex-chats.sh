#!/bin/sh
set -eu

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

[ "$#" -ge 1 ] || fail "Usage: restore-codex-chats.sh ARCHIVE [TARGET_HOME]"
archive=$1
target_home=${2:-$HOME}
[ -f "$archive" ] || fail "Archive not found: $archive"
[ -d "$target_home" ] || fail "Target home does not exist: $target_home"

command -v python3 >/dev/null 2>&1 || fail "python3 is required"
command -v tar >/dev/null 2>&1 || fail "tar is required"

target_user=$(stat -c %U "$target_home")
timestamp=$(date +%Y%m%d-%H%M%S)
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/codex-chat-restore.XXXXXXXX")
trap 'rm -rf "$work_dir"' EXIT HUP INT TERM

tar --zstd -xf "$archive" -C "$work_dir"
payload="$work_dir/codex-chat-backup"
[ -d "$payload/.codex" ] || fail "Archive does not contain a Codex chat payload"
[ -f "$payload/metadata/source-home.txt" ] || fail "Archive has no source-home metadata"
source_home=$(cat "$payload/metadata/source-home.txt")

python3 "$(dirname "$0")/rewrite-codex-paths.py" \
  "$payload/.codex" "$source_home" "$target_home"

target_codex="$target_home/.codex"
backup_dir="$target_home/.codex-chat-restore-backup-$timestamp"
mkdir -p "$target_codex" "$backup_dir"

for item in "$payload/.codex"/* "$payload/.codex"/.[!.]*; do
  [ -e "$item" ] || [ -L "$item" ] || continue
  name=$(basename "$item")
  if [ -e "$target_codex/$name" ] || [ -L "$target_codex/$name" ]; then
    mv "$target_codex/$name" "$backup_dir/$name"
  fi
  mv "$item" "$target_codex/$name"
done

if [ "$(id -u)" -eq 0 ]; then
  chown -R "$target_user" "$target_codex" "$backup_dir"
fi
chmod 700 "$target_codex" 2>/dev/null || true

printf 'Codex chats restored to %s\n' "$target_codex"
printf 'Replaced paths from %s with %s\n' "$source_home" "$target_home"
printf 'Previous colliding files were saved in %s\n' "$backup_dir"
