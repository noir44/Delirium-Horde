--**************************************************************************************
--**  Delirium Horde - event setup window                                             **
--**  Based on "Horde Event" by BitBraven (Build 41), which in turn derives a         **
--**  considerable portion of its code from TIS base game code, by Robert Johnson     **
--**************************************************************************************

require "ISUI/ISPanelJoypad"

DelHor_SpawnHordeUI = ISCollapsableWindow:derive("DelHor_SpawnHordeUI")

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local UI_BORDER_SPACING = 10
local BUTTON_HGT = FONT_HGT_SMALL + 6
local ENTRY_WID = 90
local COMBO_WID = 240
local SLIDER_WID = 200
local VALUE_WID = 40

function DelHor_SpawnHordeUI:getPickedSquareText()
    return getText("IGUI_DelHor_PickedSquare") .. ": " ..
            tostring(self.selectX) .. ", " .. tostring(self.selectY) .. ", " .. tostring(self.selectZ)
end

function DelHor_SpawnHordeUI:addNumberField(labelText, defaultValue, x, y, labelWidth)
    local label = ISLabel:new(x, y, BUTTON_HGT, labelText .. ": ", 1, 1, 1, 1, UIFont.Small, true)
    self:addChild(label)

    local entry = ISTextEntryBox:new(defaultValue, x + labelWidth + UI_BORDER_SPACING, y, ENTRY_WID, BUTTON_HGT)
    entry:initialise()
    entry:instantiate()
    entry:setOnlyNumbers(true)
    self:addChild(entry)

    return label, entry
end

