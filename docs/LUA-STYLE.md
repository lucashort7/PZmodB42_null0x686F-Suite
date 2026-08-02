# Lua Style Guide — null0x686F suite

The coding standard for `null0x686F_CoreLib`, `_QoL`, `_ContextCleaner` and `_CombatText`.

This does for code what [`RELEASE-PLAYBOOK.md`](RELEASE-PLAYBOOK.md) does for git and releases: it
writes down what was previously carried in someone's head, so a reviewer can point at a line instead
of arguing taste.

## Where these rules come from

Three layers, in precedence order:

1. **[luarocks/lua-style-guide](https://github.com/luarocks/lua-style-guide)** — the closest thing
   Lua has to a community baseline. Anything not contradicted below still applies.
2. **Observed practice in professional Lua** — Kong, OpenResty, the Neovim plugin ecosystem,
   LuaRocks, Tarantool. Rules carrying a citation were checked against real production code, not
   asserted.
3. **Project Zomboid / Kahlua reality** — the engine constraints that override everything above.

Where a rule is enforced by `luacheck`, that is noted. **A rule nobody enforces is a rule that
rots**; the linter is what makes this document real. See ADR-0005.

> **A Foolish Consistency is the Hobgoblin of Little Minds** — PEP 8, and it applies here.
> See [When to break these rules](#when-to-break-these-rules) at the end. That section is part of the
> guide, not an escape hatch bolted on.

---

## 1. Naming

| Kind | Convention | Example |
|---|---|---|
| local variable, function | `snake_case` | `target_color`, `find_replacement()` |
| module-private | `_snake_case` | `_last_highlighted_zombie` |
| constant | `SCREAMING_SNAKE_CASE` | `DEFAULT_PRIORITY`, `SECTION_ORDER` |
| class-like table (`ISPanel:derive`) | `PascalCase` | `ContextCleanerWindow` |
| patched-marker global | `__NULL0X686F_PATCHED` | — |

**Never `camelCase` for our own code.** Calls into the engine keep the engine's Java-derived names
(`getSpecificPlayer`, `setPrimaryHandItem`) — that is their API, not ours.

`snake_case` is confirmed universal in professional Lua: `encode_args()`, `validate_http_token()`
(Kong `tools/http.lua`); `M.normname()`, `M.pretty_trace()` (`lazy.nvim core/util.lua`);
`M.root_pattern()` (`nvim-lspconfig/util.lua`). Constants in `SCREAMING_SNAKE_CASE` are unanimous.

---

## 2. Module structure

**Return a table literal listing the public surface.**

```lua
-- good: the public API is visible in one glance, at the bottom of the file
local function init() ... end
local function reload_preset(id) ... end

return {
  init = init,
  reload_preset = reload_preset,
}
```

Both forms are attested in professional Lua — Kong and OpenResty use `local _M = {}` … `return _M`;
`lua-resty-core` returns a table literal. **The suite standardises on the literal**, which is what 13
of its 24 modules already do, against 11 using a named local.

*This reverses `pz-b42-modding/SKILL.md` §3, which mandated `local M = {} ... return M` while the
majority of the codebase did the opposite. The guide was lying; now it isn't.*

**Config modules are the exception** — `return cfg` where `cfg` is the table being described reads
better than wrapping it. Five modules do this and should stay.

---

## 3. Public vs private

**Privacy is enforced by scope, not by naming.** A private function is a `local` that never enters
the returned table. The `_` prefix is a *signal of intent* on top of that, not the mechanism.

```lua
local function _apply_break_behavior(item)  -- local: unreachable from outside
  ...
end

return { init = init }                      -- and not exported: that is what enforces it
```

Kong does exactly this and does **not** prefix private functions at all — `kong/tools/module.lua`
and `kong/db/dao/init.lua` export only what belongs to the API and keep the rest in locals.
`lazy.nvim` marks intent with a `---@private` annotation instead of a name.

**The suite keeps the `_` prefix**, because it is already consistent across four repos and the
benefit of renaming does not survive the churn. But understand what it is: documentation, not a lock.

---

## 4. Constants and config

- **Module-local constants** go at the top of the file, above the first function.
- **Values shared across mods** go in CoreLib. If two mods need the same number, it is not a local
  constant any more.
- **User-facing settings** live in the mod's `cfg.lua`, never inline.

This mirrors Kong: cross-cutting values in `kong/constants.lua`, module-local ones at the top of the
file (`local BUF_MAX_LEN = 1024` in `tools/http.lua`).

---

## 5. Caching globals — conditional, and mostly you should not

**Cache a global only in a genuinely hot path.** Per-frame render, per-tick, or a loop over every
zombie or every inventory item.

```lua
-- justified: runs every rendered frame
local _get_specific_player = getSpecificPlayer
Events.OnPostRender.Add(function() ... end)
```

```lua
-- not justified: this file runs once at boot
local _ipairs = ipairs
local _pcall = pcall
```

**This is the rule most often broken here, and it is measurable.** 21 files in the suite cache
globals; **only 3 contain a hot event**. `context_cleaner.lua` caches 11 globals with no per-frame
code at all; `modoptions.lua` caches 8 in a file that runs once during boot.

The pattern is copied, not reasoned about — and it costs real readability: `_string_format` at every
call site instead of `string.format`, for a lookup that happens once.

The professional evidence is that this is **subsystem-dependent, not a Lua rule**: Kong and
OpenResty cache systematically in nginx request paths and FFI code (`kong/tools/http.lua`,
`kong/tools/string.lua`); `lazy.nvim` and `nvim-lspconfig` cache nothing and call `vim.api` directly.

**Test before caching:** *does this line run more than once per player action?* If no, do not cache.

---

## 6. Error handling

Three patterns, chosen by situation — the split is Kong's and it is worth copying:

| Situation | Pattern |
|---|---|
| Broken contract / bad argument | `error("message", 2)` — level 2 blames the caller |
| Expected failure (missing item, absent option, I/O) | `return nil, err` |
| Calling code we do not own | `pcall` / `xpcall`, and handle the failure |

The third case is not theoretical here: every vanilla monkeypatch (`ISWearClothing`,
`ISInventoryTransferAction`, the `OnBreak` handlers) may already have been wrapped by another mod.
Assume the thing you are calling can throw.

> ⚠️ **Kahlua has no `xpcall`.** Use `pcall`. See [§9](#9-kahlua-is-not-full-lua-51).

---

## 7. Comments and annotations

**Style: lowercase, no numbered lists, and never restate the code.**

```lua
-- bad
-- loop through the items
for _, item in ipairs(items) do

-- good: says why, which the code cannot
-- OnEquipPrimary fires twice per break -- once synchronously from inside
-- HandleHandler, once after the weapon handler returns. see skill §V.
```

Kong's own implementation comments are exactly this — `kong/tools/string.lua` carries
*"This code is optimized, you can find microbenchmarks in: <PR link>"*, which is context that cannot
be derived from the source.

**Type annotations: LuaLS (`---@param`, `---@return`, `---@class`), never Luadoc.**

No project mixes the two, so it is a choice rather than a preference — and the suite's is already
made, because Umbrella *is* LuaLS annotation and the language server is already the tooling in play.
Adding Luadoc would mean two systems neither tool fully reads.

```lua
---@param player IsoPlayer
---@param item InventoryItem
---@return boolean
local function _can_equip(player, item)
```

---

## 8. Localization

**Every user-visible string goes through `getText()`.** No literal that a player can read belongs in
a `.lua` file.

Key format, suite-wide:

```
UI_null0x686F_<Mod>_<key>
UI_null0x686F_QoL_hide_worn
UI_null0x686F_QoL_hide_worn_tooltip
```

The prefix is not decoration — `Zomboid/Lua/` already hosts three different naming conventions from
this suite alone, and translation keys share a flat global namespace with every other installed mod.

English (`Translate/EN/`) is the source of truth and the only one we maintain. Other languages are
community contributions: a translator sends a `.txt` and never touches Lua.

---

## 9. Kahlua is not full Lua 5.1

PZ runs **Kahlua**, a partial Lua 5.1 implemented in Java. Several things the language reference
promises do not exist. `luacheck` is configured to reject them (ADR-0005), but know why:

| Missing | Use instead |
|---|---|
| all of `io.*` | `getFileReader()` / `getFileWriter()` |
| `os.*` except `date`, `difftime`, `time` | — no `os.remove`, no `os.rename`, no `os.exit` |
| `package.*` | `require` works; the table does not |
| `debug.*` | flat global `debugstacktrace()` |
| `xpcall`, `dofile`, `newproxy` | `pcall` |

> ⚠️ **A consequence worth flagging:** the atomic file-swap pattern (`.tmp` + `os.remove` +
> `os.rename`) recommended in `pz-b42-modding/SKILL.md` §3 **cannot work on Kahlua**. That guidance
> needs revisiting; it is not addressed by this document.

**Java collections handed to Lua are zero-indexed, and `#` and `ipairs` do not work on them.** Use
the object's own `:size()` and `:get(i)`. This is a silent wrong-answer bug, not a crash, and no
linter catches it.

---

## 10. Engine constraints that override everything

**Every `.lua` file under `media/lua/client/` is executed at boot, whether or not anything
`require`s it.** Commenting out a `require()` does not disable a feature. Registration must go
through an explicit `init()` called from `client.lua`.

**Hook the event that *is* the fact, not one you can infer it from.** `OnBreak` *is* the break;
`OnPlayerAttackFinished` is a guess about it. Getting this wrong is not a performance problem, it is
a correctness problem — the suite has shipped two features hooked to the wrong event.

**One state change can dispatch its event twice.** Picking the right event does not finish the job:
measure how many times it actually fires before relying on it.

---

## When to break these rules

Every rule above serves readability or correctness. When following one damages either, break it —
and leave a comment saying why, because an unexplained deviation reads as a mistake and the next
person will "fix" it.

Legitimate reasons:

- **Vanilla API shape.** Engine calls keep engine naming.
- **A measured hot path.** Cache the globals, and say what you measured.
- **Mirroring third-party structure.** Code adapted from another mod may keep its shape so the diff
  against the original stays readable.

Not legitimate: "the other file does it that way." That is how the global-caching cargo cult spread
here in the first place.
