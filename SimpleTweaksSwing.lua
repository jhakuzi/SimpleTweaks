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
local GetTime = GetTime
local pairs = pairs
local floor = math.floor
local max = math.max
local sin = math.sin
local cos = math.cos
local pi = math.pi
local format = string.format
local ticking = false
local OnSwingUpdate

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
    return format("%." .. DecimalPlaces() .. "f", remain)
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

local function BorderBand()
    local size = CircleSize()
    local cap = max(1, floor((size - 1) / 2))
    local value = tonumber(SimpleTweaksDB and SimpleTweaksDB.swingTimerBorderThickness)
    local band = value or max(1, floor(size / 9 + 0.5))
    band = floor(band + 0.5)
    if band < 1 then
        band = 1
    elseif band > cap then
        band = cap
    end
    if band > 8 then
        band = 8
    end
    return band
end

local function CircleColor()
    local db = SimpleTweaksDB
    return ClampUnit(db and db.swingTimerCircleR, 1), ClampUnit(db and db.swingTimerCircleG, 0.86), ClampUnit(db and db.swingTimerCircleB, 0.55)
end

local function CircleAlpha()
    local db = SimpleTweaksDB
    return ClampUnit(db and db.swingTimerCircleA, 1)
end

local function BorderColor()
    local db = SimpleTweaksDB
    return ClampUnit(db and db.swingTimerBorderR, 0), ClampUnit(db and db.swingTimerBorderG, 0), ClampUnit(db and db.swingTimerBorderB, 0), ClampUnit(db and db.swingTimerBorderA, 1)
end

local function LineAlpha()
    local db = SimpleTweaksDB
    return ClampUnit(db and db.swingTimerLineA, 1)
end

local function LineThickness()
    local value = tonumber(SimpleTweaksDB and SimpleTweaksDB.swingTimerLineThickness) or 1
    if value < 1 then
        return 1
    end
    if value > 8 then
        return 8
    end
    return floor(value + 0.5)
end

local function BackColor()
    local db = SimpleTweaksDB
    return ClampUnit(db and db.swingTimerBackR, 0.02), ClampUnit(db and db.swingTimerBackG, 0.02), ClampUnit(db and db.swingTimerBackB, 0.02), ClampUnit(db and db.swingTimerBackA, 0.82)
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
    mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMP", "CLAMP")
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
local sparkHalo
local pieLines
local edgeLine
local ringHolder
local ringLines
local RING_COUNT = 36
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

local function PrepareDisc(owner, layer, sublayer)
    local texture = owner:CreateTexture(nil, layer, nil, sublayer)
    texture:SetTexture("Interface\\Buttons\\WHITE8X8")
    texture:SetBlendMode("BLEND")
    if texture.SetSnapToPixelGrid then
        texture:SetSnapToPixelGrid(false)
    end
    if texture.SetTexelSnappingBias then
        texture:SetTexelSnappingBias(0)
    end
    AddCircleMask(owner, texture)
    texture:Hide()
    return texture
end

local function EnsureCircle()
    if circleFill then
        return
    end
    pieHolder = CreateFrame("Frame", nil, display)
    pieHolder:EnableMouse(false)
    ringHolder = CreateFrame("Frame", nil, display)
    ringHolder:EnableMouse(false)

    circleFill = PrepareDisc(display, "BACKGROUND", 1)
    fullDisc = PrepareDisc(pieHolder, "ARTWORK", 0)

    wedgeTextures = {}
    for i = 1, 3 do
        local tex = PrepareDisc(pieHolder, "ARTWORK", i)
        tex:SetAllPoints()
        wedgeTextures[i] = tex
    end

    sparkHalo = PrepareDisc(pieHolder, "OVERLAY", 6)
    sparkDot = PrepareDisc(pieHolder, "OVERLAY", 7)
    sparkHalo:SetVertexColor(1, 0.97, 0.82, 0.38)
    sparkDot:SetVertexColor(1, 1, 0.92, 1)

    ringLines = {}
    if ringHolder.CreateLine then
        for i = 1, RING_COUNT do
            local line = ringHolder:CreateLine(nil, "ARTWORK")
            line:Hide()
            ringLines[i] = line
        end
        edgeLine = pieHolder:CreateLine(nil, "OVERLAY", nil, 7)
        edgeLine:Hide()
    end
