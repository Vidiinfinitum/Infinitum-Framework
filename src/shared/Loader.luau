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
    Critical: boolean?,
    Init: ((self: LoaderModule, loader: Loader) -> (any?))?,
    Start: ((self: LoaderModule, loader: Loader) -> (any?))?,
}

type Loader = typeof(setmetatable(
    {} :: {
        Folder: Folder,
        Modules: {[string]: LoaderModule},
        _loadFailed: {[string]: any},
        _failed: {[string]: any},
    },
    Loader
))

function Loader.new(folder: Folder): Loader
    local self = setmetatable({}, Loader)

    self.Folder = folder
    self.Modules = {}
    self._loadFailed = {}
    self._failed = {}

    return self
end

function Loader:Load()
    return Promise.new(function(resolve)
        for _, moduleScript in self.Folder:GetChildren() do
            if not moduleScript:IsA("ModuleScript") then
                continue
            end

            local success, moduleOrErr = pcall(require, moduleScript)

            if not success then
                warn(("Não foi possível dar require em {%s}: %s"):format(moduleScript:GetFullName(), moduleOrErr))
                self._loadFailed[moduleScript.Name] = moduleOrErr
                continue
            end

            if self.Modules[moduleScript.Name] then
                warn(("Módulo duplicado: {%s}"):format(moduleScript:GetFullName()))
                self._loadFailed[moduleScript.Name] = "Duplicated module"
                continue
            end

            self.Modules[moduleScript.Name] = moduleOrErr
        end

        resolve()
    end)
end

function Loader:Get(moduleName: string)
    return self.Modules[moduleName]
end

function Loader:GetStatus(moduleName: string): "Ready" | "Failed" | "Unknown"
    if self._loadFailed[moduleName] or self._failed[moduleName] then
        return "Failed"
    end

    if not self.Modules[moduleName] then
        return "Unknown"
    end

    return "Ready"
end

function Loader:_runPhase(phaseName: "Init" | "Start")
    local promises = {}

    for name, module in self.Modules do
        local fn = module[phaseName]

        if not fn or typeof(fn) ~= "function" then
            continue
        end

        local promise = Promise.new(function(resolve)
            local success, result = pcall(fn, module, self)

            if not success then
                warn(("Erro ao dar %s em {%s}: {%s}"):format(phaseName, name, result))
                self._failed[name] = result
                resolve()
                return
            end

            if Promise.is(result) then
                result
                    :andThen(function()
                        resolve()
                    end)
                    :catch(function(err)
                        warn(("Erro assíncrono em {%s}:%s -> {%s}"):format(name, phaseName, err))
                        self._failed[name] = err
                        resolve()
                    end)
            else
                resolve()
            end
        end)

        table.insert(promises, promise)
    end

    return Promise.all(promises)
end

function Loader:Init()
    return self:_runPhase("Init")
end

function Loader:Start()
    return self:_runPhase("Start")
end

function Loader:Boot()
    return self:Load()
        :andThen(function()
            return self:Init()
        end)
        :andThen(function()
            return self:Start()
        end)
        :andThen(function()
            if next(self._loadFailed) then
                local names = {}

                for name in self._loadFailed do
                    table.insert(names, name)
                end

                return Promise.reject(
                    ("Falha ao carregar módulo(s): %s"):format(table.concat(names, ", "))
                )
            end

            for name, err in self._failed do
                local module = self.Modules[name]

                if module and module.Critical then
                    return Promise.reject(
                        ("Módulo crítico falhou: {%s} -> {%s}"):format(name, err)
                    )
                end
            end
        end)
end

return Loader