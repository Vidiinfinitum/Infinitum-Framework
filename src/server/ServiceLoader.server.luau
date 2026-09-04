-- Game Services --
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- Loader Module --
local Loader = require(ReplicatedStorage.Shared.Loader)

-- Network Registry Module --
local NetworkRegistry = require(ServerScriptService.Server.Bootstrap.NetworkRegistry)

-- Services Folder --
local ServicesFolder = ServerScriptService.Server.Services

-- Create the Loader object
local loader = Loader.new(ServicesFolder)

-- Boot the Network --
NetworkRegistry:Boot()

-- Boot the Loader --
loader:Boot()
    :catch(function(err)
       warn(("[ServerLoader] failed to boot: {%s}"):format(err))
    end)