end

local geomSize
local geomEditing
local geomBand
local RebuildSlices

local function ApplyCircleGeometry()
    EnsureCircle()
    local size = CircleSize()
    local thickness = BorderBand()
    if size == geomSize and editing == geomEditing and thickness == geomBand then
        return
    end
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
    ringHolder:ClearAllPoints()
    ringHolder:SetSize(size, size)
    ringHolder:SetPoint("CENTER", pieHolder, "CENTER", 0, 0)
    ringHolder:SetFrameLevel(display:GetFrameLevel() + 1)
    circleFill:ClearAllPoints()
    circleFill:SetSize(inner, inner)
    circleFill:SetPoint("CENTER", pieHolder, "CENTER", 0, 0)
    fullDisc:ClearAllPoints()
    fullDisc:SetAllPoints(pieHolder)
    local core = math.max(2, math.floor(inner * 0.2 + 0.5))
    sparkDot:SetSize(core, core)
    sparkHalo:SetSize(math.max(core + 2, core * 2), math.max(core + 2, core * 2))
    if editing then
        editLabel:ClearAllPoints()
        editLabel:SetPoint("TOP", ringHolder, "BOTTOM", 0, -2)
        editLabel:Show()
    else
        editLabel:Hide()
    end
    if selection and selection.SetFrameLevel then
        selection:SetFrameLevel(display:GetFrameLevel() + 8)
    end
    RebuildSlices()
    geomSize = size
    geomEditing = editing
    geomBand = thickness
end

local sliceDX = {}
local sliceDY = {}
local sliceRadius
local sliceThickness
local pointsDirty = true
local lineShown = {}
local edgeShown = false
local sparkShown = false
local lastSparkX, lastSparkY
local lastSpark
local lastFillR, lastFillG, lastFillB, lastFillA
local lastEdgeR, lastEdgeG, lastEdgeB, lastEdgeA, lastEdgeThick
local lastEdgeX, lastEdgeY
local wedgesCleared = false
local baseShown = false
local lastBorderR, lastBorderG, lastBorderB, lastBorderA
local lastBackR, lastBackG, lastBackB, lastBackA
local linesBroken = false

function RebuildSlices()
    local size = CircleSize()
    local band = BorderBand()
    local radius = max(1, (size - band * 2) / 2)
    if radius == sliceRadius and band == sliceThickness then
        return
    end
    sliceRadius = radius
    sliceThickness = band
    lastEdgeX = nil
    if not ringLines or not ringLines[1] then
        return
    end
    local outer = size / 2
    local midR = max(band / 2, outer - band / 2)
    local step = (pi * 2) / RING_COUNT
    local half = max(0.75, midR * step * 0.65)
    local br, bg, bb, ba = BorderColor()
    for i = 1, RING_COUNT do
        local line = ringLines[i]
        local angle = (i - 0.5) * step
        local rx = sin(angle)
        local ry = cos(angle)
        local tx = ry
        local ty = -rx
        local cx = rx * midR
        local cy = ry * midR
        line:SetThickness(band)
        line:SetColorTexture(br, bg, bb, ba)
        pcall(function()
            line:SetStartPoint("CENTER", ringHolder, cx - tx * half, cy - ty * half)
            line:SetEndPoint("CENTER", ringHolder, cx + tx * half, cy + ty * half)
        end)
        if ba > 0.004 then
            line:Show()
        else
            line:Hide()
        end
    end
    lastBorderR, lastBorderG, lastBorderB, lastBorderA = br, bg, bb, ba
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
    if sparkHalo then
        sparkHalo:Hide()
    end
    if sparkDot then
        sparkDot:Hide()
    end
    sparkShown = false
end

local function HidePieLines()
    if pieLines then
        for i = 1, #pieLines do
            if lineShown[i] ~= false then
                pieLines[i]:Hide()
                lineShown[i] = false
            end
        end
    end
    if edgeLine and edgeShown then
        edgeLine:Hide()
        edgeShown = false
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
    if ringHolder then
        ringHolder:Hide()
    end
    if pieHolder then
        pieHolder:Hide()
    end
    if edgeLine and edgeShown then
        edgeLine:Hide()
        edgeShown = false
    end
    baseShown = false
    wedgesCleared = false
    lastBorderA = nil
    lastSweepDeg = nil
    discShown = false
