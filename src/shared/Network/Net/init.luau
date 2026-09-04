--!strict

-- Game Services --
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Network --
local Network = ReplicatedStorage.Shared.Network
local RemotesFolder = Network:WaitForChild("Remotes")

-- Promises --
local Promise = require(ReplicatedStorage.Packages.Promise)

local Net = {}

Net._Cache = {}

-- Private --

function Net:_GetRemote(remoteName: string): RemoteEvent | RemoteFunction | UnreliableRemoteEvent
    local cachedRemote = self._Cache[remoteName]

    if cachedRemote then
        return cachedRemote
    end

    local current: Instance = RemotesFolder

    for index, segment in string.split(remoteName) do
        local child = current:FindFirstChild(segment)

        if not child then
            error(("Remote {%s} was not found"):format(remoteName))
        end

        current = child
    end

    if not(current:IsA("RemoteEvent") or current:IsA("RemoteFunction") or current:IsA("UnreliableRemoteEvent")) then
        error(("{%s} is not a valid remote"):format(remoteName))
    end

    self._Cache[remoteName] = current

    return current
end

-- Public --

function Net:FireServer(remoteName: string, ...: any)
    assert(RunService:IsClient(), "FireServer() can only be fired from client!")

    local remote = self:_GetRemote(remoteName)

    assert(remote:IsA("RemoteEvent") or remote:IsA("UnreliableRemoteEvent"), ("{%s} is not an Event"):format(remoteName))

    remote:FireServer(...)
end

function Net:FireClient(player: Player, remoteName: string, ...: any)
    assert(RunService:IsServer(), "FireClient() can only be fired from server!")

    local remote = self:_GetRemote(remoteName)

    assert(remote:IsA("RemoteEvent") or remote:IsA("UnreliableRemoteEvent"), ("{%s} is not an Event"):format(remoteName))

    remote:FireClient(player, ...)
end

function Net:FireAllClient(remoteName: string, ...: any)
     assert(RunService:IsServer(), "FirAllClients() can only be fired from server!")

    local remote = self:_GetRemote(remoteName)

    assert(remote:IsA("RemoteEvent") or remote:IsA("UnreliableRemoteEvent"), ("{%s} is not an Event"):format(remoteName))

    remote:FireClient(...)
end

function Net:InvokeServer(remoteName: string, ...: any)
    assert(RunService:IsClient(), "InvokeServer() can only be fired from client!")

    local remote = self:_GetRemote(remoteName)

    assert(remote:IsA("RemoteFunction"), ("{%s} is not a Function"):format(remoteName))

    local args = table.pack(...)

    return Promise.try(function()
        return remote:InvokeServer(table.unpack(args, 1, args.n))
    end)
end

function Net:InvokeClient(player: Player, remoteName: string, ...: any)
    assert(RunService:IsServer(), "InvokeClient() can only be fired from server!")

    local remote = self:_GetRemote(remoteName)

    assert(remote:IsA("RemoteFunction"), ("{%s} is not a Function"):format(remoteName))

    local args = table.pack(...)

    return Promise.try(function()
        return remote:InvokeClient(player, table.unpack(args, 1, args.n))
    end)
end

function Net:OnEvent(remoteName: string, callback: (...any) -> ())
    local remote = self:_GetRemote(remoteName)

    assert(remote:IsA("RemoteEvent") or remote:IsA("UnreliableRemoteEvent"), ("{%s} is not an Event"):format(remoteName))

    if RunService:IsServer() then
        return remote.OnServerEvent:Connect(callback)
    elseif RunService:IsClient() then
        return remote.OnClientEvent:Connect(callback)
    end
end

function Net:OnInvoke(remoteName: string, callback: (...any) -> ())
    local remote = self:_GetRemote(remoteName)

    assert(remote:IsA("RemoteFunction"), ("{%s} is not a Function"):format(remoteName))

    if RunService:IsServer() then
        remote.OnServerInvoke = callback
    elseif RunService:IsClient() then
        remote.OnClientInvoke = callback
    end
end

return Net

