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
local editLabel = display:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
local selection = CreateFrame("Frame", nil, display, "BackdropTemplate")
local enabled = false
local editing = false
local dragging = false
local layoutKey = "default"
local editModeHooked = false
local refreshElapsed = 0
local watchElapsed = 0

local function PlainNumber(value)
    if type(value) ~= "number" then
        return false
    end
    if issecretvalue and issecretvalue(value) then
        return false
    end
    return value == value and value > -math.huge and value < math.huge
end

local function ClampUnit(value, fallback)
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

local function TextColor()
    local db = SimpleTweaksDB
    return ClampUnit(db and db.swingTimerColorR, 1), ClampUnit(db and db.swingTimerColorG, 0.86), ClampUnit(db and db.swingTimerColorB, 0.55)
end

local function DecimalPlaces()
    local decimals = SimpleTweaksDB and tonumber(SimpleTweaksDB.swingTimerDecimals)
    if decimals == 0 or decimals == 2 then
        return decimals
    end
    return 1
end

local function FormatRemaining(remain)
    return string.format("%." .. DecimalPlaces() .. "f", remain)
end

local CIRCLE_DEFAULT = 9

local function TimerStyle()
    if SimpleTweaksDB and SimpleTweaksDB.swingTimerStyle == "circle" then
        return "circle"
    end
    return "text"
end

local function PieFills()
    return SimpleTweaksDB and SimpleTweaksDB.swingTimerPie == "fill"
end

local function SparkOn()
    return SimpleTweaksDB and SimpleTweaksDB.swingTimerSpark and true or false
end

local function CircleSize()
    local size = tonumber(SimpleTweaksDB and SimpleTweaksDB.swingTimerCircleSize) or CIRCLE_DEFAULT
    if size < 8 then
        size = 8
    elseif size > 64 then
        size = 64
    end
    return math.floor(size + 0.5)
end

local function CircleColor()
    local db = SimpleTweaksDB
    return ClampUnit(db and db.swingTimerCircleR, 1), ClampUnit(db and db.swingTimerCircleG, 0.86), ClampUnit(db and db.swingTimerCircleB, 0.55)
end

local function BorderColor()
    local db = SimpleTweaksDB
    return ClampUnit(db and db.swingTimerBorderR, 0), ClampUnit(db and db.swingTimerBorderG, 0), ClampUnit(db and db.swingTimerBorderB, 0)
end

local circleBorder
local circleFill
local pieHolder
local pieStamp
local sampleStart
local editCallbacks = false

local function AddCircleMask(owner, texture)
    if not texture or type(texture.AddMaskTexture) ~= "function" or type(owner.CreateMaskTexture) ~= "function" then
        return
    end
    local ok, mask = pcall(owner.CreateMaskTexture, owner)
    if not ok or not mask then
        return
    end
    mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(texture)
    texture:AddMaskTexture(mask)
end

local function IgnoreMouse(frame)
    if not frame then
        return
    end
    frame:EnableMouse(false)
    if frame.SetMouseClickEnabled then
        frame:SetMouseClickEnabled(false)
    end
    if frame.SetMouseMotionEnabled then
        frame:SetMouseMotionEnabled(false)
    end
end

local WEDGE_UL = UPPER_LEFT_VERTEX or 1
local WEDGE_LL = LOWER_LEFT_VERTEX or 2
local WEDGE_UR = UPPER_RIGHT_VERTEX or 3
local WEDGE_LR = LOWER_RIGHT_VERTEX or 4
local wedgeTextures
local fullDisc
local sparkDot
local pieLines
local edgeLine
local PIE_SLICES = 48

local EXACT_ANGLE = {
    [0] = { 0.5, 0 },
    [45] = { 1, 0 },
    [90] = { 1, 0.5 },
    [135] = { 1, 1 },
    [180] = { 0.5, 1 },
    [225] = { 0, 1 },
    [270] = { 0, 0.5 },
    [315] = { 0, 0 },
}
local POINT_ORDER = { "LL", "UL", "UR", "LR", "LL", "UL", "UR", "LR", "LL", "UL", "UR", "LR" }
local DEFAULT_COORD = {
    ULx = 0, ULy = 0,
    LLx = 0, LLy = 1,
    URx = 1, URy = 0,
    LRx = 1, LRy = 1,
}
local VERTEX = { UL = WEDGE_UL, LL = WEDGE_LL, UR = WEDGE_UR, LR = WEDGE_LR }