function DelHor_SpawnHordeUI:createChildren()
    ISCollapsableWindow.createChildren(self)

    local x = UI_BORDER_SPACING + 1
    local y = self:titleBarHeight() + UI_BORDER_SPACING
    local farX = x

    -- Everything is laid out off titleBarHeight() and the measured font height,
    -- because B42 sizes both from the player's UI scale.
    local labelColW = 0
    local labelTexts = {
        getText("IGUI_DelHor_ZombiesNumber"),
        getText("IGUI_DelHor_Radius"),
        getText("IGUI_DelHor_TriggerDistance"),
        getText("IGUI_DelHor_SpawnDelay"),
        getText("IGUI_DelHor_LoopCycles"),
        getText("IGUI_DelHor_LoopCooldown"),
        getText("IGUI_DelHor_ZombiesOutfit"),
        getText("IGUI_XP_Health"),
    }
    for i, text in ipairs(labelTexts) do
        labelColW = math.max(labelColW, getTextManager():MeasureStringX(UIFont.Small, text .. ": "))
    end

    -- Row: pick square button, then the current coordinates next to it. The
    -- button goes first so the label can grow without pushing anything around.
    local pickWid = UI_BORDER_SPACING * 2 +
            getTextManager():MeasureStringX(UIFont.Small, getText("IGUI_DelHor_PickNewSquare"))

    self.pickNewSq = ISButton:new(x, y, pickWid, BUTTON_HGT, getText("IGUI_DelHor_PickNewSquare"),
            self, DelHor_SpawnHordeUI.onSelectNewSquare)
    self.pickNewSq:initialise()
    self.pickNewSq:instantiate()
    self.pickNewSq.borderColor = {r=1, g=1, b=1, a=0.1}
    self:addChild(self.pickNewSq)

    self.pickedSquareLabel = ISLabel:new(self.pickNewSq:getRight() + UI_BORDER_SPACING, y, BUTTON_HGT,
            self:getPickedSquareText(), 1, 1, 1, 1, UIFont.Small, true)
    self:addChild(self.pickedSquareLabel)
    farX = math.max(farX, self.pickedSquareLabel:getRight())
    y = y + BUTTON_HGT + UI_BORDER_SPACING

    self.zombiesNbrLabel, self.zombiesNbr =
        self:addNumberField(getText("IGUI_DelHor_ZombiesNumber"), "1", x, y, labelColW)
    farX = math.max(farX, self.zombiesNbr:getRight())
    y = y + BUTTON_HGT + UI_BORDER_SPACING

    self.radiusLbl, self.radius =
        self:addNumberField(getText("IGUI_DelHor_Radius"), "1", x, y, labelColW)
    y = y + BUTTON_HGT + UI_BORDER_SPACING

    self.triggerDistanceLabel, self.triggerDistance =
        self:addNumberField(getText("IGUI_DelHor_TriggerDistance"), "20", x, y, labelColW)
    y = y + BUTTON_HGT + UI_BORDER_SPACING

    self.spawnDelayLabel, self.spawnDelay =
        self:addNumberField(getText("IGUI_DelHor_SpawnDelay"), "0", x, y, labelColW)
    y = y + BUTTON_HGT + UI_BORDER_SPACING

    self.loopForLabel, self.loopCycles =
        self:addNumberField(getText("IGUI_DelHor_LoopCycles"), "0", x, y, labelColW)
    y = y + BUTTON_HGT + UI_BORDER_SPACING

    self.loopDelayLabel, self.loopCooldown =
        self:addNumberField(getText("IGUI_DelHor_LoopCooldown"), "0", x, y, labelColW)
    y = y + BUTTON_HGT + UI_BORDER_SPACING

    self.outfitLbl = ISLabel:new(x, y, BUTTON_HGT, getText("IGUI_DelHor_ZombiesOutfit") .. ": ",
            1, 1, 1, 1, UIFont.Small, true)
    self:addChild(self.outfitLbl)

    self.outfit = ISComboBox:new(x + labelColW + UI_BORDER_SPACING, y, COMBO_WID, BUTTON_HGT)
    self.outfit:initialise()
    self:addChild(self.outfit)
    self.outfit:setEditable(true)

    self.maleOutfits = getAllOutfits(false)
    self.femaleOutfits = getAllOutfits(true)
    self.outfit:addOptionWithData(getText("IGUI_None"), nil)

    for i = 0, self.maleOutfits:size() - 1 do
        local text = ""
        if not self.femaleOutfits:contains(self.maleOutfits:get(i)) then
            text = " - " .. getText("IGUI_SpawnHorde_MaleOnly")
        end
        self.outfit:addOptionWithData(self.maleOutfits:get(i) .. text, self.maleOutfits:get(i))
    end

    for i = 0, self.femaleOutfits:size() - 1 do
        if not self.maleOutfits:contains(self.femaleOutfits:get(i)) then
            self.outfit:addOptionWithData(self.femaleOutfits:get(i) .. " - " .. getText("IGUI_SpawnHorde_FemaleOnly"),
                    self.femaleOutfits:get(i))
        end
    end

    farX = math.max(farX, self.outfit:getRight())
    y = y + BUTTON_HGT + UI_BORDER_SPACING

    self.healthSliderTitle = ISDebugUtils.addLabelNoReturnOffset(self, "Health", x, y,
            getText("IGUI_XP_Health") .. ": ", UIFont.Small, true)
    self.healthSliderLabel = ISDebugUtils.addLabelNoReturnOffset(self, "Health",
            x + labelColW + UI_BORDER_SPACING, y, "1.0", UIFont.Small, true)
    self.healthSlider = ISDebugUtils.addSliderNoReturnOffset(self, "health",
            x + labelColW + UI_BORDER_SPACING + VALUE_WID, y, SLIDER_WID, BUTTON_HGT,
            DelHor_SpawnHordeUI.onSliderChange)
    self.healthSlider.pretext = getText("IGUI_XP_Health") .. ": "
    self.healthSlider.valueLabel = self.healthSliderLabel
    self.healthSlider:setValues(0, 2, 0.1, 0.1, true)
    self.healthSlider.currentValue = 1.0

    farX = math.max(farX, self.healthSlider:getRight())
    y = y + BUTTON_HGT + UI_BORDER_SPACING

    self.boolOptions = ISTickBox:new(x, y, 200, BUTTON_HGT, "", self, DelHor_SpawnHordeUI.onBoolOptionsChange)
    self.boolOptions:initialise()
    -- Must addChild *before* addOption() or ISUIElement:getKeepOnScreen()
    -- will restrict the y-position to the screen height.
    self:addChild(self.boolOptions)
    self.boolOptions:addOption(getText("IGUI_SpawnHorde_KnockedDown"))
    self.boolOptions:addOption(getText("IGUI_SpawnHorde_Crawler"))
    self.boolOptions:addOption(getText("IGUI_SpawnHorde_FakeDead"))
    self.boolOptions:addOption(getText("IGUI_SpawnHorde_FallOnFront"))
    self.boolOptions:addOption(getText("IGUI_SpawnHorde_Invulnerable"))
    self.boolOptions:addOption(getText("IGUI_SpawnHorde_Sitting"))

    farX = math.max(farX, self.boolOptions:getRight())
    y = self.boolOptions:getBottom() + UI_BORDER_SPACING

    local buttonWid = UI_BORDER_SPACING * 2 + math.max(
            getTextManager():MeasureStringX(UIFont.Small, getText("IGUI_DelHor_Spawn")),
            getTextManager():MeasureStringX(UIFont.Small, getText("UI_Close")))

    local width = math.max(farX + UI_BORDER_SPACING + 1, buttonWid * 2 + UI_BORDER_SPACING * 3)
    self:setWidth(width)
    self:setHeight(y + BUTTON_HGT + UI_BORDER_SPACING + 1)

    self.add = ISButton:new(x, y, buttonWid, BUTTON_HGT, getText("IGUI_DelHor_Spawn"),
            self, DelHor_SpawnHordeUI.onSpawn)
    self.add.anchorTop = false
    self.add.anchorBottom = true
    self.add:initialise()
    self.add:instantiate()
    self.add.borderColor = {r=1, g=1, b=1, a=0.1}
    self:addChild(self.add)

    self.closeButton2 = ISButton:new(width - buttonWid - x, y, buttonWid, BUTTON_HGT, getText("UI_Close"),
            self, DelHor_SpawnHordeUI.close)
    self.closeButton2.anchorTop = false
    self.closeButton2.anchorBottom = true
    self.closeButton2:initialise()
    self.closeButton2:instantiate()
    self.closeButton2:enableCancelColor()
    self.closeButton2.borderColor = {r=1, g=1, b=1, a=0.1}
    self:addChild(self.closeButton2)

    if self.centerOnCreate then
        self:centerOnPlayerScreen()
    end
