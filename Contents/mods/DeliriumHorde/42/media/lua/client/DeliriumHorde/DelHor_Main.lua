--***********************************************************
--**  Delirium Horde - admin context menu                  **
--**  Based on "Horde Event" by BitBraven (Build 41)       **
--***********************************************************

if isServer() then return end

DelHorEvents = DelHorEvents or {}

local onNewEventWindow = function(square, playerObj)
    local ui = DelHor_SpawnHordeUI:new(0, 0, playerObj, square)
    ui:initialise()
    ui:addToUIManager()
end

local onDeleteEvent = function(eventIndex, playerObj)
    sendClientCommand(playerObj, DelHorEvents.MODULE, "DeleteEvent", { index = eventIndex })
end

local onWorldContextMenu = function(player, context, worldobjects, test)
    print("[DelHor] handler: isClient="..tostring(isClient())..
            " isAdmin="..tostring(isAdmin())..
            " mode="..tostring(getWorld():getGameMode())..
            " test="..tostring(test)..
            " nobjects="..tostring(worldobjects and #worldobjects))
    if not ((isClient() and isAdmin()) or getWorld():getGameMode() ~= "Multiplayer") then return true end
    if test and ISWorldObjectContextMenu.Test then return true end

    local playerObj = getSpecificPlayer(player)
    if not playerObj then print("[DelHor] bail: no playerObj") return end

    local square = nil
    for i, v in ipairs(worldobjects) do
        square = v:getSquare()
        break
    end
    -- No square under the cursor means nothing to anchor an event to.
    if not square then print("[DelHor] bail: no square") return end

    local hordeEventOption = context:addOption(getText("ContextMenu_DelHor_Event"), worldobjects, nil)
    local subMenu = ISContextMenu:getNew(context)
    context:addSubMenu(hordeEventOption, subMenu)

    subMenu:addOption(getText("ContextMenu_DelHor_NewEvent"), square, onNewEventWindow, playerObj)

    local deleteEventOption = subMenu:addOption(getText("ContextMenu_DelHor_DeleteEvent"), nil, nil)
    local delEventSubmenu = ISContextMenu:getNew(subMenu)
    subMenu:addSubMenu(deleteEventOption, delEventSubmenu)
    delEventSubmenu:addOption(getText("ContextMenu_DelHor_DeleteAllEvents"), -1, onDeleteEvent, playerObj)

    if not DelHorEvents.eventList then return end
    for i, event in ipairs(DelHorEvents.eventList) do
        delEventSubmenu:addOptionOnTop(getText("IGUI_DelHor_EventNumber") .. " " .. tostring(event.index),
                event.index, onDeleteEvent, playerObj)
    end
end

print("[DelHor] main loaded, handler registered")
Events.OnFillWorldObjectContextMenu.Add(onWorldContextMenu)