local function TanDeg(angle)
    return math.tan(math.rad(angle))
end

local function AngleToCoord(angle)
    angle = angle % 360
    if angle % 45 == 0 then
        local pair = EXACT_ANGLE[angle]
        return pair[1], pair[2]
    end
    if angle < 45 then
        return 0.5 + TanDeg(angle) / 2, 0
    elseif angle < 135 then
        return 1, 0.5 + TanDeg(angle - 90) / 2
    elseif angle < 225 then
        return 0.5 - TanDeg(angle) / 2, 1
    elseif angle < 315 then
        return 0, 0.5 - TanDeg(angle - 90) / 2
    end
    return 0.5 + TanDeg(angle) / 2, 0
end

local function EnsureCircle()
    if circleBorder then
        return
    end
    pieHolder = CreateFrame("Frame", nil, display)
    pieHolder:EnableMouse(false)

    circleBorder = display:CreateTexture(nil, "BACKGROUND", nil, 0)
    circleBorder:SetTexture("Interface\\Buttons\\WHITE8X8")
    AddCircleMask(display, circleBorder)
    circleBorder:Hide()

    circleFill = display:CreateTexture(nil, "BACKGROUND", nil, 1)
    circleFill:SetTexture("Interface\\Buttons\\WHITE8X8")
    AddCircleMask(display, circleFill)
    circleFill:Hide()

    fullDisc = pieHolder:CreateTexture(nil, "ARTWORK", nil, 0)
    fullDisc:SetAllPoints()
    fullDisc:SetTexture("Interface\\Buttons\\WHITE8X8")
    AddCircleMask(pieHolder, fullDisc)
    fullDisc:Hide()

    wedgeTextures = {}
    for i = 1, 3 do
        local tex = pieHolder:CreateTexture(nil, "ARTWORK", nil, i)
        tex:SetAllPoints()
        tex:SetTexture("Interface\\Buttons\\WHITE8X8")
        if tex.SetSnapToPixelGrid then
            tex:SetSnapToPixelGrid(false)
        end
        if tex.SetTexelSnappingBias then
            tex:SetTexelSnappingBias(0)
        end
        AddCircleMask(pieHolder, tex)
        tex:Hide()
        wedgeTextures[i] = tex
    end

    sparkDot = pieHolder:CreateTexture(nil, "OVERLAY", nil, 7)
    sparkDot:SetTexture("Interface\\Buttons\\WHITE8X8")
    AddCircleMask(pieHolder, sparkDot)
    sparkDot:Hide()

    pieLines = {}
    if pieHolder.CreateLine then
        for i = 1, PIE_SLICES do
            local line = pieHolder:CreateLine(nil, "OVERLAY")
            line:Hide()
            pieLines[i] = line
        end
        edgeLine = pieHolder:CreateLine(nil, "OVERLAY", nil, 7)
        edgeLine:Hide()
    end
end

local function ApplyCircleGeometry()
    EnsureCircle()
    local size = CircleSize()
    local thickness = math.max(1, math.floor(size / 9 + 0.5))
    local inner = math.max(1, size - thickness * 2)
    local width = size
    local height = size
    if editing then
        width = math.max(size + 16, 130)
        height = size + 22
    end
    display:SetSize(width, height)
    pieHolder:ClearAllPoints()
    pieHolder:SetSize(inner, inner)
    if editing then
        pieHolder:SetPoint("TOP", display, "TOP", 0, -(size - inner) / 2)
    else
        pieHolder:SetPoint("CENTER", display, "CENTER", 0, 0)
    end
    pieHolder:SetFrameLevel(display:GetFrameLevel() + 2)
    circleBorder:ClearAllPoints()
    circleBorder:SetSize(size, size)
    circleBorder:SetPoint("CENTER", pieHolder, "CENTER", 0, 0)
    circleFill:ClearAllPoints()
    circleFill:SetSize(inner, inner)
    circleFill:SetPoint("CENTER", pieHolder, "CENTER", 0, 0)
    sparkDot:SetSize(math.max(2, math.floor(inner * 0.16 + 0.5)), math.max(2, math.floor(inner * 0.16 + 0.5)))
    if editing then
        editLabel:ClearAllPoints()
        editLabel:SetPoint("TOP", circleBorder, "BOTTOM", 0, -2)
        editLabel:Show()
    else
        editLabel:Hide()
    end
    if selection and selection.SetFrameLevel then
        selection:SetFrameLevel(display:GetFrameLevel() + 8)
    end
