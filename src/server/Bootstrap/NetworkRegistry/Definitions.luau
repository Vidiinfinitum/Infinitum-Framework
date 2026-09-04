--!strict

export type RemoteType = "Event" | "Function" | "UnreliableEvent"

export type RemoteDefinition = {
	Name: string,
	Type: RemoteType,
}

local Definitions: {RemoteDefinition} = {
	{
		Name = "PlayerMovement.Update",
		Type = "UnreliableEvent",
	},

	{
		Name = "PlayerLifecycle.PlayerDied",
		Type = "Event",
	},
}

return Definitions