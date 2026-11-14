local GangAdmin <const> = require 'server.gangs.admin'

local Cobalt <const> = exports.cobalt_core:GetCoreObject()

Cobalt.Commands.Add('admingangs', locale('commands.admingangs.help'), {}, false, function(source)
    if not GangAdmin.allowed(source) then return end

    TriggerClientEvent('cobalt_management:open', source, 'gangAdmin')
end, 'admin')

Cobalt.Commands.Add('gangmenu', locale('commands.gangmenu.help'), {}, false, function(source)
    TriggerClientEvent('cobalt_management:open', source, 'gang')
end, 'user')

local applyArguments <const> = { { name = 'job', help = locale('commands.argument.apply_job') } }

Cobalt.Commands.Add('apply', locale('commands.apply.help'), applyArguments, false, function(source, args)
    TriggerClientEvent('cobalt_management:apply', source, args[1] and tostring(args[1]):lower() or nil)
end, 'user')