end

local function HideWedges()
    if wedgeTextures then
        for i = 1, 3 do
            wedgeTextures[i]:Hide()
        end
    end
    if fullDisc then
        fullDisc:Hide()
    end
    if sparkDot then
        sparkDot:Hide()
    end
    if pieLines then
        for i = 1, #pieLines do
            pieLines[i]:Hide()
        end
    end
    if edgeLine then
        edgeLine:Hide()
    end
end

local function HideCircle()
    if circleBorder then
        circleBorder:Hide()
    end
    if circleFill then
        circleFill:Hide()
    end
    HideWedges()
    if pieHolder then
        pieHolder:Hide()
    end
end

local function PaintWedge(tex, size, angle1, angle2)
    local index = math.floor((angle1 + 45) / 90)
    local middle = POINT_ORDER[index + 1]
    local startCorner = POINT_ORDER[index + 2]
    local endCorner1 = POINT_ORDER[index + 3]
    local endCorner2 = POINT_ORDER[index + 4]
    local coord = {}
    local function Move(corner, x, y)
        local rx = DEFAULT_COORD[corner .. "x"] - x
        local ry = DEFAULT_COORD[corner .. "y"] - y
        coord[corner .. "x"] = x
        coord[corner .. "y"] = y
        coord[corner .. "vx"] = -rx * size
        coord[corner .. "vy"] = ry * size
    end
    Move(middle, 0.5, 0.5)
    local sx, sy = AngleToCoord(angle1)
    Move(startCorner, sx, sy)
    local edge1 = math.floor((angle1 - 45) / 90)
    local edge2 = math.floor((angle2 - 45) / 90)
    if edge1 == edge2 then
        local ex, ey = AngleToCoord(angle2)
        Move(endCorner1, ex, ey)
    else
        Move(endCorner1, DEFAULT_COORD[endCorner1 .. "x"], DEFAULT_COORD[endCorner1 .. "y"])
    end
    local ex, ey = AngleToCoord(angle2)
    Move(endCorner2, ex, ey)
    tex:SetVertexOffset(VERTEX.UR, coord.URvx or 0, coord.URvy or 0)
    tex:SetVertexOffset(VERTEX.UL, coord.ULvx or 0, coord.ULvy or 0)
    tex:SetVertexOffset(VERTEX.LR, coord.LRvx or 0, coord.LRvy or 0)
    tex:SetVertexOffset(VERTEX.LL, coord.LLvx or 0, coord.LLvy or 0)
    tex:SetTexCoord(coord.ULx, coord.ULy, coord.LLx, coord.LLy, coord.URx, coord.URy, coord.LRx, coord.LRy)
end

local function PlaceSpark(shownAngle)
    if not SparkOn() then
        sparkDot:Hide()
        return
    end
    local radius = pieHolder:GetWidth() / 2
    local theta = math.rad(shownAngle)
    sparkDot:ClearAllPoints()
    sparkDot:SetPoint("CENTER", pieHolder, "CENTER", math.sin(theta) * radius, math.cos(theta) * radius)
    sparkDot:Show()
end

