-- Game Services --
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Trove --
local Trove = require(ReplicatedStorage.Packages.Trove)

-- Net -- 
local Net = require(ReplicatedStorage.Shared.Network.Net)

-- EventBus --
local EventBus = require(ReplicatedStorage.Shared.EventBus)

local ServiceControllerFactory = {}

local _createdNames: {[string]: boolean} = {}

function ServiceControllerFactory.new(name: string): {[string]: any}
    assert(RunService:IsServer() or RunService:IsClient(), "ServiceControllerFactory.new called in invalid context")
    assert(not _createdNames[name], ("Already exists an Service/Controller with name: {%s}"):format(name))

    _createdNames[name] = true

    return {
        Name = name,
        Trove = Trove.new(),
        Net = Net,
        EventBus = EventBus,
    }
end

return ServiceControllerFactory