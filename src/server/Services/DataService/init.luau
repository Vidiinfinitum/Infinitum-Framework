-- Game Services --
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Service Factory --
local ServiceControllerFactory = require(ReplicatedStorage.Shared.Classes.ServiceControllerFactory)

-- ProfileStore --
local ProfileStore = require(ServerScriptService.ServerPackages.ProfileStore)

-- Template --
local Template = require(script.Template)

local DataService = ServiceControllerFactory.new("DataService")

-- Aux Functions --
local function GetStoreName()
    return RunService:IsStudio() and "Test" or "Live"
end

local function SplitPath(path: string): {string}
    return string.split(path, ".")
end

-- Boot --

function DataService:Init(loader)
    self._store = ProfileStore.New(GetStoreName(), Template)
    self._profiles = {} -- player -> profile
end

function DataService:Start()
    self.Trove:Connect(Players.PlayerAdded, function(player)
        self:_LoadProfile(player)
    end)

    self.Trove:Connect(Players.PlayerRemoving, function(player)
        local profile = self._profiles[player]
        if not profile then return end
        profile:EndSession()
        self._profiles[player] = nil
    end)

    for _, player in Players:GetPlayers() do
        task.spawn(function() self:_LoadProfile(player) end)
    end
end

-- Private --

function DataService:_LoadProfile(player: Player)
    local profile = self._store:StartSessionAsync("Player_" .. player.UserId, {
        Cancel = function() return player.Parent ~= Players end,
    })

    if not profile then
        player:Kick("An error occurred, please rejoin the game.")
        return
    end

    profile:AddUserId(player.UserId)
    profile:Reconcile()

    profile.OnSessionEnd:Connect(function()
        self._profiles[player] = nil
        player:Kick("An error occurred, please rejoin the game.")
    end)

    if player.Parent ~= Players then
        profile:EndSession()
        return
    end

    self._profiles[player] = profile
end

-- Public API --

-- Devolve o objeto Profile inteiro do player (não só a Data), incluindo metadata do ProfileStore.
function DataService:GetProfile(player: Player)
    return self._profiles[player]
end

-- Devolve a Data inteira do player de uma vez (sem navegar por path). Útil para sincronizar
-- tudo de uma vez com o cliente, ex: no join.
function DataService:GetAll(player: Player): {[string]: any}?
    local profile = self._profiles[player]
    return profile and profile.Data
end

-- Generic Methods (Use for Dictionary, Lists and values: number, string, bool)

-- Lê o valor em qualquer path, seja ele um valor solto, uma lista ou um dicionário.
-- Devolve nil se qualquer parte do caminho não existir.
function DataService:Get(player: Player, path: string): any
    local profile = self._profiles[player]
    if not profile then return nil end

    local current: any = profile.Data
    for _, key in SplitPath(path) do
        if type(current) ~= "table" then return nil end
        current = current[key]
    end
    return current
end

-- Igual ao Get, mas devolve um valor padrão (fornecido por quem chama) em vez de nil
-- quando o path não existe.
function DataService:GetOrDefault(player: Player, path: string, default: any): any
    local value = self:Get(player, path)
    if value == nil then
        return default
    end
    return value
end

-- Escreve um valor em qualquer path (solto, lista ou dicionário), criando as tabelas
-- intermediárias que faltarem. Sobrescreve totalmente o que já estava naquele path.
-- Dispara EventBus.Server.Data.Changed avisando quem mudou.
function DataService:Set(player: Player, path: string, value: any)
	local profile = self._profiles[player]
	if not profile then return end

	local parts = SplitPath(path)
	local lastKey = table.remove(parts)
	local current = profile.Data

	for _, key in parts do
		if current[key] == nil then
			current[key] = {}
		elseif type(current[key]) ~= "table" then
			error(`Set: "{key}" in "{path}" not a table`)
		end

		current = current[key]
	end

	current[lastKey] = value

	self.EventBus.Server.Data.Changed:Fire(player, path, value)
end

-- Lê o valor atual de um path, aplica a função de transformação recebida, e salva o
-- resultado de volta no mesmo path. Base genérica usada por Increment, Insert, RemoveValue,
-- SetKey e RemoveKey.
function DataService:Update(player: Player, path: string, transformFn: (any) -> any): any
    local current = self:Get(player, path)
    local newValue = transformFn(current)
    self:Set(player, path, newValue)
    return newValue
