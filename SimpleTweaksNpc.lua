-- Bei freundlichen NSCs Lebensbalken und Stufe ausblenden.
local ST = SimpleTweaks
local IsEnabled = ST.IsEnabled
local NamePlateFor = ST.NamePlateFor
local PlainBoolean = ST.PlainBoolean
local activeNameplateUnits = ST.activeNameplateUnits
local nameplateByUnit = ST.nameplateByUnit

local function IsFriendlyNpc(unit)
    if type(UnitIsPlayer) ~= "function" then
        return false
    end
    local isPlayer
    local ok = pcall(function()
        isPlayer = PlainBoolean(UnitIsPlayer(unit))
    end)
    if not ok or isPlayer ~= false then
        return false
    end
    if type(UnitIsEnemy) == "function" then
        local enemy
        ok = pcall(function()
            enemy = PlainBoolean(UnitIsEnemy("player", unit))
        end)
        if not ok or enemy ~= false then
            return false
        end
    end
    if type(UnitCanAttack) == "function" then
        local hostile
        ok = pcall(function()
            hostile = PlainBoolean(UnitCanAttack("player", unit))
        end)
        if not ok or hostile ~= false then
            return false
        end
    end
    if type(UnitIsFriend) == "function" then
        local friend
        ok = pcall(function()
            friend = PlainBoolean(UnitIsFriend("player", unit))
        end)
        return ok and friend == true
    end
    if type(UnitReaction) ~= "function" then
        return false
    end
    local reaction
    ok = pcall(function()
        reaction = UnitReaction("player", unit)
        if issecretvalue and issecretvalue(reaction) then
            reaction = nil
        end
    end)
    return ok and type(reaction) == "number" and reaction >= 5
end

local LEVEL_KEYS = { "LevelFrame", "PlayerLevelDiffFrame" }

local function SuppressWidget(plate, widget)
    if not widget or (widget.IsForbidden and widget:IsForbidden()) then
        return
    end
    local state = plate.stNpcState
    if not state then
        state = {}
        plate.stNpcState = state
    end
    local saved = state[widget]
    if not saved then
        saved = {}
        if widget.GetAlpha then
            local ok, alpha = pcall(widget.GetAlpha, widget)
            if ok and type(alpha) == "number" then
                saved.alpha = alpha
            end
        end
        if widget.IsShown then
            local ok, shown = pcall(widget.IsShown, widget)
            if ok then
                saved.shown = shown and true or false
            end
        end
        state[widget] = saved
    end
    if widget.SetAlpha then
        pcall(widget.SetAlpha, widget, 0)
    end
    if saved.shown ~= false and widget.Hide then
        pcall(widget.Hide, widget)
    end
end

local function SuppressLevelChildren(plate, root)
    if not root or not root.GetChildren or (root.IsForbidden and root:IsForbidden()) then
        return
    end
    local children = { root:GetChildren() }
    for i = 1, #children do
        local child = children[i]
        local frameName = child.GetName and child:GetName()
        if type(frameName) == "string" and frameName:find("Level") then
            SuppressWidget(plate, child)
        end
    end
end

local function HideFriendlyChrome(plate, unitFrame)
    if not unitFrame or (unitFrame.IsForbidden and unitFrame:IsForbidden()) then
        return
    end
    SuppressWidget(plate, unitFrame.HealthBarsContainer)
    SuppressWidget(plate, unitFrame.healthBar)
    SuppressWidget(plate, unitFrame.HealthBar)
    local container = unitFrame.HealthBarsContainer
    if container and not (container.IsForbidden and container:IsForbidden()) then
        SuppressWidget(plate, container.border)
        SuppressWidget(plate, container.Border)
        SuppressWidget(plate, container.background)
        SuppressWidget(plate, container.Background)
    end
    local bar = unitFrame.healthBar or unitFrame.HealthBar
    if bar and bar ~= unitFrame.HealthBarsContainer and not (bar.IsForbidden and bar:IsForbidden()) then
        SuppressWidget(plate, bar.border)
        SuppressWidget(plate, bar.Border)
        SuppressWidget(plate, bar.background)
        SuppressWidget(plate, bar.Background)
    end
    for i = 1, #LEVEL_KEYS do
        SuppressWidget(plate, unitFrame[LEVEL_KEYS[i]])
    end
    SuppressLevelChildren(plate, unitFrame)
    SuppressLevelChildren(plate, plate)
end

local function RestoreNpcPlate(plate)
    if not plate then
        return
    end
    plate.stNpcHidden = nil
    local state = plate.stNpcState
    plate.stNpcState = nil
    if not state then
        return
    end
    for widget, saved in pairs(state) do
        if saved and not (widget.IsForbidden and widget:IsForbidden()) then
            if saved.alpha ~= nil and widget.SetAlpha then
                pcall(widget.SetAlpha, widget, saved.alpha)
            end
            if saved.shown == true and widget.Show then
                pcall(widget.Show, widget)
            end
        end
    end
end

local function ApplyNpcNameOnly(unit)
    local plate = NamePlateFor(unit)
    if not plate then
        return
    end
    nameplateByUnit[unit] = plate
    if not IsEnabled("npcNameOnly") or not IsFriendlyNpc(unit) then
        if plate.stNpcHidden or plate.stNpcState then
            RestoreNpcPlate(plate)
        end
        return
    end
    local unitFrame = plate.UnitFrame
    if not unitFrame or (unitFrame.IsForbidden and unitFrame:IsForbidden()) then
        return
    end
    plate.stNpcHidden = true
    HideFriendlyChrome(plate, unitFrame)
end


local function RefreshNpcNameOnly()
    for unit in pairs(activeNameplateUnits) do
        ApplyNpcNameOnly(unit)
    end
end

ST.RestoreNpcPlate = RestoreNpcPlate
ST.ApplyNpcNameOnly = ApplyNpcNameOnly
ST.RefreshNpcNameOnly = RefreshNpcNameOnly