local function ShowSweep(angle1, angle2, r, g, b, alpha)
    local index1 = math.floor((angle1 + 45) / 90)
    local index2 = math.floor((angle2 + 45) / 90)
    local spans = {}
    if index1 + 1 >= index2 then
        spans[1] = { angle1, angle2 }
    elseif index1 + 3 >= index2 then
        local mid = (index1 + 1) * 90 + 45
        spans[1] = { angle1, mid }
        spans[2] = { mid, angle2 }
    else
        local mid = (index1 + 1) * 90 + 45
        spans[1] = { angle1, mid }
        spans[2] = { mid, mid + 180 }
        spans[3] = { mid + 180, angle2 }
    end
    local size = pieHolder:GetWidth()
    for i = 1, 3 do
        local tex = wedgeTextures[i]
        local span = spans[i]
        if span then
            tex:SetVertexColor(r, g, b, alpha)
            local ok = pcall(PaintWedge, tex, size, span[1], span[2])
            if ok then
                tex:Show()
            else
                tex:Hide()
            end
        else
            tex:Hide()
        end
    end
end

local function UpdatePie(progress)
    if not pieLines or not pieLines[1] then
        return false
    end
    HideWedges()
    local size = CircleSize()
    local band = math.max(1, math.floor(size / 9 + 0.5))
    local radius = math.max(1, (size - band * 2) / 2 - 0.25)
    local slice = math.max(1.25, (radius * 2 * math.pi / PIE_SLICES) + 0.75)
    local alpha = 0.5 + 0.5 * progress
    local r, g, b = CircleColor()
    local grow = PieFills()
    local shown = grow and progress or (1 - progress)
    if shown < 0 then
        shown = 0
    elseif shown > 1 then
        shown = 1
    end
    local count = math.floor(shown * PIE_SLICES + 0.001)
    local lead = (grow and shown or progress) * math.pi * 2
    local drawn = 0
    for i = 1, PIE_SLICES do
        local line = pieLines[i]
        local visible = grow and i <= count or (not grow and i > PIE_SLICES - count)
        if not visible then
            line:Hide()
        else
            local angle = ((i - 0.5) / PIE_SLICES) * math.pi * 2
            local ok = pcall(function()
                line:SetThickness(slice)
                line:SetColorTexture(r, g, b, alpha)
                line:SetStartPoint("CENTER", pieHolder, 0, 0)
                line:SetEndPoint("CENTER", pieHolder, math.sin(angle) * radius, math.cos(angle) * radius)
                line:Show()
            end)
            if ok then
                drawn = drawn + 1
            else
                line:Hide()
            end
        end
    end
    local edgeOk = false
    if edgeLine and progress > 0.001 and progress < 0.999 and shown > 0.002 then
        local thickness = SparkOn() and math.max(2, slice) or math.max(1, slice * 0.45)
        local er, eg, eb, ea = r, g, b, 1
        if SparkOn() then
            er, eg, eb, ea = 1, 0.96, 0.85, 1
        end
        edgeOk = pcall(function()
            edgeLine:SetThickness(thickness)
            edgeLine:SetColorTexture(er, eg, eb, ea)
            edgeLine:SetStartPoint("CENTER", pieHolder, 0, 0)
            edgeLine:SetEndPoint("CENTER", pieHolder, math.sin(lead) * radius, math.cos(lead) * radius)
            edgeLine:Show()
        end)
        if not edgeOk then
            edgeLine:Hide()
        end
    elseif edgeLine then
        edgeLine:Hide()
    end
    return drawn > 0 or edgeOk
end

