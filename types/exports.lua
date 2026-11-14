---@meta

---@alias ManagementPermission 'open_menu' | 'view_dashboard' | 'give_bonus' | 'society'

---@alias ManagementMenu 'org' | 'gang' | 'gangAdmin' | 'apply' | 'charter'

---@class ManagementJob
---@field name string
---@field label string
---@field type string `leo`, `ems`, `mechanic`, or the job's own type
---@field onduty boolean
---@field isboss boolean
---@field grade { name: string, level: integer, payment: integer, isboss: boolean }

---@class ManagementGang
---@field name string
---@field label string
---@field isboss boolean
---@field grade { name: string, level: integer, isboss: boolean }
---@field archetype? string server only: `street`, `mc`, `mafia` or `cartel`
---@field permissions? string[] server only: what the member's rank can do in the street economy
---@field homeTurf? string server only
---@field founderCid? string server only

---@class ManagementEmployee
---@field citizenid string
---@field name string
---@field grade integer
---@field rank string
---@field pay integer per payday, after the boss's pay changes
---@field isBoss boolean
---@field online boolean
---@field onDuty boolean
---@field onLeave boolean
---@field joinedAt? string ISO 8601 UTC
---@field shiftStartedAt? string ISO 8601 UTC
---@field weekMinutes integer
---@field lastWeekMinutes integer
---@field monthBonuses integer
---@field source? integer server id when online

---@class ManagementFleetVehicle
---@field plate string
---@field model string
---@field label string
---@field minGrade integer lowest grade that may drive it

---@class CobaltManagementExports
local CobaltManagementExports = {}

---**Server.** The player's job, or nil before their character loads.
---@param source integer
---@return ManagementJob?
function CobaltManagementExports:GetJob(source) end

---**Client.** The local player's job.
---@return ManagementJob?
function CobaltManagementExports:GetJob() end

---**Server.** The player's gang with its archetype and the rank's permissions, or nil outside a gang.
---@param source integer
---@return ManagementGang?
function CobaltManagementExports:GetGang(source) end

---**Server.** Puts an online player in a job at a grade; false when the job or grade doesn't exist.
---@param source integer
---@param name string
---@param grade? integer
---@return boolean
function CobaltManagementExports:SetJob(source, name, grade) end

---**Server.** Puts an online player in a gang at a grade (`none` to remove them); false when the gang or grade doesn't exist.
---@param source integer
---@param name string
---@param grade? integer
---@return boolean
function CobaltManagementExports:SetGang(source, name, grade) end

---**Server.** Job and gang per character, online or not, for character lists. Characters with no row are left out.
---@param citizenids string[]
---@return table<string, { job?: ManagementJob, gang?: ManagementGang }>
function CobaltManagementExports:GetAffiliations(citizenids) end

---**Server.** True when the player is on duty for their job, false when off.
---@param source integer
---@return boolean
function CobaltManagementExports:GetDuty(source) end

---**Server.** How many online members of the job are on duty and how many are off. Matches the job's name or its type (`leo`, `ems`).
---@param job string job name or type
---@return integer onDuty
---@return integer offDuty
function CobaltManagementExports:GetDutyCount(job) end

---**Client.** True when the local player is on duty, false when off.
---@return boolean
function CobaltManagementExports:GetDuty() end

---**Server.** Sets duty and logs the shift.
---@param source integer
---@param onDuty boolean
---@return boolean
function CobaltManagementExports:SetDuty(source, onDuty) end

---**Server.** Whether the player's rank in the job or gang holds a menu permission. Boss ranks hold all of them.
---@param source integer
---@param org string
---@param permission ManagementPermission
---@return boolean
function CobaltManagementExports:HasPermission(source, org, permission) end

---**Server.** Everyone in a job or gang, online or not, highest grade first. It lists main jobs only, not second jobs.
---`summary` skips the duty, leave and bonus queries, so `weekMinutes`, `lastWeekMinutes` and `monthBonuses` are 0,
---`onLeave` is false and `shiftStartedAt` is nil.
---@param org string
---@param options? { summary?: boolean }
---@return ManagementEmployee[]
function CobaltManagementExports:GetEmployees(org, options) end

---**Server.** Server ids of online players in the job or gang.
---@param org string
---@return integer[]
function CobaltManagementExports:GetOnlineMembers(org) end

---**Server.** Moves an employee to another grade, online or not. Someone holding the job as a second job keeps it as one.
---@param citizenid string
---@param org string
---@param grade integer
---@return boolean ok
---@return string? error
function CobaltManagementExports:SetGrade(citizenid, org, grade) end

---**Server.** Minutes a character spent on duty for a job in the last `days` (7 when left out). Pass a list of citizenids
---to get them all from one query, as a table keyed by citizenid with 0 for each one without shifts.
---@param citizenid string
---@param job string
---@param days? integer
---@return integer
---@overload fun(self: CobaltManagementExports, citizenids: string[], job: string, days?: integer): table<string, integer>
function CobaltManagementExports:GetDutyMinutes(citizenid, job, days) end

---**Server.** Whether the player's gang rank holds a street permission such as `vault_withdraw` or `racket_claim`.
---@param source integer
---@param permission string
---@return boolean
function CobaltManagementExports:HasGangPermission(source, permission) end

---**Server.** Vehicles the org bought from its menu. cobalt_garages lists them in the org's garage.
---@param org string
---@return ManagementFleetVehicle[]
function CobaltManagementExports:GetFleet(org) end

---**Server.** Opens a menu for a player. `apply` takes `{ org = name }`.
---@param source integer
---@param menu? ManagementMenu
---@param data? table
function CobaltManagementExports:OpenMenu(source, menu, data) end

---**Client.** Opens a menu for the local player; false when it isn't available to them.
---@param menu? ManagementMenu
---@param data? table
---@return boolean
function CobaltManagementExports:OpenMenu(menu, data) end

exports.cobalt_management = CobaltManagementExports
