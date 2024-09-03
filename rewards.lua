local myname, ns = ...

local COSMETIC_COLOR = CreateColor(1, 0.5, 1)
local ATLAS_CHECK, ATLAS_CROSS = "common-icon-checkmark", "common-icon-redx"

ns.rewards = {}

-- Base reward specification, which should never really be used:
ns.rewards.Reward = ns.Class({
    classname = "Reward",
    note = false,
    requires = false,
    -- todo: consolidate these somehow?
    quest = false,
    questComplete = false,
    warband = false,
})
local Reward = ns.rewards.Reward

function Reward:init(id, extra)
    self.id = id
    if extra then
        for k, v in pairs(extra) do
            if self[k] == false then
                self[k] = v
            end
        end
    end
end
function Reward:Name(color) return UNKNOWN end
function Reward:Icon() return 134400 end -- question mark
function Reward:Obtained(for_tooltip)
    local result
    if self.quest then
        if C_QuestLog.IsQuestFlaggedCompleted(self.quest) or C_QuestLog.IsOnQuest(self.quest) then
            return true
        end
        if self.warband and C_QuestLog.IsQuestFlaggedCompletedOnAccount(self.quest) then
            return true
        end
        if for_tooltip or ns.db.quest_notable then
            result = false
        end
    end
    if self.questComplete then
        if C_QuestLog.IsQuestFlaggedCompleted(self.questComplete) then
            return true
        end
        if for_tooltip or ns.db.quest_notable then
            result = false
        end
    end
    return result
end
function Reward:Notable()
    -- Is it knowable and not obtained?
    return self:MightDrop() and (self:Obtained() == false)
end
function Reward:Available()
    if self.requires and not ns.conditions.check(self.requires) then
        return false
    end
    -- TODO: profession recipes?
    return true
end
function Reward:MightDrop() return self:Available() end
function Reward:SetTooltip(tooltip) return false end
function Reward:AddToTooltip(tooltip)
    local r, g, b = self:TooltipNameColor()
    local lr, lg, lb = self:TooltipLabelColor()
    tooltip:AddDoubleLine(
        self:TooltipLabel(),
        self:TooltipName(),
        lr, lg, lb,
        r, g, b
    )
end
function Reward:TooltipName()
    local name = self:Name(true)
    local icon = self:Icon()
    if not name then
        name = SEARCH_LOADING_TEXT
    end
    if self.requires then
        name = TEXT_MODE_A_STRING_VALUE_TYPE:format(name, ns.conditions.summarize(self.requires, true))
    end
    if self.note then
        name = TEXT_MODE_A_STRING_VALUE_TYPE:format(name, self.note)
    end
    return ("%s%s%s"):format(
        (icon and (ns.quick_texture_markup(icon) .. " ") or ""),
        ns.render_string(name),
        self:ObtainedTag() or ""
    )
end
function Reward:TooltipNameColor()
    if not self:Name() then
        return 0, 1, 1
    end
    return NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b
end
function Reward:TooltipLabel() return UNKNOWN end
function Reward:TooltipLabelColor()
    if ns.db.show_npcs_emphasizeNotable and self:Notable() then
        return 1, 0, 1
    end
    return NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b
end
function Reward:ObtainedTag()
    local known = self:Obtained(true) -- for_tooltip
    if known == nil then return end
    return " " .. CreateAtlasMarkup(known and ATLAS_CHECK or ATLAS_CROSS)
end
function Reward:Cache() end

ns.rewards.Item = ns.rewards.Reward:extends({classname="Item", spell=false})

function ns.rewards.Item:Name(color)
    local name, link = C_Item.GetItemInfo(self.id)
    if link then
        return color and link:gsub("[%[%]]", "") or name
    end
end
function ns.rewards.Item:TooltipLabel()
    local _, itemType, itemSubtype, equipLoc, icon, classID, subclassID = C_Item.GetItemInfoInstant(self.id)
    local _, link = C_Item.GetItemInfo(self.id)
    local label = ENCOUNTER_JOURNAL_ITEM
    if classID == Enum.ItemClass.Armor and subclassID ~= Enum.ItemArmorSubclass.Shield then
        label = _G[equipLoc] or label
    else
        label = itemSubtype
    end
    if label and ns.IsCosmeticItem(self.id) then
        label = TEXT_MODE_A_STRING_VALUE_TYPE:format(label, COSMETIC_COLOR:WrapTextInColorCode(ITEM_COSMETIC))
    end
    return label
end
function ns.rewards.Item:Icon() return (select(5, C_Item.GetItemInfoInstant(self.id))) end
function ns.rewards.Item:Obtained(for_tooltip)
    local result = self:super("Obtained", for_tooltip)
    if self.spell then
        -- can't use the tradeskill functions + the recipe-spell because that data's only available after the tradeskill window has been opened...
        local info = C_TooltipInfo.GetItemByID(self.id)
        if info then
            for _, line in ipairs(info.lines) do
                if line.leftText and string.match(line.leftText, _G.ITEM_SPELL_KNOWN) then
                    return true
                end
            end
        end
        result = false
    end
    if ns.CLASSIC then return result and GetItemCount(self.id, true) > 0 end
    if (for_tooltip or ns.db.transmog_notable) and ns.CanLearnAppearance(self.id) then
        return ns.HasAppearance(self.id, ns.db.transmog_specific)
    end
    return result
