local myname, ns = ...

-- Everything that goes into a point's tooltip. This is where the fiddly
-- retail-only handling lives -- secret values, and not re-anchoring a tooltip
-- that Blizzard is using for something else -- so it's worth keeping apart from
-- the pin drawing.

local render_string, render_string_list = ns.render_string, ns.render_string_list
local work_out_label = ns.work_out_label

local issecretframe = function(frame, aspect)
    if frame.IsAnchoringSecret then
        if aspect then
            return frame:HasSecretAspect(aspect)
        end
        return frame:IsAnchoringSecret()
    end
    return false
end

local get_point_progress = function(point)
    if type(point.progress) == "number" then
        -- shortcut: if the progress is an objective of the tracking quest
        return select(4, GetQuestObjectiveInfo(point.quest, point.progress, false))
    elseif type(point.progress) == "table" then
        for i, q in ipairs(point.progress) do
            if not C_QuestLog.IsQuestFlaggedCompleted(q) then
                return i - 1, #point.progress
            end
        end
        return #point.progress, #point.progress
    else
        -- function
        return point:progress()
    end
end

local function tooltip_criteria(tooltip, achievement, criteriaid, ignore_quantityString)
    local criteria, _, complete, _, _, completedBy, flags, _, quantityString = ns.GetCriteria(achievement, criteriaid) -- include hidden
    -- by this current character, or by any character if the setting says it's okay
    if completedBy and not complete then
        criteria = TEXT_MODE_A_STRING_VALUE_TYPE:format(criteria, GREEN_FONT_COLOR:WrapTextInColorCode(completedBy))
    end
    local r, g, b = (complete and GREEN_FONT_COLOR or RED_FONT_COLOR):GetRGB()
    if quantityString and not ignore_quantityString then
        local is_progressbar = bit.band(flags, EVALUATION_TREE_FLAG_PROGRESS_BAR) == EVALUATION_TREE_FLAG_PROGRESS_BAR
        local label = (criteria and #criteria > 0 and not is_progressbar) and criteria or PVP_PROGRESS_REWARDS_HEADER
        tooltip:AddDoubleLine(
            label, quantityString,
            r, g, b, r, g, b
        )
    else
        tooltip:AddDoubleLine(" ", criteria,
            nil, nil, nil,
            r, g, b, r, g, b
        )
    end
end
local function tooltip_achievement(tooltip, achievement, criteria)
    local _, name, _, anyComplete, _, _, _, _, _, _, _, _, completedByMe, earnedBy = GetAchievementInfo(achievement)
    local complete = completedByMe or (ns.db.alts_achievements_count and anyComplete)
    if anyComplete and not complete then
        name = TEXT_MODE_A_STRING_VALUE_TYPE:format(name, GREEN_FONT_COLOR:WrapTextInColorCode(earnedBy or ALT_KEY_TEXT))
    end
    tooltip:AddDoubleLine(BATTLE_PET_SOURCE_6, name or achievement,
        nil, nil, nil,
        (complete and GREEN_FONT_COLOR or RED_FONT_COLOR):GetRGB()
    )
    if criteria then
        if criteria == true then
            local numCriteria = GetAchievementNumCriteria(achievement, true) -- include hidden
            if numCriteria > 10 then
                local numComplete = 0
                for criteria=1, numCriteria do
                    if select(3, GetAchievementCriteriaInfo(achievement, criteria, true)) then
                        numComplete = numComplete + 1
                    end
                end
                tooltip:AddDoubleLine(" ", GENERIC_FRACTION_STRING:format(numComplete, numCriteria),
                    nil, nil, nil,
                    (complete and GREEN_FONT_COLOR or RED_FONT_COLOR):GetRGB()
                )
            else
                for criteria=1, numCriteria do
                    tooltip_criteria(tooltip, achievement, criteria, true)
                end
            end
        elseif type(criteria) == "table" then
            for _, criteria in ipairs(criteria) do
                tooltip_criteria(tooltip, achievement, criteria, true)
            end
        elseif type(criteria) == "number" then
            tooltip_criteria(tooltip, achievement, criteria, true)
        end
    elseif GetAchievementNumCriteria(achievement) == 1 then
        tooltip_criteria(tooltip, achievement, 1)
    end
end
local function tooltip_loot(tooltip, item, force)
    if (ns.db.tooltip_charloot and not IsShiftKeyDown() and not item:MightDrop()) and not force then
        return true
    end
    item:AddToTooltip(tooltip)
end

ns.tooltipHelpers = {
    loot = tooltip_loot,
    achievement = tooltip_achievement,
    criteria = tooltip_criteria,
}

local function handle_tooltip(tooltip, point, skip_label)
    if not point then
        tooltip:SetText(UNKNOWN)
        tooltip:Show()
        return
    end
    -- major:
    if not skip_label and point.label ~= false then
        GameTooltip_SetTitle(tooltip, work_out_label(point))
    end
    if point.OnTooltipShow then
        point:OnTooltipShow(tooltip)
    end
    if point.follower then
        local follower = C_Garrison.GetFollowerInfo(point.follower)
        if follower then
            local quality = BAG_ITEM_QUALITY_COLORS[follower.quality]
            tooltip:AddDoubleLine(REWARD_FOLLOWER, follower.name,
                0, 1, 0,
                quality.r, quality.g, quality.b
            )
            tooltip:AddDoubleLine(follower.className, UNIT_LEVEL_TEMPLATE:format(follower.level))
        end
    end
    if point.currency then
        local name
        if ns.currencies[point.currency] then
            name = ns.currencies[point.currency].name
        else
            local info = C_CurrencyInfo.GetCurrencyInfo(point.currency)
            name = info and info.name
        end
        tooltip:AddDoubleLine(CURRENCY, name or point.currency)
    end
    if point.achievement then
        tooltip_achievement(tooltip, point.achievement, point.criteria)
    end
    if point.progress then
        local fulfilled, required = get_point_progress(point)
        if fulfilled and required then
            tooltip:AddDoubleLine(PVP_PROGRESS_REWARDS_HEADER, GENERIC_FRACTION_STRING:format(fulfilled, required))
        end
    end
    if point.note then
        tooltip:AddLine(render_string(point.note, point), 1, 1, 1, true)
    end
    if point.loot then
        local hidden
        for _, item in ipairs(point.loot) do
            hidden = tooltip_loot(tooltip, item, point.showallloot) or hidden
        end
        if hidden then
            tooltip:AddLine("Items for other characters hidden", 0, 1, 1)
        end
    end
    if ns.db.tooltip_sharedloot and point.loot_shared and #point.loot_shared > 0 then
        -- This is loot flagged as being from a shared pool
        tooltip:AddLine("Shared Loot", 1, 1, 1, false)
        for _, item in ipairs(point.loot_shared) do
            tooltip_loot(tooltip, item, true)
        end
    end
    if point.hide_before then
        local summary = ns.conditions.summarize(point.hide_before)
        local isHidden = not ns.conditions.check(point.hide_before)
        if isHidden then
            tooltip:AddLine(COMMUNITY_TYPE_UNAVAILABLE, RED_FONT_COLOR:GetRGB())
        end
        if summary then
            local r, g, b = (isHidden and RED_FONT_COLOR or GREEN_FONT_COLOR):GetRGB()
            tooltip:AddLine(ns.render_string(summary, point), r, g, b, true)
        end
    end
    if point.requires then
        local summary = ns.conditions.summarize(point.requires)
        local isHidden = not ns.conditions.check(point.requires)
        if isHidden then
            tooltip:AddLine(COMMUNITY_TYPE_UNAVAILABLE, RED_FONT_COLOR:GetRGB())
        end
        if summary then
            local r, g, b = (isHidden and RED_FONT_COLOR or GREEN_FONT_COLOR):GetRGB()
            tooltip:AddLine(ns.render_string(summary, point), r, g, b, true)
        end
    end
    if point.active then
        local summary = point.active.note or ns.conditions.summarize(point.active)
        if summary then
            local isActive = ns.point_active(point)
            local r, g, b = (isActive and GREEN_FONT_COLOR or RED_FONT_COLOR):GetRGB()
            tooltip:AddLine(ns.render_string(summary, point), r, g, b, true)
        end
    end

    if point.group then
        tooltip:AddDoubleLine(GROUP, (render_string(ns.groups[point.group] or point.group, point)))
    end

    if point.quest then
        local isComplete = ns.allQuestsComplete(point.quest, point.accountquest)
        local r, g, b = (isComplete and GREEN_FONT_COLOR or RED_FONT_COLOR):GetRGB()
        tooltip:AddDoubleLine(
            QUESTS_LABEL,
            isComplete and GOAL_COMPLETED or INCOMPLETE,
            1, 1, 1, r, g, b, true
        )
        if ns.db.tooltip_questid then
            tooltip:AddDoubleLine("QuestID", render_string_list(point, "questid", point.quest), NORMAL_FONT_COLOR:GetRGB())
        end
    end

    if ns.DEBUG then
        tooltip:AddDoubleLine("Coord", point._coord)
    end

    if (ns.db.tooltip_item or IsShiftKeyDown()) and (point.loot or point.npc or point.spell) and not issecretframe(tooltip) then
        local comparison = _G[myname.."ComparisonTooltip"]
        if not comparison then
            comparison = CreateFrame("GameTooltip", myname.."ComparisonTooltip", UIParent, "ShoppingTooltipTemplate")
            if _G.GameTooltipDataMixin then Mixin(comparison, GameTooltipDataMixin) end
            comparison:SetFrameStrata("TOOLTIP")
            comparison:SetClampedToScreen(true)
        end

        -- What follows is a trimmed GameTooltip_AnchorComparisonTooltips, which
        -- classic still uses; retail does the same arithmetic in
        -- TooltipComparisonManager:AnchorShoppingTooltips.
        do
            local side
            local leftPos = tooltip:GetLeft() or 0
            local rightPos = tooltip:GetRight() or 0
            local rightDist = GetScreenWidth() - rightPos

            if (leftPos and (rightDist < leftPos)) then
                side = "left"
            else
                side = "right"
            end

            -- Sliding re-anchors the tooltip, which re-lays out its children --
            -- including the widget container, whose Layout() compares its own
            -- anchor count, and that reads secret. Blizzard can make that
            -- comparison; ours carries addon taint into it, and the error only
            -- surfaces later when they tear the widget set down. So leave a
            -- tooltip that's carrying widgets where it is.
            local hasWidgets = tooltip.widgetContainer and tooltip.widgetContainer.widgetSetID
            if not hasWidgets and tooltip:GetAnchorType() and tooltip:GetAnchorType() ~= "ANCHOR_PRESERVE" then
                local totalWidth = 0
                -- TODO: reserve the comparison's width here. Blizzard is handed
                -- primaryItemShown by ShoppingTooltip1:SetCompareItem; ours is
                -- always shown, so what's missing is the width, and it isn't
                -- known yet because the thing isn't filled in until below.
                -- Classic populates, anchors, then populates again because
                -- SetOwner cleared it; retail shows before measuring. Either way
                -- the measuring wants AppearanceTooltip's guards: IsRectValid
                -- before touching geometry, issecretvalue on GetLeft/GetRight/
                -- GetWidth rather than trusting `or 0`.
                if ( primaryItemShown  ) then
                    totalWidth = totalWidth + comparison:GetWidth()
                end

                if ( (side == "left") and (totalWidth > leftPos) ) then
                    tooltip:SetAnchorType(tooltip:GetAnchorType(), (totalWidth - leftPos), 0)
                elseif ( (side == "right") and (rightPos + totalWidth) >  GetScreenWidth() ) then
                    tooltip:SetAnchorType(tooltip:GetAnchorType(), -((rightPos + totalWidth) - GetScreenWidth()), 0)
                end
            end

            comparison:ClearAllPoints()
            comparison:SetOwner(tooltip, "ANCHOR_NONE")

            if ( side and side == "left" ) then
                comparison:SetPoint("TOPRIGHT", tooltip, "TOPLEFT", 0, -10)
            else
                comparison:SetPoint("TOPLEFT", tooltip, "TOPRIGHT", 0, -10)
            end
        end

        if point.loot and #point.loot > 0 then
            point.loot[1]:SetTooltip(comparison)
        elseif point.npc then
            comparison:SetHyperlink(("unit:Creature-0-0-0-0-%d"):format(point.npc))
        elseif point.spell then
            comparison:SetSpellByID(point.spell)
        end
        comparison:Show()
    end

    tooltip:Show()
end
local handle_tooltip_by_coord = function(tooltip, uiMapID, coord)
    return handle_tooltip(tooltip, ns.points[uiMapID] and ns.points[uiMapID][coord])
end

ns.handle_tooltip_by_coord = handle_tooltip_by_coord

---------------------------------------------------------
-- Blizzard's own map pins: if one of them is a point we know about, our
-- tooltip goes on the end of theirs.

do
    -- This is a "only do this update once a tick" gate
    local already
    local gateFrame = CreateFrame("Frame")
    gateFrame:SetScript("OnShow", function() already = true end)
    gateFrame:SetScript("OnHide", function() already = false end)
    gateFrame:SetScript("OnUpdate", function(self) self:Hide() end)

    local handleWorldMapPin = function(pin)
        if not pin then return end
        if already then return end
        gateFrame:Show()
        local point
        if pin.vignetteID then
            point = ns.VignetteIDsToPoints[pin.vignetteID]
        elseif pin.worldQuest and pin.questID then
            point = ns.WorldQuestsToPoints[pin.questID]
        elseif pin.poiInfo and pin.poiInfo.areaPoiID then
            point = ns.POIsToPoints[pin.poiInfo.areaPoiID]
        end
        if point then
            handle_tooltip(GameTooltip, point, true)
        end
    end
    local hideComparison = function()
        -- 10.0.2 doesn't hide this by default any more
        if _G[myname.."ComparisonTooltip"] then _G[myname.."ComparisonTooltip"]:Hide() end
        gateFrame:Hide()
    end

    hooksecurefunc(AreaPOIPinMixin, "TryShowTooltip", handleWorldMapPin)
    hooksecurefunc(AreaPOIPinMixin, "OnMouseLeave", hideComparison)
    hooksecurefunc(VignettePinBaseMixin or VignettePinMixin, "OnMouseEnter", handleWorldMapPin)
    hooksecurefunc(VignettePinBaseMixin or VignettePinMixin, "OnMouseLeave", hideComparison)
    if _G.TaskPOI_OnEnter then
        hooksecurefunc("TaskPOI_OnEnter", handleWorldMapPin)
        hooksecurefunc("TaskPOI_OnLeave", function(self) hideComparison() end)
    end
    EventRegistry:RegisterCallback("MapLegendPinOnEnter", function(self, pin)
        -- This wants to catch pins like the vignettes on the Dragon Isles,
        -- which appear for events but which aren't a VignettePinMixin.
        -- Regular VignettePinMixin will also trigger this, depending on
        -- client branch, but the gate frame will avoid issues.
        handleWorldMapPin(pin)
    end)
    EventRegistry:RegisterCallback("MapLegendPinOnLeave", hideComparison)
end
