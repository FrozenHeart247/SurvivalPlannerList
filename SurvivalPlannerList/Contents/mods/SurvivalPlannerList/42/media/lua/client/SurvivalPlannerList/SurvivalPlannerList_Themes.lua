SPLThemes = SPLThemes or {}

SPLThemes.MODDATA_KEY = "SurvivalPlannerListTheme"
SPLThemes.ORDER = {
    "notebook",
    "red",
    "green",
    "yellow",
    "purple",
    "neutral",
}
SPLThemes.selectedByPlayer = SPLThemes.selectedByPlayer or {}

local function color(r, g, b, a)
    return { r = r, g = g, b = b, a = a or 1 }
end

function SPLThemes.copyColor(source, alpha)
    if not source then
        return color(1, 1, 1, alpha or 1)
    end
    return color(source.r, source.g, source.b, alpha or source.a or 1)
end

local function applyButtonState(button)
    local style = button and button.splThemeStyle or nil
    if not style then
        return
    end

    local enabled = button.enable ~= false
    button.backgroundColor = SPLThemes.copyColor(
        style.background,
        enabled and style.background.a or math.min(style.background.a or 1, 0.58)
    )
    button.backgroundColorMouseOver = SPLThemes.copyColor(style.hover)
    button.borderColor = SPLThemes.copyColor(
        style.border,
        enabled and style.border.a or math.min(style.border.a or 1, 0.48)
    )
    button.textColor = SPLThemes.copyColor(enabled and style.text or style.disabledText)
    button.backgroundColorPressed = nil
end

function SPLThemes.styleButton(button, background, hover, border, text, disabledText)
    if not button then
        return
    end

    button.splThemeStyle = {
        background = SPLThemes.copyColor(background),
        hover = SPLThemes.copyColor(hover),
        border = SPLThemes.copyColor(border),
        text = SPLThemes.copyColor(text),
        disabledText = SPLThemes.copyColor(disabledText or text, 0.60),
    }

    -- ISButton:setEnable() restores these cached values. Keep them synchronized
    -- for compatibility with any vanilla code that touches the button later.
    button.backgroundColorEnabled = SPLThemes.copyColor(background)
    button.borderColorEnabled = SPLThemes.copyColor(border)
    applyButtonState(button)
end

function SPLThemes.setButtonEnabled(button, enabled)
    if not button then
        return
    end

    -- Build 42's ISButton:setEnable() paints disabled buttons black/red and
    -- restores a one-time color cache. Set the interaction state directly and
    -- let the theme own every visual state instead.
    button.enable = enabled == true
    if button.setTextureRGBA then
        local tint = button.enable and 1 or 0.48
        button:setTextureRGBA(tint, tint, tint, 1)
    end
    applyButtonState(button)
end

local function darkTheme(id, nameKey, fallbackName, panel, header, card, cardHover, selected, accent, accentHover)
    return {
        id = id,
        nameKey = nameKey,
        fallbackName = fallbackName,

        panel = panel,
        panelBorder = color(accent.r * 0.82, accent.g * 0.82, accent.b * 0.82, 1),
        header = header,
        headerBorder = color(accent.r * 0.72, accent.g * 0.72, accent.b * 0.72, 1),
        list = color(panel.r * 0.72, panel.g * 0.72, panel.b * 0.72, 0.98),
        listBorder = color(accent.r * 0.48, accent.g * 0.48, accent.b * 0.48, 1),

        card = card,
        cardHover = cardHover,
        cardSelected = selected,
        cardBorder = color(0.29, 0.28, 0.25, 1),
        cardHoverBorder = color(accent.r * 0.72, accent.g * 0.72, accent.b * 0.72, 1),
        cardSelectedBorder = accent,

        text = color(0.93, 0.90, 0.79, 1),
        mutedText = color(0.67, 0.65, 0.56, 1),
        subtleText = color(0.50, 0.49, 0.43, 1),
        accent = accent,
        accentHover = accentHover,
        success = color(0.48, 0.68, 0.36, 1),
        planned = color(0.74, 0.58, 0.31, 1),
        done = color(0.52, 0.54, 0.49, 1),
        divider = color(0.29, 0.28, 0.24, 0.92),

        button = color(card.r * 1.08, card.g * 1.08, card.b * 1.08, 1),
        buttonHover = color(cardHover.r * 1.18, cardHover.g * 1.18, cardHover.b * 1.18, 1),
        buttonBorder = color(0.58, 0.56, 0.49, 1),
        buttonText = color(0.96, 0.94, 0.86, 1),
        input = color(panel.r * 0.55, panel.g * 0.55, panel.b * 0.55, 1),
        inputBorder = color(accent.r * 0.72, accent.g * 0.72, accent.b * 0.72, 1),
        tab = color(header.r * 0.92, header.g * 0.92, header.b * 0.92, 1),
        tabHover = cardHover,
        tabBorder = color(0.34, 0.32, 0.27, 1),
        tabActive = color(
            card.r + (accent.r - card.r) * 0.46,
            card.g + (accent.g - card.g) * 0.46,
            card.b + (accent.b - card.b) * 0.46,
            1
        ),
        tabActiveBorder = accent,
        tabActiveText = color(0.98, 0.96, 0.88, 1),

        statusEditable = color(0.48, 0.68, 0.36, 1),
        statusReadonly = color(0.78, 0.52, 0.25, 1),
        danger = color(0.42, 0.035, 0.025, 1),
        dangerHover = color(0.62, 0.06, 0.04, 1),
        dangerBorder = color(0.90, 0.08, 0.04, 1),
        dangerText = color(0.98, 0.90, 0.84, 1),

        dialog = color(card.r * 1.03, card.g * 1.03, card.b * 1.03, 1),
        dialogBorder = accent,
        overlay = color(0, 0, 0, 0.56),
    }
