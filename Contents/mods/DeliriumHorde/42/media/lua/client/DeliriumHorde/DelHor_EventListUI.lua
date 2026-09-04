--***********************************************************
--**  Delirium Horde - event list / manage window          **
--***********************************************************

require "ISUI/ISPanelJoypad"

DelHor_EventListUI = ISCollapsableWindow:derive("DelHor_EventListUI")

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local UI_BORDER_SPACING = 10
local BUTTON_HGT = FONT_HGT_SMALL + 6

-- Only one of these is worth having open; a second copy would just show the
-- same list and fight over the selection.
DelHor_EventListUI.instance = nil

function DelHor_EventListUI.open(playerObj)
    if DelHor_EventListUI.instance then
        DelHor_EventListUI.instance:close()
    end

    local ui = DelHor_EventListUI:new(0, 0, playerObj)
    ui:initialise()
    ui:addToUIManager()
    DelHor_EventListUI.instance = ui
    return ui
end

function DelHor_EventListUI:createChildren()
    ISCollapsableWindow.createChildren(self)

    local x = UI_BORDER_SPACING + 1
    local y = self:titleBarHeight() + UI_BORDER_SPACING
    local listBottom = self:getHeight() - UI_BORDER_SPACING * 2 - BUTTON_HGT

    self.list = ISScrollingListBox:new(x, y, self:getWidth() - x * 2, listBottom - y)
    self.list:initialise()
    self.list:instantiate()
    self.list.itemheight = BUTTON_HGT
    self.list.selected = 0
    self.list.joypadParent = self
    self.list.font = UIFont.Small
    self.list.drawBorder = true
    self.list:setOnMouseDoubleClick(self, DelHor_EventListUI.onEdit)
    self.list.anchorTop = true
    self.list.anchorBottom = true
    self.list.anchorLeft = true
    self.list.anchorRight = true
    self:addChild(self.list)

    local buttonWid = UI_BORDER_SPACING * 2 + math.max(
            getTextManager():MeasureStringX(UIFont.Small, getText("IGUI_DelHor_Edit")),
            getTextManager():MeasureStringX(UIFont.Small, getText("IGUI_DelHor_Delete")),
            getTextManager():MeasureStringX(UIFont.Small, getText("ContextMenu_DelHor_NewEvent")),
            getTextManager():MeasureStringX(UIFont.Small, getText("UI_Close")))

    y = self:getHeight() - UI_BORDER_SPACING - BUTTON_HGT

    self.newButton = self:addBottomButton(x, y, buttonWid,
            getText("ContextMenu_DelHor_NewEvent"), DelHor_EventListUI.onNew)
    self.editButton = self:addBottomButton(self.newButton:getRight() + UI_BORDER_SPACING, y, buttonWid,
            getText("IGUI_DelHor_Edit"), DelHor_EventListUI.onEdit)
    self.deleteButton = self:addBottomButton(self.editButton:getRight() + UI_BORDER_SPACING, y, buttonWid,
            getText("IGUI_DelHor_Delete"), DelHor_EventListUI.onDelete)
    self.deleteButton:enableCancelColor()

    self.closeButton2 = self:addBottomButton(self:getWidth() - buttonWid - x, y, buttonWid,
            getText("UI_Close"), DelHor_EventListUI.close)

    self:refresh()
end

function DelHor_EventListUI:addBottomButton(x, y, width, title, onClick)
    local button = ISButton:new(x, y, width, BUTTON_HGT, title, self, onClick)
    button.anchorTop = false
    button.anchorBottom = true
    button:initialise()
    button:instantiate()
    button.borderColor = {r=1, g=1, b=1, a=0.1}
    self:addChild(button)
    return button
end

-- Cheap stand-in for "has the list changed": the server replaces the whole
-- table on every update, so comparing indices catches adds, deletes and the
-- renames that come with an edit.
function DelHor_EventListUI:listSignature()
    if not DelHorEvents.eventList then return "" end

    local parts = ""
    for i, event in ipairs(DelHorEvents.eventList) do
        parts = parts .. tostring(event.index) .. ":" .. tostring(event.name) .. ";"
    end
    return parts
end

