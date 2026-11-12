local addonName = ...
local DEFAULTS = {
    disableMapFade = true,
    hideMacroNames = true,
    hunterRangeIndicator = false,
}
local hookedButtons = setmetatable({}, { __mode = "k" })
local optionsWindow
local optionChecks = {}
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
    elseif setting == "hunterRangeIndicator" then
        SetNameplateIndicatorEnabled(enabled)
    end
    local messages = {
        disableMapFade = enabled and "Karten-Ausblenden deaktiviert." or "Karten-Ausblenden wiederhergestellt.",
        hideMacroNames = enabled and "Makronamen ausgeblendet." or "Makronamen wiederhergestellt.",
        hunterRangeIndicator = enabled and "Jäger-Reichweitenindikator aktiviert." or "Jäger-Reichweitenindikator deaktiviert.",
    }
    Print(messages[setting] or "Einstellung geändert.")
    if optionChecks[setting] then optionChecks[setting]:SetChecked(enabled) end
end

local function CreateOptionsWindow()
    if optionsWindow then return optionsWindow end

    local window = CreateFrame("Frame", "SimpleTweaksOptionsWindow", UIParent, "BackdropTemplate")
    optionsWindow = window
    window:SetSize(470, 280)
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
    return window
end

local function OpenOptions()
    CreateOptionsWindow():Show()
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
