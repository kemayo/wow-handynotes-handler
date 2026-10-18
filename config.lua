local myname, ns = ...
local L = ns.L

ns.defaults = {
    profile = {
        default_icon = "VignetteLoot",
        show_on_world = true,
        show_on_minimap = false,
        show_npcs = true,
        show_npcs_filter = "lootable", -- [lootable, notable]
        show_npcs_emphasizeNotable = true,
        show_treasure = true,
        show_treasure_filter = "lootable", -- [lootable, notable]
        -- show_treasure_emphasizeNotable = true,
        show_routes = true,
        upcoming = true,
        areapoi_soon = 10, -- minutes; how early ns.areaPoi.Soon() calls a point imminent
        found = false,
        alts_achievements_count = false,
        -- notability!
        achievement_notable = true,
        mount_notable = true,
        toy_notable = true,
        pet_notable = true,
        transmog_notable = true,
        quest_notable = true,
        decor_notable = true,
        transmog_specific = true, -- consider whether you know the appearance from *this* item specifically
        notable_shared = true,
        -- Reward:Notable() reads this: on, loot that can't drop for you isn't a
        -- reason to want a point. True keeps it doing what it always has; the
        -- plugins have no option for it yet, unlike SilverDragon
        charloot = true,
        -- icon stuff
        icon_scale = 1.0,
        icon_alpha = 1.0,
        icon_item = false,
        tooltip_charloot = true,
        tooltip_sharedloot = true,
        tooltip_pointanchor = true,
        tooltip_item = true,
        tooltip_questid = false,
        groupsHidden = {},
        groupsHiddenByZone = {['*']={},},
        zonesHidden = {},
        achievementsHidden = {},
        worldmapoverlay = true,
    },
    char = {
        hidden = {
            ['*'] = {},
        },
    },
}

