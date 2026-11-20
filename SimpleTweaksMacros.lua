-- Makronamen auf den Aktionsleisten ausblenden.
local ST = SimpleTweaks
local IsEnabled = ST.IsEnabled

local function UpdateMacroName(button)
    local name = button and button.Name
    if not name then
        return
    end

    local actionType
    if button.action then
        actionType = GetActionInfo(button.action)
    end

    if actionType == "macro" and IsEnabled("hideMacroNames") then
        name:Hide()
    else
        name:Show()
    end
end

local function HookMacroName(button)
    UpdateMacroName(button)
end

local function RefreshMacroNames()
    local actionFrames = ActionBarActionEventsFrame and ActionBarActionEventsFrame.frames
    if actionFrames then
        for button in pairs(actionFrames) do
            HookMacroName(button)
        end
    end

    local buttonFrames = ActionBarButtonEventsFrame and ActionBarButtonEventsFrame.frames
    if buttonFrames then
        for _, button in pairs(buttonFrames) do
            HookMacroName(button)
        end
    end
end

local function HookFutureMacroButtons()
    RefreshMacroNames()
end

ST.RefreshMacroNames = RefreshMacroNames
ST.HookFutureMacroButtons = HookFutureMacroButtons
