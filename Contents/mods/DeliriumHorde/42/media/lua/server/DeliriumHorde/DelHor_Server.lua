--***********************************************************
--**  Delirium Horde - server side                         **
--**  Based on "Horde Event" by BitBraven (Build 41)       **
--***********************************************************

-- media/lua/server is loaded by connected clients too; this file is the
-- authority for the event list and must only ever run on the server / in SP.
if isClient() then return end

DelHorEvents = DelHorEvents or {}

-- Snapshot of what a client was promised when it reported entering a zone.
-- The spawn is driven off this, never off the payload that arrives with
-- SpawnHorde, so a crafted packet cannot spawn anything an admin did not set up.
local pendingSpawns = {}

local function isAdminPlayer(playerObj)
    if not isServer() then return true end
    if not playerObj then return false end
    local level = playerObj:getAccessLevel()
    if not level then return false end
    level = string.lower(level)

    -- Must match the client-side gate in DelHor_Main.lua, or the menu shows
    -- for someone whose AddEvent the server then silently drops.
    return level == "admin" or level == "moderator" or level == "overseer" or level == "gm"
end

local function clampNumber(value, min, max, default)
    local n = tonumber(value)
    if not n then return default end
    if n < min then return min end
    if n > max then return max end
    return n
end

DelHorEvents.UpdateClients = function()
    if isServer() then
        local onlinePlayers = getOnlinePlayers()
        if not onlinePlayers then return end

        for i = 1, onlinePlayers:size() do
            local player = onlinePlayers:get(i - 1)
            if player then
                sendServerCommand(player, DelHorEvents.MODULE, "UpdateEvents", {})
            end
        end
    else
        local player = getPlayer()
        if player then
            sendServerCommand(player, DelHorEvents.MODULE, "UpdateEvents", {})
        end
    end
end

-- The client picks the numbers, the server decides what is acceptable.
local function sanitize(values)
    if not values then return nil end

    local square = values.centralSquare
    if not square then return nil end
    if not square.x or not square.y or not square.z then return nil end

    return {
        zNumber = clampNumber(values.zNumber, 1, DelHorEvents.MAX_ZOMBIES, 1),
        radius = clampNumber(values.radius, 0, DelHorEvents.MAX_RADIUS, 0),
        triggerDistance = clampNumber(values.triggerDistance, 1, DelHorEvents.MAX_TRIGGER_DISTANCE, 20),
        delay = clampNumber(values.delay, 0, 3600, 0),
        loopCycles = clampNumber(values.loopCycles, 0, 9999, 0),
        loopCooldown = clampNumber(values.loopCooldown, 0, 9999, 0),
        currCooldown = 0,
        zOutfit = values.zOutfit,
        femChance = values.femChance,
        isKnockedDown = values.isKnockedDown == true,
        isCrawler = values.isCrawler == true,
        isFakeDead = values.isFakeDead == true,
        isFallOnFront = values.isFallOnFront == true,
        isInvulnerable = values.isInvulnerable == true,
        isSitting = values.isSitting == true,
        zHealth = clampNumber(values.zHealth, 0, 2, 1),
        centralSquare = { x = math.floor(square.x), y = math.floor(square.y), z = math.floor(square.z) },
    }
end