ns.options = {
    type = "group",
    name = myname:gsub("HandyNotes_", ""),
    get = function(info) return ns.db[info[#info]] end,
    set = function(info, v)
        ns.db[info[#info]] = v
        ns.HL:Refresh()
    end,
    hidden = function(info)
        return ns.hiddenConfig[info[#info]]
    end,
    childGroups = "tab",
    args = {
        common = {
            type = "group",
            name = L["Common"],
            args = {
                icon = {
                    type = "group",
                    name = L["Icons"],
                    inline = true,
                    order = 10,
                    args = {
                        desc = {
                            name = L["These settings control the look and feel of the icon."],
                            type = "description",
                            order = 0,
                        },
                        icon_scale = {
                            type = "range",
                            name = L["Icon Scale"],
                            desc = L["The scale of the icons"],
                            min = 0.25, max = 2, step = 0.01,
                            order = 20,
                        },
                        icon_alpha = {
                            type = "range",
                            name = L["Icon Alpha"],
                            desc = L["The alpha transparency of the icons"],
                            min = 0, max = 1, step = 0.01,
                            order = 30,
                        },
                        show_on_world = {
                            type = "toggle",
                            name = L["World Map"],
                            desc = L["Show icons on world map"],
                            order = 40,
                        },
                        show_on_minimap = {
                            type = "toggle",
                            name = L["Minimap"],
                            desc = L["Show all icons on the minimap"],
                            order = 50,
                        },
                        default_icon = {
                            type = "select",
                            name = L["Default Icon"],
                            values = {
                                VignetteLoot = CreateAtlasMarkup("VignetteLoot", 20, 20) .. " " .. L["Chest"],
                                VignetteLootElite = CreateAtlasMarkup("VignetteLootElite", 20, 20) .. " " .. L["Chest with star"],
                                Garr_TreasureIcon = CreateAtlasMarkup("Garr_TreasureIcon", 20, 20) .. " " .. L["Shiny chest"],
                            },
                            order = 60,
                        },
                        worldmapoverlay = {
                            type = "toggle",
                            name = L["Add button to world map"],
                            desc = L["Put a button on the world map for quick access to these options"],
                            set = function(info, v)
                                ns.db[info[#info]] = v
                                if WorldMapFrame.RefreshOverlayFrames then
                                    WorldMapFrame:RefreshOverlayFrames()
                                end
                            end,
                            hidden = function(info)
                                if not ns.SetupMapOverlay then
                                    return true
                                end
                                return ns.options.hidden(info)
                            end,
                            order = 70,
                        },
                    },
                },
                display = {
                    type = "group",
                    name = L["What to display"],
                    inline = true,
                    order = 20,
                    args = {
                        npcs = {
                            type = "group",
                            inline = true,
                            name = L["NPCs"],
                            args = {
                                show_npcs = {
                                    type = "toggle",
                                    name = L["Show NPCs"],
                                    desc = L["Show rare NPCs, generally to be killed for items or achievements"],
                                    order = 10,
                                    dropdownHidden = true,
                                },
                                show_npcs_filter = {
                                    type = "select",
                                    name = L["Filter"],
                                    desc = L["Show rare NPCs, generally to be killed for items or achievements"],
                                    values = {
                                        all = ALL,
                                        lootable = L["Will drop loot"],
                                        notable = L["Will drop notable loot"],
                                    },
                                    sorting = {"all", "lootable", "notable"},
                                    order = 20,
                                },
                                show_npcs_emphasizeNotable = {
                                    type = "toggle",
                                    name = L["Emphasize notable NPCs"],
                                    desc = L["Put more emphasis on NPCs that you can still get something from: achievements, transmogs, mounts, pets, toys"],
                                    order = 30,
                                },

                            },
                            order = 10,
                        },
                        treasure = {
                            type = "group",
                            inline = true,
                            name = L["Treasure"],
                            args = {
                                show_treasure = {
                                    type = "toggle",
                                    name = L["Show Treasure"],
                                    desc = L["Show treasures that can be found in the world"],
                                    order = 10,
                                    dropdownHidden = true,
                                },
                                show_treasure_filter = {
                                    type = "select",
                                    name = L["Filter"],
                                    desc = L["Show treasures that can be found in the world"],
                                    values = {
                                        all = ALL,
                                        lootable = L["Will drop loot"],
                                        notable = L["Will drop notable loot"],
                                    },
                                    sorting = {"all", "lootable", "notable"},
                                    order = 20,
                                },
                                -- show_treasure_emphasizeNotable = {
                                --     type = "toggle",
                                --     name = "Emphasize notable NPCs",
                                --     desc = "Put more emphasis on NPCs that you can still get something from: achievements, transmogs, mounts, pets, toys",
                                --     order = 30,
                                -- },

                            },
                            order = 20,
                        },
                        unhide = {
                            type = "execute",
                            name = L["Reset hidden nodes"],
                            desc = L["Show all nodes that you manually hid by right-clicking on them and choosing \"hide\"."],
                            func = function()
                                for _, coords in pairs(ns.hidden) do
                                    wipe(coords)
                                end
                                ns.HL:Refresh()
                            end,
                            order = 50,
                        },
                    },
                },
                -- the "found" cluster
                found = {
                    type = "group",
                    name = L["Found..."],
                    inline = true,
                    order = 30,
                    args = {
                        found = {
                            type = "toggle",
                            name = L["Show found"],
                            desc = L["Show waypoints for items you've already found?"],
                            order = 20,
                        },
                    },
                },
                tooltips = {
                    type = "group",
                    name = L["Tooltips"],
                    desc = L["Settings about how tooltips are displayed"],
                    inline = true,
                    args = {
                        tooltip_item = {
                            type = "toggle",
                            name = L["Use item tooltips"],
                            desc = L["Show the full tooltips for items"],
                            order = 10,
                        },
                        tooltip_charloot = {
                            type = "toggle",
                            name = L["Loot for this character only"],
                            desc = L["Only show loot that should drop for the current character"],
                            order = 12,
                        },
                        tooltip_sharedloot = {
                            type = "toggle",
                            name = L["Shared loot"],
                            desc = L["Some rares have a common pool of drops that're shared between them"],
                            order = 12,
                        },
                        tooltip_pointanchor = {
                            type = "toggle",
                            name = L["Anchor tooltips to points"],
                            desc = L["Whether to anchor the tooltips to the individual points or to the map"],
                            order = 15,
                        },
                        tooltip_questid = {
                            type = "toggle",
                            name = L["Show quest ids"],
                            desc = L["Show the internal id of the quest associated with this node. Handy if you want to report a problem with it."],
                            order = 40,
                        },
                    },
                    order = 25,
                },
                notable = {
                    type = "group",
                    name = L["What's notable?"],
                    desc = L["Define exactly what counts as being \"notable\""],
                    inline = true,
                    args = {
                        achievement_notable = {
                            type = "toggle",
                            name = TRANSMOG_SOURCE_5,
                            desc = L["Count unearned achievement-progress as notable"],
                            order = 10,
                        },
                        mount_notable = {
                            type = "toggle",
                            name = PERKS_VENDOR_CATEGORY_MOUNT or MOUNTS, -- MOUNT is the wrong form when translated
                            desc = L["Count unlearned mounts as notable loot"],
                            order = 10,
                        },
                        toy_notable = {
                            type = "toggle",
                            name = TOY,
                            desc = L["Count unlearned toys as notable loot"],
                            order = 20,
                        },
                        pet_notable = {
                            type = "toggle",
                            name = TOOLTIP_BATTLE_PET,
                            desc = L["Count uncaught pets as notable loot"],
                            order = 30,
                        },
                        transmog_notable = {
                            type = "toggle",
                            name = L["Transmog"],
                            desc = L["Count unlearned transmogrification appearances as notable loot"],
                            order = 40,
                        },
                        decor_notable = {
                            type = "toggle",
                            name = BINDING_TAG_DECOR or L["Decor"],
                            desc = L["Count unfound decor as notable loot"],
                            order = 50,
                            disabled = not BINDING_TAG_DECOR,
                        },
                        quest_notable = {
                            type = "toggle",
                            name = L["Quest-attached"],
                            desc = L["Count items with attached uncompleted quests as notable loot (this includes a lot of \"learnable\" items, weekly reputation drops, etc)"],
                            order = 60,
                        },
                    },
                    order = 40,
                },
                fiddly = {
                    type = "group",
                    name = L["Fiddly details"],
                    desc = L["Quirky small tweaks"],
                    inline = true,
                    args = {
                        icon_item = {
                            type = "toggle",
                            name = L["Use item icons"],
                            desc = L["Show the icons for items, if known; otherwise, the achievement icon will be used"],
                            order = 10,
                        },
                        upcoming = {
                            type = "toggle",
                            name = L["Show inaccessible"],
                            desc = L["Show waypoints for items you can't get yet (max level, gated quests, etc); they'll be tinted red to indicate this"],
                            order = 25,
                        },
                        areapoi_soon = {
                            type = "range",
                            name = L["Event notice period"],
                            desc = L["How many minutes before a timed event starts to mark its point as imminent, on the map and in its tooltip"],
                            min = 1, max = 60, step = 1,
                            order = 27,
                        },
                        show_routes = {
                            type = "toggle",
                            name = L["Show routes"],
                            desc = L["Show relevant routes between points"],
                            disabled = function() return not ns.MapSystem end,
                            order = 37,
                        },
                        transmog_specific = {
                            type = "toggle",
                            name = L["Transmog exact items"],
                            desc = L["For transmog appearances, only count them as known if you know them from that exact item, rather than from another sharing the same appearance"],
                            order = 45,
                        },
                        alts_achievements_count = {
                            type = "toggle",
                            name = L["Alts achievements count"],
                            desc = L["Consider achievement-related things done if you have it completed on another character already. Lots of achievement criteria are warband-shared, in which case this setting won't make a difference."],
                            order = 55,
                        },
                        notable_shared = {
                            type = "toggle",
                            name = L["Shared loot is notable"],
                            desc = L["Some rares have a common pool of drops that're shared between them. When this is checked, that shared loot will count for notability."],
                            order = 60,
                        },
                    },
                    order = 50,
                },
            },
        },
        data = {
            name = L["Data"],
            type = "group",
            args = {
                achievementsHidden = {
                    type = "multiselect",
                    name = L["Show achievements"],
                    desc = L["Toggle whether you want to show points for a given achievement"],
                    get = function(info, key) return not ns.db[info[#info]][key] end,
                    set = function(info, key, value)
                        ns.db[info[#info]][key] = not value
                        ns.HL:Refresh()
                    end,
                    values = function(info)
                        local values = {}
                        for uiMapID, points in pairs(ns.points) do
                            for coord, point in pairs(points) do
                                if point.achievement and not values[point.achievement] then
                                    local _, achievement = GetAchievementInfo(point.achievement)
                                    values[point.achievement] = achievement or ('achievement:'..point.achievement)
                                end
                            end
                        end
                        -- replace ourself with the built values table
                        info.option.values = values
                        return values
                    end,
                    hidden = function(info)
                        for uiMapID, points in pairs(ns.points) do
                            for coord, point in pairs(points) do
                                if point.achievement then
                                    info.option.hidden = nil
                                    return ns.options.hidden(info)
                                end
                            end
                        end
                        info.option.hidden = true
                        return true
                    end,
                    order = 30,
                },
                zonesHidden = {
                    type = "multiselect",
                    name = L["Show in zones"],
                    desc = L["Toggle whether you want to show points in a given zone"],
                    get = function(info, key) return not ns.db[info[#info]][key] end,
                    set = function(info, key, value)
                        ns.db[info[#info]][key] = not value
                        ns.HL:Refresh()
                    end,
                    values = function(info)
                        local values = {}
                        for uiMapID in pairs(ns.points) do
                            if not values[uiMapID] then
                                local info = C_Map.GetMapInfo(uiMapID)
                                if info and (
                                    info.mapType == Enum.UIMapType.Zone or
                                    info.mapType == Enum.UIMapType.Continent or
                                    info.mapType == Enum.UIMapType.World
                                ) then
                                    -- zones only
                                    values[uiMapID] = info.name
                                end
                            end
                        end
                        -- replace ourself with the built values table
                        info.option.values = values
                        return values
                    end,
                    order = 35,
                },
                groupsHidden = {
                    type = "multiselect",
                    name = L["Show groups"],
                    desc = L["Toggle whether to show certain groups of points"],
                    get = function(info, key) return not ns.db[info[#info]][key] end,
                    set = function(info, key, value)
                        ns.db[info[#info]][key] = not value
                        ns.HL:Refresh()
                    end,
                    values = function(info)
                        local values = {}
                        for uiMapID, points in pairs(ns.points) do
                            for coord, point in pairs(points) do
                                if point.group and not values[point.group] then
                                    values[point.group] = ns.render_string(ns.groups[point.group] or point.group)
                                end
                            end
                        end
                        -- replace ourself with the built values table
                        info.option.values = values
                        return values
                    end,
                    hidden = function(info)
                        for uiMapID, points in pairs(ns.points) do
                            for coord, point in pairs(points) do
                                if point.group then
                                    info.option.hidden = nil
                                    return ns.options.hidden(info)
                                end
                            end
                        end
                        info.option.hidden = true
                        return true
                    end,
                    order = 40,
                },
            },
        },
    },
}
