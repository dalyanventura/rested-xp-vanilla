-- Guide exemple: Mulgore 1-12 (Tauren)

local taurGuide = {
    id = "Horde_1_12_Tauren",
    title = "Mulgore 1-12",
    faction = "Horde",
    race = "Tauren",
    levelRange = "1-12",
    steps = {
        {
            title = "Camp Narache - Debut",
            objectives = {
                {
                    action = "ACCEPT",
                    questId = 747,
                    questName = "The Hunt Begins",
                    raw = ".accept 747",
                    text = "Accepter la quete 'The Hunt Begins'."
                },
                {
                    action = "COMPLETE",
                    questId = 747,
                    questName = "The Hunt Begins",
                    raw = ".complete 747",
                    text = "Tuer les Plainstrider requis pour la quete."
                },
                {
                    action = "TURNIN",
                    questId = 747,
                    questName = "The Hunt Begins",
                    raw = ".turnin 747",
                    text = "Rendre la quete au PNJ de depart."
                }
            }
        },
        {
            title = "Orientation Mulgore",
            objectives = {
                {
                    action = "GOTO",
                    zone = "Mulgore",
                    x = 45.2,
                    y = 32.1,
                    raw = ".goto Mulgore,45.2,32.1",
                    text = "Aller vers le point indique en Mulgore."
                },
                {
                    action = "FLY",
                    raw = ".fp",
                    text = "Prendre le point de vol si accessible."
                },
                {
                    action = "SET_HEARTH",
                    raw = ".home",
                    text = "Lier la pierre de foyer a Thunder Bluff ou Bloodhoof."
                }
            }
        }
    }
}

if MyRXP and MyRXP.RegisterGuide then
    MyRXP:RegisterGuide(taurGuide)
end
