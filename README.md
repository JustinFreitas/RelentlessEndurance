# Relentless Endurance

https://github.com/JustinFreitas/RelentlessEndurance

Relentless Endurance v1.4.2, by Justin Freitas

ReadMe and Usage Notes

The Relentless Endurance extension implements the 5e half-orc racial trait Relentless Endurance for the FGC and FGU 5E ruleset. When a half-orc with the trait would be reduced to 0 hit points (but not killed outright), the extension automatically caps the incoming damage so the actor is left with 1 hit point instead, and consumes a use of the trait.

For PCs, a "Relentless Endurance" power is created (if it doesn't already exist) the first time the trait actually triggers, and its available uses are tracked there. Once a PC has used their Relentless Endurance, it will no longer save them from dropping to 0 hit points until the power's `cast` count is reset (e.g. on a long rest). NPCs are tracked by the same trait but do not get a power created.

Per the rules, the trait does not trigger while temporary hit points remain, and it cannot save an actor from damage massive enough to kill them outright (when the leftover damage past 0 meets or exceeds the actor's hit point maximum).

There is also a manual path for an already-unconscious actor:

- A radial menu option ("Apply Relentless Endurance to Unconscious Actor") is added when right-clicking a Combat Tracker actor. If invoked, it leaves the actor at one wound short of max hit points and removes the Unconscious and Prone effects if present. It only applies to an actor that currently has the Unconscious effect and has the trait with a use available.
- A chat command `/relentless` applies the same result to a Combat Tracker actor by display name (case sensitive). The first match found is used. For example: `/relentless Zeb the Half-Orc`

Changelist:
- v1.4.2 - Adopt FGU v5.1.16 `hasMenuItem` dynamic radial menu slot selection on Combat Tracker entries to prevent slot collisions with other extensions (with fallback for older builds and 3-arg `super.onMenuSelection` forwarding).
- v1.4.1 - Fix multi-type damage clause capping (proportional distribution across damage types to prevent damage total mismatch), add strict /reload and campaign lifecycle idempotency guards, and clean build package.
- v1.4 - Temporary HP is now absorbed before the trait triggers; the "killed outright" instant-death case no longer triggers the trait; the Relentless Endurance power is no longer created during ordinary damage reads (only when the trait actually triggers); the FGU vehicle subtarget health branch is now reachable; assorted cleanup.
- v1.0.2 - Use safe wrapper functions for getting actors and effects; fix deprecated ActorManager and EffectManager5E usage.
- v1.0 - Initial version.
