-- Einstellungsfenster und /tweaks.
local ST = SimpleTweaks
local Print = ST.Print
local IsEnabled = ST.IsEnabled
local optionChecks = ST.optionChecks
local optionsWindow
local SWING_CIRCLE_SIZES = { 9, 12, 16, 20, 24, 32, 40, 48 }

local UpdateMapFade = ST.UpdateMapFade
local RefreshMacroNames = ST.RefreshMacroNames
local UpdateStanceBar = ST.UpdateStanceBar
local RefreshNpcNameOnly = ST.RefreshNpcNameOnly
local UpdateFpsCounter = ST.UpdateFpsCounter
local RefreshComboPoints = ST.RefreshComboPoints
local SetNameplateIndicatorEnabled = ST.SetNameplateIndicatorEnabled

local function SetOption(setting, enabled)
    SimpleTweaksDB[setting] = enabled

    if setting == "disableMapFade" then
        UpdateMapFade(enabled)
    elseif setting == "hideMacroNames" then
        RefreshMacroNames()
    elseif setting == "hideStanceBar" then
        UpdateStanceBar()
    elseif setting == "npcNameOnly" then
        RefreshNpcNameOnly()
    elseif setting == "showFps" then
        UpdateFpsCounter()
    elseif setting == "comboPoints" then
        RefreshComboPoints()
    elseif setting == "hunterRangeIndicator" then
        SetNameplateIndicatorEnabled(enabled)
    elseif setting == "farmHud" then
        ST.UpdateFarmHudButton()
    elseif setting == "farmHudRotate" or setting == "farmHudQuestBlobs" then
        ST.UpdateFarmHud()
    elseif setting == "swingTimer" and SimpleTweaksSwing and SimpleTweaksSwing.SetEnabled then
        SimpleTweaksSwing.SetEnabled(enabled)
    elseif setting == "fiveSec" and SimpleTweaksFiveSec and SimpleTweaksFiveSec.SetEnabled then
        SimpleTweaksFiveSec.SetEnabled(enabled)
    end
    local messages = {
        disableMapFade = enabled and "Karten-Ausblenden deaktiviert." or "Karten-Ausblenden wiederhergestellt.",
        hideMacroNames = enabled and "Makronamen ausgeblendet." or "Makronamen wiederhergestellt.",
        hideStanceBar = enabled and "Haltungsanzeige ausgeblendet." or "Haltungsanzeige wiederhergestellt.",
        npcNameOnly = enabled and "Freundliche NSCs zeigen nur den Namen." or "NSC-Namensplaketten wiederhergestellt.",
        showFps = enabled and "FPS-Anzeige aktiviert." or "FPS-Anzeige ausgeblendet.",
        comboPoints = enabled and "Combo-Punkte aktiviert." or "Combo-Punkte ausgeblendet.",
        hunterRangeIndicator = enabled and "Jäger-Reichweitenindikator aktiviert." or "Jäger-Reichweitenindikator deaktiviert.",
        farmHud = enabled and "FarmHUD-Button eingeblendet." or "FarmHUD-Button ausgeblendet.",
        farmHudRotate = enabled and "FarmHUD-Kartendrehung aktiviert." or "FarmHUD-Kartendrehung deaktiviert.",
        farmHudQuestBlobs = enabled and "Blaue Questbereiche im FarmHUD eingeblendet." or "Blaue Questbereiche im FarmHUD ausgeblendet.",
        swingTimer = enabled and "Schwungtimer aktiviert." or "Schwungtimer deaktiviert.",
        fiveSec = enabled and "5-Sekunden-Regel aktiviert." or "5-Sekunden-Regel ausgeblendet.",
    }
    Print(messages[setting] or "Einstellung geändert.")
    if optionChecks[setting] then optionChecks[setting]:SetChecked(enabled) end
end