end

local wedgeCoord = {}
local spanBuf = { { 0, 0 }, { 0, 0 }, { 0, 0 } }

local function MoveCorner(corner, x, y, size)
    local rx = DEFAULT_COORD[corner .. "x"] - x
    local ry = DEFAULT_COORD[corner .. "y"] - y
    wedgeCoord[corner .. "x"] = x
    wedgeCoord[corner .. "y"] = y
    wedgeCoord[corner .. "vx"] = -rx * size
    wedgeCoord[corner .. "vy"] = ry * size
end

local function PaintWedge(tex, size, angle1, angle2)
    local index = floor((angle1 + 45) / 90)
    local middle = POINT_ORDER[index + 1]
    local startCorner = POINT_ORDER[index + 2]
    local endCorner1 = POINT_ORDER[index + 3]
    local endCorner2 = POINT_ORDER[index + 4]
    MoveCorner(middle, 0.5, 0.5, size)
    local sx, sy = AngleToCoord(angle1)
    MoveCorner(startCorner, sx, sy, size)
    local edge1 = floor((angle1 - 45) / 90)
    local edge2 = floor((angle2 - 45) / 90)
    if edge1 == edge2 then
        local ex, ey = AngleToCoord(angle2)
        MoveCorner(endCorner1, ex, ey, size)
    else
        MoveCorner(endCorner1, DEFAULT_COORD[endCorner1 .. "x"], DEFAULT_COORD[endCorner1 .. "y"], size)
    end
    local ex, ey = AngleToCoord(angle2)
    MoveCorner(endCorner2, ex, ey, size)
    tex:SetVertexOffset(VERTEX.UR, wedgeCoord.URvx or 0, wedgeCoord.URvy or 0)
    tex:SetVertexOffset(VERTEX.UL, wedgeCoord.ULvx or 0, wedgeCoord.ULvy or 0)
    tex:SetVertexOffset(VERTEX.LR, wedgeCoord.LRvx or 0, wedgeCoord.LRvy or 0)
    tex:SetVertexOffset(VERTEX.LL, wedgeCoord.LLvx or 0, wedgeCoord.LLvy or 0)
    tex:SetTexCoord(wedgeCoord.ULx, wedgeCoord.ULy, wedgeCoord.LLx, wedgeCoord.LLy, wedgeCoord.URx, wedgeCoord.URy, wedgeCoord.LRx, wedgeCoord.LRy)
end

local function ShowSparkAt(x, y, qx, qy)
    if not sparkShown or qx ~= lastSparkX or qy ~= lastSparkY then
        sparkHalo:ClearAllPoints()
        sparkDot:ClearAllPoints()
        sparkHalo:SetPoint("CENTER", pieHolder, "CENTER", x, y)
        sparkDot:SetPoint("CENTER", pieHolder, "CENTER", x, y)
        lastSparkX, lastSparkY = qx, qy
    end
    if not sparkShown then
        sparkHalo:Show()
        sparkDot:Show()
        sparkShown = true
    end
end

local function ShowSweep(angle1, angle2, r, g, b, alpha)
    local index1 = floor((angle1 + 45) / 90)
    local index2 = floor((angle2 + 45) / 90)
    local n = 1
    spanBuf[1][1], spanBuf[1][2] = angle1, angle2
    if index1 + 1 < index2 then
        local mid = (index1 + 1) * 90 + 45
        spanBuf[1][2] = mid
        if index1 + 3 < index2 then
            spanBuf[2][1], spanBuf[2][2] = mid, mid + 180
            spanBuf[3][1], spanBuf[3][2] = mid + 180, angle2
            n = 3
        else
            spanBuf[2][1], spanBuf[2][2] = mid, angle2
            n = 2
        end
    end
    local size = pieHolder:GetWidth()
    for i = 1, 3 do
        local tex = wedgeTextures[i]
        if i <= n then
            tex:SetVertexColor(r, g, b, alpha)
            if pcall(PaintWedge, tex, size, spanBuf[i][1], spanBuf[i][2]) then
                tex:Show()
            else
                tex:Hide()
            end
        elseif tex:IsShown() then
            tex:Hide()
        end
    end
end

local lastSweepDeg
local lastSweepGrow
local discShown = false

