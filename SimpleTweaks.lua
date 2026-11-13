local addonName = ...
local DEFAULTS = {
    disableMapFade = true,
    hideMacroNames = true,
    hunterRangeIndicator = false,
    hideStanceBar = false,
    swingTimer = false,
    swingTimerFontSize = 18,
    swingTimerDecimals = 1,
    swingTimerColorR = 1,
    swingTimerColorG = 0.86,
    swingTimerColorB = 0.55,
    swingTimerStyle = "text",
    swingTimerPie = "drain",
    swingTimerSpark = false,
    swingTimerCircleSize = 9,
    swingTimerCircleR = 1,
    swingTimerCircleG = 0.86,
    swingTimerCircleB = 0.55,
    swingTimerCircleA = 1,
    swingTimerBorderR = 0,
    swingTimerBorderG = 0,
    swingTimerBorderB = 0,
    swingTimerBorderA = 1,
    swingTimerLineA = 1,
    swingTimerLineThickness = 1,
    swingTimerBackR = 0.02,
    swingTimerBackG = 0.02,
    swingTimerBackB = 0.02,
    swingTimerBackA = 0.82,
}
local hookedButtons = setmetatable({}, { __mode = "k" })
local optionsWindow
local optionChecks = {}
local SWING_CIRCLE_SIZES = { 9, 12, 16, 20, 24, 32, 40, 48 }
local nameplateIndicators = {}
local activeNameplateUnits = {}
local rangeUpdateElapsed = 0
local meleeRangeItems = { 8149, 136605, 63427 }
local currentTargetUnit