local function CreateOptionsWindow()
    if optionsWindow then return optionsWindow end

    local window = CreateFrame("Frame", "SimpleTweaksOptionsWindow", UIParent, "BackdropTemplate")
    optionsWindow = window
    window:Hide()
    window:SetSize(680, 524)
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

    local function AddOption(key, label, y)
        local check = CreateFrame("CheckButton", nil, window, "UICheckButtonTemplate")
        check:SetPoint("TOPLEFT", 28, y)
        check:SetChecked(IsEnabled(key))
        check.Text:SetText(label)
        check.Text:SetTextColor(0.9, 0.79, 0.61)
        check:SetScript("OnClick", function(self) SetOption(key, self:GetChecked()) end)
        optionChecks[key] = check
    end

    AddOption("disableMapFade", "Karte beim Bewegen nicht ausblenden", -68)
    AddOption("hideMacroNames", "Makronamen auf Aktionsleisten ausblenden", -112)
    AddOption("hunterRangeIndicator", "Jäger Reichweitenindikator", -156)
    AddOption("hideStanceBar", "Haltungsanzeige ausblenden", -200)
    AddOption("npcNameOnly", "Bei freundlichen NSCs nur Namen anzeigen", -244)
    AddOption("showFps", "FPS-Anzeige unten rechts", -288)
    AddOption("comboPoints", "Combo-Punkte unter feindlichen Namensplaketten", -332)
    AddOption("swingTimer", "Schwungtimer", -376)
    AddOption("fiveSec", "5-Sekunden-Regel", -420)
    AddOption("farmHud", "FarmHUD", -464)

    local widgetParent = window

    local function MakeFontStep(labelText)
        local button = CreateFrame("Button", nil, widgetParent)
        button:SetSize(22, 22)
        local label = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetPoint("CENTER", 0, 1)
        label:SetText(labelText)
        label:SetTextColor(0.9, 0.79, 0.61)
        button:SetScript("OnEnter", function() label:SetTextColor(1, 0.93, 0.75) end)
        button:SetScript("OnLeave", function() label:SetTextColor(0.9, 0.79, 0.61) end)
        button:SetScript("OnMouseDown", function() label:SetPoint("CENTER", 1, 0) end)
        button:SetScript("OnMouseUp", function() label:SetPoint("CENTER", 0, 1) end)
        return button
    end

    local function PaintChoice(button, active)
        button.label:SetTextColor(active and 1 or 0.55, active and 0.86 or 0.48, active and 0.55 or 0.38)
        button.bg:SetColorTexture(0.65, 0.38, 0.16, active and 0.55 or 0)
    end

    local function MakeChoice(labelText, width)
        local button = CreateFrame("Button", nil, widgetParent)
        button:SetSize(width, 22)
        local bg = button:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        button.bg = bg
        local label = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetPoint("CENTER", 0, 1)
        label:SetText(labelText)
        button.label = label
        return button
    end

    local function OpenColor(getColor, applyColor)
        local r, g, b, a = getColor()
        if a == nil then
            a = 1
        end
        local function Apply(nr, ng, nb, na)
            if nr ~= nil then
                if na == nil then
                    na = a
                end
                applyColor(nr, ng, nb, na)
            end
        end
        local modernPicker = ColorPickerFrame and ColorPickerFrame.SetupColorPickerAndShow
        local function ReadAlpha()
            if ColorPickerFrame.GetColorAlpha then
                local ok, picked = pcall(ColorPickerFrame.GetColorAlpha, ColorPickerFrame)
                if ok and type(picked) == "number" then
                    return picked
                end
            end
            if type(ColorPickerFrame.opacity) == "number" then
                if modernPicker then
                    return ColorPickerFrame.opacity
                end
                return 1 - ColorPickerFrame.opacity
            end
            return a
        end
        local function ReadAndApply()
            local pickedR, pickedG, pickedB
            if ColorPickerFrame.GetColorRGB then
                local ok, pr, pg, pb = pcall(ColorPickerFrame.GetColorRGB, ColorPickerFrame)
                if ok then
                    pickedR, pickedG, pickedB = pr, pg, pb
                end
            end
            if not pickedR and ColorPickerFrame.GetColorRGB == nil then
                return
            end
            Apply(pickedR, pickedG, pickedB, ReadAlpha())
        end
        if ColorPickerFrame and ColorPickerFrame.SetupColorPickerAndShow then
            ColorPickerFrame:SetupColorPickerAndShow({
                r = r,
                g = g,
                b = b,
                opacity = a,
                a = a,
                hasOpacity = true,
                swatchFunc = ReadAndApply,
                opacityFunc = ReadAndApply,
                cancelFunc = function(previous)
                    if type(previous) == "table" then
                        Apply(previous.r ~= nil and previous.r or r, previous.g ~= nil and previous.g or g, previous.b ~= nil and previous.b or b, previous.a ~= nil and previous.a or a)
                    else
                        Apply(r, g, b, a)
                    end
                end,
            })
            return
        end
        if not ColorPickerFrame or not ColorPickerFrame.SetColorRGB then
            return
        end
        ColorPickerFrame.func = ReadAndApply
        ColorPickerFrame.opacityFunc = ReadAndApply
        ColorPickerFrame.hasOpacity = true
        ColorPickerFrame.opacity = 1 - a
        ColorPickerFrame.previousValues = { r = r, g = g, b = b, a = a }
        ColorPickerFrame.cancelFunc = function(previous)
            local previousR, previousG, previousB, previousA = r, g, b, a
            if type(previous) == "table" then
                previousR = previous.r ~= nil and previous.r or r
                previousG = previous.g ~= nil and previous.g or g
                previousB = previous.b ~= nil and previous.b or b
                previousA = previous.a ~= nil and previous.a or a
            end
            Apply(previousR, previousG, previousB, previousA)
        end
        ColorPickerFrame:SetColorRGB(r, g, b)
        ColorPickerFrame:Hide()
        ColorPickerFrame:Show()
    end

    local function MakeSwatch(tip, getColor, applyColor)
        local button = CreateFrame("Button", nil, widgetParent)
        button:SetSize(18, 18)
        local edge = button:CreateTexture(nil, "BACKGROUND")
        edge:SetAllPoints()
        edge:SetColorTexture(0.65, 0.38, 0.16, 1)
        local fill = button:CreateTexture(nil, "ARTWORK")
        fill:SetPoint("TOPLEFT", 2, -2)
        fill:SetPoint("BOTTOMRIGHT", -2, 2)
        local red, green, blue, alpha = getColor()
        if alpha == nil then
            alpha = 1
        end
        fill:SetColorTexture(red, green, blue, alpha)
        button:SetScript("OnClick", function()
            OpenColor(getColor, function(nr, ng, nb, na)
                if na == nil then
                    na = 1
                end
                fill:SetColorTexture(nr, ng, nb, na)
                applyColor(nr, ng, nb, na)
            end)
        end)
        button:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(tip, 1, 0.85, 0.55)
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", function() GameTooltip:Hide() end)
        return button
    end

    local function ClampColor(value, fallback)
        value = tonumber(value)
        if not value or value ~= value then
            return fallback
        end
        if value < 0 then
            return 0
        end
        if value > 1 then
            return 1
        end
        return value
    end

    local function BuildCircleSettings(parent, prefix, apiName)
        local mod = _G[apiName]
        local function DB(field)
            return SimpleTweaksDB and SimpleTweaksDB[prefix .. field]
        end
        local function SetField(field, value)
            if SimpleTweaksDB then
                SimpleTweaksDB[prefix .. field] = value
            end
        end
        widgetParent = parent
    local function CurrentCircleSize()
        local size = tonumber(DB("CircleSize")) or 9
        local best, bestDiff = SWING_CIRCLE_SIZES[1], math.huge
        for _, candidate in ipairs(SWING_CIRCLE_SIZES) do
            local diff = math.abs(candidate - size)
            if diff < bestDiff then
                best, bestDiff = candidate, diff
            end
        end
        return best
    end

    local function ApplyCircleSize(size)
        if mod and mod.SetCircleSize then
            mod.SetCircleSize(size)
        elseif SimpleTweaksDB then
            SetField("CircleSize", size)
        end
    end

    local groesseLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    groesseLabel:SetPoint("TOPLEFT", 16, -44)
    groesseLabel:SetText("Größe")
    groesseLabel:SetTextColor(0.75, 0.66, 0.5)
    local circleSmaller = MakeFontStep("-")
    local circleSizeText = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    circleSizeText:SetTextColor(0.9, 0.79, 0.61)
    circleSizeText:SetWidth(28)
    circleSizeText:SetJustifyH("CENTER")
    circleSizeText:SetText(tostring(CurrentCircleSize()))
    local circleLarger = MakeFontStep("+")
    circleSmaller:SetPoint("LEFT", groesseLabel, "RIGHT", 10, 0)
    circleSizeText:SetPoint("LEFT", circleSmaller, "RIGHT", 2, 0)
    circleLarger:SetPoint("LEFT", circleSizeText, "RIGHT", 2, 0)

    local PaintRahmen

    local function StepCircle(direction)
        local size = CurrentCircleSize()
        local index = 1
        for i, candidate in ipairs(SWING_CIRCLE_SIZES) do
            if candidate == size then
                index = i
                break
            end
        end
        index = index + direction
        if index < 1 then
            index = 1
        elseif index > #SWING_CIRCLE_SIZES then
            index = #SWING_CIRCLE_SIZES
        end
        local nextSize = SWING_CIRCLE_SIZES[index]
        circleSizeText:SetText(tostring(nextSize))
        ApplyCircleSize(nextSize)
        if PaintRahmen then
            PaintRahmen()
        end
    end
    circleSmaller:SetScript("OnClick", function() StepCircle(-1) end)
    circleLarger:SetScript("OnClick", function() StepCircle(1) end)

    local function CircleFillColor()
        return ClampColor(DB("CircleR"), 1), ClampColor(DB("CircleG"), 0.86), ClampColor(DB("CircleB"), 0.55), ClampColor(DB("CircleA"), 1)
    end

    local function CircleEdgeColor()
        return ClampColor(DB("BorderR"), 0), ClampColor(DB("BorderG"), 0), ClampColor(DB("BorderB"), 0), ClampColor(DB("BorderA"), 1)
    end

    local function CircleBackColor()
        return ClampColor(DB("BackR"), 0.02), ClampColor(DB("BackG"), 0.02), ClampColor(DB("BackB"), 0.02), ClampColor(DB("BackA"), 0.82)
    end

    local fillSwatch = MakeSwatch("Füllfarbe und Deckkraft", CircleFillColor, function(r, g, b, a)
        if mod and mod.SetCircleColor then
            mod.SetCircleColor(r, g, b, a)
        elseif SimpleTweaksDB then
            SetField("CircleR", r)
            SetField("CircleG", g)
            SetField("CircleB", b)
            SetField("CircleA", a)
        end
    end)
    local edgeSwatch = MakeSwatch("Randfarbe und Deckkraft", CircleEdgeColor, function(r, g, b, a)
        if mod and mod.SetBorderColor then
            mod.SetBorderColor(r, g, b, a)
        elseif SimpleTweaksDB then
            SetField("BorderR", r)
            SetField("BorderG", g)
            SetField("BorderB", b)
            SetField("BorderA", a)
        end
    end)
    local backSwatch = MakeSwatch("Hintergrund und Deckkraft", CircleBackColor, function(r, g, b, a)
        if mod and mod.SetBackColor then
            mod.SetBackColor(r, g, b, a)
        elseif SimpleTweaksDB then
            SetField("BackR", r)
            SetField("BackG", g)
            SetField("BackB", b)
            SetField("BackA", a)
        end
    end)
    fillSwatch:SetPoint("LEFT", circleLarger, "RIGHT", 12, 0)
    edgeSwatch:SetPoint("LEFT", fillSwatch, "RIGHT", 6, 0)
    backSwatch:SetPoint("LEFT", edgeSwatch, "RIGHT", 6, 0)

    local rahmenLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    rahmenLabel:SetPoint("LEFT", backSwatch, "RIGHT", 12, 0)
    rahmenLabel:SetText("Rahmen")
    rahmenLabel:SetTextColor(0.75, 0.66, 0.5)
    local rahmenLess = MakeFontStep("-")
    local rahmenText = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    rahmenText:SetTextColor(0.9, 0.79, 0.61)
    rahmenText:SetWidth(16)
    rahmenText:SetJustifyH("CENTER")
    local rahmenMore = MakeFontStep("+")
    rahmenLess:SetPoint("LEFT", rahmenLabel, "RIGHT", 6, 0)
    rahmenText:SetPoint("LEFT", rahmenLess, "RIGHT", 2, 0)
    rahmenMore:SetPoint("LEFT", rahmenText, "RIGHT", 2, 0)

    local function CurrentBorder()
        local value = tonumber(DB("BorderThickness"))
        if not value then
            local size = tonumber(DB("CircleSize")) or 9
            value = math.max(1, math.floor(size / 9 + 0.5))
        end
        if value < 1 then
            return 1
        end
        if value > 8 then
            return 8
        end
        return math.floor(value + 0.5)
    end

    function PaintRahmen()
        rahmenText:SetText(tostring(CurrentBorder()))
    end

    local function StepRahmen(direction)
        local value = CurrentBorder() + direction
        if value < 1 then
            value = 1
        elseif value > 8 then
            value = 8
        end
        if mod and mod.SetBorderThickness then
            mod.SetBorderThickness(value)
        elseif SimpleTweaksDB then
            SetField("BorderThickness", value)
        end
        PaintRahmen()
    end
    rahmenLess:SetScript("OnClick", function() StepRahmen(-1) end)
    rahmenMore:SetScript("OnClick", function() StepRahmen(1) end)
    PaintRahmen()

    local drainMode = MakeChoice("Abnehmend", 96)
    local fillMode = MakeChoice("Zunehmend", 96)
    drainMode:SetPoint("TOPLEFT", 16, -80)
    fillMode:SetPoint("LEFT", drainMode, "RIGHT", 4, 0)

    local function CurrentPie()
        if DB("Pie") == "fill" then
            return "fill"
        end
        return "drain"
    end

    local function PaintPie()
        local pie = CurrentPie()
        PaintChoice(drainMode, pie == "drain")
        PaintChoice(fillMode, pie == "fill")
    end

    local function SelectPie(direction)
        if mod and mod.SetPie then
            mod.SetPie(direction)
        elseif SimpleTweaksDB then
            SetField("Pie", direction)
        end
        PaintPie()
    end
    drainMode:SetScript("OnClick", function() SelectPie("drain") end)
    fillMode:SetScript("OnClick", function() SelectPie("fill") end)
    PaintPie()

    local spark = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    spark:SetPoint("LEFT", fillMode, "RIGHT", 10, 0)
    spark.Text:SetText("Funke")
    spark.Text:SetTextColor(0.9, 0.79, 0.61)
    spark:SetChecked(DB("Spark") and true or false)
    spark:SetScript("OnClick", function(self)
        local on = self:GetChecked() and true or false
        if mod and mod.SetSpark then
            mod.SetSpark(on)
        elseif SimpleTweaksDB then
            SetField("Spark", on)
        end
    end)

    local lineLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lineLabel:SetPoint("TOPLEFT", 16, -116)
    lineLabel:SetText("Linie")
    lineLabel:SetTextColor(0.75, 0.66, 0.5)
    local lineLess = MakeFontStep("-")
    local lineText = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    lineText:SetTextColor(0.9, 0.79, 0.61)
    lineText:SetWidth(44)
    lineText:SetJustifyH("CENTER")
    local lineMore = MakeFontStep("+")
    lineLess:SetPoint("LEFT", lineLabel, "RIGHT", 10, 0)
    lineText:SetPoint("LEFT", lineLess, "RIGHT", 2, 0)
    lineMore:SetPoint("LEFT", lineText, "RIGHT", 2, 0)

    local function CurrentLinePercent()
        local alpha = ClampColor(DB("LineA"), 1)
        return math.floor(alpha * 100 + 0.5)
    end

    local function PaintLinePercent()
        lineText:SetText(CurrentLinePercent() .. "%")
    end

    local function StepLine(direction)
        local percent = CurrentLinePercent() + direction * 5
        if percent < 0 then
            percent = 0
        elseif percent > 100 then
            percent = 100
        end
        local alpha = percent / 100
        if mod and mod.SetLineAlpha then
            mod.SetLineAlpha(alpha)
        elseif SimpleTweaksDB then
            SetField("LineA", alpha)
        end
        PaintLinePercent()
    end
    lineLess:SetScript("OnClick", function() StepLine(-1) end)
    lineMore:SetScript("OnClick", function() StepLine(1) end)
    PaintLinePercent()

    local thickLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    thickLabel:SetPoint("LEFT", lineMore, "RIGHT", 14, 0)
    thickLabel:SetText("Dicke")
    thickLabel:SetTextColor(0.75, 0.66, 0.5)
    local thickLess = MakeFontStep("-")
    local thickText = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    thickText:SetTextColor(0.9, 0.79, 0.61)
    thickText:SetWidth(16)
    thickText:SetJustifyH("CENTER")
    local thickMore = MakeFontStep("+")
    thickLess:SetPoint("LEFT", thickLabel, "RIGHT", 8, 0)
    thickText:SetPoint("LEFT", thickLess, "RIGHT", 2, 0)
    thickMore:SetPoint("LEFT", thickText, "RIGHT", 2, 0)

    local function CurrentThickness()
        local value = tonumber(DB("LineThickness")) or 1
        if value < 1 then
            return 1
        end
        if value > 8 then
            return 8
        end
        return math.floor(value + 0.5)
    end

    local function PaintThickness()
        thickText:SetText(tostring(CurrentThickness()))
    end

    local function StepThickness(direction)
        local value = CurrentThickness() + direction
        if value < 1 then
            value = 1
        elseif value > 8 then
            value = 8
        end
        if mod and mod.SetLineThickness then
            mod.SetLineThickness(value)
        elseif SimpleTweaksDB then
            SetField("LineThickness", value)
        end
        PaintThickness()
    end
    thickLess:SetScript("OnClick", function() StepThickness(-1) end)
    thickMore:SetScript("OnClick", function() StepThickness(1) end)
    PaintThickness()

    local previewBox = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    previewBox:SetSize(96, 96)
    previewBox:SetPoint("TOPRIGHT", -16, -36)
    previewBox:EnableMouse(false)
    previewBox:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    previewBox:SetBackdropColor(0.16, 0.15, 0.13, 1)
    previewBox:SetBackdropBorderColor(0.45, 0.32, 0.16, 0.65)
    local previewAnchor = CreateFrame("Frame", nil, previewBox)
    previewAnchor:SetAllPoints()
    previewAnchor:EnableMouse(false)
    local previewLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    previewLabel:SetPoint("BOTTOM", previewBox, "TOP", 0, 6)
    previewLabel:SetText("Vorschau")
    previewLabel:SetTextColor(0.9, 0.79, 0.61)

    parent:SetScript("OnShow", function()
        if mod and mod.SetPreview then
            mod.SetPreview(previewAnchor, true)
        end
    end)
    parent:SetScript("OnHide", function()
        if mod and mod.SetPreview then
            mod.SetPreview(nil, false)
        end
    end)
    end


    local function MakeSettingsPopup(title)
        local popup = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        popup:SetSize(700, 210)
        popup:SetPoint("CENTER")
        popup:SetFrameStrata("DIALOG")
        popup:SetFrameLevel(window:GetFrameLevel() + 20)
        popup:Hide()
        popup:SetMovable(true)
        popup:EnableMouse(true)
        popup:RegisterForDrag("LeftButton")
        popup:SetScript("OnDragStart", popup.StartMoving)
        popup:SetScript("OnDragStop", popup.StopMovingOrSizing)
        popup:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = false, edgeSize = 24, insets = { left = 8, right = 8, top = 8, bottom = 8 } })
        popup:SetBackdropColor(0.05, 0.05, 0.05, 0.98)
        popup:SetBackdropBorderColor(0.65, 0.38, 0.16, 1)
        local titleText = popup:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        titleText:SetPoint("TOP", 0, -16)
        titleText:SetText("|cffffd27f" .. title .. "|r")
        local close = CreateFrame("Button", nil, popup, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", -4, -4)
        close:SetScript("OnClick", function() popup:Hide() end)
        return popup
    end
    local function GearButton(y, popup)
        local button = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
        button:SetSize(118, 22)
        button:SetPoint("TOPLEFT", 430, y + 4)
        button:SetText("Einstellungen")
        button:SetScript("OnClick", function()
            if popup:IsShown() then
                popup:Hide()
            else
                popup:Show()
            end
        end)
    end
    local swingPopup = MakeSettingsPopup("Schwungtimer")
    BuildCircleSettings(swingPopup, "swingTimer", "SimpleTweaksSwing")
    local fivePopup = MakeSettingsPopup("5-Sekunden-Regel")
    BuildCircleSettings(fivePopup, "fiveSec", "SimpleTweaksFiveSec")
    local farmPopup = MakeSettingsPopup("FarmHUD")
    farmPopup:SetSize(322, 158)
    widgetParent = farmPopup
    local rotateCheck = CreateFrame("CheckButton", nil, farmPopup, "UICheckButtonTemplate")
    rotateCheck:SetPoint("TOPLEFT", 10, -43)
    rotateCheck:SetChecked(SimpleTweaksDB.farmHudRotate)
    rotateCheck.Text:SetText("Karte mit Blickrichtung drehen")
    rotateCheck.Text:SetTextColor(0.9, 0.79, 0.61)
    rotateCheck:SetScript("OnClick", function(self)
        SetOption("farmHudRotate", self:GetChecked())
    end)
    local questBlobsCheck = CreateFrame("CheckButton", nil, farmPopup, "UICheckButtonTemplate")
    questBlobsCheck:SetPoint("TOPLEFT", 10, -73)
    questBlobsCheck:SetChecked(SimpleTweaksDB.farmHudQuestBlobs)
    questBlobsCheck.Text:SetText("Blaue Questbereiche anzeigen")
    questBlobsCheck.Text:SetTextColor(0.9, 0.79, 0.61)
    questBlobsCheck:SetScript("OnClick", function(self)
        SetOption("farmHudQuestBlobs", self:GetChecked())
    end)
    local sizeLabel = farmPopup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    sizeLabel:SetPoint("TOPLEFT", 16, -118)
    sizeLabel:SetText("Größe")
    local farmSizes = { 320, 440, 560 }
    local farmChoices = {}
    local function PaintFarmSize()
        for index, button in ipairs(farmChoices) do
            PaintChoice(button, SimpleTweaksDB.farmHudSize == farmSizes[index])
        end
    end
    for index, label in ipairs({ "Klein", "Mittel", "Groß" }) do
        local size = farmSizes[index]
        local button = MakeChoice(label, 72)
        button:SetPoint("LEFT", sizeLabel, "RIGHT", 12 + (index - 1) * 76, 0)
        button:SetScript("OnClick", function()
            SimpleTweaksDB.farmHudSize = size
            ST.UpdateFarmHud()
            PaintFarmSize()
        end)
        farmChoices[index] = button
    end
    farmPopup:SetScript("OnShow", function()
        rotateCheck:SetChecked(SimpleTweaksDB.farmHudRotate)
        questBlobsCheck:SetChecked(SimpleTweaksDB.farmHudQuestBlobs)
        PaintFarmSize()
    end)
    GearButton(-376, swingPopup)
    GearButton(-420, fivePopup)
    GearButton(-464, farmPopup)

    return window
end

local function OpenOptions()
    local window = CreateOptionsWindow()
    window:Show()
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
    elseif feature == "swing" or feature == "timer" or feature == "schwung" then
        if value == "on" or value == "an" then
            SetOption("swingTimer", true)
        elseif value == "off" or value == "aus" then
            SetOption("swingTimer", false)
        else
            Print("Schwungtimer: " .. (IsEnabled("swingTimer") and "an" or "aus") .. ". /tweaks schwung an|aus")
        end
    elseif feature == "haltung" or feature == "stance" then
        if value == "on" or value == "an" then
            SetOption("hideStanceBar", true)
        elseif value == "off" or value == "aus" then
            SetOption("hideStanceBar", false)
        else
            Print("Haltungsanzeige ausblenden: " .. (IsEnabled("hideStanceBar") and "an" or "aus") .. ". /tweaks haltung an|aus")
        end
    elseif feature == "nsc" or feature == "npc" then
        if value == "on" or value == "an" then
            SetOption("npcNameOnly", true)
        elseif value == "off" or value == "aus" then
            SetOption("npcNameOnly", false)
        else
            Print("Freundliche NSCs nur als Name: " .. (IsEnabled("npcNameOnly") and "an" or "aus") .. ". /tweaks nsc an|aus")
        end
    elseif feature == "fps" then
        if value == "on" or value == "an" then
            SetOption("showFps", true)
        elseif value == "off" or value == "aus" then
            SetOption("showFps", false)
        else
            Print("FPS-Anzeige: " .. (IsEnabled("showFps") and "an" or "aus") .. ". /tweaks fps an|aus")
        end
    elseif feature == "combo" or feature == "punkte" then
        if value == "on" or value == "an" then
            SetOption("comboPoints", true)
        elseif value == "off" or value == "aus" then
            SetOption("comboPoints", false)
        else
            Print("Combo-Punkte: " .. (IsEnabled("comboPoints") and "an" or "aus") .. ". /tweaks combo an|aus")
        end
    elseif feature == "regel" or feature == "fsr" or feature == "fuenf" then
        if value == "on" or value == "an" then
            SetOption("fiveSec", true)
        elseif value == "off" or value == "aus" then
            SetOption("fiveSec", false)
        else
            Print("5-Sekunden-Regel: " .. (IsEnabled("fiveSec") and "an" or "aus") .. ". /tweaks regel an|aus")
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

ST.OpenOptions = OpenOptions
