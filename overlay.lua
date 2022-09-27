local myname, ns = ...

local LDD = LibStub("LibDropDown")
local LibDD = LibStub:GetLibrary("LibUIDropDownMenu-4.0")

local function hideTextureWithAtlas(atlas, ...)
    for i=1, select("#", ...) do
        local region = select(i, ...)
        if region:IsObjectType("Texture") and region:GetAtlas() == atlas then
            region:Hide()
        end
    end
end
local defaultSort = function(a, b) return a < b end
local function iterKeysByValue(tbl, sortFunction)
    local keys = {}
    for key in pairs(tbl) do
        table.insert(keys, key)
    end
    table.sort(keys, function(a, b)
        return (sortFunction or defaultSort)(tbl[a], tbl[b])
    end)
    return ipairs(keys)
end
local OptionsDropdown = {}
do
    local inherited = {"set", "get", "func", "confirm", "validate", "disabled", "hidden"}
    local function inherit(t1, t2)
        for _,k in ipairs(inherited) do
            if t2[k] ~= nil then
                t1[k] = t2[k]
            end
        end
    end
    local nodet = {}
    function OptionsDropdown.node(options, ...)
        wipe(nodet)
        local node = options
        inherit(nodet, node)
        for i=1, select('#', ...) do
            node = node.args[select(i, ...)]
            if not node then return end
            inherit(nodet, node)
        end
        return ns.merge(nodet, node)
    end
    local info = {}
    function OptionsDropdown.makeInfo(options, ...)
        local node = OptionsDropdown.node(options, ...)
        wipe(info)
        info.options = options
        info.option = node
        info.arg = node.arg
        info.type = node.type
        info.handler = node.handler
        info.uiType = "dropdown"
        info.uiName = "HandyNotesTreasures-Dropdown"
        info[0] = "" -- not a slashcommand
        for i=1, select('#', ...) do
            info[i] = select(i, ...)
        end
        return info
    end
    local function nodeValueOrFunc(key, options, ...)
        local node = OptionsDropdown.node(options, ...)
        if not node then return end
        if type(node[key]) == "function" then
            return node[key](OptionsDropdown.makeInfo(options, ...))
        end
        return node[key]
    end
    function OptionsDropdown.isHidden(options, ...)
        return nodeValueOrFunc('hidden', options, ...)
    end
    function OptionsDropdown.values(options, ...)
        return nodeValueOrFunc('values', options, ...)
    end
end
local zoneGroups, zoneHasGroups, zoneAchievements, zoneHasAchievements, allGroups, hasGroups
do
    local gcache
    function allGroups()
        if not gcache then
            gcache = {}
            for _, points in pairs(ns.points) do
                for _, point in pairs(points) do
                    if point.group then
                        gcache[point.group] = true
                    end
                end
            end
        end
        return gcache
    end
    function hasGroups()
        local groups = allGroups()
        for _ in pairs(groups) do
            return true
        end
    end
    local zcache = {}
    function zoneGroups(uiMapID)
        if not zcache[uiMapID] then
            local relevant = {}
            for _, point in pairs(ns.points[uiMapID] or {}) do
                if point.group then
                    relevant[point.group] = point.group
                end
            end
            zcache[uiMapID] = relevant
        end
        return zcache[uiMapID]
    end
    function zoneHasGroups(uiMapID)
        for _, _ in pairs(zoneGroups(uiMapID)) do
            return true
        end
    end
    local acache = {}
    function zoneAchievements(uiMapID)
        if not acache[uiMapID] then
            local relevant = {}
            for _, point in pairs(ns.points[uiMapID] or {}) do
                if point.achievement then
                    relevant[point.achievement] = true
                end
            end
            acache[uiMapID] = relevant
        end
        return acache[uiMapID]
    end
    function zoneHasAchievements(uiMapID)
        for _, _ in pairs(zoneAchievements(uiMapID)) do
            return true
        end
    end
