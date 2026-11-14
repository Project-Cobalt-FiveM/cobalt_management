return {
    -- Ranges and periods
    hireRadius = 10.0, -- meters within which a boss can hire a player
    inviteRadius = 8.0, -- meters within which a gang leader can invite a player
    dutyPeriodDays = 7, -- days of duty time shown on the roster

    -- Input limits
    limits = {
        bonus = 50000, -- largest bonus one payout can be, in dollars
        title = 120, -- characters in an announcement or report title
        message = 1000, -- characters in an announcement, report or application
        reason = 255, -- characters in a firing, warning or leave reason
    },

    -- Job logos
    logoHosts = { 'cdn.fivemesh.io' }, -- https hosts a job logo link may use, lowercase and matched exactly; cdn.fivemesh.io holds cobalt_core uploads; empty turns logos off

    -- Menu pages that are turned on for every job; secondJobs lets players hold a second job
    features = {
        society = true, -- society account page
        applications = true, -- job applications from players
        leaves = true, -- leave requests
        reports = true, -- staff reports to the boss
        vehicles = true, -- fleet vehicles bought from the society account
        announcements = true, -- announcements to staff
        duty = true, -- duty time tracking
        secondJobs = false, -- players can hold second jobs besides their main one
    },

    -- Fleet vehicles a job can buy: by job name, or by job type for every job of that type (mechanic covers all mechanic shops)
    -- plate: plate prefix; model: vehicle spawn name, named in the menu from cobalt_core's shared vehicles
    -- role: what the vehicle is for, shown in the catalogue from the vehicles.role.<role> locale key
    -- price: dollars from the society account; grade: lowest grade that may take it out
    vehicles = {
        police = {
            plate = 'LSPD',
            catalogue = {
                { model = 'police', role = 'patrol', price = 0, grade = 0 },
                { model = 'police2', role = 'patrol', price = 25000, grade = 2 },
                { model = 'police3', role = 'pursuit', price = 50000, grade = 3 },
                { model = 'policet', role = 'transport', price = 45000, grade = 3 },
                { model = 'sheriff', role = 'command', price = 60000, grade = 4 },
            },
        },
        ambulance = {
            plate = 'EMS',
            catalogue = {
                { model = 'ambulance', role = 'emergency', price = 0, grade = 0 },
            },
        },
        mechanic = {
            plate = 'LSC',
            catalogue = {
                { model = 'towtruck', role = 'service', price = 0, grade = 0 },
                { model = 'flatbed', role = 'service', price = 35000, grade = 2 },
            },
        },
    },

    -- Gangs
    gangs = {
        maxActive = 8, -- most gangs that can exist at once
        vaultCap = 2000000, -- most a gang vault can hold, in dollars
        nameLength = { min = 3, max = 32 }, -- characters in a gang name

        -- The charterer who registers new gangs; its ped model and scenario are in config/client.lua
        charter = {
            price = 250000, -- cost to start a gang
            item = 'markedbills', -- paid in this item; must exist in cobalt_inventory
            rotateMinutes = 360, -- minutes before the charterer moves to the next location
            range = 4.0, -- meters to talk to the charterer
            locations = { -- spots the charterer rotates between
                vec4(-435.75, -2187.33, 10.19, 174.91),
            },
        },
        -- Upgrading a street gang to an MC, mafia or cartel
        upgrade = {
            costs = { mc = 750000, mafia = 1000000, cartel = 1000000 }, -- dollars from the vault
            minAgeDays = 7, -- days the gang must exist first
            minMembers = 5, -- members needed
            minVault = 500000, -- dollars that must be in the vault
            cooldownDays = 14, -- days between upgrades
        },
        turf = { cost = 50000, cooldownHours = 24 }, -- claiming turf: dollars and hours between claims
        hq = { cost = 25000, cooldownHours = 24, maxDistance = 25.0 }, -- moving the HQ: dollars, hours between moves, meters the leader can place it from where they stand
        colours = { -- gang colours: GTA blip colour id and hex for the menu; each id is named by the gang.colour.<id> locale key
            { id = 1, hex = '#e03232' },
            { id = 2, hex = '#72cc72' },
            { id = 5, hex = '#eec64e' },
            { id = 7, hex = '#9a6ab6' },
            { id = 11, hex = '#5fd0c9' },
            { id = 25, hex = '#f08ec6' },
            { id = 27, hex = '#8ec1f0' },
            { id = 38, hex = '#2c57c7' },
            { id = 47, hex = '#f49b29' },
            { id = 0, hex = '#fafafa' },
        },
    },
}