local function PaintFillColor(r, g, b, alpha)
    if fullDisc and discShown then
        fullDisc:SetVertexColor(r, g, b, alpha)
    end
    if wedgeTextures then
        for i = 1, 3 do
            local tex = wedgeTextures[i]
            if tex:IsShown() then
                tex:SetVertexColor(r, g, b, alpha)
            end
        end
    end
end

local function UpdatePie(progress)
    local alpha = (0.5 + 0.5 * progress) * CircleAlpha()
    local alphaQ = floor(alpha * 256 + 0.5)
    local r, g, b = CircleColor()
    local grow = PieFills()
    local shown = grow and progress or (1 - progress)
    if shown < 0 then
        shown = 0
    elseif shown > 1 then
        shown = 1
    end
    local deg = floor(shown * 360 + 0.5)
    local colorChanged = r ~= lastFillR or g ~= lastFillG or b ~= lastFillB or alphaQ ~= lastFillA
    if colorChanged then
        lastFillR, lastFillG, lastFillB, lastFillA = r, g, b, alphaQ
    end
    local shapeChanged = deg ~= lastSweepDeg or grow ~= lastSweepGrow
    if shapeChanged then
        lastSweepDeg = deg
        lastSweepGrow = grow
        if shown >= 0.995 then
            HideWedges()
            fullDisc:SetVertexColor(r, g, b, alpha)
            fullDisc:Show()
            discShown = true
        elseif shown <= 0.002 then
            HideWedges()
            if discShown then
                fullDisc:Hide()
                discShown = false
            end
        else
            if discShown then
                fullDisc:Hide()
                discShown = false
            end
            if grow then
                ShowSweep(0, deg, r, g, b, alpha)
            else
                ShowSweep(360 - deg, 360, r, g, b, alpha)
            end
        end
    elseif colorChanged then
        PaintFillColor(r, g, b, alpha)
    end
    local edgeOk = false
    local active = progress > 0.001 and progress < 0.999 and shown > 0.002 and sliceRadius
    if edgeLine and active then
        local ea = LineAlpha()
        local lead = (grow and shown or progress) * pi * 2
        local edx = sin(lead) * sliceRadius
        local edy = cos(lead) * sliceRadius
        local qx = floor(edx * 4 + 0.5)
        local qy = floor(edy * 4 + 0.5)
        local wantThick = LineThickness()
        local moved = qx ~= lastEdgeX or qy ~= lastEdgeY
        local recolor = r ~= lastEdgeR or g ~= lastEdgeG or b ~= lastEdgeB or ea ~= lastEdgeA or wantThick ~= lastEdgeThick
        if moved or recolor or not edgeShown then
            local ok = pcall(function()
                if not edgeShown then
                    edgeLine:SetStartPoint("CENTER", pieHolder, 0, 0)
                end
                if moved or not edgeShown then
                    edgeLine:SetEndPoint("CENTER", pieHolder, edx, edy)
                end
                if recolor or not edgeShown then
                    edgeLine:SetThickness(wantThick)
                    edgeLine:SetColorTexture(r, g, b, ea)
                end
            end)
            if ok then
                lastEdgeX, lastEdgeY = qx, qy
                lastEdgeR, lastEdgeG, lastEdgeB, lastEdgeA = r, g, b, ea
                lastEdgeThick = wantThick
                if not edgeShown then
                    edgeLine:Show()
                    edgeShown = true
                end
                edgeOk = true
            elseif edgeShown then
                edgeLine:Hide()
                edgeShown = false
            end
        else
            edgeOk = true
        end
        if edgeOk and SparkOn() and sparkDot and sparkHalo then
            ShowSparkAt(edx, edy, qx, qy)
        elseif sparkShown then
            sparkHalo:Hide()
            sparkDot:Hide()
            sparkShown = false
        end
    else
        if edgeShown then
            edgeLine:Hide()
            edgeShown = false
        end
        if sparkShown then
            sparkHalo:Hide()
            sparkDot:Hide()
            sparkShown = false
        end
    end
    return true
end

