--!strict
-- CmdrInterface glue. Builds the UI, initialises the Window controller, wires
-- up the AutoComplete, and registers the text-change / submission handlers
-- against Cmdr.Dispatcher. Kept structurally close to evaera/Cmdr so that
-- hooks / commands behave identically.

local Players = game:GetService("Players")
local Player = Players.LocalPlayer

local Theme = require(script.Parent:WaitForChild("Theme"))
local UIBuilder = require(script.Parent:WaitForChild("UIBuilder"))

return function(Cmdr: any)
	local Util = Cmdr.Util

	-- Build the GUI tree and parent into PlayerGui
	local refs = UIBuilder.Build(Player.Name)
	refs.Gui.Parent = Player:WaitForChild("PlayerGui")
	Cmdr._refs = refs

	-- Initialise the live theme application (UIBuilder.ApplyTheme is called in
	-- the subscription callback set up by Window.Init).
	UIBuilder.ApplyTheme(refs, Theme.Current)

	local Window = require(script:WaitForChild("Window")).Init(refs, Cmdr)
	local AutoComplete = require(script:WaitForChild("AutoComplete"))(Cmdr)
	Window.AutoComplete = AutoComplete

	-- Process a submitted command line
	Window.ProcessEntry = function(text: string)
		text = Util.TrimString(text)
		if #text == 0 then
			return
		end

		Window:AddLine(Window:GetLabel() .. " " .. text, { Color = Theme.Current.Accent })
		local result = Cmdr.Dispatcher:EvaluateAndRun(text, Player, { IsHuman = true })
		if result and result ~= "" then
			Window:AddLine(result)
		end
	end

	-- Update autocomplete as the user types
	Window.OnTextChanged = function(text: string)
		local command = Cmdr.Dispatcher:Evaluate(text, Player, true)
		local arguments = Util.SplitString(text)
		local commandText = table.remove(arguments, 1)
		local atEnd = false
		if command then
			arguments = Util.MashExcessArguments(arguments, #command.Object.Args)
			atEnd = #arguments == #command.Object.Args
		end

		local entryComplete = commandText and #arguments > 0

		if text:sub(#text, #text):match("%s") and not atEnd then
			entryComplete = true
			arguments[#arguments + 1] = ""
		end

		if command and entryComplete then
			local commandValid, errorText = command:Validate()
			Window:SetIsValidInput(commandValid, ("Validation errors: %s"):format(errorText or ""))

			local acItems = {}
			local lastArgument = command:GetArgument(#arguments)
			if lastArgument then
				local typedText = lastArgument.TextSegmentInProgress
				local isPartial = false
				if lastArgument.RawSegmentsAreAutocomplete then
					for i, segment in ipairs(lastArgument.RawSegments) do
						acItems[i] = { segment, segment }
					end
				else
					local items, options = lastArgument:GetAutocomplete()
					options = options or {}
					isPartial = options.IsPartial or false
					for i, item in pairs(items) do
						acItems[i] = { typedText, item }
					end
				end

				local valid = true
				if #typedText > 0 then
					valid, errorText = lastArgument:Validate()
				end

				if not atEnd and valid then
					Window:HideInvalidState()
				end

				return AutoComplete:Show(acItems, {
					at = atEnd and #text - #typedText + (text:sub(#text, #text):match("%s") and -1 or 0),
					prefix = #lastArgument.RawSegments == 1 and lastArgument.Prefix or "",
					isLast = #command.Arguments == #command.ArgumentDefinitions and #typedText > 0,
					numArgs = #arguments,
					command = command,
					arg = lastArgument,
					name = lastArgument.Name .. (lastArgument.Required and "" or "?"),
					type = lastArgument.Type.DisplayName,
					description = (valid == false and errorText) or lastArgument.Object.Description,
					invalid = not valid,
					isPartial = isPartial,
				})
			end
		elseif commandText and #arguments == 0 then
			Window:SetIsValidInput(true)
			local exactCommand = Cmdr.Registry:GetCommand(commandText)
			local exactMatch
			if exactCommand then
				exactMatch = {
					exactCommand.Name,
					exactCommand.Name,
					options = {
						name = exactCommand.Name,
						description = exactCommand.Description,
					},
				}

				local arg = exactCommand.Args and exactCommand.Args[1]
				if type(arg) == "function" then
					arg = arg(command)
				end
				if arg and (not arg.Optional and arg.Default == nil) then
					Window:SetIsValidInput(false, "This command has required arguments.")
					Window:HideInvalidState()
				end
			else
				Window:SetIsValidInput(
					false,
					("%q is not a valid command name. Use the help command to see all available commands."):format(
						commandText
					)
				)
			end

			local acItems = { exactMatch }
			for _, cmd in pairs(Cmdr.Registry:GetCommandNames()) do
				if
					commandText:lower() == cmd:lower():sub(1, #commandText)
					and (exactMatch == nil or exactMatch[1] ~= commandText)
				then
					local commandObject = Cmdr.Registry:GetCommand(cmd)
					acItems[#acItems + 1] = {
						commandText,
						cmd,
						options = {
							name = commandObject.Name,
							description = commandObject.Description,
						},
					}
				end
			end

			return AutoComplete:Show(acItems)
		end

		Window:SetIsValidInput(false, "Use the help command to see all available commands.")
		AutoComplete:Hide()
	end

	Window:UpdateLabel()
	Window:UpdateWindowHeight()

	return {
		Window = Window,
		AutoComplete = AutoComplete,
	}
end
