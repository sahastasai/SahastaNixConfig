#!/usr/bin/env python3
from __future__ import annotations

import os
import sqlite3
import sys
import tempfile
from pathlib import Path


def replace_file(path: Path, replacements: list[tuple[bytes, bytes]]) -> int:
    max_pattern = max(len(old) for old, _ in replacements)
    changed = 0
    mode = path.stat().st_mode

    with path.open("rb") as source, tempfile.NamedTemporaryFile(
        mode="wb", dir=path.parent, delete=False
    ) as target:
        temporary = Path(target.name)
        carry = b""
        while chunk := source.read(4 * 1024 * 1024):
            data = carry + chunk
            keep = min(max_pattern - 1, len(data))
            body, carry = data[:-keep] if keep else data, data[-keep:] if keep else b""
            for old, new in replacements:
                count = body.count(old)
                if count:
                    changed += count
                    body = body.replace(old, new)
            target.write(body)

        for old, new in replacements:
            count = carry.count(old)
            if count:
                changed += count
                carry = carry.replace(old, new)
        target.write(carry)

    if changed:
        os.chmod(temporary, mode)
        os.replace(temporary, path)
    else:
        temporary.unlink()
    return changed


def quote_identifier(value: str) -> str:
    return '"' + value.replace('"', '""') + '"'


def rewrite_database(path: Path, replacements: list[tuple[str, str]]) -> int:
    changed = 0
    connection = sqlite3.connect(path)
    try:
        result = connection.execute("PRAGMA integrity_check").fetchone()
        if not result or result[0] != "ok":
            raise RuntimeError(f"SQLite integrity check failed for {path}")

        tables = connection.execute(
            "SELECT name FROM sqlite_master "
            "WHERE type = 'table' AND name NOT LIKE 'sqlite_%'"
        ).fetchall()
        for (table_name,) in tables:
            table = quote_identifier(table_name)
            columns = connection.execute(f"PRAGMA table_xinfo({table})").fetchall()
            for column in columns:
                column_name = quote_identifier(column[1])
                for old, new in replacements:
                    before = connection.total_changes
                    try:
                        connection.execute(
                            f"UPDATE {table} SET {column_name} = "
                            f"replace({column_name}, ?, ?) "
                            f"WHERE typeof({column_name}) = 'text' "
                            f"AND instr({column_name}, ?) > 0",
                            (old, new, old),
                        )
                    except sqlite3.DatabaseError:
                        continue
                    changed += connection.total_changes - before
        connection.commit()
        result = connection.execute("PRAGMA integrity_check").fetchone()
        if not result or result[0] != "ok":
            raise RuntimeError(f"SQLite integrity check failed after rewriting {path}")
    finally:
        connection.close()
    return changed


def main() -> int:
    if len(sys.argv) != 4:
        print("Usage: rewrite-codex-paths.py ROOT SOURCE_HOME TARGET_HOME", file=sys.stderr)
        return 2

    root = Path(sys.argv[1])
    source_home = sys.argv[2].rstrip("/")
    target_home = sys.argv[3].rstrip("/")
    old_homes = [source_home, "/home/sahastasai"]
    old_homes = list(dict.fromkeys(home for home in old_homes if home != target_home))
    text_replacements = [(old.encode(), target_home.encode()) for old in old_homes]
    sql_replacements = [(old, target_home) for old in old_homes]

    text_names = {
        ".codex-global-state.json",
        ".codex-global-state.json.bak",
        "external_agent_session_imports.json",
        "history.jsonl",
        "session_index.jsonl",
    }
    text_suffixes = {".json", ".jsonl", ".toml", ".txt"}
    text_changes = 0
    database_changes = 0

    for path in root.rglob("*"):
        if not path.is_file() or path.is_symlink():
            continue
        if path.suffix in {".sqlite", ".db"}:
            database_changes += rewrite_database(path, sql_replacements)
        elif path.name in text_names or path.suffix in text_suffixes:
            text_changes += replace_file(path, text_replacements)

    print(f"Text path replacements: {text_changes}")
    print(f"SQLite rows updated: {database_changes}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
