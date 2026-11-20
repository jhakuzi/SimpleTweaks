-- Reichweitenpunkt für Jäger am feindlichen Ziel.
local ST = SimpleTweaks
local IsEnabled = ST.IsEnabled
local activeNameplateUnits = ST.activeNameplateUnits

local nameplateIndicators = {}
local meleeRangeItems = { 8149, 136605, 63427 }
local currentTargetUnit

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

ST.SetNameplateIndicatorEnabled = SetNameplateIndicatorEnabled

function ST.ClearRangeIndicator(unit)
    local entry = nameplateIndicators[unit]
    if entry then
        SetIndicatorColor(entry, nil)
    end
    nameplateIndicators[unit] = nil
    if currentTargetUnit == unit then
        currentTargetUnit = nil
    end
end
