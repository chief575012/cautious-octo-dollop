--!nonstrict
-- Server-side initialisation. Sets up remotes, replicates the client portion
-- to ReplicatedStorage, and registers the built-in types. Built-in commands
-- are kept server-side under `Server commands` so the client doesn't see their
-- run implementations until requested.
--
-- Unlike evaera/Cmdr we don't parent a ScreenGui to StarterGui — the new
-- client builds its UI in-code, so the StarterGui dance is no longer required.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

return function(cmdr)
	local ReplicatedRoot, RemoteFunction, RemoteEvent

	local function Create(class: string, name: string, parent: Instance?): Instance
		local object = Instance.new(class)
		object.Name = name
		object.Parent = parent or ReplicatedRoot
		return object
	end

	ReplicatedRoot = script.Parent.CmdrClient
	ReplicatedRoot.Parent = ReplicatedStorage

	RemoteFunction = Create("RemoteFunction", "CmdrFunction")
	RemoteEvent = Create("RemoteEvent", "CmdrEvent")

	Create("Folder", "Commands")
	Create("Folder", "Types")

	script.Parent.Shared.Parent = ReplicatedRoot

	cmdr.ReplicatedRoot = ReplicatedRoot
	cmdr.RemoteFunction = RemoteFunction
	cmdr.RemoteEvent = RemoteEvent

	cmdr:RegisterTypesIn(script.Parent.BuiltInTypes)
	script.Parent.BuiltInTypes:Destroy()
	script.Parent.BuiltInCommands.Name = "Server commands"
end
