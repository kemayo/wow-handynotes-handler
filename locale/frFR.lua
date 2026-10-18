if GetLocale() ~= "frFR" then return end
local _, ns = ...

-- Pilot strings, not yet checked by a French speaker
ns.AddTranslations("frFR", {
    ["Create waypoint"] = "Créer un point de passage",
    ["Create waypoint for all %s"] = "Créer des points de passage pour : %s",
    ["Hide this point"] = "Masquer ce point",
    ["Hide %s"] = "Masquer : %s",
    ["Hide %s only in %s"] = "Masquer %s uniquement dans %s",
    ["Hide all %s"] = "Tout masquer : %s",
    ["Hide %s in all zones"] = "Masquer %s dans toutes les zones",
})
