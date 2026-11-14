return {
    -- Opening the management menu
    openCommand = 'bossmenu', -- chat command
    openKey = 'F5', -- default key; players can rebind it in GTA settings

    -- The charterer who registers new gangs
    charter = {
        ped = `s_m_y_dealer_01`, -- ped model the charterer spawns as
        scenario = 'WORLD_HUMAN_CLIPBOARD', -- GTA scenario the charterer plays while waiting
        spawnDistance = 100.0, -- meters from the charterer at which the ped spawns; it despawns past this
    },
}
