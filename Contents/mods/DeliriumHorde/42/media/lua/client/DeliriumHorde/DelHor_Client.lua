--***********************************************************
--**  Delirium Horde - client side                         **
--**  Based on "Horde Event" by BitBraven (Build 41)       **
--***********************************************************

if isServer() then return end

DelHorEvents = DelHorEvents or {}

local tickCounter = 0

local function onInitGlobalModData()
    if not isClient() then return end

    if ModData.exists(DelHorEvents.MODDATA_KEY) then
        ModData.remove(DelHorEvents.MODDATA_KEY)
    end

    DelHorEvents.eventList = ModData.getOrCreate(DelHorEvents.MODDATA_KEY)
    ModData.request(DelHorEvents.MODDATA_KEY)
end

local function onReceiveGlobalModData(modDataName, data)
    if not isClient() then return end
    if modDataName ~= DelHorEvents.MODDATA_KEY then return end
    if not DelHorEvents.eventList then return end
    if not data then return end

    -- Clear before merging. Merging alone leaves deleted events alive on the
    -- client, which then keeps triggering zones the server no longer knows about.
    for i = #DelHorEvents.eventList, 1, -1 do
        table.remove(DelHorEvents.eventList, i)
    end
    for key, value in pairs(data) do
        DelHorEvents.eventList[key] = value
    end
end

-- Credits for this function: Konijima
local delayFunction = function(func, delay)

    delay = delay or 1
    local ticks = 0
    local canceled = false

    local function onTick()

        if not canceled and ticks < delay then
            ticks = ticks + 1
            return
        end

        Events.OnTick.Remove(onTick)
        if not canceled then func() end
    end

    Events.OnTick.Add(onTick)
    return function()
        canceled = true
    end
end

-- The client only reports "I walked into zone N". Every parameter of the horde
-- comes from the copy the server holds, so nothing here can be tampered with.
local triggerEvent = function(hordeEvent)
    local index = hordeEvent.index
    local playerObj = getPlayer()
    if not playerObj then return end

    sendClientCommand(playerObj, DelHorEvents.MODULE, "TriggerEvent", { index = index })

    delayFunction(function()
        local player = getPlayer()
        if not player then return end
        sendClientCommand(player, DelHorEvents.MODULE, "SpawnHorde", { index = index })
    end, (hordeEvent.delay or 0) * 60)
end

local OccasionalCheck = function(playerObj)
    if not playerObj then return end
    if not DelHorEvents.eventList then return end

    local playerX = playerObj:getX()
    local playerY = playerObj:getY()
    local playerZ = playerObj:getZ()

    for i, event in ipairs(DelHorEvents.eventList) do
        local square = event.centralSquare

        if square and playerZ == square.z then
            local triggerDistance = (event.triggerDistance or 20) + (event.radius or 0)
            local dx = playerX - square.x
            local dy = playerY - square.y

            if (dx * dx + dy * dy) < (triggerDistance * triggerDistance) then
                if not event.spent and (not event.currCooldown or event.currCooldown == 0) then
                    triggerEvent(event)
                end
            end
        end
    end
end

local onTick = function()
    local playerObj = getPlayer(); if not playerObj then return end

    if tickCounter < 70 then
        tickCounter = tickCounter + 1
    else
        OccasionalCheck(playerObj)
        tickCounter = 0
    end
end

local function onServerCommand(module, command, arguments)
    if module ~= DelHorEvents.MODULE then return end
    if command ~= "UpdateEvents" then return end
    if not isClient() then return end

    if ModData.exists(DelHorEvents.MODDATA_KEY) then
        ModData.remove(DelHorEvents.MODDATA_KEY)
    end

    DelHorEvents.eventList = ModData.getOrCreate(DelHorEvents.MODDATA_KEY)
    ModData.request(DelHorEvents.MODDATA_KEY)
end

Events.OnServerCommand.Add(onServerCommand)
Events.OnTick.Add(onTick)
Events.OnInitGlobalModData.Add(onInitGlobalModData)
Events.OnReceiveGlobalModData.Add(onReceiveGlobalModData)