local function ShowCircle(startTime, duration, progress)
    EnsureCircle()
    ApplyCircleGeometry()
    if progress < 0 then
        progress = 0
    elseif progress > 1 then
        progress = 1
    end
    local br, bg, bb, ba = BorderColor()
    local backR, backG, backB, backA = BackColor()
    if br ~= lastBorderR or bg ~= lastBorderG or bb ~= lastBorderB or ba ~= lastBorderA then
        lastBorderR, lastBorderG, lastBorderB, lastBorderA = br, bg, bb, ba
        if ringLines then
            for i = 1, #ringLines do
                local line = ringLines[i]
                line:SetColorTexture(br, bg, bb, ba)
                if ba > 0.004 then
                    line:Show()
                else
                    line:Hide()
                end
            end
        end
    end
    if backR ~= lastBackR or backG ~= lastBackG or backB ~= lastBackB or backA ~= lastBackA then
        lastBackR, lastBackG, lastBackB, lastBackA = backR, backG, backB, backA
        circleFill:SetVertexColor(backR, backG, backB, backA)
    end
    if not baseShown then
        display:Show()
        circleFill:Show()
        if ringHolder then
            ringHolder:Show()
        end
        pieHolder:Show()
        baseShown = true
    end
    UpdatePie(progress)
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

local textHidden = true
local lastTextR, lastTextG, lastTextB

local function PaintTextColor()
    local r, g, b = TextColor()
    if r == lastTextR and g == lastTextG and b == lastTextB then
        return
    end
    lastTextR, lastTextG, lastTextB = r, g, b
    text:SetTextColor(r, g, b)
end

local function ApplyFont()
    local size = FontSize()
    local font = (GameFontNormal and GameFontNormal.GetFont and GameFontNormal:GetFont()) or "Fonts\\FRIZQT__.TTF"
    local ok = pcall(text.SetFont, text, font, size, "OUTLINE")
    if not ok then
        pcall(text.SetFont, text, "Fonts\\FRIZQT__.TTF", size, "OUTLINE")
    end
    PaintTextColor()
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

local remainNow
local remainExpiry
local function ReadRemain()
    return remainExpiry - remainNow
end

local function NextSwing(now)
    local bestRemain, bestSpeed, bestExpiry
    remainNow = now
    for _, swing in pairs(swings) do
        if swing.active and swing.expiry then
            remainExpiry = swing.expiry
            local ok, remain = pcall(ReadRemain)
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

local REDRAW_INTERVAL = 1 / 30

local function StartTicker()
    if ticking then
        return
    end
    ticking = true
    refreshElapsed = REDRAW_INTERVAL
    driver:SetScript("OnUpdate", OnSwingUpdate)
end

local function StopTicker()
    if not ticking then
        return
    end
    ticking = false
    refreshElapsed = 0
    driver:SetScript("OnUpdate", nil)
end

local function RefreshText()
    if not enabled and not editing then
        display:Hide()
        HideCircle()
        StopTicker()
        return
    end
    if not textHidden then
        text:Hide()
        textHidden = true
    end
    local now = GetTime()
    local remain, speed, expiry = NextSwing(now)
    if remain and PlainNumber(speed) and speed > 0 and PlainNumber(expiry) then
        local progress = 1 - (remain / speed)
        ShowCircle(expiry - speed, speed, progress)
        StartTicker()
    elseif editing then
        local duration = 1.6
        if not sampleStart or now >= sampleStart + duration then
            sampleStart = now
            pieStamp = nil
        end
        ShowCircle(sampleStart, duration, (now - sampleStart) / duration)
        StartTicker()
    else
        HideCircle()
        display:Hide()
        StopTicker()
    end
end

OnSwingUpdate = function(_, elapsed)
    refreshElapsed = refreshElapsed + elapsed
    if refreshElapsed < REDRAW_INTERVAL then
        return
    end
    refreshElapsed = 0
    RefreshText()
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
    PaintTextColor()
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

local function RefreshPreviewNow()
    if SimpleTweaksSwing.RefreshPreview then
        SimpleTweaksSwing.RefreshPreview()
    end
end

function SimpleTweaksSwing.SetPie(direction)
    if SimpleTweaksDB then
        SimpleTweaksDB.swingTimerPie = direction == "fill" and "fill" or "drain"
    end
    pieStamp = nil
    RefreshText()
    RefreshPreviewNow()
end

function SimpleTweaksSwing.SetSpark(on)
    if SimpleTweaksDB then
        SimpleTweaksDB.swingTimerSpark = on and true or false
    end
    RefreshText()
    RefreshPreviewNow()
end