end
function ns.rewards.Item:MightDrop()
    -- We think an item might drop if it either has no spec information, or
    -- returns any spec information at all (because the game will only give
    -- specs for the current character)
    -- can't pass in a reusable table for the second argument because it changes the no-data case
    local specTable = C_Item.GetItemSpecInfo(self.id)
    -- Some cosmetic items seem to be flagged as not dropping for any spec. I
    -- could only confirm this for some cosmetic back items but let's play it
    -- safe and say that any cosmetic item can drop regardless of what the
    -- spec info says...
    if specTable and #specTable == 0 and not ns.IsCosmeticItem(self.id) then
        return false
    end
    -- parent catches covenants / classes / etc
    return self:super("MightDrop")
end
function ns.rewards.Item:SetTooltip(tooltip)
    tooltip:SetItemByID(self.id)
end
function ns.rewards.Item:Cache()
    C_Item.RequestLoadItemDataByID(self.id)
end

-- These are all Items becuase the loot is an actual item, but they're very
-- overridden to support whatever thing that item teaches you:

ns.rewards.Toy = ns.rewards.Item:extends({classname="Toy"})
function ns.rewards.Toy:TooltipLabel() return TOY end
function ns.rewards.Toy:Obtained(...)
    if ns.CLASSIC then return GetItemCount(self.id, true) > 0 end
    return self:super("Obtained", ...) ~= false and PlayerHasToy(self.id)
end
function ns.rewards.Toy:Notable(...) return ns.db.toy_notable and self:super("Notable", ...) end

ns.rewards.Mount = ns.rewards.Item:extends({classname="Mount"})
function ns.rewards.Mount:init(id, mountid, ...)
    self:super("init", id, ...)
    self.mountid = mountid
end
function ns.rewards.Mount:TooltipLabel() return MOUNT end
function ns.rewards.Mount:Obtained(...)
    if self:super("Obtained", ...) == false then return false end
    if ns.CLASSIC then return GetItemCount(self.id, true) > 0 end
    if not _G.C_MountJournal then return false end
    if not self.mountid then
        self.mountid = C_MountJournal.GetMountFromItem and C_MountJournal.GetMountFromItem(self.id)
    end
    return self.mountid and (select(11, C_MountJournal.GetMountInfoByID(self.mountid)))
end
function ns.rewards.Mount:Notable(...) return ns.db.mount_notable and self:super("Notable", ...) end

ns.rewards.Pet = ns.rewards.Item:extends({classname="Pet"})
function ns.rewards.Pet:init(id, petid, ...)
    self:super("init", id, ...)
    self.petid = petid
end
function ns.rewards.Pet:TooltipLabel() return TOOLTIP_BATTLE_PET end
function ns.rewards.Pet:Obtained(...)
    if self:super("Obtained", ...) == false then return false end
    if ns.CLASSIC then return GetItemCount(self.id, true) > 0 end
    if not self.petid then
        self.petid = select(13, C_PetJournal.GetPetInfoByItemID(self.id))
    end
    return self.petid and C_PetJournal.GetNumCollectedInfo(self.petid) > 0
end
function ns.rewards.Pet:Notable(...) return ns.db.pet_notable and self:super("Notable", ...) end

ns.rewards.Set = ns.rewards.Item:extends({classname="Set"})
function ns.rewards.Set:init(id, setid, ...)
    self:super("init", id, ...)
    self.setid = setid
end
function ns.rewards.Set:Name()
    local info = C_TransmogSets.GetSetInfo(self.setid)
    if info then
        return info.name
    end
    return self:Super("Name")
end
function ns.rewards.Set:TooltipLabel() return WARDROBE_SETS end
function ns.rewards.Set:Obtained(...)
    if not self:super("Obtained", ...) then return false end
    if ns.CLASSIC then return GetItemCount(self.id, true) > 0 end
    local info = C_TransmogSets.GetSetInfo(self.setid)
    if info then
        if info.collected then return true end
        -- we want to fall through and return nil for sets the current class can't learn:
        if info.classMask and bit.band(info.classMask, ns.playerClassMask) == ns.playerClassMask then return false end
    end
end
function ns.rewards.Set:ObtainedTag()
    local info = C_TransmogSets.GetSetInfo(self.setid)
    if not info then return end
    if not info.collected then
        local sources = C_TransmogSets.GetSetPrimaryAppearances(self.setid)
        if sources and #sources > 0 then
            local numKnown = 0
            for _, source in pairs(sources) do
                if source.collected then
                    numKnown = numKnown + 1
                end
            end
            return RED_FONT_COLOR:WrapTextInColorCode(GENERIC_FRACTION_STRING:format(numKnown, #sources))
        end
    end
    return self:super("ObtainedTag")
end

ns.rewards.Currency = Reward:extends({classname="Currency"})
function ns.rewards.Currency:init(id, amount, ...)
    self:super("init", id, ...)
    self.amount = amount
    self.faction = C_CurrencyInfo.GetFactionGrantedByCurrency(id)
    -- This effect is a little specialized around the rep drops from rares
    -- in War Within; will need to revisit it if there's future warband
    -- currency rewards that are character-gated not account-gated...
    self.warband = self.faction and C_Reputation.IsAccountWideReputation(self.faction)
end
function ns.rewards.Currency:Name(color)
    local info = C_CurrencyInfo.GetBasicCurrencyInfo(self.id, self.amount)
    if info and info.name then
        local name = color and ITEM_QUALITY_COLORS[info.quality].color:WrapTextInColorCode(info.name) or info.name
        return (self.amount and self.amount > 1) and
            ("%s x %d"):format(name, self.amount) or
            name
    end
    return self:Super("Name", color)
end
function ns.rewards.Currency:Icon()
    local info = C_CurrencyInfo.GetBasicCurrencyInfo(self.id)
    if info and info.icon then
        return info.icon
    end
end
function ns.rewards.Currency:TooltipLabel()
    return self.faction and REPUTATION or CURRENCY
end
