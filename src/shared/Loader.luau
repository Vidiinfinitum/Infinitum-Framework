--!strict

-- Game Services --
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages -- 
local Packages = ReplicatedStorage.Packages

-- Promise Library --
local Promise = require(Packages.Promise)

local Loader = {}
Loader.__index = Loader

type LoaderModule = {
    [string]: any,
    Init: ((self: LoaderModule, loader: Loader) -> ())?,
    Start: ((self: LoaderModule, loader: Loader) -> ())?,
}

type Loader = typeof(setmetatable(
	{} :: {
		Folder: Folder,
		Modules: {[string]: LoaderModule},
	},
	Loader
))
    

function Loader.new(folder: Folder): Loader
    local self = setmetatable({}, Loader)

    self.Folder = folder
    self.Modules = {}

    return self
end

function Loader:Load()
    return Promise.new(function(resolve, reject)
        for _, moduleScript in self.Folder:GetChildren() do
            if not moduleScript:IsA("ModuleScript") then
                continue
            end

            local success, module = pcall(require, moduleScript)

            if not success then
                reject(("Not possible no require {%s}: %s"):format(moduleScript:GetFullName(), module))
                return
            end

            if self.Modules[moduleScript.Name] then
                reject(("Duplicated module: {%s}"):format(moduleScript:GetFullName()))
                return
            end

            self.Modules[moduleScript.Name] = module
        end

        resolve()
    end)
end

function Loader:Get(moduleName: string)
    return self.Modules[moduleName]
end

function Loader:Init()
    return Promise.new(function(resolve, reject)
        for name, module in self.Modules do
            if not module.Init or typeof(module.Init) ~= "function" then
                warn(("%s does not have Init method"):format(name))
                continue
            end

            local success, err = pcall(function(...)
                module:Init(self)
            end)

            if not success then
                reject(("Error while trying to Init {%s}: {%s}"):format(name, err))
                return
            end
        end

        resolve()
    end)
end

function Loader:Start()
    return Promise.new(function(resolve, reject)
        for name, module in self.Modules do
            if not module.Start or typeof(module.Start) ~= "function" then
                warn(("%s does not have Start method"):format(name))
                continue
            end

            local success, err = pcall(function(...)
                module:Start()
            end)

            if not success then
                reject(("Error while trying to Start {%s}: {%s}"):format(name, err))
                return
            end

        end

        resolve()
    end)
end

function Loader:Boot()
    return self:Load()
        :andThen(function()
            return self:Init()
        end)
        :andThen(function()
            return self:Start()
        end)
end

return Loader