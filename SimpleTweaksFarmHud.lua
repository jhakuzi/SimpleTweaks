-- Die Blizzard-Minimap als transparente Anzeige mit einem Umschalter am Kartenrand.
local ST = SimpleTweaks
local original
local toggleButton
local hudOpen = false
local previousMinimapCVars = {}

BINDING_HEADER_SIMPLETWEAKS = "SimpleTweaks"
BINDING_NAME_SIMPLETWEAKS_TOGGLE_FARMHUD = "FarmHUD-Projektion umschalten"

local function GetMinimapCVar(name)
    if type(GetCVar) ~= "function" then
        return nil
    end
    local ok, value = pcall(GetCVar, name)
    if not ok or value == nil then
        return nil
    end
    return tostring(value)
end

local function SetMinimapCVar(name, value)
    if type(SetCVar) ~= "function" then
        return false
    end
    local ok = pcall(SetCVar, name, value)
    return ok and GetMinimapCVar(name) == value
end

local function UpdateMinimapCVar(name, value)
    local previousValue = previousMinimapCVars[name]
    if value == nil and previousValue == nil then
        return
    end
    local current = GetMinimapCVar(name)
    if current == nil then
        return
    end

    if value ~= nil then
        if current == value or SetMinimapCVar(name, value) then
            previousMinimapCVars[name] = previousValue or current
        end
    elseif current == previousValue or SetMinimapCVar(name, previousValue) then
        previousMinimapCVars[name] = nil
    end
end

function ST.RestoreFarmHudCVars()
    UpdateMinimapCVar("rotateMinimap")
    UpdateMinimapCVar("questPOI")
end

function ST.ToggleFarmHud()
    hudOpen = not hudOpen
    ST.UpdateFarmHud()
end

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

local function PositionToggleButton(button, map)
    button:ClearAllPoints()

    local screenPosition = SimpleTweaksDB.farmHudButtonScreen
    if original and screenPosition then
        local scale = UIParent:GetEffectiveScale() / button:GetEffectiveScale()
        button:SetPoint("CENTER", UIParent, "CENTER", screenPosition.x * scale, screenPosition.y * scale)
        return
    end

    local width, height = map:GetSize()
    local rimPosition = SimpleTweaksDB.farmHudButtonRim
    local x = rimPosition and rimPosition.x or 0.24
    local y = rimPosition and rimPosition.y or -0.44
    button:SetPoint("CENTER", map, "CENTER", width * x, height * y)
end

local function MoveToggleButton(button, map, cursorX, cursorY)
    if original then
        local scale = UIParent:GetEffectiveScale()
        local x, y = UIParent:GetCenter()
        SimpleTweaksDB.farmHudButtonScreen = {x = cursorX / scale - x, y = cursorY / scale - y}
    else
        local x, y = map:GetCenter()
        local width, height = map:GetSize()
        if not x or width <= 0 or height <= 0 then
            return
        end
        local scale = map:GetEffectiveScale()
        local dx = (cursorX / scale - x) / width
        local dy = (cursorY / scale - y) / height
        local distance = math.sqrt(dx * dx + dy * dy)
        if distance == 0 then
            return
        end
        SimpleTweaksDB.farmHudButtonRim = {x = dx / (2 * distance), y = dy / (2 * distance)}
    end
    PositionToggleButton(button, map)
end

local function StopToggleDrag(button)
    button:SetScript("OnUpdate", nil)
end

local function StartToggleDrag(button, map)
    local centerX, centerY = button:GetCenter()
    if not centerX then
        return
    end
    GameTooltip:Hide()

    local cursorX, cursorY = GetCursorPosition()
    local scale = button:GetEffectiveScale()
    local offsetX, offsetY = centerX * scale - cursorX, centerY * scale - cursorY
    local mapState = original
    button:SetScript("OnUpdate", function(self)
        if original ~= mapState then
            StopToggleDrag(self)
            return
        end
        local x, y = GetCursorPosition()
        MoveToggleButton(self, map, x + offsetX, y + offsetY)
    end)
end

local function CreateToggleButton(map)
    local button = CreateFrame("Button", nil, map)
    button:SetSize(28, 28)
    button:SetFrameLevel(map:GetFrameLevel() + 8)
    button:SetIgnoreParentAlpha(true)
    button:SetClampedToScreen(true)
    button:EnableMouse(true)
    button:EnableMouseWheel(false)
    button:RegisterForClicks("LeftButtonUp")
    button:RegisterForDrag("RightButton")

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

    button:SetScript("OnClick", function(self)
        StopToggleDrag(self)
        GameTooltip:Hide()
        ST.ToggleFarmHud()
    end)
    button:SetScript("OnDragStart", function(self)
        StartToggleDrag(self, map)
    end)
    button:SetScript("OnDragStop", StopToggleDrag)
    button:SetScript("OnHide", StopToggleDrag)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("FarmHUD")
        GameTooltip:AddLine(hudOpen and "Minimap zurücksetzen" or "FarmHUD anzeigen", 1, 1, 1)
        GameTooltip:AddLine("Mit der rechten Maustaste ziehen.", 1, 1, 1)
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
    PositionToggleButton(toggleButton, map)
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
        local projected = original ~= nil
        UpdateMinimapCVar("rotateMinimap", projected and SimpleTweaksDB.farmHudRotate and "1" or nil)
        UpdateMinimapCVar("questPOI", projected and not SimpleTweaksDB.farmHudQuestBlobs and "0" or nil)
    end
    ST.UpdateFarmHudButton()
end

EventRegistry:RegisterCallback("EditMode.Enter", ST.UpdateFarmHud, ST)
EventRegistry:RegisterCallback("EditMode.Exit", ST.UpdateFarmHud, ST)
