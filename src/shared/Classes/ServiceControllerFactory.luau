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

function ServiceControllerFactory.new(name: string): {[string]: any}
    assert(RunService:IsServer() or RunService:IsClient(), "ServiceControllerFactory.new chamado em contexto inválido")

    return {
        Name = name,
        Trove = Trove.new(),
        Net = Net,
        EventBus = EventBus,
    }
end

return ServiceControllerFactory