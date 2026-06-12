-- luacheck configuration for the Relentless Endurance FG extension.
-- Fantasy Grounds runs Lua in a sandbox that injects many globals and expects
-- script functions (onInit, etc.) to be defined as globals, so we relax those rules.

std = "lua51"

-- Don't complain about setting/using FG-injected globals or our own global script API.
allow_defined_top = true
unused = false  -- many handler params (rSource, subselection, ...) are intentionally unused
max_line_length = false  -- long inline comments and DB string literals are normal in FG extensions

-- FG-injected globals available to extension scripts (read/write where applicable).
globals = {
    -- Engine entry points (onInit, onMenuSelection): defined for FG to call, never
    -- referenced by our own code. W131 (unused global) for these is ignored below.
    "onInit",
    "onMenuSelection",
    -- Ruleset action handlers: the extension deliberately replaces their .apply/.applyDamage
    -- fields to hook damage, so they must be writable.
    "ActionDamage",
    "ActionHealthD20",
}

-- W131 = "unused global variable"; expected for engine-invoked entry points above.
ignore = {
    "131",
}

read_globals = {
    "DB",
    "ActorManager",
    "EffectManager",
    "EffectManager5E",
    "Comm",
    "User",
    "Session",
    "CombatManager",
    "StringManager",
    -- This extension's own script, aliased via <script name="RelentlessEndurance"> in extension.xml.
    "RelentlessEndurance",
    -- Per-windowclass script environment (ct_host_ct_entry.lua).
    "super",
    "registerMenuItem",
    "getDatabaseNode",
}