function DelHor_EventListUI:refresh()
    local previousIndex = self:getSelectedIndex()

    self.list:clear()
    self.signature = self:listSignature()

    if not DelHorEvents.eventList then return end

    for i, event in ipairs(DelHorEvents.eventList) do
        local square = event.centralSquare or {}
        local text = DelHorEvents.eventLabel(event) ..
                "   [" .. tostring(square.x) .. ", " .. tostring(square.y) .. ", " .. tostring(square.z) .. "]" ..
                "   " .. getText("IGUI_DelHor_ZombiesNumber") .. ": " .. tostring(event.zNumber) ..
                "   " .. getText("IGUI_DelHor_LoopCycles") .. ": " .. tostring(event.loopCycles)

        if event.spent then
            text = text .. "   (" .. getText("IGUI_DelHor_Spent") .. ")"
        end

        self.list:addItem(text, event)

        if previousIndex and event.index == previousIndex then
            self.list.selected = i
        end
    end
end

function DelHor_EventListUI:getSelectedEvent()
    if not self.list then return nil end
    if not self.list.selected then return nil end
    if self.list.selected < 1 then return nil end

    local item = self.list.items[self.list.selected]
    if not item then return nil end
    return item.item
end

function DelHor_EventListUI:getSelectedIndex()
    local event = self:getSelectedEvent()
    if not event then return nil end
    return event.index
end

function DelHor_EventListUI:onNew()
    local square = getCell():getGridSquare(math.floor(self.chr:getX()), math.floor(self.chr:getY()),
            math.floor(self.chr:getZ()))

    local ui = DelHor_SpawnHordeUI:new(0, 0, self.chr, square)
    ui:initialise()
    ui:addToUIManager()
end

function DelHor_EventListUI:onEdit()
    local event = self:getSelectedEvent()
    if not event then return end

    local square = nil
    if event.centralSquare then
        square = getCell():getGridSquare(event.centralSquare.x, event.centralSquare.y, event.centralSquare.z)
    end

    local ui = DelHor_SpawnHordeUI:new(0, 0, self.chr, square, event)
    ui:initialise()
    ui:addToUIManager()
end

function DelHor_EventListUI:onDelete()
    local event = self:getSelectedEvent()
    if not event then return end

    sendClientCommand(self.chr, DelHorEvents.MODULE, "DeleteEvent", { index = event.index })
end

function DelHor_EventListUI:prerender()
    ISCollapsableWindow.prerender(self)

    -- The server pushes the whole list back on every change, so rather than
    -- wiring this window into that path, notice the change here.
    if self.signature ~= self:listSignature() then
        self:refresh()
    end

    local hasSelection = self:getSelectedEvent() ~= nil
    self.editButton:setEnable(hasSelection)
    self.deleteButton:setEnable(hasSelection)
end

function DelHor_EventListUI:render()
    ISCollapsableWindow.render(self)

    if self.list and self.list:size() == 0 then
        self:drawText(getText("IGUI_DelHor_NoEvents"),
                self.list.x + UI_BORDER_SPACING, self.list.y + UI_BORDER_SPACING,
                0.7, 0.7, 0.7, 1, UIFont.Small)
    end
end

function DelHor_EventListUI:close()
    if DelHor_EventListUI.instance == self then
        DelHor_EventListUI.instance = nil
    end

    self:setVisible(false)
    self:removeFromUIManager()
end

function DelHor_EventListUI:new(x, y, character)
    local width = 620
    local height = 380

    local o = ISCollapsableWindow.new(self, x, y, width, height)
    o.playerNum = character:getPlayerNum()
    o.width = width
    o.height = height
    o.chr = character
    o.title = getText("IGUI_DelHor_ListTitle")
    o.moveWithMouse = true
    o.anchorLeft = true
    o.anchorRight = true
    o.anchorTop = true
    o.anchorBottom = true

    if x == 0 then
        o:setX(getPlayerScreenLeft(o.playerNum) + (getPlayerScreenWidth(o.playerNum) - width) / 2)
    end
    if y == 0 then
        o:setY(getPlayerScreenTop(o.playerNum) + (getPlayerScreenHeight(o.playerNum) - height) / 2)
    end

    return o
end
