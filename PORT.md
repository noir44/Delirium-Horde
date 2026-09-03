# Horde Event (B41) → Delirium Horde (B42.20)

Source: `Horde Event` by BitBraven, Steam Workshop `2992366401` — 4 Lua files
(~675 lines), 11 languages, `mod.info` without `versionMin`, `media/` at the mod
root (B41 layout). Everything below was checked against the live 42.20 install
at `E:\pz-srv` (`media/lua` and `java/projectzomboid.jar`), not against memory.

## Blockers — the mod could not run on 42.20 without these

### 1. `addZombiesInOutfit` signature changed

B41: `(x, y, z, count, outfit, femaleChance, crawler, isFallOnFront, isFakeDead, knockedDown, health)` — 11 args.

B42.20 overloads, read out of `LuaManager$GlobalObject.class`:

```
(IIIILjava/lang/String;Ljava/lang/Integer;)
(IIIILjava/lang/String;Ljava/lang/Integer;ZZZZZZF)
(IIIILjava/lang/String;Ljava/lang/Integer;ZZZZZZFZ)
(IIIILjava/lang/String;Ljava/lang/Integer;ZZZZZZFZF)
(IIIILjava/lang/String;Ljava/lang/Integer;ZZZZZZFZFZ)
(IIIILjava/lang/String;Ljava/lang/Integer;ZZZZZZFZFZZ)
```

Order is now `..., crawler, isFallOnFront, isFakeDead, knockedDown,
isInvulnerable, isSitting, health, isRecordingAnims, heightOffset,
isRagdolling, onFire`. **There is no 4-boolean + float overload any more**, so
the B41 call has no match at all — it puts `health` (a float) into the
`isInvulnerable` slot and throws. Fixed by moving to the 13-argument form and
adding the two new flags to the UI. Reference: vanilla
`client/DebugUIs/ISSpawnHordeUI.lua:276`.

Server-side spawning is legitimate: `zombie/commands/serverCommands/CreateHorde2Command`
calls the same `LuaManager.GlobalObject.addZombiesInOutfit`.

### 2. Translations `.txt` → `.json`

B42 reads JSON only. The 22 B41 files wrapped their strings in a Lua table
(`IGUI_EN = { ... }`) and were in per-language codepages — `RU`/`PL` came back
as Cp1251/Cp1250, `CH`/`JP` were already UTF-8. Converted to flat
`Translate/<LANG>/IG_UI.json` and `ContextMenu.json`, UTF-8 without BOM, no
language suffix in the filename. Keys were namespaced at the same time
(`IGUI_Radius` → `IGUI_DelHor_Radius`) because the old ones were generic enough
to collide with another mod's. RU strings were rewritten — the originals were
machine-translated ("Зомби номер", "Циклы цикла").

Left as-is on purpose: the tick-box labels, *None*, *Male Only*, *Female Only*,
*Close* and *Health* now use vanilla's own keys, which are already translated in
every language the game ships.

### 3. Mod layout

`mods/HordeEvent/media/...` → `Contents/mods/DeliriumHorde/42/media/...` with
`versionMin=42.20`, plus the duplicate root `mod.info` the other Delirium repos
use. Workshop id removed, mod id is now `DelHor`.

## Checked and unchanged — no work needed

- `ModData` — `exists / getOrCreate / get / add / remove / request / transmit`
  all still present (`zombie/world/moddata/GlobalModData`).
- `Events.OnFillWorldObjectContextMenu`, and the
  `if test and ISWorldObjectContextMenu.Test then return true end` idiom.
- `ISContextMenu:getNew / addSubMenu / addOption / addOptionOnTop`.
- `ISCollapsableWindow`, `ISLabel` (incl. `setNameWithoutMoving`), `ISButton`
  (incl. `enableCancelColor`), `ISTextEntryBox:setOnlyNumbers`,
  `ISComboBox:addOptionWithData / setEditable`, `ISTickBox`,
  `ISSliderPanel:setValues / getCurrentValue` — the slider file moved to
  `client/RadioCom/ISUIRadio/`, the API did not change.
- `ISDebugUtils.addLabel / addSlider / printval` and the
  `*NoReturnOffset` variants — same signatures.
- `ISSelectCursor:new(character, ui, onSquareSelected)` and
  `getCell():setDrag(cursor, playerNum)`.
- `getWorldMarkers():addGridSquareMarker(...)`, `:addDirectionArrow(...)`,
  `:setScaleCircleTexture(true)`.
- `getAllOutfits(bool)`, `getPlayerScreenLeft/Top/Width/Height`,
  `getWorld():getGameMode()`, `IsoPlayer:getAccessLevel()`.

## Bugs fixed on the way over

These are B41 bugs, not build differences — they would have bitten on the first
live test.

1. **`if event.currCooldown > 0` with a nil cooldown.** Every relational
   operator in Kahlua is a metamethod call and `nil` has none, so this throws
   `__lt not defined for operand` — once per game minute, aborting the whole
   `EveryOneMinute` handler. Now guarded.
2. **`eventList` indexed by `event.index` but mutated with `table.remove`.**
   `TriggerEvent(i)` and `DeleteEvent(i)` did `eventList[i]`, where `i` is the
   stable index shown in the menu, not the array position. After the first
   deletion the two stop agreeing and `eventList[i]` can be nil → `.loopCycles`
   on nil. Replaced with `DelHorEvents.findByIndex()`.
3. **`DeleteEvent` removed twice** — `eventList[i] = nil` *and*
   `table.remove(eventList, i)`.
4. **Deleted events stayed alive on clients.** `onReceiveGlobalModData` merged
   the incoming table into the local one without clearing it first, so a
   removed zone kept firing on every client that had already seen it.
5. **`AddEvent` computed `index` twice**, the first assignment dead.
6. **No square under the cursor** → `square:getX()` on nil in the UI
   constructor. The menu now bails out instead.
7. **The client decided what to spawn.** It sent the whole event table with
   `SpawnHorde` and the server passed it straight to `addZombiesInOutfit` —
   any client could spawn an arbitrary horde anywhere. Now the client sends
   only `{index}`; the server spawns from a snapshot it took when it accepted
   the trigger, after checking the player's server-known position and clamping
   every stored number. `AddEvent`/`DeleteEvent` additionally require `admin`.
8. **`EveryOneMinute` ran on clients too** — `media/lua/server` is loaded by
   connected clients, so every client was also decrementing its own copy of the
   cooldowns. The server file now returns early when `isClient()`.

## Layout rework

The B41 window hard-coded `y = 60`, three fixed columns and a 430×450 frame,
and drew the picked-square text at `y = 25` — which lands on the title bar once
B42 scales the UI font. Rebuilt off `self:titleBarHeight()`,
`getTextManager():getFontHeight()` and a measured label column, with the frame
sized from its contents and re-centred afterwards.

## Not done

- `luac5.4 -p` has not been run — no Lua toolchain on this machine. Run it
  before shipping.
- Untested in game. Nothing here has been through a live server round.
- The remaining B42 spawn flags (`isRecordingAnims`, `heightOffset`,
  `isRagdolling`, `onFire`) are not exposed; the 13-argument overload is used,
  which leaves them at their engine defaults.