end
function ns.SetupMapOverlay()
    local frame
    local Krowi = LibStub("Krowi_WorldMapButtons-1.3", true)
    if Krowi then
        frame = Krowi:Add("WorldMapTrackingOptionsButtonTemplate", "DROPDOWNTOGGLEBUTTON")
    elseif WorldMapFrame.AddOverlayFrame then
        frame = WorldMapFrame:AddOverlayFrame("WorldMapTrackingOptionsButtonTemplate", "DROPDOWNTOGGLEBUTTON", "TOPRIGHT", WorldMapFrame:GetCanvasContainer(), "TOPRIGHT", -68, -2)
    else
        -- classic!
        frame = CreateFrame("Button", nil, WorldMapFrame:GetCanvasContainer())
        frame:SetPoint("TOPRIGHT", -68, -2)
        frame:SetSize(31, 31)
        frame:RegisterForClicks("anyUp")
        frame:SetHighlightTexture(136477) --"Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight"
        local overlay = frame:CreateTexture(nil, "OVERLAY")
        overlay:SetSize(53, 53)
        overlay:SetTexture(136430) --"Interface\\Minimap\\MiniMap-TrackingBorder"
        overlay:SetPoint("TOPLEFT")
        frame.IconOverlay = overlay
        local background = frame:CreateTexture(nil, "BACKGROUND")
        background:SetSize(20, 20)
        background:SetTexture(136467) --"Interface\\Minimap\\UI-Minimap-Background"
        background:SetPoint("TOPLEFT", 7, -5)
        local icon = frame:CreateTexture(nil, "ARTWORK")
        icon:SetSize(17, 17)
        icon:SetPoint("TOPLEFT", 7, -6)
        frame.Icon = icon
        frame.isMouseDown = false
        hooksecurefunc(WorldMapFrame, "OnMapChanged", function()
            frame:Refresh()
        end)
    end
    frame.DropDown = LDD:NewMenu(frame, myname .. "OptionsDropdown")
    frame.DropDown:SetStyle("MENU")
    frame.DropDown:SetFrameStrata("DIALOG")
    frame.DropDown:SetScale(0.8)
    frame.Icon:SetAtlas("VignetteLootElite")
    frame.Icon:SetPoint("TOPLEFT", 6, -5)
    hideTextureWithAtlas("MapCornerShadow-Right", frame:GetRegions())
    frame.Refresh = function(self)
        local uiMapID = WorldMapFrame.mapID
        local info = C_Map.GetMapInfo(uiMapID)
        local parentMapID = info and info.parentMapID or 0
        if ns.db.worldmapoverlay and (ns.points[uiMapID] or ns.points[parentMapID]) then
            self:Show()
        else
            self:Hide()
        end
    end
    frame.OnMouseDown = function(self, button)
        self.Icon:SetPoint("TOPLEFT", 8, -8);
        self.IconOverlay:Show()

        local mapID = self:GetParent():GetMapID()
        if not mapID then
            return
        end

        ns.ShowOverlayMenu(self.DropDown, mapID)
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    end
    frame.OnMouseUp = function(self)
        self.Icon:SetPoint("TOPLEFT", 6, -5)
        self.IconOverlay:Hide()
    end
    frame:SetScript("OnMouseUp", frame.OnMouseUp)
    frame:SetScript("OnMouseDown", frame.OnMouseDown)
    frame.OnSelection = function(self, value, checked, arg1, arg2) end
end

local separator = {isSpacer = true}
local function lineCheck(line)
    local checked = not line:GetCheckedState()
    line:SetCheckedState(checked)
    if (checked) then
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    else
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
    end
    return checked
end