function SimpleTweaksSwing.SetCircleSize(size)
    if SimpleTweaksDB then
        SimpleTweaksDB.swingTimerCircleSize = tonumber(size) or CIRCLE_DEFAULT
    end
    ApplyCircleGeometry()
    RefreshText()
    RefreshPreviewNow()
end

function SimpleTweaksSwing.SetCircleColor(r, g, b, a)
    if SimpleTweaksDB then
        SimpleTweaksDB.swingTimerCircleR = ClampUnit(r, 1)
        SimpleTweaksDB.swingTimerCircleG = ClampUnit(g, 0.86)
        SimpleTweaksDB.swingTimerCircleB = ClampUnit(b, 0.55)
        if a ~= nil then
            SimpleTweaksDB.swingTimerCircleA = ClampUnit(a, 1)
        end
    end
    RefreshText()
    RefreshPreviewNow()
end

function SimpleTweaksSwing.SetBorderThickness(thickness)
    thickness = tonumber(thickness) or 1
    if thickness < 1 then
        thickness = 1
    elseif thickness > 8 then
        thickness = 8
    end
    if SimpleTweaksDB then
        SimpleTweaksDB.swingTimerBorderThickness = thickness
    end
    geomSize = nil
    sliceRadius = nil
    lastSweepDeg = nil
    ApplyCircleGeometry()
    RefreshText()
    RefreshPreviewNow()
end

function SimpleTweaksSwing.SetBorderColor(r, g, b, a)
    if SimpleTweaksDB then
        SimpleTweaksDB.swingTimerBorderR = ClampUnit(r, 0)
        SimpleTweaksDB.swingTimerBorderG = ClampUnit(g, 0)
        SimpleTweaksDB.swingTimerBorderB = ClampUnit(b, 0)
        if a ~= nil then
            SimpleTweaksDB.swingTimerBorderA = ClampUnit(a, 1)
        end
    end
    if circleBorder then
        circleBorder:SetColorTexture(BorderColor())
    end
    RefreshText()
    RefreshPreviewNow()
end

function SimpleTweaksSwing.SetBackColor(r, g, b, a)
    if SimpleTweaksDB then
        SimpleTweaksDB.swingTimerBackR = ClampUnit(r, 0.02)
        SimpleTweaksDB.swingTimerBackG = ClampUnit(g, 0.02)
        SimpleTweaksDB.swingTimerBackB = ClampUnit(b, 0.02)
        if a ~= nil then
            SimpleTweaksDB.swingTimerBackA = ClampUnit(a, 0.82)
        end
    end
    if circleFill then
        circleFill:SetColorTexture(BackColor())
    end
    RefreshText()
    RefreshPreviewNow()
end

function SimpleTweaksSwing.SetLineAlpha(a)
    if SimpleTweaksDB then
        SimpleTweaksDB.swingTimerLineA = ClampUnit(a, 1)
    end
    RefreshText()
    RefreshPreviewNow()
end

function SimpleTweaksSwing.SetLineThickness(thickness)
    thickness = tonumber(thickness) or 1
    if thickness < 1 then
        thickness = 1
    elseif thickness > 8 then
        thickness = 8
    end
    if SimpleTweaksDB then
        SimpleTweaksDB.swingTimerLineThickness = thickness
    end
    lastEdgeThick = nil
    RefreshText()
    RefreshPreviewNow()
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

local preview
local pvSpan = { { 0, 0 }, { 0, 0 }, { 0, 0 } }

local function PreviewSweep(wedges, holder, angle1, angle2, r, g, b, alpha)
    local index1 = floor((angle1 + 45) / 90)
    local index2 = floor((angle2 + 45) / 90)
    local n = 1
    pvSpan[1][1], pvSpan[1][2] = angle1, angle2
    if index1 + 1 < index2 then
        local mid = (index1 + 1) * 90 + 45
        pvSpan[1][2] = mid
        if index1 + 3 < index2 then
            pvSpan[2][1], pvSpan[2][2] = mid, mid + 180
            pvSpan[3][1], pvSpan[3][2] = mid + 180, angle2
            n = 3
        else
            pvSpan[2][1], pvSpan[2][2] = mid, angle2
            n = 2
        end
    end
    local size = holder:GetWidth()
    for i = 1, 3 do
        local tex = wedges[i]
        if i <= n then
            tex:SetVertexColor(r, g, b, alpha)
            if pcall(PaintWedge, tex, size, pvSpan[i][1], pvSpan[i][2]) then
                tex:Show()
            else
                tex:Hide()
            end
        elseif tex:IsShown() then
            tex:Hide()
        end
    end
