--***********************************************************
--**  Delirium Horde - admin context menu                  **
--**  Based on "Horde Event" by BitBraven (Build 41)       **
--***********************************************************

if isServer() then return end

DelHorEvents = DelHorEvents or {}

-- isAdmin() came back false for a player the server had logged in with
-- role="admin" (vanilla's own AdminContextMenu, gated the same way, was
-- missing from that client's menu too). getAccessLevel() is the value the
-- server actually enforces, so gate on that and keep isAdmin() as a fast path.
local function canManageEvents()
    if getWorld():getGameMode() ~= "Multiplayer" then return true end
    if isAdmin() then return true end

    local level = getAccessLevel()
    if not level then return false end
    level = string.lower(level)

    return level == "admin" or level == "moderator" or level == "overseer" or level == "gm"
end

local onNewEventWindow = function(square, playerObj)
    local ui = DelHor_SpawnHordeUI:new(0, 0, playerObj, square)
    ui:initialise()
    ui:addToUIManager()
end

local onDeleteEvent = function(eventIndex, playerObj)
    sendClientCommand(playerObj, DelHorEvents.MODULE, "DeleteEvent", { index = eventIndex })
end

local onWorldContextMenu = function(player, context, worldobjects, test)
    print("[DelHor] handler: isAdmin=" .. tostring(isAdmin()) ..
            " accessLevel=" .. tostring(getAccessLevel()) ..
            " allowed=" .. tostring(canManageEvents()))
    if not canManageEvents() then return true end
    if test and ISWorldObjectContextMenu.Test then return true end

    local playerObj = getSpecificPlayer(player)
    if not playerObj then return end

    local square = nil
    for i, v in ipairs(worldobjects) do
        square = v:getSquare()
        break
    end
    -- No square under the cursor means nothing to anchor an event to.
    if not square then return end

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

Events.OnFillWorldObjectContextMenu.Add(onWorldContextMenu)