function ns.ShowOverlayMenu(dropdown, uiMapID)
    dropdown:ClearLines()
    local info = {}

    info.isTitle = true
    info.text = "HandyNotes - " .. myname:gsub("HandyNotes_", "")
    dropdown:AddLine(info)

    info.isTitle = nil
    info.keepShown = true
    info.func = function(line, _, key)
        local option = ns.options.args.display.args[key]
        if option.type == "execute" then
            option.func()
        else
            ns.db[key] = lineCheck(line)
        end
        ns.HL:Refresh()
    end

    local sorted = {}
    for key in pairs(ns.options.args.display.args) do
        table.insert(sorted, key)
    end
    table.sort(sorted, function(a, b)
        return (ns.options.args.display.args[a].order or 0) < (ns.options.args.display.args[b].order or 0)
    end)
    for _, key in ipairs(sorted) do
        local option = ns.options.args.display.args[key]
        info.text = option.name
        info.tooltipTitle = option.name
        info.tooltip = option.desc
        info.args = {key}
        if option.type == "toggle" then
            info.notCheckable = nil
            info.checked = ns.db[key]
        elseif option.type == "execute" then
            info.checked = nil
        end
        if option.disabled then
            info.disabled = option.disabled()
        else
            info.disabled = nil
        end
        dropdown:AddLine(info)
    end

    dropdown:AddLine(separator)

    if not (ns.hiddenConfig.groupsHiddenByZone and OptionsDropdown.isHidden(ns.options, "groupsHidden")) and zoneHasGroups(uiMapID) then
        local global = ns.hiddenConfig.groupsHiddenByZone
        wipe(info)
        info.keepShown = true
        info.func = function(line, _, group)
            if global then
                ns.db.groupsHidden[group] = not lineCheck(line)
            else
                ns.db.groupsHiddenByZone[uiMapID][group] = not lineCheck(line)
            end
            ns.HL:Refresh()
        end
        info.tooltip = global and "Hide this type of point everywhere" or "Hide this type of point on this map"
        for _, group in iterKeysByValue(zoneGroups(uiMapID)) do
            info.text = ns.render_string(ns.groups[group] or group)
            info.tooltipTitle = info.text
            info.args = {group}
            if global then
                info.checked = not ns.db.groupsHidden[group]
            else
                info.checked = not ns.db.groupsHiddenByZone[uiMapID][group]
            end
            dropdown:AddLine(info)
        end
    end
    if not OptionsDropdown.isHidden(ns.options, "achievementsHidden") and zoneHasAchievements(uiMapID) then
        wipe(info)
        info.keepShown = true
        info.func = function(line, _, achievementid)
            ns.db.achievementsHidden[achievementid] = not lineCheck(line)
            ns.HL:Refresh()
        end
        info.tooltip = "Hide this type of point"
        for achievementid in pairs(zoneAchievements(uiMapID)) do
            info.text = ns.render_string(("{achievement:%d}"):format(achievementid))
            info.tooltipTitle = info.text
            info.args = {achievementid}
            info.checked = not ns.db.achievementsHidden[achievementid]
            dropdown:AddLine(info)
        end
    end

    wipe(info)
    info.keepShown = true

    -- The submenus:
    -- (Also all negative-checked)
    local subfunc = function(line, _, key, section, subsection)
        -- print("subfunc", key, section, subsection)
        if subsection then
            ns.db[section][subsection][key] = not lineCheck(line)
        else
            ns.db[section][key] = not lineCheck(line)
        end
        ns.HL:Refresh()
    end

    local displayed = false
    if not OptionsDropdown.isHidden(ns.options, "achievementsHidden") then
        print("building achievements menu")
        info.text = ACHIEVEMENTS
        info.value = "achievementsHidden"
        info.menu = {}
        local relevant = zoneAchievements(uiMapID)
        local values = OptionsDropdown.values(ns.options, "achievementsHidden")
        for _, achievementid in iterKeysByValue(values) do
            local data = {}
            data.text = values[achievementid]
            data.keepShown = true
            data.func = subfunc
            data.args = {achievementid, "achievementsHidden"}
            data.checked = not ns.db.achievementsHidden[achievementid]
            if relevant[achievementid] then
                data.text = BRIGHTBLUE_FONT_COLOR:WrapTextInColorCode(data.text) .. " " .. CreateAtlasMarkup("VignetteKill", 0)
            end
            table.insert(info.menu, data)
        end
        dropdown:AddLine(info)
        displayed = true
    end

    if not OptionsDropdown.isHidden(ns.options, "zonesHidden") then
        info.text = ZONE
        info.value = "zonesHidden"
        info.menu = {}
        local values = OptionsDropdown.values(ns.options, "zonesHidden")
        for _, zuiMapID in iterKeysByValue(values) do
            local data = {}
            data.text = values[zuiMapID]
            data.keepShown = true
            data.func = subfunc
            data.args = {zuiMapID, "zonesHidden"}
            data.checked = not ns.db.zonesHidden[zuiMapID]
            if zuiMapID == uiMapID then
                data.text = BRIGHTBLUE_FONT_COLOR:WrapTextInColorCode(data.text) .. " " .. CreateAtlasMarkup("VignetteKill", 0)
            end
            if not ns.hiddenConfig.groupsHiddenByZone and zoneHasGroups(zuiMapID) then
                data.menu = {}
                local groups = zoneGroups(zuiMapID)
                for _, group in iterKeysByValue(groups) do
                    local data2 = {}
                    data2.text = ns.render_string(ns.groups[group] or group)
                    data2.keepShown = true
                    data2.func = subfunc
                    data2.args = {group, "groupsHiddenByZone", zuiMapID}
                    -- data2.tooltip = "Hide this type of point on this map"
                    data2.checked = not ns.db.groupsHiddenByZone[zuiMapID][group]
                    table.insert(data.menu, data2)
                end
            end
            table.insert(info.menu, data)
        end
        dropdown:AddLine(info)
        displayed = true
    end

    if not OptionsDropdown.isHidden(ns.options, "groupsHidden") and hasGroups() then
        info.text = GROUP
        info.value = "groupsHidden"
        info.menu = {}
        local groups = allGroups()
        for _, group in iterKeysByValue(groups) do
            local data = {}
            data.tooltip = "Hide this type of point everywhere"
            data.keepShown = true
            data.text = ns.render_string(ns.groups[group] or group)
            data.func = subfunc
            data.args = {group, "groupsHidden"}
            data.checked = not ns.db.groupsHidden[group]
            table.insert(info.menu, data)
        end
        dropdown:AddLine(info)
        displayed = true
    end
    wipe(info)

    if displayed then
        dropdown:AddLine(separator)
    end

    info.text = "Open HandyNotes options"
    info.keepShown = nil
    info.func = function(button)
        InterfaceOptionsFrame_Show()
        InterfaceOptionsFrame_OpenToCategory('HandyNotes')
        LibStub('AceConfigDialog-3.0'):SelectGroup('HandyNotes', 'plugins', myname:gsub("HandyNotes_", ""))
    end
    dropdown:AddLine(info)

    -- dropdown:SetAnchor('TOPLEFT', frame, 'BOTTOMLEFT', 10, -10)
    dropdown:Toggle()
end
