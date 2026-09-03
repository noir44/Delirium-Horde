# Delirium Horde

Build 42.20 port of **Horde Event** by BitBraven (Workshop `2992366401`, Build 41),
rewritten for the Delirium server. Mod id: `DelHor`.

## What it does

An admin right-clicks the ground and gets **Horde Event → New Event**. The window
lets you pick the square, the spawn radius, the zombie count, an outfit, the
per-zombie flags (knocked down / crawler / fake dead / fall on front /
invulnerable / sitting) and a health multiplier, plus:

- **Trigger Distance** — how close a player has to get before the zone fires.
- **Spawn Delay** — real seconds between the trigger and the horde appearing.
- **Loop Cycles** / **Loop Cooldown** — how many extra times the zone re-arms,
  and how many game minutes it stays dormant between firings.

Two world markers are drawn while the window is open: a red circle for the spawn
box and a yellow one for the trigger radius.

**Horde Event → Delete Event** lists the live zones by index, plus *Delete All*.

Zones live in the global ModData table `DelHor.eventList` and survive restarts.

## Layout

```
Contents/mods/DeliriumHorde/
├── mod.info                  (duplicate of 42/mod.info, for the mod list)
├── poster.png
└── 42/
    ├── mod.info              versionMin=42.20
    ├── poster.png
    └── media/lua/
        ├── shared/DeliriumHorde/DelHor_Shared.lua      constants + findByIndex
        ├── shared/Translate/<LANG>/{IG_UI,ContextMenu}.json
        ├── client/DeliriumHorde/DelHor_Client.lua      proximity check, ModData sync
        ├── client/DeliriumHorde/DelHor_Main.lua        admin context menu
        ├── client/DeliriumHorde/DelHor_SpawnHordeUI.lua  setup window
        └── server/DeliriumHorde/DelHor_Server.lua      authority: store + spawn
```

## Authority model

The client is presentation and timing only. It reports `TriggerEvent {index}`
when a player walks into a zone and `SpawnHorde {index}` when the delay runs
out — it never sends spawn parameters. The server:

- accepts `AddEvent` / `DeleteEvent` only from an `admin` access level,
- clamps every stored number (max 500 zombies, radius 100, trigger distance 200),
- checks the player really is near the zone, against its own copy of the position,
- spawns from the snapshot it took at trigger time, so a crafted packet cannot
  conjure a horde an admin never configured.

See [PORT.md](PORT.md) for the B41 → B42.20 API differences and the bugs fixed
along the way.

## Credits

Original mod and design: **BitBraven**. `delayFunction` is Konijima's. The setup
window derives from TIS base game code (`ISSpawnHordeUI`, Robert Johnson).
