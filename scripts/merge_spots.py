#!/usr/bin/env python3
"""Merge MiniMap spot data from one Lua file into another.

Usage:
    merge_spots.py source.lua target.lua
    merge_spots.py --target-var MiniMapDefaultSpots source.lua MiniMap/MiniMapData.lua

The target file is updated in place. A .bak copy is written by default.
Duplicate spots are detected with the same threshold as the addon:
MINIMAP_SPOT_DUPLICATE_THRESHOLD = 0.0005.
When a duplicate is found, the target spot is kept.
"""

from __future__ import annotations

import argparse
import math
import shutil
import sys
from collections import OrderedDict
from pathlib import Path
from typing import Any


DEFAULT_SPOTS_VAR_NAME = "MiniMapSpots"
MINIMAP_SPOT_DUPLICATE_THRESHOLD = 0.0005


class LuaParseError(ValueError):
    pass


class LuaParser:
    def __init__(self, text: str, pos: int = 0) -> None:
        self.text = text
        self.pos = pos

    def parse_value(self) -> Any:
        self._skip_ws()
        ch = self._peek()
        if ch == "{":
            return self._parse_table()
        if ch in ("'", '"'):
            return self._parse_string()
        if ch == "-" or ch.isdigit():
            return self._parse_number()
        ident = self._parse_identifier()
        if ident == "true":
            return True
        if ident == "false":
            return False
        if ident == "nil":
            return None
        raise LuaParseError(f"unsupported value {ident!r} at offset {self.pos}")

    def _parse_table(self) -> OrderedDict[Any, Any]:
        table: OrderedDict[Any, Any] = OrderedDict()
        array_index = 1
        self._expect("{")

        while True:
            self._skip_ws()
            if self._peek() == "}":
                self.pos += 1
                return table

            key = None
            has_explicit_key = False

            if self._peek() == "[":
                self.pos += 1
                key = self.parse_value()
                self._skip_ws()
                self._expect("]")
                self._skip_ws()
                self._expect("=")
                has_explicit_key = True
            else:
                mark = self.pos
                if self._peek().isalpha() or self._peek() == "_":
                    ident = self._parse_identifier()
                    self._skip_ws()
                    if self._peek() == "=":
                        self.pos += 1
                        key = ident
                        has_explicit_key = True
                    else:
                        self.pos = mark

            if has_explicit_key:
                table[key] = self.parse_value()
            else:
                table[array_index] = self.parse_value()
                array_index += 1

            self._skip_ws()
            if self._peek() in (",", ";"):
                self.pos += 1

    def _parse_string(self) -> str:
        quote = self._peek()
        self.pos += 1
        out = []
        while self.pos < len(self.text):
            ch = self.text[self.pos]
            self.pos += 1
            if ch == quote:
                return "".join(out)
            if ch == "\\":
                if self.pos >= len(self.text):
                    raise LuaParseError("unterminated string escape")
                esc = self.text[self.pos]
                self.pos += 1
                out.append(
                    {
                        "n": "\n",
                        "r": "\r",
                        "t": "\t",
                        "\\": "\\",
                        '"': '"',
                        "'": "'",
                    }.get(esc, esc)
                )
            else:
                out.append(ch)
        raise LuaParseError("unterminated string")

    def _parse_number(self) -> float | int:
        start = self.pos
        if self._peek() == "-":
            self.pos += 1
        while self.pos < len(self.text) and self.text[self.pos].isdigit():
            self.pos += 1
        if self.pos < len(self.text) and self.text[self.pos] == ".":
            self.pos += 1
            while self.pos < len(self.text) and self.text[self.pos].isdigit():
                self.pos += 1
        if self.pos < len(self.text) and self.text[self.pos] in ("e", "E"):
            self.pos += 1
            if self.pos < len(self.text) and self.text[self.pos] in ("+", "-"):
                self.pos += 1
            while self.pos < len(self.text) and self.text[self.pos].isdigit():
                self.pos += 1

        raw = self.text[start : self.pos]
        if raw in ("", "-"):
            raise LuaParseError(f"invalid number at offset {start}")
        if any(c in raw for c in ".eE"):
            return float(raw)
        return int(raw)

    def _parse_identifier(self) -> str:
        self._skip_ws()
        start = self.pos
        if self.pos >= len(self.text):
            raise LuaParseError("unexpected end of input")
        if not (self.text[self.pos].isalpha() or self.text[self.pos] == "_"):
            raise LuaParseError(f"expected identifier at offset {self.pos}")
        self.pos += 1
        while self.pos < len(self.text):
            ch = self.text[self.pos]
            if not (ch.isalnum() or ch == "_"):
                break
            self.pos += 1
        return self.text[start : self.pos]

    def _skip_ws(self) -> None:
        while self.pos < len(self.text):
            if self.text[self.pos].isspace():
                self.pos += 1
                continue
            if self.text.startswith("--[[", self.pos):
                end = self.text.find("]]", self.pos + 4)
                if end < 0:
                    raise LuaParseError("unterminated block comment")
                self.pos = end + 2
                continue
            if self.text.startswith("--", self.pos):
                end = self.text.find("\n", self.pos + 2)
                self.pos = len(self.text) if end < 0 else end + 1
                continue
            break

    def _peek(self) -> str:
        self._skip_ws()
        if self.pos >= len(self.text):
            return ""
        return self.text[self.pos]

    def _expect(self, expected: str) -> None:
        self._skip_ws()
        if not self.text.startswith(expected, self.pos):
            raise LuaParseError(f"expected {expected!r} at offset {self.pos}")
        self.pos += len(expected)


