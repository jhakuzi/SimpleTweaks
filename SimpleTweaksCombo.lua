-- Combo-Punkte unter feindlichen Namensplaketten.
local ST = SimpleTweaks
local NamePlateFor = ST.NamePlateFor
local PlainBoolean = ST.PlainBoolean
local activeNameplateUnits = ST.activeNameplateUnits
local nameplateByUnit = ST.nameplateByUnit

local COMBO_BORDER = 9
local COMBO_DOT = 7
local COMBO_GAP = 2
local COMBO_MAX = 10

local function PlainNumber(value)
    if type(value) ~= "number" then
        return nil
    end
    if issecretvalue and issecretvalue(value) then
        return nil
    end
    return value
end

local function IsEnemyUnit(unit)
    if type(UnitCanAttack) ~= "function" then
        return false
    end
    local attack
    local ok = pcall(function()
        attack = PlainBoolean(UnitCanAttack("player", unit))
    end)
    return ok and attack == true
end

local function ComboPointsOn(unit)
    local points
    if type(GetComboPoints) == "function" then
        local ok, value = pcall(GetComboPoints, "player", unit)
        if ok then
            points = PlainNumber(value)
        end
        if points == nil then
            ok, value = pcall(GetComboPoints, unit)
            if ok then
                points = PlainNumber(value)
            end
        end
    end
    if points == nil and type(UnitIsUnit) == "function" and type(UnitPower) == "function" then
        local isTarget
        local ok = pcall(function()
            isTarget = PlainBoolean(UnitIsUnit(unit, "target"))
        end)
        if ok and isTarget then
            local powerType = Enum and Enum.PowerType and Enum.PowerType.ComboPoints or 4
            local amount
            ok = pcall(function()
                amount = UnitPower("player", powerType)
            end)
            if ok then
                points = PlainNumber(amount)
            end
        end
    end
    if not points or points < 1 then
        return 0
    end
    if points > COMBO_MAX then
        return COMBO_MAX
    end
    return points
end

local function HideCombo(plate)
    local holder = plate and plate.stCombo
    if not holder then
        return
    end
    holder.lastPoints = 0
    holder:Hide()
end

local function EnsureCombo(plate)
    local holder = plate.stCombo
    if holder then
        return holder
    end
    holder = CreateFrame("Frame", nil, plate)
    holder:SetSize((COMBO_BORDER + COMBO_GAP) * COMBO_MAX, COMBO_BORDER)
    holder.dots = {}
    holder.borders = {}
    for i = 1, COMBO_MAX do
        local border = holder:CreateTexture(nil, "OVERLAY", nil, 1)
        border:SetTexture("Interface\\Buttons\\WHITE8X8")
        border:SetColorTexture(0, 0, 0, 1)
        border:SetSize(COMBO_BORDER, COMBO_BORDER)
        border:Hide()
        local dot = holder:CreateTexture(nil, "OVERLAY", nil, 2)
        dot:SetTexture("Interface\\Buttons\\WHITE8X8")
        dot:SetColorTexture(0.82, 0.24, 0.08, 1)
        dot:SetSize(COMBO_DOT, COMBO_DOT)
        dot:Hide()
        if holder.CreateMaskTexture then
            local borderMask = holder:CreateMaskTexture()
            borderMask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            borderMask:SetAllPoints(border)
            border:AddMaskTexture(borderMask)
            local dotMask = holder:CreateMaskTexture()
            dotMask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            dotMask:SetAllPoints(dot)
            dot:AddMaskTexture(dotMask)
        end
        holder.borders[i] = border
        holder.dots[i] = dot
    end
    plate.stCombo = holder
    return holder
end

local function AnchorCombo(plate, holder)
    local unitFrame = plate.UnitFrame
    if unitFrame and unitFrame.IsForbidden and unitFrame:IsForbidden() then
        unitFrame = nil
    end
    local anchor = unitFrame
    if unitFrame then
        local container = unitFrame.HealthBarsContainer
        if container and not (container.IsForbidden and container:IsForbidden()) then
            anchor = container
        else
            local bar = unitFrame.healthBar or unitFrame.HealthBar
            if bar and not (bar.IsForbidden and bar:IsForbidden()) then
                anchor = bar
            end
        end
    end
    anchor = anchor or plate
    if holder.anchor == anchor then
        return
    end
    holder:ClearAllPoints()
    local placed = pcall(holder.SetPoint, holder, "TOP", anchor, "BOTTOM", 0, -3)
    if not placed and anchor ~= plate then
        pcall(holder.SetPoint, holder, "TOP", plate, "BOTTOM", 0, 10)
        anchor = plate
    end
    holder.anchor = anchor
    holder.lastPoints = nil
end

local function ShowComboCount(holder, points)
    if holder.lastPoints == points then
        holder:Show()
        return
    end
    local step = COMBO_BORDER + COMBO_GAP
    local total = points * COMBO_BORDER + (points - 1) * COMBO_GAP
    local origin = -total / 2 + COMBO_BORDER / 2
    for i = 1, COMBO_MAX do
        local border = holder.borders[i]
        local dot = holder.dots[i]
        if i <= points then
            local x = origin + (i - 1) * step
            border:ClearAllPoints()
            border:SetPoint("CENTER", holder, "CENTER", x, 0)
            dot:ClearAllPoints()
            dot:SetPoint("CENTER", border, "CENTER", 0, 0)
            border:Show()
            dot:Show()
        else
            border:Hide()
            dot:Hide()
        end
    end
    holder.lastPoints = points
    holder:Show()
end

local function UpdateComboPlate(unit)
    local plate = nameplateByUnit[unit] or NamePlateFor(unit)
    if not plate then
        return
    end
    if not (SimpleTweaksDB and SimpleTweaksDB.comboPoints) or not IsEnemyUnit(unit) then
        HideCombo(plate)
        return
    end
    local points = ComboPointsOn(unit)
    if points < 1 then
        HideCombo(plate)
        return
    end
    local holder = EnsureCombo(plate)
    AnchorCombo(plate, holder)
    ShowComboCount(holder, points)
end

local function RefreshComboPoints()
    for unit in pairs(activeNameplateUnits) do
        pcall(UpdateComboPlate, unit)
    end
end

ST.HideCombo = HideCombo
ST.UpdateComboPlate = UpdateComboPlate
ST.RefreshComboPoints = RefreshComboPoints
