-- Game Services --
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Client --
local Client = script.Parent

-- Loader --
local Loader = require(ReplicatedStorage.Shared.Loader)

-- ControllersFolder --
local ControllersFolder = Client.ControllerLoader

-- Create the Loader object
local loader = Loader.new(ControllersFolder)

-- Boot the Loader --
loader:Boot()
    :catch(function(err)
       warn(("[ServerLoader] failed to boot: {%s}"):format(err))
    end)