def find_lua_assignment(text: str, var_name: str) -> tuple[int, int, OrderedDict[Any, Any]]:
    search_pos = 0
    while True:
        pos = text.find(var_name, search_pos)
        if pos < 0:
            raise LuaParseError(f"{var_name} assignment not found")
        before = text[pos - 1] if pos > 0 else ""
        after_pos = pos + len(var_name)
        after = text[after_pos] if after_pos < len(text) else ""
        if (before.isalnum() or before == "_") or (after.isalnum() or after == "_"):
            search_pos = after_pos
            continue

        parser = LuaParser(text, after_pos)
        parser._skip_ws()
        if parser._peek() != "=":
            search_pos = after_pos
            continue
        parser.pos += 1
        parser._skip_ws()
        value_start = parser.pos
        value = parser.parse_value()
        if not isinstance(value, OrderedDict):
            raise LuaParseError(f"{var_name} is not a Lua table")
        return value_start, parser.pos, value


def is_identifier(value: str) -> bool:
    return value.isidentifier() and value not in {"true", "false", "nil"}


def quote_lua_string(value: str) -> str:
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n") + '"'


def key_to_lua(key: Any) -> str:
    if isinstance(key, str) and is_identifier(key):
        return key
    return f"[{to_lua(key, 0)}]"


def is_inline_spot_table(value: Any) -> bool:
    if not looks_like_spot(value):
        return False
    return all(not isinstance(item, OrderedDict) for item in value.values())


def to_inline_lua_table(value: OrderedDict[Any, Any]) -> str:
    parts = []
    for key, item in value.items():
        parts.append(f"{key_to_lua(key)} = {to_lua(item, 0)}")
    return "{ " + ", ".join(parts) + " }"


def to_lua(value: Any, indent: int = 0) -> str:
    if isinstance(value, OrderedDict):
        if not value:
            return "{}"
        if is_inline_spot_table(value):
            return to_inline_lua_table(value)
        pad = " " * indent
        child_pad = " " * (indent + 4)
        lines = ["{"]
        for key, item in value.items():
            lines.append(f"{child_pad}{key_to_lua(key)} = {to_lua(item, indent + 4)},")
        lines.append(f"{pad}}}")
        return "\n".join(lines)
    if isinstance(value, str):
        return quote_lua_string(value)
    if isinstance(value, bool):
        return "true" if value else "false"
    if value is None:
        return "nil"
    if isinstance(value, float):
        if math.isfinite(value):
            return f"{value:.10g}"
        raise ValueError("cannot serialize non-finite float")
    return str(value)


