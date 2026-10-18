local myname, ns = ...

-- /<name>keys opens a window holding a translation template for this addon's
-- data strings, ready to copy into a new locale file. It is in release builds
-- too, so that translators do not need a development copy. The handler's own L
-- keys are not included.

local function collect()
    local keys, seen = {}, {}
    local function add(s, point)
        if type(s) == "function" then
            local ok, result = pcall(s, point)
            s = ok and result
        end
        if type(s) == "string" then
            local key = ns.translation_key(s)
            if key then keys[key] = true end
        end
    end
    -- notes turn up at any depth: on points, conditions and rewards
    local function walk(t, point, depth)
        if seen[t] or depth > 4 then return end
        seen[t] = true
        for k, v in pairs(t) do
            if k == "label" or k == "note" then
                add(v, point)
            elseif type(v) == "table" then
                walk(v, point, depth + 1)
            end
        end
    end
    for _, points in pairs(ns.points) do
        for _, point in pairs(points) do
            walk(point, point, 1)
        end
    end
    for _, group in pairs(ns.groups) do
        add(group)
    end

    local list = {}
    for key in pairs(keys) do
        table.insert(list, key)
    end
    table.sort(list)
    return list
end

local function literal(s)
    return (("%q"):format(s):gsub("\\\n", "\\n"))
end

-- On a client with translations, the template is for its locale and keeps what
-- is already translated. Otherwise it's blank, for a new locale.
local function template(keys)
    local locale = ns.translate and GetLocale() or "xxXX"
    local lines = {
        ('if GetLocale() ~= "%s" then return end'):format(locale),
        "local _, ns = ...",
        "",
        '-- Fill in the translations. Entries left as "" are ignored.',
        "-- Keep {name:id} markers as they are: the game replaces each one with a name or",
        "-- icon. They can move to wherever they fit the sentence.",
        "-- In {gc:colour:text}, translate only the text.",
        "-- Keep %s as it is. Use %2$s and %1$s to change the order.",
        ('ns.AddTranslations("%s", {'):format(locale),
    }
    for _, key in ipairs(keys) do
        local translation = ns.translate and ns.translate(key) or ""
        table.insert(lines, ("    [%s] = %s,"):format(literal(key), literal(translation)))
    end
    table.insert(lines, "})")
    return table.concat(lines, "\n")
end

local frame
local function show(text)
    if not frame then
        frame = CreateFrame("Frame", myname .. "KeysFrame", UIParent, "BasicFrameTemplateWithInset")
        frame:SetSize(560, 420)
        frame:SetPoint("CENTER")
        frame:SetFrameStrata("DIALOG")
        frame:SetMovable(true)
        frame:EnableMouse(true)
        frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart", frame.StartMoving)
        frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
        table.insert(UISpecialFrames, frame:GetName())

        local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOP", 0, -5)
        title:SetText(myname .. " translation keys")

        local scroll = CreateFrame("ScrollFrame", nil, frame, "InputScrollFrameTemplate")
        local INSET_LEFT, INSET_RIGHT = 10, 10
        scroll:SetPoint("TOPLEFT", INSET_LEFT, -28)
        scroll:SetPoint("BOTTOMRIGHT", -INSET_RIGHT, 10)
        -- the template sizes its edit box on load, before the anchors exist
        scroll.EditBox:SetWidth(frame:GetWidth() - (14 + INSET_LEFT + INSET_RIGHT))
        scroll.CharCount:Hide()
        frame.EditBox = scroll.EditBox
    end
    frame.EditBox:SetText(text)
    frame.EditBox:HighlightText()
    frame.EditBox:SetFocus()
    frame:Show()
end

local short = (myname:gsub("HandyNotes_", ""))
local slash = "HANDYNOTESKEYS" .. short:upper()
_G["SLASH_" .. slash .. "1"] = "/" .. short:lower() .. "keys"
SlashCmdList[slash] = function()
    show(template(collect()))
end
