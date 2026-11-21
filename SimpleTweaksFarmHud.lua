-- Die Blizzard-Minimap als transparente Anzeige mit einem Umschalter am Kartenrand.
local ST = SimpleTweaks
local original
local toggleButton
local hudOpen = false

local function DisableMouseTree(frame)
    if frame == toggleButton or frame:IsForbidden() or not frame:CanChangeProtectedState() then
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

local function CreateToggleButton(map)
    local button = CreateFrame("Button", nil, map)
    button:SetSize(28, 28)
    button:SetFrameLevel(map:GetFrameLevel() + 8)
    button:SetIgnoreParentAlpha(true)
    button:EnableMouse(true)
    button:EnableMouseWheel(false)
    button:RegisterForClicks("LeftButtonUp")

    local rim = button:CreateTexture(nil, "OVERLAY")
    rim:SetAllPoints(button)
    rim:SetAtlas("UI-HUD-Minimap-Frame-Cycle")

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(22, 22)
    icon:SetPoint("CENTER")
    icon:SetTexture("Interface\\AddOns\\" .. ST.addonName .. "\\Media\\FarmHudIcon.tga")
    local mask = button:CreateMaskTexture()
    mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMP", "CLAMP")
    mask:SetAllPoints(icon)
    icon:AddMaskTexture(mask)
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight", "ADD")

    button:SetScript("OnClick", function()
        GameTooltip:Hide()
        hudOpen = not hudOpen
        ST.UpdateFarmHud()
    end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("FarmHUD")
        GameTooltip:AddLine(hudOpen and "Minimap zurücksetzen" or "FarmHUD anzeigen", 1, 1, 1)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    return button
end

function ST.UpdateFarmHudButton()
    local map = Minimap
    if not map or not SimpleTweaksDB or not SimpleTweaksDB.farmHud then
        if toggleButton then
            toggleButton:Hide()
        end
        return
    end

    toggleButton = toggleButton or CreateToggleButton(map)
    local width, height = map:GetSize()
    toggleButton:ClearAllPoints()
    toggleButton:SetPoint("CENTER", map, "CENTER", width * 0.24, -height * 0.44)
    toggleButton:Show()
end

function ST.UpdateFarmHud()
    if not InCombatLockdown() then
        local map = Minimap
        local editing = EditModeManagerFrame and EditModeManagerFrame:IsEditModeActive()
        if map and hudOpen and not editing then
            if not original then
                UndockMinimap(map)
            end
            local size = SimpleTweaksDB.farmHudSize * UIParent:GetEffectiveScale() / map:GetEffectiveScale()
            map:SetSize(size, size)
        else
            DockMinimap()
        end
    end
    ST.UpdateFarmHudButton()
end

EventRegistry:RegisterCallback("EditMode.Enter", ST.UpdateFarmHud, ST)
EventRegistry:RegisterCallback("EditMode.Exit", ST.UpdateFarmHud, ST)
