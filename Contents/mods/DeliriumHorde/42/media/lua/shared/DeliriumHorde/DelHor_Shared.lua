--***********************************************************
--**  Delirium Horde - shared definitions                  **
--**  Based on "Horde Event" by BitBraven (Build 41)       **
--***********************************************************

DelHorEvents = DelHorEvents or {}
DelHorEvents.eventList = DelHorEvents.eventList or {}

DelHorEvents.MODULE = "DelHor"
DelHorEvents.MODDATA_KEY = "DelHor.eventList"

-- Hard caps. Applied server-side when an event is stored, so a crafted packet
-- cannot ask for a hundred thousand zombies.
DelHorEvents.MAX_ZOMBIES = 500
DelHorEvents.MAX_RADIUS = 100
DelHorEvents.MAX_TRIGGER_DISTANCE = 200

function DelHorEvents.count(tbl)
    if not tbl then return 0 end
    local n = 0
    for _ in pairs(tbl) do n = n + 1 end
    return n
end

-- Events are addressed by their stable .index, never by array position:
-- table.remove() shifts every position after it, .index never moves.
function DelHorEvents.findByIndex(index)
    if not index then return nil, nil end
    for pos, event in ipairs(DelHorEvents.eventList) do
        if event.index == index then return pos, event end
    end
    return nil, nil
end
