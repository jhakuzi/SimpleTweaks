local FONT_MIN = 10
local FONT_MAX = 64
local DEFAULT_FONT_SIZE = 18
local OVERDUE_LIMIT = 1.5

SimpleTweaksSwing = SimpleTweaksSwing or {}

local HAND_MAIN = 0
local HAND_OFF = 1
local HAND_RANGED = 2

if Enum and Enum.PlayerSwingType then
    HAND_MAIN = Enum.PlayerSwingType.MainHand or HAND_MAIN
    HAND_OFF = Enum.PlayerSwingType.OffHand or HAND_OFF
    HAND_RANGED = Enum.PlayerSwingType.Ranged or HAND_RANGED
end

local swings = {}
swings[HAND_MAIN] = {}
swings[HAND_OFF] = {}
swings[HAND_RANGED] = {}
swings[0] = swings[0] or {}
swings[1] = swings[1] or {}
swings[2] = swings[2] or {}

local knownHands = {
    [HAND_MAIN] = true,
    [HAND_OFF] = true,
    [HAND_RANGED] = true,
    [0] = true,
    [1] = true,
    [2] = true,
}

local driver = CreateFrame("Frame")
local display = CreateFrame("Frame", "SimpleTweaksSwingTimer", UIParent)
local text = display:CreateFontString(nil, "OVERLAY")
local selection = CreateFrame("Frame", nil, display, "BackdropTemplate")
local enabled = false
local editing = false
local dragging = false
local layoutKey = "default"
local editModeHooked = false
local refreshElapsed = 0

local function PlainNumber(value)
    if type(value) ~= "number" then
        return false
    end
    if issecretvalue and issecretvalue(value) then
        return false
    end
    return value == value and value > -math.huge and value < math.huge
end

local function FontSize()
    local size = SimpleTweaksDB and tonumber(SimpleTweaksDB.swingTimerFontSize) or DEFAULT_FONT_SIZE
    if not size then
        size = DEFAULT_FONT_SIZE
    end
    if size < FONT_MIN then
        size = FONT_MIN
    elseif size > FONT_MAX then
        size = FONT_MAX
    end
    return math.floor(size + 0.5)
end

local function ApplyFont()
    local size = FontSize()
    local font = (GameFontNormal and GameFontNormal.GetFont and GameFontNormal:GetFont()) or "Fonts\\FRIZQT__.TTF"
    local ok = pcall(text.SetFont, text, font, size, "OUTLINE")
    if not ok then
        pcall(text.SetFont, text, "Fonts\\FRIZQT__.TTF", size, "OUTLINE")
    end
    text:SetTextColor(1, 0.86, 0.55)
    display:SetSize(math.max(72, size * 3.4), math.max(28, size + 12))
end