local function ShowCircle(startTime, duration, progress)
    display:Show()
    EnsureCircle()
    ApplyCircleGeometry()
    if progress < 0 then
        progress = 0
    elseif progress > 1 then
        progress = 1
    end
    local r, g, b = CircleColor()
    local br, bg, bb = BorderColor()
    local alpha = 0.5 + 0.5 * progress
    local grow = PieFills()
    local shown = grow and progress or (1 - progress)
    circleBorder:SetColorTexture(br, bg, bb, 1)
    circleBorder:Show()
    circleFill:SetColorTexture(0.02, 0.02, 0.02, 0.82)
    circleFill:Show()
    pieHolder:Show()
    if UpdatePie(progress) then
        return
    end
    HideWedges()
    if shown >= 0.995 then
        fullDisc:SetVertexColor(r, g, b, alpha)
        fullDisc:Show()
        return
    end
    if shown <= 0.002 then
        return
    end
    local angle1, angle2, lead
    if grow then
        angle1, angle2, lead = 0, shown * 360, shown * 360
    else
        angle1, angle2, lead = (1 - shown) * 360, 360, (1 - shown) * 360
    end
    ShowSweep(angle1, angle2, r, g, b, alpha)
    PlaceSpark(lead)
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
    text:SetTextColor(TextColor())
    if TimerStyle() ~= "circle" then
        display:SetSize(math.max(72, size * 3.4), math.max(28, size + 12))
    end
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
local function NextSwing(now)
    local bestRemain, bestSpeed, bestExpiry
    for _, swing in pairs(swings) do
        if swing.active and swing.expiry then
            local ok, remain = pcall(function()
                return swing.expiry - now
            end)
            if not ok or not PlainNumber(remain) then
                swing.active = false
                swing.expiry = nil
            elseif remain < -OVERDUE_LIMIT then
                swing.active = false
                swing.expiry = nil
            else
                if remain < 0 then
                    remain = 0
                end
                if not bestRemain or remain < bestRemain then
                    bestRemain = remain
                    bestSpeed = swing.speed
                    bestExpiry = swing.expiry
                end
            end
        end
    end
    return bestRemain, bestSpeed, bestExpiry
end

local function RefreshText()
    if not enabled and not editing then
        display:Hide()
        HideCircle()
        return
    end
    text:Hide()
    local now = GetTime()
    local remain, speed, expiry = NextSwing(now)
    if remain and PlainNumber(speed) and speed > 0 and PlainNumber(expiry) then
        local progress = 1 - (remain / speed)
        ShowCircle(expiry - speed, speed, progress)
    elseif editing then
        local duration = 1.6
        if not sampleStart or now >= sampleStart + duration then
            sampleStart = now
            pieStamp = nil
        end
        ShowCircle(sampleStart, duration, (now - sampleStart) / duration)
    else
        HideCircle()
        display:Hide()
    end
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
    if editing then
        return
    end
    editing = true
    display.editing = true
    display:SetFrameStrata("TOOLTIP")
    display:SetFrameLevel(400)
    display:EnableMouse(true)
    selection:EnableMouse(true)
    selection:Show()
    editLabel:Show()
    pieStamp = nil
    sampleStart = nil
    if layoutKey == "default" and C_EditMode and C_EditMode.GetLayouts then
        local ok, info = pcall(C_EditMode.GetLayouts)
        if ok then
            pcall(NoteLayouts, info)
        end
    end
    RefreshText()
end

local function ExitEditMode()
    if not editing then
        return
    end
    if dragging then
        display:StopMovingOrSizing()
        dragging = false
    end
    editing = false
    display.editing = false
    display:SetFrameStrata("HIGH")
    display:SetFrameLevel(20)
    display:EnableMouse(false)
    selection:EnableMouse(false)
    selection:Hide()
    editLabel:Hide()
    SavePosition()
    SimpleTweaksSwing.ApplyPosition()
    RefreshText()
end

local function HookEditMode()
    if EditModeManagerFrame and EditModeManagerFrame.HookScript and not editModeHooked then
        editModeHooked = true
        EditModeManagerFrame:HookScript("OnShow", EnterEditMode)
        EditModeManagerFrame:HookScript("OnHide", ExitEditMode)
    end
    if not editCallbacks and EventRegistry and EventRegistry.RegisterCallback then
        editCallbacks = true
        pcall(EventRegistry.RegisterCallback, EventRegistry, "EditMode.Enter", EnterEditMode, driver)
        pcall(EventRegistry.RegisterCallback, EventRegistry, "EditMode.Exit", ExitEditMode, driver)
    end
    if EditModeManagerFrame and EditModeManagerFrame.IsShown and EditModeManagerFrame:IsShown() then
        EnterEditMode()
    elseif editing and EditModeManagerFrame and EditModeManagerFrame.IsShown and not EditModeManagerFrame:IsShown() then
        ExitEditMode()
    end
end

function SimpleTweaksSwing.SetColor(r, g, b)
    if SimpleTweaksDB then
        SimpleTweaksDB.swingTimerColorR = ClampUnit(r, 1)
        SimpleTweaksDB.swingTimerColorG = ClampUnit(g, 0.86)
        SimpleTweaksDB.swingTimerColorB = ClampUnit(b, 0.55)
    end
    text:SetTextColor(TextColor())
    RefreshText()