end

function DelHor_SpawnHordeUI:centerOnPlayerScreen()
    local playerNum = self.playerNum or 0
    self:setX(getPlayerScreenLeft(playerNum) + (getPlayerScreenWidth(playerNum) - self:getWidth()) / 2)
    self:setY(getPlayerScreenTop(playerNum) + (getPlayerScreenHeight(playerNum) - self:getHeight()) / 2)
end

function DelHor_SpawnHordeUI:onBoolOptionsChange(index, selected)
    if index == 1 then
        if not selected then
            self.boolOptions.selected[2] = false
            self.boolOptions.selected[3] = false
        end
    end
    if index == 2 then
        self.boolOptions.selected[1] = selected
        if selected then
            self.boolOptions.selected[4] = true
        end
    end
    if index == 3 then
        self.boolOptions.selected[1] = selected
    end
    if index == 4 then
        if not selected then
            self.boolOptions.selected[2] = false
        end
    end
end

function DelHor_SpawnHordeUI:onSliderChange(_newval, _slider)
    if _slider.valueLabel then
        _slider.valueLabel:setName(ISDebugUtils.printval(_newval, 3))
    end
end

function DelHor_SpawnHordeUI:getZombiesNumber()
    local nbr = tonumber(self.zombiesNbr:getInternalText()) or 1
    if nbr < 1 then nbr = 1 end
    if nbr > DelHorEvents.MAX_ZOMBIES then nbr = DelHorEvents.MAX_ZOMBIES end
    return math.floor(nbr)
end

-- The field is a size in squares (1 = a single square); the stored radius is
-- that size minus one, which is what the ZombRand() spawn box expects.
function DelHor_SpawnHordeUI:getRadius()
    local size = tonumber(self.radius:getInternalText()) or 1
    if size < 1 then size = 1 end
    if size > DelHorEvents.MAX_RADIUS then size = DelHorEvents.MAX_RADIUS end
    return math.floor(size) - 1
end

function DelHor_SpawnHordeUI:getTriggerDistance()
    local nbr = tonumber(self.triggerDistance:getInternalText()) or 20
    if nbr < 1 then nbr = 1 end
    if nbr > DelHorEvents.MAX_TRIGGER_DISTANCE then nbr = DelHorEvents.MAX_TRIGGER_DISTANCE end
    return math.floor(nbr)
end

function DelHor_SpawnHordeUI:getSpawnDelay()
    local nbr = tonumber(self.spawnDelay:getInternalText()) or 0
    if nbr < 0 then nbr = 0 end
    return nbr
end

function DelHor_SpawnHordeUI:getLoopCyles()
    local nbr = tonumber(self.loopCycles:getInternalText()) or 0
    if nbr < 0 then nbr = 0 end
    return math.floor(nbr)
end

function DelHor_SpawnHordeUI:getLoopCooldown()
    local nbr = tonumber(self.loopCooldown:getInternalText()) or 0
    if nbr < 0 then nbr = 0 end
    return math.floor(nbr)
end

function DelHor_SpawnHordeUI:getOutfit()
    local option = self.outfit.options[self.outfit.selected]
    if not option then return nil end
    return option.data
end

