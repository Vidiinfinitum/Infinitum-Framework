--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Definitions = require(script.Definitions)

type NetworkRegistry = {
    RemotesFolder: Folder,

    -- Public --
    Boot: (self: NetworkRegistry) -> (),

    -- Private --
    _CreateRemotesFolder: (self: NetworkRegistry) -> Folder,
    _RegisterDefinitions: (self: NetworkRegistry) -> (),
    _CreateRemote: (self: NetworkRegistry, definition: Definitions.RemoteDefinition) -> (),
}

local NetworkRegistry = {} :: NetworkRegistry

local REMOTES_FOLDER_NAME = "Remotes"

local REMOTE_CLASSES: {[Definitions.RemoteType]: string} = {
	Event = "RemoteEvent",
	Function = "RemoteFunction",
	UnreliableEvent = "UnreliableRemoteEvent",
}

-- Public --

function NetworkRegistry:Boot()
	self.RemotesFolder = self:_CreateRemotesFolder()
	self:_RegisterDefinitions()
end

-- Private --

function NetworkRegistry:_CreateRemotesFolder(): Folder
	local networkFolder = ReplicatedStorage.Shared.Network

	local folder = networkFolder:FindFirstChild(REMOTES_FOLDER_NAME)

	if folder then
		if not folder:IsA("Folder") then
			error(
				("%s already exists but is not a Folder")
					:format(REMOTES_FOLDER_NAME)
			)
		end

		return folder
	end

	local newFolder = Instance.new("Folder")
	newFolder.Name = REMOTES_FOLDER_NAME
	newFolder.Parent = networkFolder

	return newFolder
end

function NetworkRegistry:_RegisterDefinitions()
	for _, definition: Definitions.RemoteDefinition in Definitions do
		self:_CreateRemote(definition)
	end
end

function NetworkRegistry:_CreateRemote(definition: Definitions.RemoteDefinition)
	local segments = string.split(definition.Name, ".")
	local current: Folder = self.RemotesFolder

	for index, segment in segments do
		local existing = current:FindFirstChild(segment)
		local isLast = index == #segments

		if existing then
			if isLast then
				local expectedClass = REMOTE_CLASSES[definition.Type]

				if not existing:IsA(expectedClass) then
					error(
						("Remote '%s' exists as %s, expected %s")
							:format(
								definition.Name,
								existing.ClassName,
								expectedClass
							)
					)
				end
			else
				if not existing:IsA("Folder") then
					error(
						("'%s' is not a Folder")
							:format(existing:GetFullName())
					)
				end

				current = existing
			end

			continue
		end

		if isLast then
			local className = REMOTE_CLASSES[definition.Type]

			local remote = Instance.new(className)
			remote.Name = segment
			remote.Parent = current
		else
			local folder = Instance.new("Folder")
			folder.Name = segment
			folder.Parent = current

			current = folder
		end
	end
end

return NetworkRegistry