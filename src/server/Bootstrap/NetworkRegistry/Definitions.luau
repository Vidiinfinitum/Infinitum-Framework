export type RemoteType = "Event" | "Function" | "UnreliableEvent"

export type RemoteDefinition = {
	Name: string,
	Type: RemoteType,
}

local Definitions: {RemoteDefinition} = {
	{
		Name = "Test.Test1",
		Type = "UnreliableEvent",
	},

	{
		Name = "Test.Test2",
		Type = "Event",
	},
}

return Definitions