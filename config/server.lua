return {
    -- Ranges and periods
    hireRadius = 10.0, -- meters within which a boss can hire a player
    inviteRadius = 8.0, -- meters within which a gang leader can invite a player
    dutyPeriodDays = 7, -- days of duty time shown on the roster; each job keeps daily duty totals for twice this many days

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
        -- Rank ladder of every gang founded at the charterer, lowest rank first; the last rank is the boss, who holds every permission
        -- permissions: what the rank can do until the boss changes it in the gang menu
        -- vault_view: see the vault balance; vault_deposit: put money in; vault_withdraw: take money out
        -- vault_audit: read the vault history; gang_invite: invite players into the gang
        ranks = {
            { name = 'Recruit', permissions = { 'vault_deposit', 'gang_invite' } },
            { name = 'Soldier', permissions = { 'vault_deposit', 'gang_invite' } },
            { name = 'Lieutenant', permissions = { 'vault_view', 'vault_deposit', 'gang_invite' } },
            { name = 'Underboss', permissions = { 'vault_view', 'vault_deposit', 'vault_withdraw', 'vault_audit', 'gang_invite' } },
            { name = 'Boss' },
        },
        -- Gangs from cobalt_core's data/gangs.lua keep their own rank names
        builtInPermissions = { 'vault_deposit', 'gang_invite' }, -- what each of their ranks below the boss starts with
    },
}
