#!/usr/bin/env bash
# Extract top-level (runtime) global names from Umbrella LuaLS stub files.
#
# Umbrella (~2900 stub files under library/) mirrors the actual PZ Lua
# runtime: every real global is a column-0 statement of one of two shapes:
#   1. function Name(...) ... end        -- global function
#   2. Name = <expr>                      -- global table/class/value
# `---@class`/`---@field`/`---@type`/`---@param` annotations are LuaLS-only
# metadata (comments) and do NOT correspond 1:1 with globals -- many
# ---@class blocks describe a *type* that is only ever used as a field type
# or return type, never itself bound to a bare global. So we do not parse
# annotations; we parse the actual Lua statements the file would execute,
# which is what luacheck (and the PZ engine) actually cares about.
#
# Dotted assignments (GameWindow.DEBUG_SAVE = nil) and colon/dot method
# defs (function GameWindow.Foo(...), function ISBaseObject:instanceof(...))
# are deliberately excluded: they are *fields* of an already-captured
# global, not new globals themselves.
#
# `local X = ...` at column 0 is excluded (not a global).

set -euo pipefail

UMBRELLA_ROOT="${1:-/mnt/c/Users/lucas/Documents/Umbrella/library}"

find "$UMBRELLA_ROOT" -type f -name '*.lua' -print0 |
  xargs -0 grep -hE '^(function [A-Za-z_][A-Za-z0-9_]*\s*\(|[A-Za-z_][A-Za-z0-9_]*\s*=[^=])' -- |
  sed -E \
    -e 's/^function ([A-Za-z_][A-Za-z0-9_]*)\s*\(.*/\1/' \
    -e 's/^([A-Za-z_][A-Za-z0-9_]*)\s*=.*/\1/' |
  grep -vE '^(local|return|if|for|while|repeat|do|end|then|else|elseif|function|break)$' |
  sort -u

# --- Kahlua std lua51 SUBTRACTIONS (not this script's job to prove, just to
# record): luacheck's std="lua51" is PUC-Rio Lua 5.1, but Kahlua (PZ's
# interpreter) only implements a subset of it -- BaseLib, CoroutineLib,
# OsLib, RandomLib, StringLib, TableLib in
# core/src/se/krka/kahlua/stdlib/. No IoLib, no PackageLib, and
# debug/xpcall/dofile/newproxy aren't registered in BaseLib.java either.
# OsLib.java only registers os.date/os.difftime/os.time. See .luacheckrc's
# `not_globals` for the actual subtraction list -- kept there, not here,
# since it's a fixed correction to the std, not something re-derived from
# Umbrella on every run.
#
# --- Kahlua stdlib extensions ---
# Kahlua (PZ's Lua 5.1 interpreter) adds a handful of extra fields to the
# *standard* table/string/math libraries (table.wipe, string.trim,
# math.clamp, ...). Those aren't new globals -- table/string/math already
# exist under std=lua51 -- they're extra fields on existing globals, so
# they can't go in the flat name list above. Emitted separately (one
# "libname.fieldname" per line) so the caller can fold them into
# `globals.<lib>.fields` in .luacheckrc instead.
find "$UMBRELLA_ROOT" -type f -name '*.lua' -print0 |
  xargs -0 grep -hoE '^function (table|string|math|os|io)\.[A-Za-z_][A-Za-z0-9_]*\s*\(' -- |
  sed -E 's/^function ([a-z]+)\.([A-Za-z_][A-Za-z0-9_]*)\s*\(.*/\1.\2/' \
  > "${STDLIB_FIELDS_OUT:-/dev/null}" 2>/dev/null || true
find "$UMBRELLA_ROOT" -type f -name '*.lua' -print0 |
  xargs -0 grep -hoE '^(table|string|math|os|io)\.[A-Za-z_][A-Za-z0-9_]*\s*=[^=]' -- |
  sed -E 's/^([a-z]+)\.([A-Za-z_][A-Za-z0-9_]*)\s*=.*/\1.\2/' \
  >> "${STDLIB_FIELDS_OUT:-/dev/null}" 2>/dev/null || true