function DelHor_SpawnHordeUI:onSpawn()
    local outfit = self:getOutfit()

    -- force female or male chance if you've selected a outfit that's only for male or female
    local femaleChance = nil
    if outfit then
        if self.maleOutfits:contains(outfit) and not self.femaleOutfits:contains(outfit) then
            femaleChance = 0
        end
        if self.femaleOutfits:contains(outfit) and not self.maleOutfits:contains(outfit) then
            femaleChance = 100
        end
    end

    local args = {
        zNumber = self:getZombiesNumber(),
        radius = self:getRadius(),
        delay = self:getSpawnDelay(),
        loopCycles = self:getLoopCyles(),
        triggerDistance = self:getTriggerDistance(),
        currCooldown = 0,
        loopCooldown = self:getLoopCooldown(),
        zOutfit = outfit,
        femChance = femaleChance,
        isKnockedDown = self.boolOptions.selected[1] == true,
        isCrawler = self.boolOptions.selected[2] == true,
        isFakeDead = self.boolOptions.selected[3] == true,
        isFallOnFront = self.boolOptions.selected[4] == true,
        isInvulnerable = self.boolOptions.selected[5] == true,
        isSitting = self.boolOptions.selected[6] == true,
        zHealth = self.healthSlider:getCurrentValue(),
        centralSquare = { x = self.selectX, y = self.selectY, z = self.selectZ },
    }

    sendClientCommand(self.chr, DelHorEvents.MODULE, "AddEvent", args)
end

function DelHor_SpawnHordeUI:onSelectNewSquare()
    self.cursor = ISSelectCursor:new(self.chr, self, self.onSquareSelected)
    getCell():setDrag(self.cursor, self.chr:getPlayerNum())
end

function DelHor_SpawnHordeUI:onSquareSelected(square)
    self.cursor = nil
    self:removeMarkers()
    self.selectX = square:getX()
    self.selectY = square:getY()
    self.selectZ = square:getZ()
    self:addMarkers(square, self:getRadius() + 1, self:getRadius() + self:getTriggerDistance())
end

function DelHor_SpawnHordeUI:prerender()
    ISCollapsableWindow.prerender(self)

    if self.pickedSquareLabel then
        self.pickedSquareLabel:setNameWithoutMoving(self:getPickedSquareText())
    end

    local spawnSize = self:getRadius() + 1
    if self.spawnMarker and (self.spawnMarker:getSize() ~= spawnSize) then
        self.spawnMarker:setSize(spawnSize)
    end

    local triggerSize = self:getRadius() + self:getTriggerDistance()
    if self.triggerMarker and (self.triggerMarker:getSize() ~= triggerSize) then
        self.triggerMarker:setSize(triggerSize)
    end
end

function DelHor_SpawnHordeUI:addMarkers(square, spawnSize, triggerSize)
    self.triggerMarker = getWorldMarkers():addGridSquareMarker(square, 0.8, 0.8, 0.0, true, triggerSize)
    self.triggerMarker:setScaleCircleTexture(true)

    self.spawnMarker = getWorldMarkers():addGridSquareMarker(square, 1.0, 0.1, 0.0, true, spawnSize)
    self.spawnMarker:setScaleCircleTexture(true)

    local texName = nil -- use default
    self.spawnArrow = getWorldMarkers():addDirectionArrow(self.chr, self.selectX, self.selectY, self.selectZ,
            texName, 1.0, 1.0, 1.0, 1.0)
end

function DelHor_SpawnHordeUI:removeMarkers()
    if self.triggerMarker then
        self.triggerMarker:remove()
        self.triggerMarker = nil
    end
    if self.spawnMarker then
        self.spawnMarker:remove()
        self.spawnMarker = nil
    end
    if self.spawnArrow then
        self.spawnArrow:remove()
        self.spawnArrow = nil
    end
end

function DelHor_SpawnHordeUI:close()
    self:removeMarkers()
    self:setVisible(false)
    self:removeFromUIManager()
end

function DelHor_SpawnHordeUI:new(x, y, character, square)
    -- Provisional size; createChildren() measures the real one and re-centres.
    local width = 520
    local height = 560

    local o = ISCollapsableWindow.new(self, x, y, width, height)
    o.playerNum = character:getPlayerNum()
    o.centerOnCreate = (x == 0 and y == 0)
    o.width = width
    o.height = height
    o.chr = character
    o.title = getText("IGUI_DelHor_Title")
    o.moveWithMouse = true
    o.selectX = square:getX()
    o.selectY = square:getY()
    o.selectZ = square:getZ()
    o.anchorLeft = true
    o.anchorRight = true
    o.anchorTop = true
    o.anchorBottom = true
    o:addMarkers(square, 1, 20)
    return o
end