DelHorEvents.AddEvent = function(values, playerObj)
    if not isAdminPlayer(playerObj) then return end
    if not DelHorEvents.eventList then return end

    local event = sanitize(values)
    if not event then return end

    local last = DelHorEvents.eventList[#DelHorEvents.eventList]
    if last and last.index then
        event.index = last.index + 1
    else
        event.index = 1
    end

    table.insert(DelHorEvents.eventList, event)
    DelHorEvents.UpdateClients()
end

-- No permission check: also called when an event runs out of loop cycles.
DelHorEvents.RemoveEvent = function(index)
    if not DelHorEvents.eventList then return end

    if index == -1 then
        for i = #DelHorEvents.eventList, 1, -1 do
            table.remove(DelHorEvents.eventList, i)
        end
        return
    end

    local pos = DelHorEvents.findByIndex(index)
    if pos then
        table.remove(DelHorEvents.eventList, pos)
    end
end

DelHorEvents.DeleteEvent = function(index, playerObj)
    if not isAdminPlayer(playerObj) then return end
    if not index then return end

    DelHorEvents.RemoveEvent(index)
    DelHorEvents.UpdateClients()
end

local function isPlayerNearEvent(playerObj, event)
    if not playerObj then return false end

    local square = event.centralSquare
    if not square then return false end
    if playerObj:getZ() ~= square.z then return false end

    -- Generous slack: the server's copy of the position lags the client's.
    local reach = (event.triggerDistance or 20) + (event.radius or 0) + 10
    local dx = playerObj:getX() - square.x
    local dy = playerObj:getY() - square.y

    return (dx * dx + dy * dy) < (reach * reach)
end

DelHorEvents.TriggerEvent = function(index, playerObj)
    if not DelHorEvents.eventList then return end

    local _, event = DelHorEvents.findByIndex(index)
    if not event then return end
    if event.currCooldown and event.currCooldown > 0 then return end
    if not isPlayerNearEvent(playerObj, event) then return end

    -- Snapshot now. The event may be deleted a few lines below, but the horde
    -- it already promised still has to spawn when the client's delay runs out.
    if playerObj then
        pendingSpawns[playerObj:getUsername()] = { index = index, event = event, age = 0 }
    end

    if event.loopCycles then
        event.loopCycles = event.loopCycles - 1
        event.currCooldown = event.loopCooldown or 0
    end

    if not event.loopCycles or event.loopCycles < 0 then
        DelHorEvents.RemoveEvent(index)
    end

    DelHorEvents.UpdateClients()
end

DelHorEvents.SpawnHorde = function(index, playerObj)
    if not playerObj then return end

    local username = playerObj:getUsername()
    local pending = pendingSpawns[username]
    if not pending then return end
    if pending.index ~= index then return end
    pendingSpawns[username] = nil

    local event = pending.event
    local square = event.centralSquare
    local radius = event.radius

    for i = 1, event.zNumber do
        local x = ZombRand(square.x - radius, square.x + radius + 1)
        local y = ZombRand(square.y - radius, square.y + radius + 1)

        -- B42 signature. B41 took 11 arguments and ended on health; B42 has no
        -- such overload - isInvulnerable and isSitting sit between knockedDown
        -- and health. See vanilla client/DebugUIs/ISSpawnHordeUI.lua.
        addZombiesInOutfit(x, y, square.z, 1,
            event.zOutfit, event.femChance,
            event.isCrawler, event.isFallOnFront, event.isFakeDead, event.isKnockedDown,
            event.isInvulnerable, event.isSitting, event.zHealth)
    end
end

local function everyMinute()
    if not DelHorEvents.eventList then return end

    for i, event in ipairs(DelHorEvents.eventList) do
        -- currCooldown can be nil, and comparing nil with > throws in Kahlua
        -- ("__lt not defined for operand") on every call that reaches it.
        if event.currCooldown and event.currCooldown > 0 then
            event.currCooldown = event.currCooldown - 1
        end
    end

    -- Drop spawn promises whose client never came back for them.
    local stale = {}
    for username, pending in pairs(pendingSpawns) do
        pending.age = (pending.age or 0) + 1
        if pending.age > 10 then
            table.insert(stale, username)
        end
    end
    for i, username in ipairs(stale) do
        pendingSpawns[username] = nil
    end
end

local function onClientCommand(module, command, playerObj, args)
    if module ~= DelHorEvents.MODULE then return end

    if command == "AddEvent" then
        DelHorEvents.AddEvent(args, playerObj)
    elseif command == "DeleteEvent" then
        DelHorEvents.DeleteEvent(args and args.index, playerObj)
    elseif command == "TriggerEvent" then
        DelHorEvents.TriggerEvent(args and args.index, playerObj)
    elseif command == "SpawnHorde" then
        DelHorEvents.SpawnHorde(args and args.index, playerObj)
    end
end

local function onInitGlobalModData()
    DelHorEvents.eventList = ModData.getOrCreate(DelHorEvents.MODDATA_KEY)
end

Events.EveryOneMinute.Add(everyMinute)
Events.OnClientCommand.Add(onClientCommand)
Events.OnInitGlobalModData.Add(onInitGlobalModData)
