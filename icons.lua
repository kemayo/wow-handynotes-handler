local myname, ns = ...

-- Working out which icon a point gets. Everything here hands back a table in
-- the shape HandyNotes wants -- an icon plus tex-coords, optionally r/g/b/a and
-- scale -- and those tables are shared between every point that asks for the
-- same one, so nothing may modify one after it has been handed out.

local npc_texture, follower_texture, currency_texture, junk_texture, notable_npc_texture, lessnotable_npc_texture
local trimmed_cache = {}
local atlas_cache = {}
local trimmed_icon = function(texture)
    if not trimmed_cache[texture] then
        trimmed_cache[texture] = {
            icon = texture,
            tCoordLeft = 0.1,
            tCoordRight = 0.9,
            tCoordTop = 0.1,
            tCoordBottom = 0.9,
        }
    end
    return trimmed_cache[texture]
end
local atlas_texture = function(atlas, extra, left, right, top, bottom)
    local atlasInfo = C_Texture.GetAtlasInfo(atlas)
    if not atlasInfo then
        if ns.DEBUG then
            if not ns.DEBUG_missing_atlas_cache then ns.DEBUG_missing_atlas_cache = {} end
            if not ns.DEBUG_missing_atlas_cache[atlas] then
                print(("%s: missing atlas %s"):format(myname, atlas))
                ns.DEBUG_missing_atlas_cache[atlas] = true
            end
        end
        atlasInfo = C_Texture.GetAtlasInfo("QuestObjective") or C_Texture.GetAtlasInfo("VignetteLoot")
    end
    if type(extra) == "number" then
        extra = {scale=extra}
    end
    if left and not right then
        -- this is the "trim every side by this" path
        right = 1 - left
        top = left
        bottom = 1 - left
    end
    if left then
        -- An atlas is already cropped into a texture, so we need to treat something else as our 1
        local horizontal = atlasInfo.rightTexCoord - atlasInfo.leftTexCoord
        local vertical = atlasInfo.bottomTexCoord - atlasInfo.topTexCoord
        atlasInfo.rightTexCoord = atlasInfo.leftTexCoord + (right * horizontal)
        atlasInfo.leftTexCoord = atlasInfo.leftTexCoord + (left * horizontal)
        atlasInfo.bottomTexCoord = atlasInfo.topTexCoord + (bottom * vertical)
        atlasInfo.topTexCoord = atlasInfo.topTexCoord + (top * vertical)
    end
    return ns.merge({
        icon = atlasInfo.file,
        tCoordLeft = atlasInfo.leftTexCoord, tCoordRight = atlasInfo.rightTexCoord, tCoordTop = atlasInfo.topTexCoord, tCoordBottom = atlasInfo.bottomTexCoord,
    }, extra)
end
ns.atlas_texture = atlas_texture

-- Whichever atlas the player picked for their default icon. The three offered
-- in the config each want their own scale; anything else gets a generic one.
--[[
note to self:
atlas_texture("delves-scenario-treasure-unavailable", nil, 0, 0.9, 0.1, 1)
atlas_texture("delves-scenario-treasure-available", nil, 0, 0.9, 0.05, 0.95)
--]]
local default_scales = {
    VignetteLoot = 1.1,
    VignetteLootElite = 1.2,
    Garr_TreasureIcon = 2.2,
}
local default_textures = setmetatable({}, {__index = function(self, atlas)
    self[atlas] = atlas_texture(atlas, default_scales[atlas] or 1.5)
    return self[atlas]
end})

local function work_out_texture(point)
    if point.texture then
        return point.texture
    end
    if point.atlas then
        if not atlas_cache[point.atlas] then
            atlas_cache[point.atlas] = atlas_texture(point.atlas)
        end
        return atlas_cache[point.atlas]
    end
    if ns.db.icon_item or point.icon then
        if point.icon then
            return trimmed_icon(point.icon)
        end
        if point.loot and #point.loot > 0 then
            local texture = point.loot[1]:Icon()
            if texture then
                return trimmed_icon(texture)
            end
        end
        if point.currency then
            if ns.currencies[point.currency] then
                local texture = ns.currencies[point.currency].texture
                if texture then
                    return trimmed_icon(texture)
                end
            else
                local info = C_CurrencyInfo.GetCurrencyInfo(point.currency)
                if info then
                    return trimmed_icon(info.iconFileID)
                end
            end
        end
        if point.achievement then
            local texture = select(10, GetAchievementInfo(point.achievement))
            if texture then
                return trimmed_icon(texture)
            end
        end
    end
    if point.follower then
        if not follower_texture then
            follower_texture = atlas_texture("GreenCross", 1.5)
        end
        return follower_texture
    end
    if point.npc then
        if not npc_texture then
            if ns.CLASSIC then
                lessnotable_npc_texture = atlas_texture("DungeonSkull", {r=1, g=0.3, b=1, scale=1.1})
                notable_npc_texture = atlas_texture("DungeonSkull", {r=0.5, g=1, b=1, scale=1.1})
            else
                lessnotable_npc_texture = atlas_texture("nazjatar-nagaevent", 1, 0.2)
                notable_npc_texture = atlas_texture("nazjatar-nagaevent", {r=0.5, g=1, b=1}, 0.2)
            end
            npc_texture = atlas_texture("DungeonSkull", 1)
        end
        if ns.db.show_npcs_emphasizeNotable and ns.PointIsNotable(point, true) then
            if (not point.loot) or ns.hasNotableLoot(point.loot, true) then
                -- still notable without transmog
                return notable_npc_texture
            end
            return lessnotable_npc_texture
        else
            return npc_texture
        end
    end
    if point.currency then
        if not currency_texture then
            currency_texture = atlas_texture("Auctioneer", 1.3)
        end
        return currency_texture
    end
    if point.junk then
        if not junk_texture then
            junk_texture = atlas_texture("VignetteLoot", 1)
        end
        return junk_texture
    end
    return default_textures[ns.db.default_icon]
end
ns.work_out_texture = work_out_texture

local inactive_cache = {}
local function get_inactive_texture_variant(icon)
    if not inactive_cache[icon] then
        inactive_cache[icon] = CopyTable(icon)
        if inactive_cache[icon].r then
            inactive_cache[icon].a = 0.5
        else
            inactive_cache[icon].r = 0.5
            inactive_cache[icon].g = 0.5
            inactive_cache[icon].b = 0.5
            inactive_cache[icon].a = 1
        end
    end
    return inactive_cache[icon]
end
local upcoming_cache = {}
local function get_upcoming_texture_variant(icon)
    if not upcoming_cache[icon] then
        upcoming_cache[icon] = CopyTable(icon)
        upcoming_cache[icon].r = 1
        upcoming_cache[icon].g = 0
        upcoming_cache[icon].b = 0
        upcoming_cache[icon].a = 0.7
    end
    return upcoming_cache[icon]
end
ns.get_inactive_texture_variant = get_inactive_texture_variant
ns.get_upcoming_texture_variant = get_upcoming_texture_variant