local function Print(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cffd6a45eSimpleTweaks:|r " .. message)
end

local function IsEnabled(setting)
    return SimpleTweaksDB ~= nil and SimpleTweaksDB[setting] ~= false
end

local function UpdateMapFade(enable)
    if enable then
        if SimpleTweaksDB.mapFadeBeforeOverride == nil then
            SimpleTweaksDB.mapFadeBeforeOverride = GetCVarBool("mapFade")
        end
        SetCVar("mapFade", "0")
    elseif SimpleTweaksDB.mapFadeBeforeOverride ~= nil then
        SetCVar("mapFade", SimpleTweaksDB.mapFadeBeforeOverride and "1" or "0")
        SimpleTweaksDB.mapFadeBeforeOverride = nil
    end
end

local function UpdateMacroName(button)
    local name = button and button.Name
    if not name then
        return
    end

    local actionType
    if button.action then
        actionType = GetActionInfo(button.action)
    end

    if actionType == "macro" and IsEnabled("hideMacroNames") then
        name:Hide()
    else
        name:Show()
    end
end

local function HookMacroName(button)
    if button and button.Update and not hookedButtons[button] then
        hooksecurefunc(button, "Update", UpdateMacroName)
        hookedButtons[button] = true
    end
    UpdateMacroName(button)
end

local function RefreshMacroNames()
    local actionFrames = ActionBarActionEventsFrame and ActionBarActionEventsFrame.frames
    if actionFrames then
        for button in pairs(actionFrames) do
            HookMacroName(button)
        end
    end

    local buttonFrames = ActionBarButtonEventsFrame and ActionBarButtonEventsFrame.frames
    if buttonFrames then
        for _, button in pairs(buttonFrames) do
            HookMacroName(button)
        end
    end
end

local function HookFutureMacroButtons()
    local mixins = { ActionBarActionButtonMixin, ActionButtonMixin }
    for _, mixin in ipairs(mixins) do
        if type(mixin) == "table" and type(mixin.Update) == "function" and not mixin.simpleTweaksMacroHook then
            hooksecurefunc(mixin, "Update", UpdateMacroName)
            mixin.simpleTweaksMacroHook = true
        end
    end
end

local stanceHooked = {}
local stanceEditHooked = false

local function ShouldHideStance()
    if not IsEnabled("hideStanceBar") then
        return false
    end
    if EditModeManagerFrame and EditModeManagerFrame.IsShown and EditModeManagerFrame:IsShown() then
        return false
    end
    return true
end

local function HookStanceFrame(frame)
    if not frame or stanceHooked[frame] or not frame.HookScript then
        return
    end
    stanceHooked[frame] = true
    frame:HookScript("OnShow", function(self)
        if ShouldHideStance() then
            self:Hide()
        end
    end)
end

local function UpdateStanceBar()
    if EditModeManagerFrame and EditModeManagerFrame.HookScript and not stanceEditHooked then
        stanceEditHooked = true
        pcall(EditModeManagerFrame.HookScript, EditModeManagerFrame, "OnShow", UpdateStanceBar)
        pcall(EditModeManagerFrame.HookScript, EditModeManagerFrame, "OnHide", UpdateStanceBar)
    end
    local frames = { StanceBar, StanceBarFrame, ShapeshiftBarFrame }
    local hide = ShouldHideStance()
    for i = 1, #frames do
        local frame = frames[i]
        if frame then
            HookStanceFrame(frame)
            if hide then
                frame.stHiddenByTweaks = true
                frame:Hide()
            elseif frame.stHiddenByTweaks then
                frame.stHiddenByTweaks = nil
                frame:Show()
                if type(StanceBarFrame_Update) == "function" then
                    pcall(StanceBarFrame_Update)
                elseif frame.Update then
                    pcall(frame.Update, frame)
                end
            end
        end
    end
end

local function SetIndicatorColor(entry, color)
    local indicator = entry.indicator
    if color then
        if color == "orange" then
            indicator:SetColorTexture(1, 0.65, 0, 1)
        elseif color == "green" then
            indicator:SetColorTexture(0, 1, 0, 1)
        elseif color == "red" then
            indicator:SetColorTexture(1, 0, 0, 1)
        end
        entry.border:Show()
        indicator:Show()
    else
        entry.border:Hide()
        indicator:Hide()
    end
end

local function GetSpellRange(spellID, unit)
    if type(C_Spell) == "table" and type(C_Spell.IsSpellInRange) == "function" then
        local ok, inRange = pcall(C_Spell.IsSpellInRange, spellID, unit)
        if not ok then return nil end
        if inRange == true or inRange == 1 then return true end
        if inRange == false or inRange == 0 then return false end
        return nil
    end
    if type(IsSpellInRange) ~= "function" or type(GetSpellInfo) ~= "function" then return nil end
    local spellName = GetSpellInfo(spellID)
    if not spellName then return nil end
    local ok, inRange = pcall(IsSpellInRange, spellName, unit)
    if not ok then return nil end
    if inRange == 1 or inRange == true then return true end
    if inRange == 0 or inRange == false then return false end
    return nil
end

local function GetMeleeRange(unit)
    -- Raptor Strike has a 0–0/next-swing range entry in Forever, so its
    -- spell range check can report "in range" at any distance. A five-yard
    -- item check is the client-supported melee probe used by Forever addons.
    local isItemInRange = C_Item and C_Item.IsItemInRange or IsItemInRange
    if type(isItemInRange) ~= "function" then return nil end
    for _, itemID in ipairs(meleeRangeItems) do
        local ok, inRange = pcall(isItemInRange, itemID, unit)
        if ok then
            if inRange == true or inRange == 1 then return true end
            if inRange == false or inRange == 0 then return false end
        end
    end
    return nil
end

local function EnsureNameplateIndicator(unit)
    if type(C_NamePlate) ~= "table" or type(C_NamePlate.GetNamePlateForUnit) ~= "function" then
        return nil
    end
    local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
    if not ok or not plate or not plate.UnitFrame then return nil end
    local unitFrame = plate.UnitFrame
    local healthBarContainer = unitFrame.HealthBarsContainer
    local healthBar = healthBarContainer and healthBarContainer.healthBar
    if not healthBar or type(unitFrame.CreateTexture) ~= "function" then return nil end

    local entry = unitFrame.simpleTweaksRangeIndicator
    local needsAnchor = false
    if not entry then
        local border = unitFrame:CreateTexture(nil, "OVERLAY", nil, 1)
        border:SetTexture("Interface\\Buttons\\WHITE8X8")
        border:SetColorTexture(0, 0, 0, 1)
        border:SetSize(9, 9)
        local indicator = unitFrame:CreateTexture(nil, "OVERLAY", nil, 2)
        indicator:SetTexture("Interface\\Buttons\\WHITE8X8")
        indicator:SetSize(7, 7)
        local mask
        if type(unitFrame.CreateMaskTexture) == "function" then
            mask = unitFrame:CreateMaskTexture(nil, "OVERLAY")
            mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            mask:SetAllPoints(indicator)
            indicator:AddMaskTexture(mask)
            local borderMask = unitFrame:CreateMaskTexture(nil, "OVERLAY")
            borderMask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            borderMask:SetAllPoints(border)
            border:AddMaskTexture(borderMask)
        end
        entry = { indicator = indicator, border = border, mask = mask, healthBar = healthBar }
        unitFrame.simpleTweaksRangeIndicator = entry
        needsAnchor = true
    elseif entry.healthBar ~= healthBar then
        entry.indicator:ClearAllPoints()
        entry.border:ClearAllPoints()
        entry.healthBar = healthBar
        needsAnchor = true
    end
    if needsAnchor then
        entry.border:SetPoint("CENTER", healthBar, "LEFT", -12, 0)
        entry.indicator:SetPoint("CENTER", entry.border, "CENTER", 0, 0)
    end
    nameplateIndicators[unit] = entry
    return entry
end

local function UpdateNameplateIndicator(unit)
    if not currentTargetUnit or unit ~= currentTargetUnit or not UnitIsUnit(unit, "target") then
        local oldEntry = nameplateIndicators[unit]
        if oldEntry then SetIndicatorColor(oldEntry, nil) end
        return
    end
    if type(UnitClass) ~= "function" then return end
    local _, class = UnitClass("player")
    if class ~= "HUNTER" then return end
    local indicator = EnsureNameplateIndicator(unit)
    if not indicator then return end
    if not IsEnabled("hunterRangeIndicator") or type(UnitCanAttack) ~= "function" or not UnitCanAttack("player", unit) then
        SetIndicatorColor(indicator, nil)
        return
    end

    -- Auto Shot (spell 75) is the relevant Hunter ranged band in Forever
    -- (8–35 yd). Raptor Strike is unsuitable as a melee probe: its 0–0
    -- next-swing range can read as in range at any distance. Unknown results
    -- stay hidden instead of implying a wrong distance.
    local meleeRange = GetMeleeRange(unit)
    local rangedRange = GetSpellRange(75, unit)
    if meleeRange == true then
        SetIndicatorColor(indicator, "orange")
    elseif rangedRange == true then
        SetIndicatorColor(indicator, "green")
    elseif rangedRange == false and meleeRange == false then
        SetIndicatorColor(indicator, "red")
    else
        SetIndicatorColor(indicator, nil)
    end
end

local function SetNameplateIndicatorEnabled(enabled)
    if not enabled then
        for _, entry in pairs(nameplateIndicators) do
            SetIndicatorColor(entry, nil)
        end
        return
    end
    if type(UnitClass) ~= "function" then return end
    local _, class = UnitClass("player")
    if class ~= "HUNTER" then
        for _, entry in pairs(nameplateIndicators) do SetIndicatorColor(entry, nil) end
        return
    end

    -- Find the target token without querying range for other visible units.
    local targetUnit
    if UnitExists("target") and UnitCanAttack("player", "target") then
        for unit in pairs(activeNameplateUnits) do
            if UnitIsUnit(unit, "target") then
                targetUnit = unit
                break
            end
        end
    end

    if currentTargetUnit ~= targetUnit then
        if currentTargetUnit and nameplateIndicators[currentTargetUnit] then
            SetIndicatorColor(nameplateIndicators[currentTargetUnit], nil)
        end
        currentTargetUnit = targetUnit
    end
    if not targetUnit then
        for _, entry in pairs(nameplateIndicators) do SetIndicatorColor(entry, nil) end
        return
    end
    -- Only this token reaches spell/item range APIs.
    UpdateNameplateIndicator(targetUnit)
end

local function SetOption(setting, enabled)
    SimpleTweaksDB[setting] = enabled

    if setting == "disableMapFade" then
        UpdateMapFade(enabled)
    elseif setting == "hideMacroNames" then
        RefreshMacroNames()
    elseif setting == "hideStanceBar" then
        UpdateStanceBar()
    elseif setting == "hunterRangeIndicator" then
        SetNameplateIndicatorEnabled(enabled)
    elseif setting == "swingTimer" and SimpleTweaksSwing and SimpleTweaksSwing.SetEnabled then
        SimpleTweaksSwing.SetEnabled(enabled)
    end
    local messages = {
        disableMapFade = enabled and "Karten-Ausblenden deaktiviert." or "Karten-Ausblenden wiederhergestellt.",
        hideMacroNames = enabled and "Makronamen ausgeblendet." or "Makronamen wiederhergestellt.",
        hideStanceBar = enabled and "Haltungsanzeige ausgeblendet." or "Haltungsanzeige wiederhergestellt.",
        hunterRangeIndicator = enabled and "Jäger-Reichweitenindikator aktiviert." or "Jäger-Reichweitenindikator deaktiviert.",
        swingTimer = enabled and "Schwungtimer aktiviert." or "Schwungtimer deaktiviert.",
    }
    Print(messages[setting] or "Einstellung geändert.")
    if optionChecks[setting] then optionChecks[setting]:SetChecked(enabled) end
end

local function CreateOptionsWindow()
    if optionsWindow then return optionsWindow end

    local window = CreateFrame("Frame", "SimpleTweaksOptionsWindow", UIParent, "BackdropTemplate")
    optionsWindow = window
    window:Hide()
    window:SetSize(680, 424)
    window:SetPoint("CENTER")
    window:SetFrameStrata("DIALOG")
    window:SetClampedToScreen(true)
    window:SetMovable(true)
    window:EnableMouse(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", window.StartMoving)
    window:SetScript("OnDragStop", window.StopMovingOrSizing)
    window:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = false, edgeSize = 24, insets = { left = 8, right = 8, top = 8, bottom = 8 } })
    window:SetBackdropColor(0, 0, 0, 0.96)
    window:SetBackdropBorderColor(0.65, 0.38, 0.16, 1)

    local title = window:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -20)
    title:SetText("|cffffd27fSimpleTweaks|r")

    local close = CreateFrame("Button", nil, window, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -5, -5)
    close:SetScript("OnClick", function() window:Hide() end)

    local function AddOption(key, label, y)
        local check = CreateFrame("CheckButton", nil, window, "UICheckButtonTemplate")
        check:SetPoint("TOPLEFT", 28, y)
        check:SetChecked(IsEnabled(key))
        check.Text:SetText(label)
        check.Text:SetTextColor(0.9, 0.79, 0.61)
        check:SetScript("OnClick", function(self) SetOption(key, self:GetChecked()) end)
        optionChecks[key] = check
    end

    AddOption("disableMapFade", "Karte beim Bewegen nicht ausblenden", -68)
    AddOption("hideMacroNames", "Makronamen auf Aktionsleisten ausblenden", -112)
    AddOption("hunterRangeIndicator", "Jäger Reichweitenindikator", -156)
    AddOption("hideStanceBar", "Haltungsanzeige ausblenden", -200)
    AddOption("swingTimer", "Schwungtimer", -244)

    local function MakeFontStep(labelText)
        local button = CreateFrame("Button", nil, window)
        button:SetSize(22, 22)
        local label = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetPoint("CENTER", 0, 1)
        label:SetText(labelText)
        label:SetTextColor(0.9, 0.79, 0.61)
        button:SetScript("OnEnter", function() label:SetTextColor(1, 0.93, 0.75) end)
        button:SetScript("OnLeave", function() label:SetTextColor(0.9, 0.79, 0.61) end)
        button:SetScript("OnMouseDown", function() label:SetPoint("CENTER", 1, 0) end)
        button:SetScript("OnMouseUp", function() label:SetPoint("CENTER", 0, 1) end)
        return button
    end

    local function PaintChoice(button, active)
        button.label:SetTextColor(active and 1 or 0.55, active and 0.86 or 0.48, active and 0.55 or 0.38)
        button.bg:SetColorTexture(0.65, 0.38, 0.16, active and 0.55 or 0)
    end

    local function MakeChoice(labelText, width)
        local button = CreateFrame("Button", nil, window)
        button:SetSize(width, 22)
        local bg = button:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        button.bg = bg
        local label = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetPoint("CENTER", 0, 1)
        label:SetText(labelText)
        button.label = label
        return button
    end

    local function OpenColor(getColor, applyColor)
        local r, g, b, a = getColor()
        a = a or 1
        local function Apply(nr, ng, nb, na)
            if nr then
                applyColor(nr, ng, nb, na or a)
            end
        end
        local function ReadAlpha()
            if ColorPickerFrame.GetColorAlpha then
                local ok, picked = pcall(ColorPickerFrame.GetColorAlpha, ColorPickerFrame)
                if ok and type(picked) == "number" then
                    return picked
                end
            end
            if type(ColorPickerFrame.opacity) == "number" then
                return 1 - ColorPickerFrame.opacity
            end
            return a
        end
        local function ReadAndApply()
            local pickedR, pickedG, pickedB
            if ColorPickerFrame.GetColorRGB then
                local ok, pr, pg, pb = pcall(ColorPickerFrame.GetColorRGB, ColorPickerFrame)
                if ok then
                    pickedR, pickedG, pickedB = pr, pg, pb
                end
            end
            if not pickedR and ColorPickerFrame.GetColorRGB == nil then
                return
            end
            Apply(pickedR, pickedG, pickedB, ReadAlpha())
        end
        if ColorPickerFrame and ColorPickerFrame.SetupColorPickerAndShow then
            ColorPickerFrame:SetupColorPickerAndShow({
                r = r,
                g = g,
                b = b,
                opacity = a,
                a = a,
                hasOpacity = true,
                swatchFunc = ReadAndApply,
                opacityFunc = ReadAndApply,
                cancelFunc = function(previous)
                    if type(previous) == "table" then
                        Apply(previous.r or r, previous.g or g, previous.b or b, previous.a or a)
                    else
                        Apply(r, g, b, a)
                    end
                end,
            })
            return
        end
        if not ColorPickerFrame or not ColorPickerFrame.SetColorRGB then
            return
        end
        ColorPickerFrame.func = ReadAndApply
        ColorPickerFrame.opacityFunc = ReadAndApply
        ColorPickerFrame.hasOpacity = true
        ColorPickerFrame.opacity = 1 - a
        ColorPickerFrame.previousValues = { r = r, g = g, b = b, a = a }
        ColorPickerFrame.cancelFunc = function(previous)
            local previousR, previousG, previousB, previousA = r, g, b, a
            if type(previous) == "table" then
                previousR, previousG, previousB = previous.r or r, previous.g or g, previous.b or b
                previousA = previous.a or a
            end
            Apply(previousR, previousG, previousB, previousA)
        end
        ColorPickerFrame:SetColorRGB(r, g, b)
        ColorPickerFrame:Hide()
        ColorPickerFrame:Show()
    end

    local function MakeSwatch(tip, getColor, applyColor)
        local button = CreateFrame("Button", nil, window)
        button:SetSize(18, 18)
        local edge = button:CreateTexture(nil, "BACKGROUND")
        edge:SetAllPoints()
        edge:SetColorTexture(0.65, 0.38, 0.16, 1)
        local fill = button:CreateTexture(nil, "ARTWORK")
        fill:SetPoint("TOPLEFT", 2, -2)
        fill:SetPoint("BOTTOMRIGHT", -2, 2)
        local red, green, blue, alpha = getColor()
        fill:SetColorTexture(red, green, blue, alpha or 1)
        button:SetScript("OnClick", function()
            OpenColor(getColor, function(nr, ng, nb, na)
                fill:SetColorTexture(nr, ng, nb, na or 1)
                applyColor(nr, ng, nb, na)
            end)
        end)
        button:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(tip, 1, 0.85, 0.55)
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", function() GameTooltip:Hide() end)
        return button
    end

    local function ClampColor(value, fallback)
        value = tonumber(value)
        if not value or value ~= value then
            return fallback
        end
        if value < 0 then
            return 0
        end
        if value > 1 then
            return 1
        end
        return value
    end

    local function CurrentCircleSize()
        local size = tonumber(SimpleTweaksDB and SimpleTweaksDB.swingTimerCircleSize) or 9
        local best, bestDiff = SWING_CIRCLE_SIZES[1], math.huge
        for _, candidate in ipairs(SWING_CIRCLE_SIZES) do
            local diff = math.abs(candidate - size)
            if diff < bestDiff then
                best, bestDiff = candidate, diff
            end
        end
        return best
    end

    local function ApplyCircleSize(size)
        if SimpleTweaksSwing and SimpleTweaksSwing.SetCircleSize then
            SimpleTweaksSwing.SetCircleSize(size)
        elseif SimpleTweaksDB then
            SimpleTweaksDB.swingTimerCircleSize = size
        end
    end

    local groesseLabel = window:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    groesseLabel:SetPoint("TOPLEFT", 52, -284)
    groesseLabel:SetText("Größe")
    groesseLabel:SetTextColor(0.75, 0.66, 0.5)
    local circleSmaller = MakeFontStep("-")
    local circleSizeText = window:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    circleSizeText:SetTextColor(0.9, 0.79, 0.61)
    circleSizeText:SetWidth(28)
    circleSizeText:SetJustifyH("CENTER")
    circleSizeText:SetText(tostring(CurrentCircleSize()))
    local circleLarger = MakeFontStep("+")
    circleSmaller:SetPoint("LEFT", groesseLabel, "RIGHT", 10, 0)
    circleSizeText:SetPoint("LEFT", circleSmaller, "RIGHT", 2, 0)
    circleLarger:SetPoint("LEFT", circleSizeText, "RIGHT", 2, 0)

    local PaintRahmen

    local function StepCircle(direction)
        local size = CurrentCircleSize()
        local index = 1
        for i, candidate in ipairs(SWING_CIRCLE_SIZES) do
            if candidate == size then
                index = i
                break
            end
        end
        index = index + direction
        if index < 1 then
            index = 1
        elseif index > #SWING_CIRCLE_SIZES then
            index = #SWING_CIRCLE_SIZES
        end
        local nextSize = SWING_CIRCLE_SIZES[index]
        circleSizeText:SetText(tostring(nextSize))
        ApplyCircleSize(nextSize)
        if PaintRahmen then
            PaintRahmen()
        end
    end
    circleSmaller:SetScript("OnClick", function() StepCircle(-1) end)
    circleLarger:SetScript("OnClick", function() StepCircle(1) end)

    local function CircleFillColor()
        local db = SimpleTweaksDB
        return ClampColor(db and db.swingTimerCircleR, 1), ClampColor(db and db.swingTimerCircleG, 0.86), ClampColor(db and db.swingTimerCircleB, 0.55), ClampColor(db and db.swingTimerCircleA, 1)
    end

    local function CircleEdgeColor()
        local db = SimpleTweaksDB
        return ClampColor(db and db.swingTimerBorderR, 0), ClampColor(db and db.swingTimerBorderG, 0), ClampColor(db and db.swingTimerBorderB, 0), ClampColor(db and db.swingTimerBorderA, 1)
    end

    local function CircleBackColor()
        local db = SimpleTweaksDB
        return ClampColor(db and db.swingTimerBackR, 0.02), ClampColor(db and db.swingTimerBackG, 0.02), ClampColor(db and db.swingTimerBackB, 0.02), ClampColor(db and db.swingTimerBackA, 0.82)
    end

    local fillSwatch = MakeSwatch("Füllfarbe und Deckkraft", CircleFillColor, function(r, g, b, a)
        if SimpleTweaksSwing and SimpleTweaksSwing.SetCircleColor then
            SimpleTweaksSwing.SetCircleColor(r, g, b, a)
        elseif SimpleTweaksDB then
            SimpleTweaksDB.swingTimerCircleR = r
            SimpleTweaksDB.swingTimerCircleG = g
            SimpleTweaksDB.swingTimerCircleB = b
            SimpleTweaksDB.swingTimerCircleA = a
        end
    end)
    local edgeSwatch = MakeSwatch("Randfarbe und Deckkraft", CircleEdgeColor, function(r, g, b, a)
        if SimpleTweaksSwing and SimpleTweaksSwing.SetBorderColor then
            SimpleTweaksSwing.SetBorderColor(r, g, b, a)
        elseif SimpleTweaksDB then
            SimpleTweaksDB.swingTimerBorderR = r
            SimpleTweaksDB.swingTimerBorderG = g
            SimpleTweaksDB.swingTimerBorderB = b
            SimpleTweaksDB.swingTimerBorderA = a
        end
    end)
    local backSwatch = MakeSwatch("Hintergrund und Deckkraft", CircleBackColor, function(r, g, b, a)
        if SimpleTweaksSwing and SimpleTweaksSwing.SetBackColor then
            SimpleTweaksSwing.SetBackColor(r, g, b, a)
        elseif SimpleTweaksDB then
            SimpleTweaksDB.swingTimerBackR = r
            SimpleTweaksDB.swingTimerBackG = g
            SimpleTweaksDB.swingTimerBackB = b
            SimpleTweaksDB.swingTimerBackA = a
        end
    end)
    fillSwatch:SetPoint("LEFT", circleLarger, "RIGHT", 12, 0)
    edgeSwatch:SetPoint("LEFT", fillSwatch, "RIGHT", 6, 0)
    backSwatch:SetPoint("LEFT", edgeSwatch, "RIGHT", 6, 0)

    local rahmenLabel = window:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    rahmenLabel:SetPoint("LEFT", backSwatch, "RIGHT", 12, 0)
    rahmenLabel:SetText("Rahmen")
    rahmenLabel:SetTextColor(0.75, 0.66, 0.5)
    local rahmenLess = MakeFontStep("-")
    local rahmenText = window:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    rahmenText:SetTextColor(0.9, 0.79, 0.61)
    rahmenText:SetWidth(16)
    rahmenText:SetJustifyH("CENTER")
    local rahmenMore = MakeFontStep("+")
    rahmenLess:SetPoint("LEFT", rahmenLabel, "RIGHT", 6, 0)
    rahmenText:SetPoint("LEFT", rahmenLess, "RIGHT", 2, 0)
    rahmenMore:SetPoint("LEFT", rahmenText, "RIGHT", 2, 0)

    local function CurrentBorder()
        local value = tonumber(SimpleTweaksDB and SimpleTweaksDB.swingTimerBorderThickness)
        if not value then
            local size = tonumber(SimpleTweaksDB and SimpleTweaksDB.swingTimerCircleSize) or 9
            value = math.max(1, math.floor(size / 9 + 0.5))
        end
        if value < 1 then
            return 1
        end
        if value > 8 then
            return 8
        end
        return math.floor(value + 0.5)
    end

    function PaintRahmen()
        rahmenText:SetText(tostring(CurrentBorder()))
    end

    local function StepRahmen(direction)
        local value = CurrentBorder() + direction
        if value < 1 then
            value = 1
        elseif value > 8 then
            value = 8
        end
        if SimpleTweaksSwing and SimpleTweaksSwing.SetBorderThickness then
            SimpleTweaksSwing.SetBorderThickness(value)
        elseif SimpleTweaksDB then
            SimpleTweaksDB.swingTimerBorderThickness = value
        end
        PaintRahmen()
    end
    rahmenLess:SetScript("OnClick", function() StepRahmen(-1) end)
    rahmenMore:SetScript("OnClick", function() StepRahmen(1) end)
    PaintRahmen()

    local drainMode = MakeChoice("Abnehmend", 96)
    local fillMode = MakeChoice("Zunehmend", 96)
    drainMode:SetPoint("TOPLEFT", 52, -320)
    fillMode:SetPoint("LEFT", drainMode, "RIGHT", 4, 0)

    local function CurrentPie()
        if SimpleTweaksDB and SimpleTweaksDB.swingTimerPie == "fill" then
            return "fill"
        end
        return "drain"
    end

    local function PaintPie()
        local pie = CurrentPie()
        PaintChoice(drainMode, pie == "drain")
        PaintChoice(fillMode, pie == "fill")
    end

    local function SelectPie(direction)
        if SimpleTweaksSwing and SimpleTweaksSwing.SetPie then
            SimpleTweaksSwing.SetPie(direction)
        elseif SimpleTweaksDB then
            SimpleTweaksDB.swingTimerPie = direction
        end
        PaintPie()
    end
    drainMode:SetScript("OnClick", function() SelectPie("drain") end)
    fillMode:SetScript("OnClick", function() SelectPie("fill") end)
    PaintPie()

    local spark = CreateFrame("CheckButton", nil, window, "UICheckButtonTemplate")
    spark:SetPoint("LEFT", fillMode, "RIGHT", 10, 0)
    spark.Text:SetText("Funke")
    spark.Text:SetTextColor(0.9, 0.79, 0.61)
    spark:SetChecked(SimpleTweaksDB and SimpleTweaksDB.swingTimerSpark and true or false)
    spark:SetScript("OnClick", function(self)
        local on = self:GetChecked() and true or false
        if SimpleTweaksSwing and SimpleTweaksSwing.SetSpark then
            SimpleTweaksSwing.SetSpark(on)
        elseif SimpleTweaksDB then
            SimpleTweaksDB.swingTimerSpark = on
        end
    end)

    local lineLabel = window:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lineLabel:SetPoint("TOPLEFT", 52, -356)
    lineLabel:SetText("Linie")
    lineLabel:SetTextColor(0.75, 0.66, 0.5)
    local lineLess = MakeFontStep("-")
    local lineText = window:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    lineText:SetTextColor(0.9, 0.79, 0.61)
    lineText:SetWidth(44)
    lineText:SetJustifyH("CENTER")
    local lineMore = MakeFontStep("+")
    lineLess:SetPoint("LEFT", lineLabel, "RIGHT", 10, 0)
    lineText:SetPoint("LEFT", lineLess, "RIGHT", 2, 0)
    lineMore:SetPoint("LEFT", lineText, "RIGHT", 2, 0)

    local function CurrentLinePercent()
        local alpha = ClampColor(SimpleTweaksDB and SimpleTweaksDB.swingTimerLineA, 1)
        return math.floor(alpha * 100 + 0.5)
    end

    local function PaintLinePercent()
        lineText:SetText(CurrentLinePercent() .. "%")
    end

    local function StepLine(direction)
        local percent = CurrentLinePercent() + direction * 5
        if percent < 0 then
            percent = 0
        elseif percent > 100 then
            percent = 100
        end
        local alpha = percent / 100
        if SimpleTweaksSwing and SimpleTweaksSwing.SetLineAlpha then
            SimpleTweaksSwing.SetLineAlpha(alpha)
        elseif SimpleTweaksDB then
            SimpleTweaksDB.swingTimerLineA = alpha
        end
        PaintLinePercent()
    end
    lineLess:SetScript("OnClick", function() StepLine(-1) end)
    lineMore:SetScript("OnClick", function() StepLine(1) end)
    PaintLinePercent()

    local thickLabel = window:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    thickLabel:SetPoint("LEFT", lineMore, "RIGHT", 14, 0)
    thickLabel:SetText("Dicke")
    thickLabel:SetTextColor(0.75, 0.66, 0.5)
    local thickLess = MakeFontStep("-")
    local thickText = window:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    thickText:SetTextColor(0.9, 0.79, 0.61)
    thickText:SetWidth(16)
    thickText:SetJustifyH("CENTER")
    local thickMore = MakeFontStep("+")
    thickLess:SetPoint("LEFT", thickLabel, "RIGHT", 8, 0)
    thickText:SetPoint("LEFT", thickLess, "RIGHT", 2, 0)
    thickMore:SetPoint("LEFT", thickText, "RIGHT", 2, 0)

    local function CurrentThickness()
        local value = tonumber(SimpleTweaksDB and SimpleTweaksDB.swingTimerLineThickness) or 1
        if value < 1 then
            return 1
        end
        if value > 8 then
            return 8
        end
        return math.floor(value + 0.5)
    end

    local function PaintThickness()
        thickText:SetText(tostring(CurrentThickness()))
    end

    local function StepThickness(direction)
        local value = CurrentThickness() + direction
        if value < 1 then
            value = 1
        elseif value > 8 then
            value = 8
        end
        if SimpleTweaksSwing and SimpleTweaksSwing.SetLineThickness then
            SimpleTweaksSwing.SetLineThickness(value)
        elseif SimpleTweaksDB then
            SimpleTweaksDB.swingTimerLineThickness = value
        end
        PaintThickness()
    end
    thickLess:SetScript("OnClick", function() StepThickness(-1) end)
    thickMore:SetScript("OnClick", function() StepThickness(1) end)
    PaintThickness()

    local previewBox = CreateFrame("Frame", nil, window, "BackdropTemplate")
    previewBox:SetSize(96, 96)
    previewBox:SetPoint("TOPRIGHT", -36, -292)
    previewBox:EnableMouse(false)
    previewBox:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    previewBox:SetBackdropColor(0.16, 0.15, 0.13, 1)
    previewBox:SetBackdropBorderColor(0.45, 0.32, 0.16, 0.65)
    local previewAnchor = CreateFrame("Frame", nil, previewBox)
    previewAnchor:SetAllPoints()
    previewAnchor:EnableMouse(false)
    local previewLabel = window:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    previewLabel:SetPoint("BOTTOM", previewBox, "TOP", 0, 6)
    previewLabel:SetText("Vorschau")
    previewLabel:SetTextColor(0.9, 0.79, 0.61)

    local function SyncSwingPreview()
        if SimpleTweaksSwing and SimpleTweaksSwing.SetPreview then
            SimpleTweaksSwing.SetPreview(previewAnchor, window:IsShown())
        end
    end
    window.SyncSwingPreview = SyncSwingPreview
    window:SetScript("OnShow", SyncSwingPreview)
    window:SetScript("OnHide", function()
        if SimpleTweaksSwing and SimpleTweaksSwing.SetPreview then
            SimpleTweaksSwing.SetPreview(nil, false)
        end
    end)

    return window