local function BaseLayoutNames()
    local names = {}
    if EDIT_MODE_MODERN_SYSTEM_MAP then
        names[#names + 1] = "Modern"
    end
    if EDIT_MODE_CLASSIC_SYSTEM_MAP then
        names[#names + 1] = "Classic"
    end
    if EDIT_MODE_GAMEPAD_SYSTEM_MAP then
        names[#names + 1] = "Gamepad"
    end
    if #names == 0 then
        names[1] = "Modern"
        names[2] = "Classic"
    end
    return names
end

local function NoteLayouts(layoutInfo)
    if type(layoutInfo) ~= "table" or not PlainNumber(layoutInfo.activeLayout) then
        return
    end
    local active = layoutInfo.activeLayout
    local bases = BaseLayoutNames()
    local key
    if active >= 1 and active <= #bases then
        key = bases[active]
    else
        local custom = layoutInfo.layouts and layoutInfo.layouts[active - #bases]
        if type(custom) == "table" and type(custom.layoutName) == "string" and custom.layoutName ~= "" then
            key = custom.layoutName
        else
            key = "layout:" .. tostring(active)
        end
    end
    if key == layoutKey then
        return
    end
    layoutKey = key
    if not dragging then
        SimpleTweaksSwing.ApplyPosition()
    end
end

local function ClearHand(hand)
    local swing = swings[hand]
    if not swing then
        return
    end
    swing.active = false
    swing.expiry = nil
end

local function StartHand(hand, duration)
    if not knownHands[hand] or not PlainNumber(duration) or duration <= 0 or duration > 10 then
        return
    end
    local swing = swings[hand]
    if not swing then
        return
    end
    swing.active = true
    swing.speed = duration
    swing.expiry = GetTime() + duration
end

local function StartHandIfIdle(hand, duration)
    local swing = swings[hand]
    if swing and swing.active and swing.expiry and swing.expiry > GetTime() then
        return
    end
    StartHand(hand, duration)
end

local function ReadAttackSpeeds()
    if type(UnitAttackSpeed) ~= "function" then
        return
    end
    local ok, main, off, ranged = pcall(UnitAttackSpeed, "player")
    if not ok then
        return
    end
    local function Readable(value)
        if PlainNumber(value) then
            return value
        end
    end
    return Readable(main), Readable(off), Readable(ranged)
end

local function SeedMelee()
    local main, off = ReadAttackSpeeds()
    if main then
        StartHandIfIdle(HAND_MAIN, main)
    end
    if off and off > 0 then
        StartHandIfIdle(HAND_OFF, off)
    end
end

local function SeedRanged()
    local _, _, ranged = ReadAttackSpeeds()
    if ranged and ranged > 0 then
        StartHandIfIdle(HAND_RANGED, ranged)
    end
end

local function RescaleHand(hand, newSpeed)
    if not PlainNumber(newSpeed) or newSpeed <= 0 or newSpeed > 10 then
        return
    end
    local swing = swings[hand]
    if not swing or not swing.active or not PlainNumber(swing.speed) or swing.speed <= 0 or not swing.expiry then
        return
    end
    local now = GetTime()
    if swing.expiry > now then
        swing.expiry = now + (swing.expiry - now) * (newSpeed / swing.speed)
    end
    swing.speed = newSpeed
end

local function RescaleFromSpeeds()
    local main, off, ranged = ReadAttackSpeeds()
    if main and main > 0 then
        RescaleHand(HAND_MAIN, main)
    end
    if off == 0 then
        ClearHand(HAND_OFF)
    elseif off and off > 0 then
        RescaleHand(HAND_OFF, off)
    end
    if ranged == 0 then
        ClearHand(HAND_RANGED)
    elseif ranged and ranged > 0 then
        RescaleHand(HAND_RANGED, ranged)
    end
end

-- Soonest live swing. An overdue active swing stays at 0 until the client
-- sends the hit or the attack stops, so a delayed shot does not vanish.
local function NextRemaining(now)
    local best
    for _, swing in pairs(swings) do
        if swing.active and swing.expiry then
            local remain = swing.expiry - now
            if remain < -OVERDUE_LIMIT then
                swing.active = false
                swing.expiry = nil
            else
                if remain < 0 then
                    remain = 0
                end
                if not best or remain < best then
                    best = remain
                end
            end
        end
    end
    return best
end

local function RefreshText()
    if not enabled and not editing then
        display:Hide()
        return
    end
    local remain = NextRemaining(GetTime())
    if remain then
        text:SetText(string.format("%.1f", remain))
    elseif editing then
        text:SetText("1.6")
    else
        display:Hide()
        return
    end
    display:Show()
end

function SimpleTweaksSwing.ApplyPosition()
    if dragging or not display then
        return
    end
    local layouts = SimpleTweaksDB and SimpleTweaksDB.swingTimerLayouts
    local pos = layouts and layouts[layoutKey]
    display:ClearAllPoints()
    if type(pos) == "table" and type(pos.point) == "string" then
        display:SetPoint(pos.point, UIParent, pos.relativePoint or pos.point, pos.x or 0, pos.y or 0)
    else
        display:SetPoint("CENTER", UIParent, "CENTER", 0, -160)
    end
end

local function SavePosition()
    if not SimpleTweaksDB then
        return
    end
    local point, _, relativePoint, x, y = display:GetPoint(1)
    if type(point) ~= "string" then
        return
    end
    SimpleTweaksDB.swingTimerLayouts = SimpleTweaksDB.swingTimerLayouts or {}
    SimpleTweaksDB.swingTimerLayouts[layoutKey] = {
        point = point,
        relativePoint = relativePoint or point,
        x = x or 0,
        y = y or 0,
    }
end

local function EnterEditMode()
    editing = true
    display.editing = true
    display:EnableMouse(true)
    selection:Show()
    if layoutKey == "default" and C_EditMode and C_EditMode.GetLayouts then
        local ok, info = pcall(C_EditMode.GetLayouts)
        if ok then
            NoteLayouts(info)
        end
    end
    RefreshText()
end

local function ExitEditMode()
    if dragging then
        display:StopMovingOrSizing()
        dragging = false
    end
    editing = false
    display.editing = false
    display:EnableMouse(false)
    selection:Hide()
    SavePosition()
    RefreshText()
end

local function HookEditMode()
    if editModeHooked or not EditModeManagerFrame or not EditModeManagerFrame.HookScript then
        return
    end
    editModeHooked = true
    EditModeManagerFrame:HookScript("OnShow", EnterEditMode)
    EditModeManagerFrame:HookScript("OnHide", ExitEditMode)
    if EditModeManagerFrame:IsShown() then
        EnterEditMode()
    end
    if EventRegistry and EventRegistry.RegisterFrameEventAndCallback then
        pcall(EventRegistry.RegisterFrameEventAndCallback, EventRegistry, "EDIT_MODE_LAYOUTS_UPDATED", function(_, layoutInfo)
            if type(layoutInfo) ~= "table" then
                return
            end
            NoteLayouts(layoutInfo)
        end, driver)
    end
end

function SimpleTweaksSwing.SetFontSize(size)
    if SimpleTweaksDB and PlainNumber(tonumber(size) or size) then
        SimpleTweaksDB.swingTimerFontSize = tonumber(size) or size
    end
    ApplyFont()
    RefreshText()
end

function SimpleTweaksSwing.SetEnabled(on)
    enabled = on and true or false
    if not enabled then
        for hand in pairs(swings) do
            ClearHand(hand)
        end
    end
    RefreshText()
end

local function HandleSwing(duration, swingType)
    if not knownHands[swingType] then
        return
    end
    StartHand(swingType, duration)
    RefreshText()
end

driver:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_SWING" then
        local first, second, third = ...
        if PlainNumber(first) then
            HandleSwing(first, second)
        elseif PlainNumber(second) then
            HandleSwing(second, third)
        end
    elseif event == "PLAYER_ENTER_COMBAT" then
        SeedMelee()
        RefreshText()
    elseif event == "PLAYER_LEAVE_COMBAT" then
        ClearHand(HAND_MAIN)
        ClearHand(HAND_OFF)
        RefreshText()
    elseif event == "START_AUTOREPEAT_SPELL" then
        SeedRanged()
        RefreshText()
    elseif event == "STOP_AUTOREPEAT_SPELL" then
        ClearHand(HAND_RANGED)
        RefreshText()
    elseif event == "UNIT_ATTACK_SPEED" then
        RescaleFromSpeeds()
        RefreshText()
    elseif event == "PLAYER_DEAD" then
        for hand in pairs(swings) do
            ClearHand(hand)
        end
        RefreshText()
    elseif event == "EDIT_MODE_LAYOUTS_UPDATED" then
        local layoutInfo = ...
        if type(layoutInfo) ~= "table" then
            layoutInfo = select(2, ...)
        end
        NoteLayouts(layoutInfo)
    elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
        if C_EditMode and C_EditMode.GetLayouts then
            local ok, info = pcall(C_EditMode.GetLayouts)
            if ok then
                layoutKey = "default"
                NoteLayouts(info)
            end
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        HookEditMode()
    end
end)

driver:SetScript("OnUpdate", function(_, elapsed)
    if not enabled and not editing then
        return
    end
    refreshElapsed = refreshElapsed + elapsed
    if refreshElapsed < 0.05 then
        return
    end
    refreshElapsed = 0
    RefreshText()
end)

display:SetClampedToScreen(true)
display:SetFrameStrata("HIGH")
display:SetMovable(true)
display:EnableMouse(false)
display:RegisterForDrag("LeftButton")
display:SetScript("OnDragStart", function(self)
    if not editing or InCombatLockdown() then
        return
    end
    dragging = true
    self:StartMoving()
end)
display:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    dragging = false
    SavePosition()
end)
display:Hide()

text:SetAllPoints()
text:SetJustifyH("CENTER")
text:SetJustifyV("MIDDLE")

selection:SetAllPoints()
selection:EnableMouse(false)
selection:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    tile = false,
    edgeSize = 1,
})
selection:SetBackdropColor(0.2, 0.55, 0.85, 0.18)
selection:SetBackdropBorderColor(0.35, 0.75, 1, 0.95)
selection:Hide()

