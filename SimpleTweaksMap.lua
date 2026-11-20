-- Karte beim Bewegen sichtbar halten.
local function UpdateMapFade(enable)
    if enable then
        if SimpleTweaksDB.mapFadeBeforeOverride == nil then
            SimpleTweaksDB.mapFadeBeforeOverride = GetCVarBool("mapFade")
        end
        SetCVar("mapFade", "0")
    elseif SimpleTweaksDB.mapFadeBeforeOverride ~= nil then
        SetCVar("mapFade", SimpleTweaksDB.mapFadeBeforeOverride and "1" or "0")
        SimpleTweaksDB.mapFadeBeforeOverride = nil
    end
end

SimpleTweaks.UpdateMapFade = UpdateMapFade
