-- Ereignisse und der kurze Prüfintervall. Die Funktionen selbst stehen in den anderen Dateien.
local ST = SimpleTweaks
local frame = CreateFrame("Frame")
local rangeUpdateElapsed = 0

local function OnNameplateAdded(unit)
    ST.activeNameplateUnits[unit] = true
    local plate = ST.NamePlateFor(unit)
    if plate then
        ST.nameplateByUnit[unit] = plate
    end
    if ST.IsEnabled("hunterRangeIndicator") then
        ST.SetNameplateIndicatorEnabled(true)
    end
    if ST.IsEnabled("npcNameOnly") then
        ST.ApplyNpcNameOnly(unit)
    end
    if SimpleTweaksDB and SimpleTweaksDB.comboPoints then
        ST.UpdateComboPlate(unit)
    end
end

local function OnNameplateRemoved(unit)
    local plate = ST.nameplateByUnit[unit]
    ST.nameplateByUnit[unit] = nil
    if not plate then
        plate = ST.NamePlateFor(unit)
    end
    if plate then
        ST.RestoreNpcPlate(plate)
        ST.HideCombo(plate)
    end
    ST.activeNameplateUnits[unit] = nil
    ST.ClearRangeIndicator(unit)
    if ST.IsEnabled("hunterRangeIndicator") then
        ST.SetNameplateIndicatorEnabled(true)
    end
end

frame:RegisterEvent("ADDON_LOADED")
pcall(frame.RegisterEvent, frame, "NAME_PLATE_UNIT_ADDED")
pcall(frame.RegisterEvent, frame, "NAME_PLATE_UNIT_REMOVED")
pcall(frame.RegisterEvent, frame, "PLAYER_TARGET_CHANGED")
pcall(frame.RegisterEvent, frame, "UNIT_COMBO_POINTS")
pcall(frame.RegisterEvent, frame, "UNIT_POWER_UPDATE")
pcall(frame.RegisterEvent, frame, "PLAYER_ENTERING_WORLD")
pcall(frame.RegisterEvent, frame, "PLAYER_LOGOUT")
pcall(frame.RegisterEvent, frame, "ACTIONBAR_SLOT_CHANGED")
pcall(frame.RegisterEvent, frame, "UPDATE_BONUS_ACTIONBAR")
pcall(frame.RegisterEvent, frame, "ACTIONBAR_PAGE_CHANGED")
pcall(frame.RegisterEvent, frame, "UPDATE_SHAPESHIFT_FORM")
pcall(frame.RegisterEvent, frame, "UPDATE_SHAPESHIFT_FORMS")
pcall(frame.RegisterEvent, frame, "PLAYER_REGEN_ENABLED")
frame:SetScript("OnEvent", function(_, event, loadedAddon, arg2)
    if event == "PLAYER_LOGOUT" then
        ST.RestoreFarmHudCVars()
        return
    elseif event == "NAME_PLATE_UNIT_ADDED" then
        OnNameplateAdded(loadedAddon)
        return
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        OnNameplateRemoved(loadedAddon)
        return
    elseif event == "PLAYER_TARGET_CHANGED" or event == "UNIT_COMBO_POINTS" or (event == "UNIT_POWER_UPDATE" and (arg2 == nil or arg2 == "COMBO_POINTS")) then
        if ST.IsEnabled("hunterRangeIndicator") and event == "PLAYER_TARGET_CHANGED" then
            ST.SetNameplateIndicatorEnabled(true)
        end
        if SimpleTweaksDB and SimpleTweaksDB.comboPoints then
            ST.RefreshComboPoints()
        end
        return
    elseif event == "PLAYER_REGEN_ENABLED" then
        ST.UpdateStanceBar()
        ST.UpdateFarmHud()
        return
    elseif event == "PLAYER_ENTERING_WORLD" or event == "ACTIONBAR_SLOT_CHANGED" or event == "UPDATE_BONUS_ACTIONBAR" or event == "ACTIONBAR_PAGE_CHANGED" or event == "UPDATE_SHAPESHIFT_FORM" or event == "UPDATE_SHAPESHIFT_FORMS" then
        if event == "PLAYER_ENTERING_WORLD" then
            ST.UpdateFarmHud()
        end
        ST.HookFutureMacroButtons()
        ST.RefreshMacroNames()
        ST.UpdateStanceBar()
        ST.UpdateFpsCounter()
        if ST.IsEnabled("npcNameOnly") then
            ST.RefreshNpcNameOnly()
        end
        if SimpleTweaksDB and SimpleTweaksDB.comboPoints then
            ST.RefreshComboPoints()
        end
        return
    end
    if event ~= "ADDON_LOADED" or loadedAddon ~= ST.addonName then
        return
    end

    SimpleTweaksDB = SimpleTweaksDB or {}
    for key, value in pairs(ST.DEFAULTS) do
        if SimpleTweaksDB[key] == nil then
            SimpleTweaksDB[key] = value
        end
    end
    ST.SetInstantLootEnabled(SimpleTweaksDB.instantLoot)

    if ST.IsEnabled("disableMapFade") then
        ST.UpdateMapFade(true)
    end
    if ST.IsEnabled("hunterRangeIndicator") then
        ST.SetNameplateIndicatorEnabled(true)
    end

    ST.RefreshMacroNames()
    ST.HookFutureMacroButtons()
    ST.UpdateStanceBar()
    ST.UpdateFpsCounter()
    if SimpleTweaksSwing and SimpleTweaksSwing.Init then
        SimpleTweaksSwing.Init()
    end
    if SimpleTweaksFiveSec and SimpleTweaksFiveSec.Init then
        SimpleTweaksFiveSec.Init()
    end
    if AddonCompartmentFrame and AddonCompartmentFrame.RegisterAddon then
        AddonCompartmentFrame:RegisterAddon({ text = "SimpleTweaks", icon = "Interface\\Icons\\INV_Misc_Gear_01", notCheckable = true, func = ST.OpenOptions })
    end
    ST.Print("Geladen. /tweaks öffnet die Einstellungen.")
    frame:UnregisterEvent("ADDON_LOADED")
end)
frame:SetScript("OnUpdate", function(_, elapsed)
    rangeUpdateElapsed = rangeUpdateElapsed + elapsed
    if rangeUpdateElapsed >= 0.2 then
        rangeUpdateElapsed = 0
        if ST.IsEnabled("hideStanceBar") then
            ST.UpdateStanceBar()
        end
        if ST.IsEnabled("hideMacroNames") then
            ST.RefreshMacroNames()
        end
        if ST.IsEnabled("hunterRangeIndicator") then
            ST.SetNameplateIndicatorEnabled(true)
        end
        if ST.IsEnabled("npcNameOnly") then
            ST.RefreshNpcNameOnly()
        end
        if SimpleTweaksDB and SimpleTweaksDB.showFps then
            ST.UpdateFpsCounter()
        end
        if SimpleTweaksDB and SimpleTweaksDB.comboPoints then
            ST.RefreshComboPoints()
        end
    end
end)