def is_number(value: Any) -> bool:
    return isinstance(value, (int, float)) and not isinstance(value, bool)


def iter_array_items(table: OrderedDict[Any, Any]) -> list[Any]:
    return [table[key] for key in sorted(k for k in table.keys() if isinstance(k, int))]


def looks_like_spot(value: Any) -> bool:
    return isinstance(value, OrderedDict) and is_number(value.get("x")) and is_number(value.get("y"))


def looks_like_spot_list(value: Any) -> bool:
    if not isinstance(value, OrderedDict):
        return False
    spots = iter_array_items(value)
    return not spots or all(looks_like_spot(spot) for spot in spots)


def looks_like_map_data(value: Any) -> bool:
    if not isinstance(value, OrderedDict):
        return False
    if not value:
        return True
    for _map_name, map_data in value.items():
        if not isinstance(map_data, OrderedDict):
            return False
        for _category, spots in map_data.items():
            if not looks_like_spot_list(spots):
                return False
    return True


def collect_data_tables(root: OrderedDict[Any, Any]) -> list[tuple[tuple[Any, ...], OrderedDict[Any, Any]]]:
    found: list[tuple[tuple[Any, ...], OrderedDict[Any, Any]]] = []

    def walk(value: Any, path: tuple[Any, ...]) -> None:
        if not isinstance(value, OrderedDict):
            return
        data = value.get("data")
        if looks_like_map_data(data):
            found.append((path + ("data",), data))
            return
        for key, item in value.items():
            if isinstance(item, OrderedDict):
                walk(item, path + (key,))

    walk(root, ())

    if found:
        return found

    if looks_like_map_data(root):
        found.append(((), root))
    return found


def next_array_index(table: OrderedDict[Any, Any]) -> int:
    numeric_keys = [key for key in table.keys() if isinstance(key, int)]
    return (max(numeric_keys) + 1) if numeric_keys else 1


def is_duplicate(target_spots: OrderedDict[Any, Any], source_spot: OrderedDict[Any, Any]) -> bool:
    threshold_sq = MINIMAP_SPOT_DUPLICATE_THRESHOLD * MINIMAP_SPOT_DUPLICATE_THRESHOLD
    sx = float(source_spot["x"])
    sy = float(source_spot["y"])
    for target_spot in iter_array_items(target_spots):
        if not looks_like_spot(target_spot):
            continue
        dx = float(target_spot["x"]) - sx
        dy = float(target_spot["y"]) - sy
        if (dx * dx + dy * dy) <= threshold_sq:
            return True
    return False


def clone_spot(spot: OrderedDict[Any, Any]) -> OrderedDict[Any, Any]:
    copied: OrderedDict[Any, Any] = OrderedDict()
    for key, value in spot.items():
        copied[key] = value
    return copied


def merge_map_data(source: OrderedDict[Any, Any], target: OrderedDict[Any, Any]) -> dict[str, int]:
    stats = {
        "added": 0,
        "duplicates": 0,
        "invalid": 0,
        "maps": 0,
        "categories": 0,
    }

    for map_name, source_map_data in source.items():
        if not isinstance(map_name, str) or not isinstance(source_map_data, OrderedDict):
            stats["invalid"] += 1
            continue
        if map_name not in target or not isinstance(target.get(map_name), OrderedDict):
            target[map_name] = OrderedDict()
            stats["maps"] += 1
        target_map_data = target[map_name]

        for category, source_spots in source_map_data.items():
            if not isinstance(category, str) or not looks_like_spot_list(source_spots):
                stats["invalid"] += 1
                continue
            if category not in target_map_data or not isinstance(target_map_data.get(category), OrderedDict):
                target_map_data[category] = OrderedDict()
                stats["categories"] += 1
            target_spots = target_map_data[category]

            for source_spot in iter_array_items(source_spots):
                if not looks_like_spot(source_spot):
                    stats["invalid"] += 1
                    continue
                if is_duplicate(target_spots, source_spot):
                    stats["duplicates"] += 1
                    continue
                target_spots[next_array_index(target_spots)] = clone_spot(source_spot)
                stats["added"] += 1

    return stats