end

local function EnsurePreview(parent)
    if preview then
        preview.root:SetParent(parent)
        return preview
    end
    local root = CreateFrame("Frame", nil, parent)
    root:EnableMouse(false)
    local pie = CreateFrame("Frame", nil, root)
    pie:EnableMouse(false)
    local ring = CreateFrame("Frame", nil, root)
    ring:EnableMouse(false)
    local fill = PrepareDisc(root, "BACKGROUND", 1)
    local disc = PrepareDisc(pie, "ARTWORK", 0)
    local wedges = {}
    for i = 1, 3 do
        local tex = PrepareDisc(pie, "ARTWORK", i)
        tex:SetAllPoints()
        wedges[i] = tex
    end
    local halo = PrepareDisc(pie, "OVERLAY", 6)
    local dot = PrepareDisc(pie, "OVERLAY", 7)
    halo:SetVertexColor(1, 0.97, 0.82, 0.38)
    dot:SetVertexColor(1, 1, 0.92, 1)
    local lines = {}
    local edge
    if ring.CreateLine then
        for i = 1, RING_COUNT do
            local line = ring:CreateLine(nil, "ARTWORK")
            line:Hide()
            lines[i] = line
        end
        edge = pie:CreateLine(nil, "OVERLAY", nil, 7)
        edge:Hide()
    end
    preview = {
        root = root,
        pie = pie,
        ring = ring,
        fill = fill,
        disc = disc,
        wedges = wedges,
        halo = halo,
        dot = dot,
        lines = lines,
        edge = edge,
        edgeOn = false,
        sparkOn = false,
        discOn = false,
    }
    return preview
end

local function LayoutPreview(p)
    local size = CircleSize()
    local band = BorderBand()
    if p.size == size and p.band == band then
        return
    end
    p.size = size
    p.band = band
    local inner = max(1, size - band * 2)
    p.root:SetSize(size, size)
    p.ring:SetFrameLevel(p.root:GetFrameLevel() + 1)
    p.pie:SetFrameLevel(p.root:GetFrameLevel() + 2)
    p.pie:ClearAllPoints()
    p.pie:SetSize(inner, inner)
    p.pie:SetPoint("CENTER", p.root, "CENTER", 0, 0)
    p.ring:ClearAllPoints()
    p.ring:SetSize(size, size)
    p.ring:SetPoint("CENTER", p.pie, "CENTER", 0, 0)
    p.fill:ClearAllPoints()
    p.fill:SetSize(inner, inner)
    p.fill:SetPoint("CENTER", p.pie, "CENTER", 0, 0)
    p.disc:ClearAllPoints()
    p.disc:SetAllPoints(p.pie)
    local core = max(2, floor(inner * 0.2 + 0.5))
    p.dot:SetSize(core, core)
    p.halo:SetSize(max(core + 2, core * 2), max(core + 2, core * 2))
    p.edgeOn = false
    if not p.lines[1] then
        return
    end
    local outer = size / 2
    local midR = max(band / 2, outer - band / 2)
    local step = (pi * 2) / RING_COUNT
    local half = max(0.75, midR * step * 0.65)
    local br, bg, bb, ba = BorderColor()
    p.br, p.bg, p.bb, p.ba = br, bg, bb, ba
    for i = 1, RING_COUNT do
        local line = p.lines[i]
        local angle = (i - 0.5) * step
        local rx = sin(angle)
        local ry = cos(angle)
        local tx = ry
        local ty = -rx
        local cx = rx * midR
        local cy = ry * midR
        line:SetThickness(band)
        line:SetColorTexture(br, bg, bb, ba)
        pcall(function()
            line:SetStartPoint("CENTER", p.ring, cx - tx * half, cy - ty * half)
            line:SetEndPoint("CENTER", p.ring, cx + tx * half, cy + ty * half)
        end)
        if ba > 0.004 then
            line:Show()
        else
            line:Hide()
        end
    end
end

