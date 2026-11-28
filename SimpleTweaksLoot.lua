-- Beute direkt bei LOOT_READY anfordern und das Beutefenster ausblenden.
local ST = SimpleTweaks
local frame = CreateFrame("Frame")
local enabled = false
local sessionId = 0
local looting = false
local lootHandled = false
local lootFrame
local hookedLootFrame
local savedAlpha
local visibleAlpha = 1
local savedAnimations = {}

local function SetLootWindowHidden(hidden, showForManual)
    if not lootFrame then
        return
    end

    if hidden then
        if savedAlpha == nil then
            savedAlpha = lootFrame:GetAlpha()
            -- Beide Blizzard-Animationen setzen die Deckkraft selbst.
            for _, animationGroup in ipairs({ lootFrame.ShowAnim, lootFrame.HideAnim }) do
                if animationGroup and animationGroup.GetAnimations then
                    for _, animation in ipairs({ animationGroup:GetAnimations() }) do
                        if animation.GetFromAlpha and animation.GetToAlpha then
                            savedAnimations[#savedAnimations + 1] = {
                                animation = animation,
                                from = animation:GetFromAlpha(),
                                to = animation:GetToAlpha(),
                            }
                            if animationGroup == lootFrame.ShowAnim then
                                visibleAlpha = animation:GetFromAlpha()
                            end
                            animation:SetFromAlpha(0)
                            animation:SetToAlpha(0)
                        end
                    end
                end
            end
        end
        lootFrame:SetAlpha(0)
    elseif savedAlpha ~= nil then
        for _, saved in ipairs(savedAnimations) do
            saved.animation:SetFromAlpha(saved.from)
            saved.animation:SetToAlpha(saved.to)
        end
        savedAnimations = {}
        lootFrame:SetAlpha(showForManual and visibleAlpha or savedAlpha)
        savedAlpha = nil
    end
end

local function FinishSession(showLootWindow)
    sessionId = sessionId + 1
    looting = false
    if showLootWindow then
        SetLootWindowHidden(false, true)
    end
end

local function BeginSession()
    sessionId = sessionId + 1
    looting = true
    lootFrame = LootFrame
    if lootFrame and lootFrame ~= hookedLootFrame then
        hookedLootFrame = lootFrame
        lootFrame:HookScript("OnHide", function()
            if not looting then
                SetLootWindowHidden(false)
            end
        end)
    end
    SetLootWindowHidden(true)
    local currentSession = sessionId
    C_Timer.After(2, function()
        if looting and sessionId == currentSession then
            FinishSession(true)
        end
    end)
end

local function OnLootReady()
    if not enabled or lootHandled then
        return
    end
    if IsModifiedClick("AUTOLOOTTOGGLE") then
        FinishSession(true)
        lootHandled = true
        return
    end

    local ok, slotCount = pcall(GetNumLootItems)
    if not ok or type(slotCount) ~= "number" or slotCount < 1 then
        SetLootWindowHidden(false, true)
        return
    end

    BeginSession()
    lootHandled = true
    -- Auch bei aktivem WoW-Autoloot sofort anfordern, bevor der Client regulär plündert.
    local attempted = false
    for slot = slotCount, 1, -1 do
        local slotOk, slotType, locked = pcall(function()
            local _, _, _, _, _, isLocked = GetLootSlotInfo(slot)
            return GetLootSlotType(slot), isLocked
        end)
        if not slotOk then
            FinishSession(true)
            return
        end
        if not locked and slotType ~= Enum.LootSlotType.None then
            local lootOk = pcall(LootSlot, slot)
            if not lootOk then
                FinishSession(true)
                return
            end
            attempted = true
            if not looting then
                return
            end
        end
    end

    if not attempted then
        FinishSession(true)
    end
end

frame:SetScript("OnEvent", function(_, event, ...)
    if event == "LOOT_READY" then
        OnLootReady()
    elseif event == "LOOT_CLOSED" then
        FinishSession(false)
        lootHandled = false
        if savedAlpha ~= nil then
            -- Normalerweise räumt OnHide auf. Das Fenster kann bereits geschlossen sein.
            local closedSession = sessionId
            C_Timer.After(0.2, function()
                if not looting and sessionId == closedSession then
                    SetLootWindowHidden(false)
                end
            end)
        end
    elseif event == "LOOT_BIND_CONFIRM" then
        if looting then
            FinishSession(true)
        end
    elseif event == "UI_ERROR_MESSAGE" then
        local _, errorMessage = ...
        if looting and errorMessage == ERR_INV_FULL then
            FinishSession(true)
        end
    end
end)

local function RegisterLootEvents(shouldRegister)
    local events = { "LOOT_READY", "LOOT_CLOSED", "LOOT_BIND_CONFIRM", "UI_ERROR_MESSAGE" }
    for _, event in ipairs(events) do
        if shouldRegister then
            frame:RegisterEvent(event)
        else
            frame:UnregisterEvent(event)
        end
    end
end

function ST.SetInstantLootEnabled(shouldEnable)
    enabled = shouldEnable and true or false
    if enabled then
        RegisterLootEvents(true)
    else
        lootHandled = false
        FinishSession(true)
        RegisterLootEvents(false)
    end
end
