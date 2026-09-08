-- MyRXP_VGImporter - Import du format VanillaGuide-Enhanced vers un format type RestedXP

MyRXP = MyRXP or {}

local ACTION_MAP = {
    A = "ACCEPT",
    T = "TURNIN",
    C = "COMPLETE",
    G = "GOTO",
    F = "FLY",
    H = "SET_HEARTH"
}

local function trim(text)
    if not text then return "" end
    return string.gsub(text, "^%s*(.-)%s*$", "%1")
end

local function splitPipe(line)
    local fields = {}
    for token in string.gfind(line .. "|", "(.-)|") do
        if token and token ~= "" then
            table.insert(fields, token)
        end
    end
    return fields
end

function MyRXP:ParseVGEntry(line)
    if type(line) ~= "string" then return nil end
    line = trim(line)
    if line == "" then return nil end

    local actionCode = string.sub(line, 1, 1)
    actionCode = string.upper(actionCode)
    local action = ACTION_MAP[actionCode]
    if not action then
        return nil
    end

    local objective = {
        action = action,
        raw = line,
        text = "",
        questId = nil,
        questName = nil,
        zone = nil,
        x = nil,
        y = nil
    }

    -- Format pipe (ex: A Quete|QID|788|M|52.2,43.1|Z|Durotar|N|Depuis Gornek|)
    local fields = splitPipe(line)
    if table.getn(fields) > 0 then
        local first = fields[1]
        if first and string.len(first) > 2 then
            objective.questName = trim(string.sub(first, 3))
        end

        local i = 2
        while i <= table.getn(fields) do
            local k = string.upper(trim(fields[i]))
            local v = fields[i + 1]

            if k == "QID" and v then
                objective.questId = tonumber(v)
            elseif k == "N" and v then
                objective.text = trim(v)
            elseif (k == "Z" or k == "ZONE") and v then
                objective.zone = trim(v)
            elseif (k == "M" or k == "COORD" or k == "G") and v then
                local sx, sy = string.gfind(v, "([%d%.]+)%s*,%s*([%d%.]+)")()
                if sx and sy then
                    objective.x = tonumber(sx)
                    objective.y = tonumber(sy)
                end
            end

            i = i + 2
        end
    end

    -- Fallbacks pour formats plus simples (ex: G Durotar,43.2,67.5 Note)
    if not objective.questId then
        local qid = string.gfind(line, "QID%s*[:=]?%s*(%d+)")()
        if qid then objective.questId = tonumber(qid) end
    end

    if not objective.zone or not objective.x or not objective.y then
        local z, x, y = string.gfind(line, "G%s+([^,]+),%s*([%d%.]+),%s*([%d%.]+)")()
        if z and x and y then
            objective.zone = trim(z)
            objective.x = tonumber(x)
            objective.y = tonumber(y)
        end
    end

    if (not objective.questName or objective.questName == "") and action ~= "GOTO" then
        local qname = string.gfind(line, "^[ATC]%s+([^|:]+)")()
        if qname then
            objective.questName = trim(qname)
        end
    end

    if objective.text == "" then
        if objective.action == "GOTO" and objective.zone and objective.x and objective.y then
            objective.text = "Aller vers " .. objective.zone .. " (" .. objective.x .. ", " .. objective.y .. ")"
        elseif objective.action == "ACCEPT" then
            objective.text = "Accepter : " .. (objective.questName or "quete")
        elseif objective.action == "TURNIN" then
            objective.text = "Rendre : " .. (objective.questName or "quete")
        elseif objective.action == "COMPLETE" then
            objective.text = "Completer : " .. (objective.questName or "quete")
        elseif objective.action == "FLY" then
            objective.text = "Prendre un trajet aerien"
        elseif objective.action == "SET_HEARTH" then
            objective.text = "Lier la pierre de foyer"
        end
    end

    -- Equivalent style RestedXP (.accept/.turnin/.complete/.goto/.fp/.home)
    if objective.action == "ACCEPT" then
        objective.raw = ".accept " .. (objective.questId or (objective.questName or ""))
    elseif objective.action == "TURNIN" then
        objective.raw = ".turnin " .. (objective.questId or (objective.questName or ""))
    elseif objective.action == "COMPLETE" then
        objective.raw = ".complete " .. (objective.questId or (objective.questName or ""))
    elseif objective.action == "GOTO" then
        if objective.zone and objective.x and objective.y then
            objective.raw = ".goto " .. objective.zone .. "," .. objective.x .. "," .. objective.y
        else
            objective.raw = ".goto"
        end
    elseif objective.action == "FLY" then
        objective.raw = ".fp"
    elseif objective.action == "SET_HEARTH" then
        objective.raw = ".home"
    end

    return objective
end

function MyRXP:ImportVanillaGuide(vgData)
    local source = vgData or VG_Data
    if not source then return nil end

    local guide = {
        id = "Imported_VG",
        title = "Guide importe VanillaGuide",
        steps = {}
    }

    local function pushLineAsStep(line)
        local objective = MyRXP:ParseVGEntry(line)
        if not objective then return end

        local stepTitle = objective.action
        if objective.questName and objective.questName ~= "" then
            stepTitle = stepTitle .. " - " .. objective.questName
        end

        table.insert(guide.steps, {
            title = stepTitle,
            objectives = { objective }
        })
    end

    if type(source) == "string" then
        for line in string.gfind(source, "([^\n\r]+)") do
            pushLineAsStep(line)
        end
    elseif type(source) == "table" then
        for _, entry in pairs(source) do
            if type(entry) == "string" then
                pushLineAsStep(entry)
            elseif type(entry) == "table" then
                for _, subEntry in pairs(entry) do
                    if type(subEntry) == "string" then
                        pushLineAsStep(subEntry)
                    end
                end
            end
        end
    end

    return guide
end

-- Exemple concret: conversion d'un mini-guide Durotar complet (format VanillaGuide simplifie)
MyRXP_VG_Durotar_ExampleSource = {
    "A Votre place dans le monde|QID|4641|M|42.1,68.3|Z|Durotar|N|Depuis Kaltunk|",
    "T Votre place dans le monde|QID|4641|M|42.0,68.4|Z|Durotar|N|Parler a Gornek|",
    "A Les epreuves|QID|788|M|42.0,68.4|Z|Durotar|N|Depuis Gornek|",
    "C Les epreuves|QID|788|M|43.3,71.2|Z|Durotar|N|Tuer des Mottled Boars|",
    "T Les epreuves|QID|788|M|42.1,68.5|Z|Durotar|N|Retour a Gornek|",
    "G Durotar,52.0,43.0|N|Se diriger vers Sen'jin Village|",
    "F|N|Prendre le point de vol si disponible|",
    "H|N|Lier la pierre de foyer a Razor Hill|"
}

MyRXP_VG_Durotar_ExampleConverted = MyRXP:ImportVanillaGuide(MyRXP_VG_Durotar_ExampleSource)