local function DrawPreview(progress)
    local p = preview
    if not p then
        return
    end
    LayoutPreview(p)
    local br, bg, bb, ba = BorderColor()
    if br ~= p.br or bg ~= p.bg or bb ~= p.bb or ba ~= p.ba then
        p.br, p.bg, p.bb, p.ba = br, bg, bb, ba
        for i = 1, #p.lines do
            local line = p.lines[i]
            line:SetColorTexture(br, bg, bb, ba)
            if ba > 0.004 then
                line:Show()
            else
                line:Hide()
            end
        end
    end
    local backR, backG, backB, backA = BackColor()
    if backR ~= p.backR or backG ~= p.backG or backB ~= p.backB or backA ~= p.backA then
        p.backR, p.backG, p.backB, p.backA = backR, backG, backB, backA
        p.fill:SetVertexColor(backR, backG, backB, backA)
    end
    p.fill:Show()
    p.ring:Show()
    p.pie:Show()
    p.progress = progress
    local alpha = (0.5 + 0.5 * progress) * CircleAlpha()
    local r, g, b = CircleColor()
    local grow = PieFills()
    local shown = grow and progress or (1 - progress)
    if shown < 0 then
        shown = 0
    elseif shown > 1 then
        shown = 1
    end
    local deg = floor(shown * 360 + 0.5)
    if shown >= 0.995 then
        for i = 1, 3 do
            p.wedges[i]:Hide()
        end
        p.disc:SetVertexColor(r, g, b, alpha)
        p.disc:Show()
        p.discOn = true
    elseif shown <= 0.002 then
        for i = 1, 3 do
            p.wedges[i]:Hide()
        end
        if p.discOn then
            p.disc:Hide()
            p.discOn = false
        end
    else
        if p.discOn then
            p.disc:Hide()
            p.discOn = false
        end
        if grow then
            PreviewSweep(p.wedges, p.pie, 0, deg, r, g, b, alpha)
        else
            PreviewSweep(p.wedges, p.pie, 360 - deg, 360, r, g, b, alpha)
        end
    end
    local radius = p.pie:GetWidth() / 2
    local active = progress > 0.001 and progress < 0.999 and shown > 0.002 and radius > 0
    if p.edge and active then
        local lead = (grow and shown or progress) * pi * 2
        local ex = sin(lead) * radius
        local ey = cos(lead) * radius
        local ok = pcall(function()
            p.edge:SetStartPoint("CENTER", p.pie, 0, 0)
            p.edge:SetEndPoint("CENTER", p.pie, ex, ey)
            p.edge:SetThickness(LineThickness())
            p.edge:SetColorTexture(r, g, b, LineAlpha())
        end)
        if ok then
            p.edge:Show()
            p.edgeOn = true
            if SparkOn() then
                p.halo:ClearAllPoints()
                p.dot:ClearAllPoints()
                p.halo:SetPoint("CENTER", p.pie, "CENTER", ex, ey)
                p.dot:SetPoint("CENTER", p.pie, "CENTER", ex, ey)
                p.halo:Show()
                p.dot:Show()
                p.sparkOn = true
            elseif p.sparkOn then
                p.halo:Hide()
                p.dot:Hide()
                p.sparkOn = false
            end
        end
    else
        if p.edgeOn and p.edge then
            p.edge:Hide()
            p.edgeOn = false
        end
        if p.sparkOn then
            p.halo:Hide()
            p.dot:Hide()
            p.sparkOn = false
        end
    end
end

function SimpleTweaksSwing.RefreshPreview()
    if preview and preview.running then
        DrawPreview(preview.progress or 0)
    end
end

function SimpleTweaksSwing.SetPreview(parent, on)
    if not on or not parent then
        if preview then
            preview.running = false
            preview.root:SetScript("OnUpdate", nil)
            preview.root:Hide()
        end
        return
    end
    local p = EnsurePreview(parent)
    p.running = true
    p.root:ClearAllPoints()
    p.root:SetPoint("CENTER", parent, "CENTER", 0, 0)
    p.root:Show()
    p.size = nil
    local wait = 0
    p.root:SetScript("OnUpdate", function(_, elapsed)
        wait = wait + elapsed
        if wait < 0.033 then
            return
        end
        wait = 0
        DrawPreview((GetTime() % 2.4) / 2.4)
    end)
    DrawPreview((GetTime() % 2.4) / 2.4)
end
