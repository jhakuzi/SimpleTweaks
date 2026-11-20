-- Kern: gemeinsame Helfer. Die einzelnen Funktionen liegen in eigenen Dateien.
local addonName = ...
SimpleTweaks = SimpleTweaks or {}
local ST = SimpleTweaks

ST.addonName = addonName
ST.optionChecks = {}
ST.activeNameplateUnits = {}
ST.nameplateByUnit = {}
ST.DEFAULTS = {
    disableMapFade = true,
    hideMacroNames = true,
    hunterRangeIndicator = false,
    hideStanceBar = false,
    npcNameOnly = false,
    showFps = false,
    comboPoints = false,
    swingTimer = false,
    swingTimerFontSize = 18,
    swingTimerDecimals = 1,
    swingTimerColorR = 1,
    swingTimerColorG = 0.86,
    swingTimerColorB = 0.55,
    swingTimerStyle = "text",
    swingTimerPie = "drain",
    swingTimerSpark = false,
    swingTimerCircleSize = 9,
    swingTimerCircleR = 1,
    swingTimerCircleG = 0.86,
    swingTimerCircleB = 0.55,
    swingTimerCircleA = 1,
    swingTimerBorderR = 0,
    swingTimerBorderG = 0,
    swingTimerBorderB = 0,
    swingTimerBorderA = 1,
    swingTimerLineA = 1,
    swingTimerLineThickness = 1,
    swingTimerBackR = 0.02,
    swingTimerBackG = 0.02,
    swingTimerBackB = 0.02,
    swingTimerBackA = 0.82,
}

function ST.Print(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cffd6a45eSimpleTweaks:|r " .. message)
end

function ST.IsEnabled(setting)
    return SimpleTweaksDB ~= nil and SimpleTweaksDB[setting] ~= false
end

function ST.NamePlateFor(unit)
    if type(C_NamePlate) ~= "table" or type(C_NamePlate.GetNamePlateForUnit) ~= "function" then
        return nil
    end
    local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
    if not ok or not plate then
        return nil
    end
    return plate
end

function ST.PlainBoolean(value)
    if value == nil then
        return nil
    end
    if issecretvalue and issecretvalue(value) then
        return nil
    end
    return value and true or false
end
