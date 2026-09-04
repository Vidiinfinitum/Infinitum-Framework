-- Game Services --
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Signal --
local Signal = require(ReplicatedStorage.Packages.GoodSignal)

return {
    Test = Signal.new()
}