end

SPLThemes.DEFINITIONS = {
    notebook = {
        id = "notebook",
        nameKey = "IGUI_SPL_Theme_Notebook",
        fallbackName = "Notebook",

        panel = color(0.82, 0.85, 0.85, 0.98),
        panelBorder = color(0.18, 0.34, 0.48, 1),
        header = color(0.72, 0.79, 0.83, 1),
        headerBorder = color(0.20, 0.40, 0.57, 1),
        list = color(0.67, 0.72, 0.74, 0.98),
        listBorder = color(0.25, 0.38, 0.47, 1),

        card = color(0.92, 0.92, 0.87, 1),
        cardHover = color(0.84, 0.88, 0.88, 1),
        cardSelected = color(0.72, 0.82, 0.87, 1),
        cardBorder = color(0.43, 0.48, 0.49, 1),
        cardHoverBorder = color(0.29, 0.45, 0.53, 1),
        cardSelectedBorder = color(0.16, 0.42, 0.62, 1),

        text = color(0.09, 0.13, 0.17, 1),
        mutedText = color(0.30, 0.35, 0.36, 1),
        subtleText = color(0.40, 0.43, 0.40, 1),
        accent = color(0.16, 0.42, 0.63, 1),
        accentHover = color(0.23, 0.53, 0.73, 1),
        success = color(0.19, 0.46, 0.27, 1),
        planned = color(0.66, 0.45, 0.13, 1),
        done = color(0.41, 0.45, 0.44, 1),
        divider = color(0.38, 0.43, 0.42, 0.78),

        button = color(0.69, 0.76, 0.79, 1),
        buttonHover = color(0.60, 0.69, 0.73, 1),
        buttonBorder = color(0.30, 0.42, 0.49, 1),
        buttonText = color(0.08, 0.12, 0.16, 1),
        input = color(0.94, 0.95, 0.93, 1),
        inputBorder = color(0.18, 0.42, 0.60, 1),
        tab = color(0.72, 0.78, 0.79, 1),
        tabHover = color(0.64, 0.70, 0.70, 1),
        tabBorder = color(0.34, 0.40, 0.41, 1),
        tabActive = color(0.27, 0.48, 0.64, 1),
        tabActiveBorder = color(0.12, 0.33, 0.51, 1),
        tabActiveText = color(0.97, 0.95, 0.86, 1),

        statusEditable = color(0.18, 0.44, 0.25, 1),
        statusReadonly = color(0.65, 0.37, 0.10, 1),
        danger = color(0.54, 0.10, 0.07, 1),
        dangerHover = color(0.72, 0.16, 0.10, 1),
        dangerBorder = color(0.38, 0.05, 0.035, 1),
        dangerText = color(0.98, 0.93, 0.86, 1),

        dialog = color(0.92, 0.92, 0.87, 1),
        dialogBorder = color(0.16, 0.42, 0.63, 1),
        overlay = color(0, 0, 0, 0.54),
    },
}

