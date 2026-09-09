-- Game Services --
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Signal --
local Signal = require(ReplicatedStorage.Packages.GoodSignal)

return {
    Data = {
        Changed = Signal.new()
    }
}