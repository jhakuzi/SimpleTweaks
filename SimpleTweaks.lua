local addonName = ...
local DEFAULTS = {
    disableMapFade = true,
    hideMacroNames = true,
}
local hookedButtons = setmetatable({}, { __mode = "k" })
local optionsWindow
local optionChecks = {}
local cvarRows = {}
local cvarNames = {}
    local graphicsRefreshing = false

local function Print(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cffd6a45eSimpleTweaks:|r " .. message)
end

local function IsEnabled(setting)
    return SimpleTweaksDB[setting] ~= false
end

local function SetCVarChecked(name, value)
    local ok, err = pcall(SetCVar, name, value)
    if not ok then return false, tostring(err) end
    local actual = GetCVar(name)
    if actual == nil then return false, "CVar nicht verfügbar" end
    if tostring(actual) ~= tostring(value) then
        return false, "Wert wurde abgelehnt (aktuell: " .. tostring(actual) .. ")"
    end
    return true
end

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
    if button and button.Update and not hookedButtons[button] then
        hooksecurefunc(button, "Update", UpdateMacroName)
        hookedButtons[button] = true
    end
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

local function SetOption(setting, enabled)
    SimpleTweaksDB[setting] = enabled

    if setting == "disableMapFade" then
        UpdateMapFade(enabled)
    elseif setting == "hideMacroNames" then
        RefreshMacroNames()
    end

    Print((setting == "disableMapFade" and "Karten-Ausblenden" or "Makronamen") .. (enabled and (setting == "disableMapFade" and " deaktiviert." or " ausgeblendet.") or " wiederhergestellt."))
    if optionChecks[setting] then optionChecks[setting]:SetChecked(enabled) end
end

local function CreateOptionsWindow()
    if optionsWindow then return optionsWindow end

    local window = CreateFrame("Frame", "SimpleTweaksOptionsWindow", UIParent, "BackdropTemplate")
    optionsWindow = window
    window:SetSize(720, 520)
    window:SetPoint("CENTER")
    window:SetFrameStrata("DIALOG")
    window:SetClampedToScreen(true)
    window:SetMovable(true)
    window:EnableMouse(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", window.StartMoving)
    window:SetScript("OnDragStop", window.StopMovingOrSizing)
    window:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = false, edgeSize = 24, insets = { left = 8, right = 8, top = 8, bottom = 8 } })
    window:SetBackdropColor(0, 0, 0, 0.96)
    window:SetBackdropBorderColor(0.65, 0.38, 0.16, 1)

    local title = window:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -20)
    title:SetText("|cffffd27fSimpleTweaks|r")

    local close = CreateFrame("Button", nil, window, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -5, -5)
    close:SetScript("OnClick", function() window:Hide() end)

    local pages = {}
    local navButtons = {}
    local LoadCVars, RefreshGraphics
    local function NewPage(name)
        local page = CreateFrame("Frame", nil, window)
        page:SetPoint("TOPLEFT", 188, -66)
        page:SetPoint("BOTTOMRIGHT", -20, 20)
        page:Hide()
        pages[name] = page
        return page
    end
    local function ShowPage(name)
        for _, page in pairs(pages) do page:Hide() end
        pages[name]:Show()
        for buttonName, button in pairs(navButtons) do
            button:SetEnabled(buttonName ~= name)
        end
        if name == "cvars" and LoadCVars then LoadCVars() end
        if name == "graphics" and RefreshGraphics then RefreshGraphics() end
    end
    local sidebar = CreateFrame("Frame", nil, window, "BackdropTemplate")
    sidebar:SetPoint("TOPLEFT", 16, -62)
    sidebar:SetPoint("BOTTOMLEFT", 16, 18)
    sidebar:SetWidth(154)
    sidebar:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    sidebar:SetBackdropColor(0.035, 0.025, 0.018, 0.95)
    sidebar:SetBackdropBorderColor(0.52, 0.3, 0.12, 1)
    local sidebarTitle = sidebar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    sidebarTitle:SetPoint("TOPLEFT", 12, -12)
    sidebarTitle:SetText("|cffffd27fKategorien|r")
    local function SidebarButton(label, y, page)
        local button = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
        button:SetSize(138, 32)
        button:SetPoint("TOPLEFT", sidebar, 8, y)
        button:SetText(label)
        button:SetScript("OnClick", function() ShowPage(page) end)
        navButtons[page] = button
    end
    local mainPage = NewPage("main")
    local cvarPage = NewPage("cvars")
    local graphicsPage = NewPage("graphics")
    SidebarButton("Allgemein", -42, "main")
    SidebarButton("CVar-Browser", -82, "cvars")
    SidebarButton("Grafik", -122, "graphics")

    local function AddOption(key, label, y)
        local check = CreateFrame("CheckButton", nil, mainPage, "UICheckButtonTemplate")
        check:SetPoint("TOPLEFT", 28, y)
        check:SetChecked(IsEnabled(key))
        check.Text:SetText(label)
        check.Text:SetTextColor(0.9, 0.79, 0.61)
        check:SetScript("OnClick", function(self) SetOption(key, self:GetChecked()) end)
        optionChecks[key] = check
    end
    AddOption("disableMapFade", "Karte beim Bewegen nicht ausblenden", -68)
    AddOption("hideMacroNames", "Makronamen auf Aktionsleisten ausblenden", -112)

    local search = CreateFrame("EditBox", nil, cvarPage, "InputBoxTemplate")
    search:SetSize(300, 26); search:SetPoint("TOPLEFT", 8, -8); search:SetAutoFocus(false)
    search:SetTextInsets(6, 6, 0, 0)
    local results = CreateFrame("Frame", nil, cvarPage)
    results:SetPoint("TOPLEFT", search, "BOTTOMLEFT", 0, -10); results:SetSize(520, 330)
    local scroll = CreateFrame("ScrollFrame", nil, results, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT"); scroll:SetPoint("BOTTOMRIGHT", -26, 0)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(490, 1); scroll:SetScrollChild(content)
    local resultHint = results:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    resultHint:SetPoint("TOPLEFT", 4, -4)
    local function RefreshCVarSearch()
        for _, row in ipairs(cvarRows) do row:Hide() end
        local query = (search:GetText() or ""):lower()
        local y, shown = 0, 0
        for _, item in ipairs(cvarNames) do
            local name = item.name
            if query == "" or name:lower():find(query, 1, true) or (item.description and item.description:lower():find(query, 1, true)) then
                shown = shown + 1
                local row = cvarRows[shown]
                if not row then
                    row = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
                    row:SetSize(460, 24)
                    row.value = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                    row.value:SetPoint("RIGHT", -8, 0)
                    row.value:SetJustifyH("RIGHT")
                    cvarRows[shown] = row
                end
                row:SetPoint("TOPLEFT", 0, -y)
                row:SetText(name .. (item.isCVar and "  |cffb18a5a[CVar]|r" or ""))
                row.value:SetText(item.isCVar and tostring(GetCVar(name) or "") or "")
                row:SetEnabled(item.isCVar)
                row:SetScript("OnClick", function()
                    if not item.isCVar then return end
                    local cvarName = item.name
                    local current = tostring(GetCVar(cvarName) or "")
                    StaticPopup_Show("SIMPLETWEAKS_CVAR", cvarName, current, { name = cvarName, current = current })
                end)
                row:Show(); y = y + 27
            end
        end
        content:SetHeight(math.max(y, 1))
        resultHint:SetText(shown == 0 and (query == "" and "Keine CVars verfügbar." or "Keine Treffer.") or "")
    end
    search:SetScript("OnTextChanged", RefreshCVarSearch)
    StaticPopupDialogs.SIMPLETWEAKS_CVAR = {
        text = "Wert für %s eingeben (aktuell: %s)", button1 = ACCEPT, button2 = CANCEL,
        hasEditBox = true, whileDead = true, hideOnEscape = true,
        OnShow = function(self, data)
            local popupData = data or self.data
            self.data = popupData
            self.editBox:SetText(popupData and popupData.current or "")
            self.editBox:HighlightText()
        end,
        OnAccept = function(self)
            local data, value = self.data, self.editBox:GetText()
            if data and data.name and value ~= "" then
                local ok, err = SetCVarChecked(data.name, value)
                if not ok then Print("CVar " .. data.name .. ": " .. err) end
            end
            RefreshCVarSearch()
        end,
        EditBoxOnEnterPressed = function(self) self:GetParent().button1:Click() end,
    }
    LoadCVars = function()
        wipe(cvarNames)
        if C_Console and C_Console.GetAllCommands then
            for _, command in ipairs(C_Console.GetAllCommands()) do
                local name = command.command or command.name
                if type(name) == "string" and name ~= "" then
                    local value = GetCVar(name)
                    table.insert(cvarNames, {
                        name = name,
                        description = command.help or command.helpText or command.description or "",
                        isCVar = value ~= nil,
                    })
                end
            end
        end
        table.sort(cvarNames, function(a, b) return a.name:lower() < b.name:lower() end)
        RefreshCVarSearch()
    end

    local settings = {
        {"groundEffectDensity", "Grasdichte", 0, 256, 256},
        {"groundEffectDist", "Sichtweite für Gras", 0, 500, 500},
        {"graphicsGroundClutter", "Bodendetails", 0, 9, 9},
        {"graphicsViewDistance", "Sichtweite", 1, 9, 9},
        {"graphicsLightMode", "Sekundäre Beleuchtung", 0, 3, 3},
        {"sunshafts", "Sonnenstrahlen", 0, 2, 2},
        {"shadowNumCascades", "Detaillierte Fernschatten", 0, 4, 4},
    }
    for index, info in ipairs(settings) do
        local settingInfo = info
        local label = graphicsPage:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        label:SetPoint("TOPLEFT", 8, -8 - (index - 1) * 52); label:SetText(info[2])
        local current = graphicsPage:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        current:SetPoint("LEFT", label, "RIGHT", 10, 0)
        local slider = CreateFrame("Slider", nil, graphicsPage, "OptionsSliderTemplate")
        slider:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -4); slider:SetWidth(400)
        slider:SetMinMaxValues(settingInfo[3], settingInfo[4]); slider:SetValueStep(1); slider:SetObeyStepOnDrag(true)
        slider.Low:SetText(tostring(settingInfo[3])); slider.High:SetText(tostring(settingInfo[4]))
        local available = GetCVar(settingInfo[1]) ~= nil
        slider:SetEnabled(available)
        slider:SetScript("OnValueChanged", function(self, value)
            if graphicsRefreshing then return end
            local rounded = math.floor(value + 0.5)
            local ok, err = SetCVarChecked(settingInfo[1], tostring(rounded))
            if not ok then Print(settingInfo[1] .. ": " .. err); RefreshGraphics() end
            current:SetText(tostring(GetCVar(settingInfo[1]) or "Nicht verfügbar"))
        end)
        slider.cvarName, slider.minValue = settingInfo[1], settingInfo[3]
        slider.currentText, slider.label = current, label
        if not available then label:SetText(info[2] .. " (nicht verfügbar)") end
    end
    RefreshGraphics = function()
        graphicsRefreshing = true
        for _, child in ipairs({ graphicsPage:GetChildren() }) do
            if child.cvarName then
                local value = GetCVar(child.cvarName)
                local number = tonumber(value)
                child:SetEnabled(value ~= nil)
                child.currentText:SetText(value and ("Aktuell: " .. tostring(value)) or "Nicht verfügbar")
                if value then child:SetValue(number or child.minValue) end
                child.label:SetText(child.label:GetText():gsub(" %(nicht verfügbar%)$", ""))
                if not value then child.label:SetText(child.label:GetText() .. " (nicht verfügbar)") end
            end
        end
        graphicsRefreshing = false
    end
    ShowPage("main")
    return window