end

-- Apaga a chave inteira daquele path (funciona pra remover um valor solto, uma lista
-- inteira ou um dicionário inteiro). O "pai" continua existindo, só aquela chave some.
function DataService:Remove(player: Player, path: string)
    local profile = self._profiles[player]
    if not profile then return end

    local parts = SplitPath(path)
    local lastKey = table.remove(parts)
    local current = profile.Data

    for _, key in parts do
        if type(current) ~= "table" then return end
        current = current[key]
    end

    if type(current) ~= "table" then return end
    current[lastKey] = nil

    self.EventBus.Server.Data.Changed:Fire(player, path, nil)
end

-- Verifica se existe algo (não-nil) naquele path, seja valor solto, lista ou dicionário.
function DataService:Has(player: Player, path: string): boolean
    return self:Get(player, path) ~= nil
end

-- Method to increment a number amount to a data path 

-- Soma (ou subtrai, se amount for negativo) um número guardado naquele path.
-- Só funciona para valores soltos do tipo number.
function DataService:Increment(player: Player, path: string, amount: number): number
    return self:Update(player, path, function(current)
        local value = current or 0
        assert(type(value) == "number", `Increment: value in "{path}" not a number`)
        return value + amount
    end)
end

-- List methods (only works for list table) 

-- Adiciona um valor no final da lista naquele path (cria a lista se ainda não existir).
function DataService:Insert(player: Player, path: string, value: any)
    self:Update(player, path, function(list)
        list = list or {}
        assert(type(list) == "table", `Insert: value in "{path}" needs to be a table`)
        table.insert(list, value)
        return list
    end)
end

-- Procura e remove a primeira ocorrência de um valor dentro da lista naquele path.
-- Devolve true/false avisando se algo foi de fato removido.
function DataService:RemoveValue(player: Player, path: string, value: any): boolean
    local removed = false

    self:Update(player, path, function(list)
        if type(list) ~= "table" then return list end
        for i, v in list do
            if v == value then
                table.remove(list, i)
                removed = true
                break
            end
        end
        return list
    end)

    return removed
end

-- Verifica se um valor específico existe dentro da lista naquele path.
function DataService:Contains(player: Player, path: string, value: any): boolean
    local list = self:Get(player, path)
    if type(list) ~= "table" then return false end

    for _, v in list do
        if v == value then
            return true
        end
    end

    return false
end

-- Dictionary methods (only works in dictionaries)

-- Adiciona ou atualiza uma entrada (key -> value) de um dicionário naquele path,
-- sem apagar as outras chaves que já existiam.
function DataService:SetKey(player: Player, path: string, key: string, value: any)
    self:Update(player, path, function(dict)
        dict = dict or {}
        assert(type(dict) == "table", `SetKey: value in "{path}" is not a table`)
        dict[key] = value
        return dict
    end)
end

-- Remove uma entrada específica de um dicionário naquele path, mantendo as demais chaves.
function DataService:RemoveKey(player: Player, path: string, key: string)
    self:Update(player, path, function(dict)
        if type(dict) ~= "table" then return dict end
        dict[key] = nil
        return dict
    end)
end

-- Verifica se uma chave específica existe dentro do dicionário naquele path.
function DataService:HasKey(player: Player, path: string, key: string): boolean
    local dict = self:Get(player, path)
    return type(dict) == "table" and dict[key] ~= nil
end

-- Devolve uma lista com todas as chaves de um dicionário naquele path (sem ordem garantida).
-- Útil para enumerar tudo que o player possui sem saber os nomes de antemão.
function DataService:GetKeys(player: Player, path: string): {string}
    local dict = self:Get(player, path)
    if type(dict) ~= "table" then return {} end

    local keys = {}
    for key in dict do
        table.insert(keys, key)
    end
    return keys
end

-- List and Dictionary method (Works for Lists or Dictionaries)

-- Conta quantos itens existem numa lista ou quantas chaves existem num dicionário naquele path.
function DataService:Count(player: Player, path: string): number
    local value = self:Get(player, path)
    if type(value) ~= "table" then return 0 end

    local count = 0
    for _ in value do
        count += 1
    end
    return count
end

return DataService