pcall(driver.RegisterEvent, driver, "PLAYER_SWING")
pcall(driver.RegisterEvent, driver, "PLAYER_ENTER_COMBAT")
pcall(driver.RegisterEvent, driver, "PLAYER_LEAVE_COMBAT")
pcall(driver.RegisterEvent, driver, "START_AUTOREPEAT_SPELL")
pcall(driver.RegisterEvent, driver, "STOP_AUTOREPEAT_SPELL")
pcall(driver.RegisterEvent, driver, "PLAYER_DEAD")
pcall(driver.RegisterEvent, driver, "PLAYER_ENTERING_WORLD")
pcall(driver.RegisterEvent, driver, "EDIT_MODE_LAYOUTS_UPDATED")
pcall(driver.RegisterEvent, driver, "PLAYER_SPECIALIZATION_CHANGED")
if driver.RegisterUnitEvent then
    pcall(driver.RegisterUnitEvent, driver, "UNIT_ATTACK_SPEED", "player")
else
    pcall(driver.RegisterEvent, driver, "UNIT_ATTACK_SPEED")
end

function SimpleTweaksSwing.Init()
    HookEditMode()
    ApplyFont()
    SimpleTweaksSwing.ApplyPosition()
    SimpleTweaksSwing.SetEnabled(SimpleTweaksDB and SimpleTweaksDB.swingTimer)
end