end

function SimpleTweaksSwing.SetDecimals(decimals)
    decimals = tonumber(decimals)
    if decimals ~= 0 and decimals ~= 2 then
        decimals = 1
    end
    if SimpleTweaksDB then
        SimpleTweaksDB.swingTimerDecimals = decimals
    end
    RefreshText()
end

function SimpleTweaksSwing.SetStyle(style)
    if SimpleTweaksDB then
        SimpleTweaksDB.swingTimerStyle = style == "circle" and "circle" or "text"
    end
    pieStamp = nil
    sampleStart = nil
    if TimerStyle() == "circle" then
        ApplyCircleGeometry()
    end
    RefreshText()
end

function SimpleTweaksSwing.SetPie(direction)
    if SimpleTweaksDB then
        SimpleTweaksDB.swingTimerPie = direction == "fill" and "fill" or "drain"
    end
    pieStamp = nil
    RefreshText()
end

function SimpleTweaksSwing.SetSpark(on)
    if SimpleTweaksDB then
        SimpleTweaksDB.swingTimerSpark = on and true or false
    end
    RefreshText()
end

function SimpleTweaksSwing.SetCircleSize(size)
    if SimpleTweaksDB then
        SimpleTweaksDB.swingTimerCircleSize = tonumber(size) or CIRCLE_DEFAULT
    end
    ApplyCircleGeometry()
    RefreshText()
end

function SimpleTweaksSwing.SetCircleColor(r, g, b)
    if SimpleTweaksDB then
        SimpleTweaksDB.swingTimerCircleR = ClampUnit(r, 1)
        SimpleTweaksDB.swingTimerCircleG = ClampUnit(g, 0.86)
        SimpleTweaksDB.swingTimerCircleB = ClampUnit(b, 0.55)
    end
    RefreshText()
end

function SimpleTweaksSwing.SetBorderColor(r, g, b)
    if SimpleTweaksDB then
        SimpleTweaksDB.swingTimerBorderR = ClampUnit(r, 0)
        SimpleTweaksDB.swingTimerBorderG = ClampUnit(g, 0)
        SimpleTweaksDB.swingTimerBorderB = ClampUnit(b, 0)
    end
    if circleBorder then
        circleBorder:SetColorTexture(BorderColor())
    end
    RefreshText()
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
        RefreshText()
    elseif event == "PLAYER_LEAVE_COMBAT" then
        ClearHand(HAND_MAIN)
        ClearHand(HAND_OFF)
        RefreshText()
    elseif event == "START_AUTOREPEAT_SPELL" then
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
    elseif event == "PLAYER_ENTERING_WORLD" or event == "ADDON_LOADED" then
        HookEditMode()
    end
end)

driver:SetScript("OnUpdate", function(_, elapsed)
    watchElapsed = watchElapsed + elapsed
    if watchElapsed >= 0.5 then
        watchElapsed = 0
        HookEditMode()
    end
    if not enabled and not editing then
        return
    end
    refreshElapsed = refreshElapsed + elapsed
    if refreshElapsed < 0.02 then
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

text:Hide()
editLabel:SetText("Schwungtimer")
editLabel:SetTextColor(1, 0.86, 0.55)
editLabel:Hide()

selection:SetAllPoints()
selection:EnableMouse(false)
selection:RegisterForDrag("LeftButton")
selection:SetScript("OnDragStart", function()
    if not editing or InCombatLockdown() then
        return
    end
    dragging = true
    display:StartMoving()
end)
selection:SetScript("OnDragStop", function()
    display:StopMovingOrSizing()
    dragging = false
    SavePosition()
end)
selection:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    tile = false,
    edgeSize = 1,
})
selection:SetBackdropColor(0.2, 0.55, 0.85, 0.18)
selection:SetBackdropBorderColor(0.35, 0.75, 1, 0.95)
selection:Hide()

pcall(driver.RegisterEvent, driver, "ADDON_LOADED")
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