SPLThemes.DEFINITIONS.red = darkTheme(
    "red", "IGUI_SPL_Theme_Red", "Red",
    color(0.13, 0.085, 0.075, 0.98),
    color(0.17, 0.105, 0.09, 1),
    color(0.16, 0.10, 0.085, 1),
    color(0.21, 0.12, 0.10, 1),
    color(0.26, 0.13, 0.105, 1),
    color(0.67, 0.18, 0.13, 1),
    color(0.82, 0.27, 0.19, 1)
)

SPLThemes.DEFINITIONS.green = darkTheme(
    "green", "IGUI_SPL_Theme_Green", "Green",
    color(0.09, 0.105, 0.075, 0.98),
    color(0.12, 0.135, 0.09, 1),
    color(0.115, 0.13, 0.085, 1),
    color(0.15, 0.18, 0.105, 1),
    color(0.19, 0.25, 0.13, 1),
    color(0.39, 0.59, 0.27, 1),
    color(0.50, 0.72, 0.35, 1)
)

SPLThemes.DEFINITIONS.yellow = darkTheme(
    "yellow", "IGUI_SPL_Theme_Yellow", "Yellow",
    color(0.13, 0.115, 0.065, 0.98),
    color(0.17, 0.145, 0.075, 1),
    color(0.16, 0.135, 0.075, 1),
    color(0.21, 0.175, 0.085, 1),
    color(0.27, 0.215, 0.10, 1),
    color(0.72, 0.55, 0.15, 1),
    color(0.86, 0.69, 0.23, 1)
)

SPLThemes.DEFINITIONS.purple = darkTheme(
    "purple", "IGUI_SPL_Theme_Purple", "Purple",
    color(0.105, 0.085, 0.13, 0.98),
    color(0.14, 0.105, 0.17, 1),
    color(0.135, 0.10, 0.16, 1),
    color(0.18, 0.125, 0.21, 1),
    color(0.23, 0.15, 0.29, 1),
    color(0.53, 0.33, 0.68, 1),
    color(0.67, 0.44, 0.82, 1)
)

SPLThemes.DEFINITIONS.neutral = darkTheme(
    "neutral", "IGUI_SPL_Theme_Neutral", "Neutral",
    color(0.095, 0.10, 0.105, 0.98),
    color(0.125, 0.13, 0.135, 1),
    color(0.13, 0.135, 0.14, 1),
    color(0.17, 0.18, 0.185, 1),
    color(0.21, 0.23, 0.24, 1),
    color(0.43, 0.51, 0.56, 1),
    color(0.55, 0.64, 0.70, 1)
)

function SPLThemes.getDefinition(themeId)
    return SPLThemes.DEFINITIONS[themeId] or SPLThemes.DEFINITIONS.notebook
end

function SPLThemes.getName(theme)
    local definition = type(theme) == "table" and theme or SPLThemes.getDefinition(theme)
    local translated = getText and getText(definition.nameKey) or nil
    if not translated or translated == definition.nameKey then
        return definition.fallbackName
    end
    return translated
end

function SPLThemes.getSelectedId(playerNum)
    local index = playerNum or 0
    local runtimeId = SPLThemes.selectedByPlayer[index]
    if SPLThemes.DEFINITIONS[runtimeId] then
        return runtimeId
    end

    local player = getSpecificPlayer and getSpecificPlayer(index) or nil
    local savedId = player and player:getModData()[SPLThemes.MODDATA_KEY] or nil
    if not SPLThemes.DEFINITIONS[savedId] then
        savedId = "notebook"
    end

    SPLThemes.selectedByPlayer[index] = savedId
    return savedId
end

function SPLThemes.get(playerNum)
    return SPLThemes.getDefinition(SPLThemes.getSelectedId(playerNum))
end

function SPLThemes.set(playerNum, themeId)
    local index = playerNum or 0
    if not SPLThemes.DEFINITIONS[themeId] then
        themeId = "notebook"
    end

    SPLThemes.selectedByPlayer[index] = themeId
    local player = getSpecificPlayer and getSpecificPlayer(index) or nil
    if player then
        player:getModData()[SPLThemes.MODDATA_KEY] = themeId
    end
    return SPLThemes.DEFINITIONS[themeId]
end