end

local function OpenOptions()
    local window = CreateOptionsWindow()
    window:Show()
    if window.SyncSwingPreview then
        window.SyncSwingPreview()
    end
end

local function HandleSlashCommand(message)
    local feature, value = message:match("^(%S+)%s*(%S*)$")
    feature = feature and feature:lower()
    value = value and value:lower()

    if feature == "map" or feature == "mapfade" then
        if value == "on" or value == "off" then
            SetOption("disableMapFade", value == "on")
        else
            Print("Karte nicht ausblenden: " .. (IsEnabled("disableMapFade") and "an" or "aus") .. ". /tweaks karte an|aus")
        end
    elseif feature == "macros" or feature == "macro" then
        if value == "on" or value == "off" then
            SetOption("hideMacroNames", value == "on")
        else
            Print("Makronamen ausblenden: " .. (IsEnabled("hideMacroNames") and "an" or "aus") .. ". /tweaks makros an|aus")
        end
    elseif feature == "swing" or feature == "timer" or feature == "schwung" then
        if value == "on" or value == "an" then
            SetOption("swingTimer", true)
        elseif value == "off" or value == "aus" then
            SetOption("swingTimer", false)
        else
            Print("Schwungtimer: " .. (IsEnabled("swingTimer") and "an" or "aus") .. ". /tweaks schwung an|aus")
        end
    elseif feature == "haltung" or feature == "stance" then
        if value == "on" or value == "an" then
            SetOption("hideStanceBar", true)
        elseif value == "off" or value == "aus" then
            SetOption("hideStanceBar", false)
        else
            Print("Haltungsanzeige ausblenden: " .. (IsEnabled("hideStanceBar") and "an" or "aus") .. ". /tweaks haltung an|aus")
        end
    elseif feature == "karte" or feature == "makros" or feature == "fenster" or feature == "optionen" then
        if feature == "karte" then
            if value == "an" or value == "aus" then SetOption("disableMapFade", value == "an") else Print("Verwendung: /tweaks karte an|aus") end
        elseif feature == "makros" then
            if value == "an" or value == "aus" then SetOption("hideMacroNames", value == "an") else Print("Verwendung: /tweaks makros an|aus") end
        else OpenOptions() end
    else
        OpenOptions()
    end