end

local function OpenOptions()
    CreateOptionsWindow():Show()
end

local function HandleSlashCommand(message)
    local feature, value = message:match("^(%S+)%s*(%S*)$")
    feature = feature and feature:lower()
    value = value and value:lower()

    if feature == "map" or feature == "mapfade" then
        if value == "on" or value == "off" then
            SetOption("disableMapFade", value == "on")
        else
            Print("Karte nicht ausblenden: " .. (IsEnabled("disableMapFade") and "an" or "aus") .. ". /tweaks karte an|aus")
        end
    elseif feature == "macros" or feature == "macro" then
        if value == "on" or value == "off" then
            SetOption("hideMacroNames", value == "on")
        else
            Print("Makronamen ausblenden: " .. (IsEnabled("hideMacroNames") and "an" or "aus") .. ". /tweaks makros an|aus")
        end
    elseif feature == "karte" or feature == "makros" or feature == "fenster" or feature == "optionen" then
        if feature == "karte" then
            if value == "an" or value == "aus" then SetOption("disableMapFade", value == "an") else Print("Verwendung: /tweaks karte an|aus") end
        elseif feature == "makros" then
            if value == "an" or value == "aus" then SetOption("hideMacroNames", value == "an") else Print("Verwendung: /tweaks makros an|aus") end
        else OpenOptions() end
    else
        OpenOptions()
    end
end

SLASH_SIMPLETWEAKS1 = "/tweaks"
SlashCmdList.SIMPLETWEAKS = HandleSlashCommand

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(_, event, loadedAddon)
    if event ~= "ADDON_LOADED" or loadedAddon ~= addonName then
        return
    end

    SimpleTweaksDB = SimpleTweaksDB or {}
    for key, value in pairs(DEFAULTS) do
        if SimpleTweaksDB[key] == nil then
            SimpleTweaksDB[key] = value
        end
    end

    if IsEnabled("disableMapFade") then
        UpdateMapFade(true)
    end

    RefreshMacroNames()
    if AddonCompartmentFrame and AddonCompartmentFrame.RegisterAddon then
        AddonCompartmentFrame:RegisterAddon({ text = "SimpleTweaks", icon = "Interface\\Icons\\INV_Misc_Gear_01", notCheckable = true, func = OpenOptions })
    end
    Print("Geladen. /tweaks öffnet die Einstellungen.")
    frame:UnregisterEvent("ADDON_LOADED")
end)
