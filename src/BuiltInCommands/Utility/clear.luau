return {
	Name = "clear",
	Aliases = {},
	Description = "Clear all lines above the entry line of the Cmdr window.",
	Group = "DefaultUtil",
	Args = {},
	ClientRun = function(context)
		local refs = context.Cmdr._refs
		if not refs or not refs.Output then
			return ""
		end

		for _, child in ipairs(refs.Output:GetChildren()) do
			if child.Name == "Line" and child:IsA("TextLabel") then
				child:Destroy()
			end
		end

		refs.Output.CanvasPosition = Vector2.zero
		return ""
	end,
}
