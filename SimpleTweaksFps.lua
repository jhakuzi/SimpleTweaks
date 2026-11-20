-- Blizzard-FPS-Anzeige unten rechts.
local originalFpsLabel

local function FpsLabelWidget()
    if FramerateLabel then
        return FramerateLabel
    end
    if FramerateFrame and FramerateFrame.Label then
        return FramerateFrame.Label
    end
end

local function ShowFpsWord()
    local label = FpsLabelWidget()
    if not label or not label.SetText then
        return
    end
    if originalFpsLabel == nil and label.GetText then
        local ok, text = pcall(label.GetText, label)
        if ok and type(text) == "string" then
            originalFpsLabel = text
        end
    end
    local ok, text = pcall(label.GetText, label)
    if not ok or text ~= "FPS:" then
        pcall(label.SetText, label, "FPS:")
    end
end

local function RestoreFpsWord()
    local label = FpsLabelWidget()
    if label and originalFpsLabel and label.SetText then
        pcall(label.SetText, label, originalFpsLabel)
    end
end

local function UpdateFpsCounter()
    local frame = FramerateFrame or FramerateLabel
    if not (SimpleTweaksDB and SimpleTweaksDB.showFps) then
        if frame and frame.stTweaksFps and frame.IsShown and frame:IsShown() then
            frame.stTweaksFps = nil
            if type(ToggleFramerate) == "function" then
                pcall(ToggleFramerate)
            elseif frame.Hide then
                frame:Hide()
            end
            RestoreFpsWord()
        end
        return
    end
    if not frame and type(ToggleFramerate) == "function" then
        pcall(ToggleFramerate)
        frame = FramerateFrame or FramerateLabel
    end
    if not frame then
        return
    end
    if frame.IsShown and not frame:IsShown() then
        if type(ToggleFramerate) == "function" then
            pcall(ToggleFramerate)
        elseif frame.Show then
            frame:Show()
        end
    end
    frame.stTweaksFps = true
    local point, relativeTo, relativePoint = frame:GetPoint(1)
    if point ~= "BOTTOMRIGHT" or relativeTo ~= UIParent or relativePoint ~= "BOTTOMRIGHT" then
        frame:ClearAllPoints()
        frame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -8, 8)
    end
    ShowFpsWord()
end

SimpleTweaks.UpdateFpsCounter = UpdateFpsCounter