end

SLASH_SIMPLETWEAKS1 = "/tweaks"
SlashCmdList.SIMPLETWEAKS = HandleSlashCommand

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
pcall(frame.RegisterEvent, frame, "NAME_PLATE_UNIT_ADDED")
pcall(frame.RegisterEvent, frame, "NAME_PLATE_UNIT_REMOVED")
pcall(frame.RegisterEvent, frame, "PLAYER_TARGET_CHANGED")
pcall(frame.RegisterEvent, frame, "PLAYER_ENTERING_WORLD")
pcall(frame.RegisterEvent, frame, "ACTIONBAR_SLOT_CHANGED")
pcall(frame.RegisterEvent, frame, "UPDATE_BONUS_ACTIONBAR")
pcall(frame.RegisterEvent, frame, "ACTIONBAR_PAGE_CHANGED")
pcall(frame.RegisterEvent, frame, "UPDATE_SHAPESHIFT_FORM")
pcall(frame.RegisterEvent, frame, "UPDATE_SHAPESHIFT_FORMS")
frame:SetScript("OnEvent", function(_, event, loadedAddon)
    if event == "NAME_PLATE_UNIT_ADDED" then
        activeNameplateUnits[loadedAddon] = true
        if IsEnabled("hunterRangeIndicator") then SetNameplateIndicatorEnabled(true) end
        return
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        activeNameplateUnits[loadedAddon] = nil
        local entry = nameplateIndicators[loadedAddon]
        if entry then SetIndicatorColor(entry, nil) end
        nameplateIndicators[loadedAddon] = nil
        if currentTargetUnit == loadedAddon then currentTargetUnit = nil end
        if IsEnabled("hunterRangeIndicator") then SetNameplateIndicatorEnabled(true) end
        return
    elseif event == "PLAYER_TARGET_CHANGED" then
        if IsEnabled("hunterRangeIndicator") then SetNameplateIndicatorEnabled(true) end
        return
    elseif event == "PLAYER_ENTERING_WORLD" or event == "ACTIONBAR_SLOT_CHANGED" or event == "UPDATE_BONUS_ACTIONBAR" or event == "ACTIONBAR_PAGE_CHANGED" or event == "UPDATE_SHAPESHIFT_FORM" or event == "UPDATE_SHAPESHIFT_FORMS" then
        HookFutureMacroButtons()
        RefreshMacroNames()
        UpdateStanceBar()
        return
    end
    if event ~= "ADDON_LOADED" or loadedAddon ~= addonName then
        return
    end

    SimpleTweaksDB = SimpleTweaksDB or {}
    for key, value in pairs(DEFAULTS) do
        if SimpleTweaksDB[key] == nil then
            SimpleTweaksDB[key] = value
        end
    end

    if IsEnabled("disableMapFade") then
        UpdateMapFade(true)
    end

    if IsEnabled("hunterRangeIndicator") then
        SetNameplateIndicatorEnabled(true)
    end

    RefreshMacroNames()
    HookFutureMacroButtons()
    UpdateStanceBar()
    if SimpleTweaksSwing and SimpleTweaksSwing.Init then
        SimpleTweaksSwing.Init()
    end
    if AddonCompartmentFrame and AddonCompartmentFrame.RegisterAddon then
        AddonCompartmentFrame:RegisterAddon({ text = "SimpleTweaks", icon = "Interface\\Icons\\INV_Misc_Gear_01", notCheckable = true, func = OpenOptions })
    end
    Print("Geladen. /tweaks öffnet die Einstellungen.")
    frame:UnregisterEvent("ADDON_LOADED")
end)
frame:SetScript("OnUpdate", function(_, elapsed)
    if not IsEnabled("hunterRangeIndicator") then return end
    rangeUpdateElapsed = rangeUpdateElapsed + elapsed
    if rangeUpdateElapsed < 0.2 then return end
    rangeUpdateElapsed = 0
    SetNameplateIndicatorEnabled(true)
end)
