-- Die Blizzard-Minimap als transparente, nicht anklickbare Anzeige in der Bildschirmmitte.
local ST = SimpleTweaks
local original

local function DisableMouseTree(frame)
    if frame:IsForbidden() or not frame:CanChangeProtectedState() then
        return
    end

    local click = frame:IsMouseClickEnabled()
    local motion = frame:IsMouseMotionEnabled()
    local wheel = frame:IsMouseWheelEnabled()
    if click or motion or wheel then
        if not original.mouse[frame] then
            original.mouse[frame] = {click = click, motion = motion, wheel = wheel}
        end
        frame:SetMouseClickEnabled(false)
        frame:SetMouseMotionEnabled(false)
        frame:EnableMouseWheel(false)
    end

    for _, child in ipairs({frame:GetChildren()}) do
        DisableMouseTree(child)
    end
end

local function DockMinimap()
    if not original then
        return
    end

    original.mouseTicker:Cancel()
    local map = original.map
    map:ClearAllPoints()
    map:SetSize(original.width, original.height)
    for _, point in ipairs(original.points) do
        map:SetPoint(unpack(point, 1, 5))
    end
    map:SetZoom(original.zoom)
    map:SetAlpha(original.alpha)
    for frame, mouse in pairs(original.mouse) do
        if not frame:IsForbidden() then
            frame:SetMouseClickEnabled(mouse.click)
            frame:SetMouseMotionEnabled(mouse.motion)
            frame:EnableMouseWheel(mouse.wheel)
        end
    end
    for frame, shown in pairs(original.chrome) do
        frame:SetShown(shown)
    end
    original = nil
end

local function UndockMinimap(map)
    local width, height = map:GetSize()
    original = {
        map = map,
        width = width,
        height = height,
        zoom = map:GetZoom(),
        alpha = map:GetAlpha(),
        mouse = {},
        points = {},
        chrome = {},
    }
    for index = 1, map:GetNumPoints() do
        original.points[index] = {map:GetPoint(index)}
    end

    local container = MinimapCluster and MinimapCluster.MinimapContainer
    for _, frame in pairs({
        MinimapBackdrop,
        map.ZoomHitArea,
        map.ZoomIn,
        map.ZoomOut,
        container and container.PlayerCoords,
    }) do
        original.chrome[frame] = frame:IsShown()
        frame:Hide()
    end

    map:ClearAllPoints()
    map:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    DisableMouseTree(map)
    original.mouseTicker = C_Timer.NewTicker(0.2, function()
        DisableMouseTree(map)
    end)
    map:SetZoom(0)
    -- Der Client zeichnet die nativen Kartensymbole auch ohne sichtbares Gelände.
    map:SetAlpha(0)
end

function ST.UpdateFarmHud()
    if InCombatLockdown() then
        return
    end

    local editing = EditModeManagerFrame and EditModeManagerFrame:IsEditModeActive()
    local map = Minimap
    if not map or not ST.IsEnabled("farmHud") or editing then
        DockMinimap()
        return
    end

    if not original then
        UndockMinimap(map)
    end
    local size = SimpleTweaksDB.farmHudSize * UIParent:GetEffectiveScale() / map:GetEffectiveScale()
    map:SetSize(size, size)
end

EventRegistry:RegisterCallback("EditMode.Enter", ST.UpdateFarmHud, ST)
EventRegistry:RegisterCallback("EditMode.Exit", ST.UpdateFarmHud, ST)
