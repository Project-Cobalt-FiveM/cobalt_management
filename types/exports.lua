---@meta

---@alias ManagementPermission 'open_menu' | 'view_dashboard' | 'give_bonus' | 'society'

---@alias GangPermission 'vault_view' | 'vault_deposit' | 'vault_withdraw' | 'vault_audit' | 'gang_invite'

---@alias ManagementMenu 'job' | 'gang' | 'gangAdmin' | 'apply' | 'charter'

---@class ManagementJob
---@field name string
---@field label string
---@field type string `leo`, `ems`, `mechanic`, or the job's own type
---@field onduty boolean
---@field isboss boolean
---@field grade { name: string, level: integer, payment: integer, isboss: boolean }
---@field since? integer unix seconds when the character joined the job

---@class ManagementGang
---@field name string
---@field label string
---@field isboss boolean
---@field grade { name: string, level: integer, isboss: boolean }
---@field since? integer unix seconds when the character joined the gang; nil outside a gang
---@field permissions? GangPermission[] server only: what the member's rank can do
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

---@class ManagementJobStatus
---@field open boolean false while staff keep the job closed
---@field paidToday integer dollars paid out for the job since midnight, server time

---@class CobaltManagementExports
local CobaltManagementExports = {}

---**Server.** The player's job, or nil before their character loads.
---@param source integer
---@return ManagementJob?
function CobaltManagementExports:GetJob(source) end

---**Client.** The local player's job.
---@return ManagementJob?
function CobaltManagementExports:GetJob() end

---**Server.** The player's gang with its rank's permissions, or nil outside a gang.
---@param source integer
---@return ManagementGang?
function CobaltManagementExports:GetGang(source) end

---**Client.** The local player's gang, or nil outside a gang.
---@return ManagementGang?
function CobaltManagementExports:GetGang() end

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

---**Server.** Job and gang per character, online or not, read from `metadata.job` and `metadata.gang`, for character lists. Characters with neither are left out.
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

---**Server.** Puts the player on or off duty and starts or ends their shift. The change stays in memory; characters log in on their job's default duty while cobalt_core's `forceDefaultDutyAtLogin` is on.
---@param source integer
---@param onDuty boolean
---@return boolean
function CobaltManagementExports:SetDuty(source, onDuty) end

---**Server.** Whether the player's rank in the job holds a menu permission. Boss ranks hold all of them; in a gang only the boss holds them.
---@param source integer
---@param name string job or gang
---@param permission ManagementPermission
---@return boolean
function CobaltManagementExports:HasPermission(source, name, permission) end

---**Server.** Everyone in a job or gang, online or not, highest grade first. It lists main jobs only, not second jobs.
---`summary` skips the duty, leave and bonus totals, so `weekMinutes`, `lastWeekMinutes` and `monthBonuses` are 0,
---`onLeave` is false and `shiftStartedAt` is nil. Gangs always get those defaults.
---@param name string job or gang
---@param options? { summary?: boolean }
---@return ManagementEmployee[]
function CobaltManagementExports:GetEmployees(name, options) end

---**Server.** Server ids of online players in the job or gang.
---@param name string job or gang
---@return integer[]
function CobaltManagementExports:GetOnlineMembers(name) end

---**Server.** Moves an employee to another grade, online or not. Someone holding the job as a second job keeps it as one.
---@param citizenid string
---@param job string
---@param grade integer
---@return boolean ok
---@return string? error
function CobaltManagementExports:SetGrade(citizenid, job, grade) end

---**Server.** Minutes a character spent on duty for a job in the last `days` (7 when left out), the shift in progress included.
---Jobs keep daily totals for twice `dutyPeriodDays` (14 days by default); a longer `days` returns every minute on record.
---Pass a list of citizenids to get them all at once, as a table keyed by citizenid with 0 for each one without duty time.
---@param citizenid string
---@param job string
---@param days? integer
---@return integer
---@overload fun(self: CobaltManagementExports, citizenids: string[], job: string, days?: integer): table<string, integer>
function CobaltManagementExports:GetDutyMinutes(citizenid, job, days) end

---**Server.** Whether the player's gang rank holds a permission. The boss holds all of them.
---@param source integer
---@param permission GangPermission
---@return boolean
function CobaltManagementExports:HasGangPermission(source, permission) end

---**Server.** Vehicles the job bought from its menu. cobalt_garages lists them in the job's garage.
---@param job string
---@return ManagementFleetVehicle[]
function CobaltManagementExports:GetFleet(job) end

---**Server.** Opens a menu for a player. `apply` takes `{ job = name }`.
---@param source integer
---@param menu? ManagementMenu `job` when left out
---@param data? table
function CobaltManagementExports:OpenMenu(source, menu, data) end

---**Client.** Opens a menu for the local player; false when it isn't available to them.
---@param menu? ManagementMenu `job` when left out
---@param data? table
---@return boolean
function CobaltManagementExports:OpenMenu(menu, data) end

---**Server.** Whether each job is open and what it paid out today, from the `jobs` table. A job with no row is open with nothing paid.
---@param names string[]
---@return table<string, ManagementJobStatus> statuses by job name
function CobaltManagementExports:GetJobStatus(names) end

---**Server.** Opens or closes a job; city hall stops starting shifts for a closed one. False when the name or flag is invalid.
---@param name string
---@param open boolean
---@return boolean
function CobaltManagementExports:SetJobOpen(name, open) end

---**Server.** Adds a payout to the job's total for today, which starts over at midnight, server time. False when the name or amount is invalid.
---@param name string
---@param amount integer whole dollars above 0
---@return boolean
function CobaltManagementExports:AddJobPayout(name, amount) end

exports.cobalt_management = CobaltManagementExports