def add_stats(total: dict[str, int], partial: dict[str, int]) -> None:
    for key, value in partial.items():
        total[key] = total.get(key, 0) + value


def select_merge_pairs(
    source_tables: list[tuple[tuple[Any, ...], OrderedDict[Any, Any]]],
    target_tables: list[tuple[tuple[Any, ...], OrderedDict[Any, Any]]],
) -> list[tuple[OrderedDict[Any, Any], OrderedDict[Any, Any], tuple[Any, ...], tuple[Any, ...]]]:
    target_by_path = {path: table for path, table in target_tables}
    pairs = []
    unmatched = []

    for source_path, source_table in source_tables:
        target_table = target_by_path.get(source_path)
        if target_table is not None:
            pairs.append((source_table, target_table, source_path, source_path))
        else:
            unmatched.append((source_path, source_table))

    if unmatched and len(target_tables) == 1:
        target_path, target_table = target_tables[0]
        for source_path, source_table in unmatched:
            pairs.append((source_table, target_table, source_path, target_path))
        unmatched = []

    if unmatched:
        skipped = ", ".join(format_path(path) for path, _table in unmatched)
        raise LuaParseError(
            "could not choose a target data table for source path(s): "
            f"{skipped}. Use files with a single MiniMapSpots account/profile, or matching paths."
        )

    return pairs


def format_path(path: tuple[Any, ...]) -> str:
    if not path:
        return "<MiniMapSpots>"
    return ".".join(str(part) for part in path)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Merge MiniMap spot data from one Lua table into another."
    )
    parser.add_argument("source", type=Path, help="Lua file to read spots from")
    parser.add_argument("target", type=Path, help="Lua file to update")
    parser.add_argument(
        "--source-var",
        default=DEFAULT_SPOTS_VAR_NAME,
        help=f"source Lua variable name to read, default: {DEFAULT_SPOTS_VAR_NAME}",
    )
    parser.add_argument(
        "--target-var",
        default=DEFAULT_SPOTS_VAR_NAME,
        help=f"target Lua variable name to update, default: {DEFAULT_SPOTS_VAR_NAME}",
    )
    parser.add_argument(
        "--no-backup",
        action="store_true",
        help="do not create target.lua.bak before writing",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="parse and merge in memory, but do not write the target file",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()

    source_text = args.source.read_text(encoding="utf-8")
    target_text = args.target.read_text(encoding="utf-8")

    _source_start, _source_end, source_spots = find_lua_assignment(source_text, args.source_var)
    target_start, target_end, target_spots = find_lua_assignment(target_text, args.target_var)

    source_tables = collect_data_tables(source_spots)
    target_tables = collect_data_tables(target_spots)

    if not source_tables:
        raise LuaParseError(f"no spot data table found in {args.source}")
    if not target_tables:
        raise LuaParseError(f"no spot data table found in {args.target}")

    stats = {
        "added": 0,
        "duplicates": 0,
        "invalid": 0,
        "maps": 0,
        "categories": 0,
    }

    for source_table, target_table, _source_path, _target_path in select_merge_pairs(source_tables, target_tables):
        add_stats(stats, merge_map_data(source_table, target_table))

    if not args.dry_run:
        if not args.no_backup:
            shutil.copy2(args.target, args.target.with_suffix(args.target.suffix + ".bak"))
        merged_text = target_text[:target_start] + to_lua(target_spots, 0) + target_text[target_end:]
        args.target.write_text(merged_text, encoding="utf-8")

    mode = "dry-run" if args.dry_run else "written"
    print(
        f"{mode}: added={stats['added']} duplicates={stats['duplicates']} "
        f"invalid={stats['invalid']} new_maps={stats['maps']} "
        f"new_categories={stats['categories']}"
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, LuaParseError, ValueError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        raise SystemExit(1)
