-- Haltungsanzeige ausblenden.
local ST = SimpleTweaks
local IsEnabled = ST.IsEnabled

local function ShouldHideStance()
    if not IsEnabled("hideStanceBar") then
        return false
    end
    if EditModeManagerFrame and EditModeManagerFrame.IsShown and EditModeManagerFrame:IsShown() then
        return false
    end
    return true
end

local function UpdateStanceBar()
    if InCombatLockdown and InCombatLockdown() then
        return
    end
    local frames = { StanceBar, StanceBarFrame, ShapeshiftBarFrame }
    local hide = ShouldHideStance()
    for i = 1, #frames do
        local frame = frames[i]
        if frame then
            if type(UnregisterStateDriver) == "function" then
                pcall(UnregisterStateDriver, frame, "visibility")
            end
            if hide then
                frame.stHiddenByTweaks = true
                if not frame.GetAlpha or frame:GetAlpha() ~= 0 then
                    frame:SetAlpha(0)
                end
            elseif frame.stHiddenByTweaks then
                frame.stHiddenByTweaks = nil
                if not frame.GetAlpha or frame:GetAlpha() ~= 1 then
                    frame:SetAlpha(1)
                end
                if frame.IsShown and not frame:IsShown() then
                    frame:Show()
                end
            end
        end
    end
end

ST.UpdateStanceBar = UpdateStanceBar
