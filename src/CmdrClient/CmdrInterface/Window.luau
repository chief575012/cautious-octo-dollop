--!nonstrict
-- Window controller for CmdrPlus. Operates on a `refs` tree from UIBuilder.
-- Responsibilities: visibility/animation, input handling, output rendering,
-- history traversal, theme subscription, mobile keyboard inset.

local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local TextChatService = game:GetService("TextChatService")
local Players = game:GetService("Players")

local Theme = require(script.Parent.Parent:WaitForChild("Theme"))
local UIBuilder = require(script.Parent.Parent:WaitForChild("UIBuilder"))

local Player = Players.LocalPlayer
local MOUSE_TOUCH_ENUM = { Enum.UserInputType.MouseButton1, Enum.UserInputType.MouseButton2, Enum.UserInputType.Touch }
local SHOW_TWEEN = TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local HIDE_TWEEN = TweenInfo.new(0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
local INVALID_FLASH = TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)

export type WindowController = {
	Cmdr: any,
	AutoComplete: any,
	Refs: any,
	ProcessEntry: ((string) -> ())?,
	OnTextChanged: ((string) -> ())?,
	Valid: boolean,
	_errorText: string?,
	HistoryState: any,

	UpdateLabel: (self: WindowController) -> (),
	UpdateWindowHeight: (self: WindowController) -> (),
	AddLine: (self: WindowController, text: any, options: any?) -> (),
	IsVisible: (self: WindowController) -> boolean,
	SetVisible: (self: WindowController, visible: boolean) -> (),
	Hide: (self: WindowController) -> (),
	Show: (self: WindowController) -> (),
	SetEntryText: (self: WindowController, text: string) -> (),
	GetEntryText: (self: WindowController) -> string,
	GetLabel: (self: WindowController) -> string,
	SetIsValidInput: (self: WindowController, isValid: boolean, errorText: string?) -> (),
	HideInvalidState: (self: WindowController) -> (),
	LoseFocus: (self: WindowController, submit: boolean) -> (),
	TraverseHistory: (self: WindowController, delta: number) -> (),
	ClearHistoryState: (self: WindowController) -> (),
	SelectVertical: (self: WindowController, delta: number) -> (),
	BeginInput: (self: WindowController, input: InputObject, gameProcessed: boolean) -> (),
	HandleAction: (self: WindowController, action: string) -> (),
}

local Window = {} :: WindowController
Window.Valid = true

-- Convenience: get the bottom label that gets prefixed onto echoed commands.
function Window:GetLabel(): string
	local placeName = self.Cmdr.PlaceName
	if placeName and placeName ~= "" then
		return ("%s@%s ›"):format(Player.Name, placeName)
	end
	return ("%s ›"):format(Player.Name)
end

function Window:UpdateLabel(): ()
	self.Refs.Prompt.Text = self:GetLabel()
end

function Window:UpdateWindowHeight(): ()
	-- Nothing to do — Container is sized by Root which is fixed; Output uses
	-- AutomaticCanvasSize. We just scroll to bottom.
	local output = self.Refs.Output
	output.CanvasPosition = Vector2.new(0, math.max(0, output.AbsoluteCanvasSize.Y - output.AbsoluteSize.Y))
end

function Window:AddLine(text: any, options: any?): ()
	options = options or {}
	text = tostring(text)

	if typeof(options) == "Color3" then
		options = { Color = options }
	end

	if #text == 0 then
		self:UpdateWindowHeight()
		return
	end

	local theme = Theme.Current
	local str = self.Cmdr.Util.EmulateTabstops(text, 8)
	local line = self.Refs.LineTemplate:Clone()
	line.Name = "Line"
	line.Text = str
	line.TextColor3 = options.Color or theme.Text
	line.RichText = options.RichText or false
	line.LayoutOrder = self._lineCount or 0
	self._lineCount = (self._lineCount or 0) + 1
	line.Parent = self.Refs.Output

	-- Defer the scroll to next frame so AutomaticCanvasSize has settled
	task.defer(function()
		self:UpdateWindowHeight()
	end)
end

function Window:IsVisible(): boolean
	return self._visible == true
end

function Window:SetVisible(visible: boolean): ()
	local refs = self.Refs
	local root = refs.Root

	if visible == self._visible then
		return
	end
	self._visible = visible

	if visible then
		root.Visible = true
		root.Position = UDim2.new(0.5, 0, 0, -10)
		TweenService:Create(root, SHOW_TWEEN, {
			Position = UDim2.new(0.5, 0, 0, 24),
		}):Play()

		-- Chat takeover (matches Cmdr behaviour so chat doesn't intercept text)
		self.PreviousChatWindowConfigurationEnabled = TextChatService.ChatWindowConfiguration.Enabled
		self.PreviousChatInputBarConfigurationEnabled = TextChatService.ChatInputBarConfiguration.Enabled
		self.PreviousChannelTabsConfigurationEnabled = TextChatService.ChannelTabsConfiguration.Enabled
		TextChatService.ChatWindowConfiguration.Enabled = false
		TextChatService.ChatInputBarConfiguration.Enabled = false
		TextChatService.ChannelTabsConfiguration.Enabled = false

		refs.TextBox:CaptureFocus()
		self:SetEntryText("")

		if self.Cmdr.ActivationUnlocksMouse then
			self.PreviousMouseBehavior = UserInputService.MouseBehavior
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		end

		-- Show mobile bar on touch
		if UserInputService.TouchEnabled and self.Cmdr.MobileToggleEnabled then
			refs.MobileBar.Visible = true
			refs.MobileToggle.Visible = false
		end
	else
		local tween = TweenService:Create(root, HIDE_TWEEN, {
			Position = UDim2.new(0.5, 0, 0, -10),
		})
		tween.Completed:Connect(function()
			if not self._visible then
				root.Visible = false
				root.Position = UDim2.new(0.5, 0, 0, 24)
			end
		end)
		tween:Play()

		TextChatService.ChatWindowConfiguration.Enabled = if self.PreviousChatWindowConfigurationEnabled ~= nil
			then self.PreviousChatWindowConfigurationEnabled
			else true
		TextChatService.ChatInputBarConfiguration.Enabled = if self.PreviousChatInputBarConfigurationEnabled ~= nil
			then self.PreviousChatInputBarConfigurationEnabled
			else true
		TextChatService.ChannelTabsConfiguration.Enabled = if self.PreviousChannelTabsConfigurationEnabled ~= nil
			then self.PreviousChannelTabsConfigurationEnabled
			else true

		refs.TextBox:ReleaseFocus()
		self.AutoComplete:Hide()

		if self.PreviousMouseBehavior then
			UserInputService.MouseBehavior = self.PreviousMouseBehavior
			self.PreviousMouseBehavior = nil
		end

		refs.MobileBar.Visible = false
		if UserInputService.TouchEnabled and self.Cmdr.MobileToggleEnabled then
			refs.MobileToggle.Visible = true
		end
	end
end

function Window:Hide(): ()
	return self:SetVisible(false)
end

function Window:Show(): ()
	return self:SetVisible(true)
end

function Window:SetEntryText(text: string): ()
	local box = self.Refs.TextBox
	box.Text = text
	if self:IsVisible() then
		box:CaptureFocus()
		box.CursorPosition = #text + 1
		self:UpdateWindowHeight()
	end
end

function Window:GetEntryText(): string
	return (self.Refs.TextBox.Text:gsub("\t", ""))
end

function Window:SetIsValidInput(isValid: boolean, errorText: string?): ()
	local theme = Theme.Current
	local box = self.Refs.TextBox
	if isValid then
		box.TextColor3 = theme.TextStrong
	else
		-- flash to error then settle on muted error
		TweenService:Create(box, INVALID_FLASH, { TextColor3 = theme.Error }):Play()
	end
	self.Valid = isValid
	self._errorText = errorText
end

function Window:HideInvalidState(): ()
	self.Refs.TextBox.TextColor3 = Theme.Current.TextStrong
end

function Window:LoseFocus(submit: boolean): ()
	local refs = self.Refs
	local text = refs.TextBox.Text

	self:ClearHistoryState()

	if self:IsVisible() and not GuiService.MenuIsOpen and not UserInputService.TouchEnabled then
		refs.TextBox:CaptureFocus()
	elseif GuiService.MenuIsOpen and self:IsVisible() then
		self:Hide()
	end

	if submit and self.Valid then
		task.wait()
		self:SetEntryText("")
		if self.ProcessEntry then
			self.ProcessEntry(text)
		end
	elseif submit then
		self:AddLine(self._errorText or "Invalid input", { Color = Theme.Current.Error })
	end
end

function Window:TraverseHistory(delta: number): ()
	local history = self.Cmdr.Dispatcher:GetHistory()

	if self.HistoryState == nil then
		self.HistoryState = {
			Position = #history + 1,
			InitialText = self:GetEntryText(),
		}
	end

	self.HistoryState.Position = math.clamp(self.HistoryState.Position + delta, 1, #history + 1)

	self:SetEntryText(
		self.HistoryState.Position == #history + 1 and self.HistoryState.InitialText
			or history[self.HistoryState.Position]
	)
end

function Window:ClearHistoryState(): ()
	self.HistoryState = nil
end

function Window:SelectVertical(delta: number): ()
	if self.AutoComplete:IsVisible() and not self.HistoryState then
		self.AutoComplete:Select(delta)
	else
		self:TraverseHistory(delta)
	end
end

-- Centralised "action" dispatcher used by the keyboard and by the mobile bar.
function Window:HandleAction(action: string): ()
	if action == "Up" then
		self:SelectVertical(-1)
	elseif action == "Down" then
		self:SelectVertical(1)
	elseif action == "Hide" then
		self:Hide()
	elseif action == "Submit" then
		local text = self:GetEntryText()
		if self.Valid and #text > 0 then
			self:SetEntryText("")
			if self.ProcessEntry then
				self.ProcessEntry(text)
			end
		end
	elseif action == "Tab" then
		local item = self.AutoComplete:GetSelectedItem()
		local text = self:GetEntryText()
		if item and not (text:sub(#text, #text):match("%s") and self.AutoComplete.LastItem) then
			local replace = item[2]
			local newText: string
			local insertSpace = true
			local command = self.AutoComplete.Command

			if command then
				local lastArg = self.AutoComplete.Arg
				newText = command.Alias
				insertSpace = self.AutoComplete.NumArgs ~= #command.ArgumentDefinitions
					and self.AutoComplete.IsPartial == false

				local args = command.Arguments
				for i = 1, #args do
					local arg = args[i]
					local segments = arg.RawSegments
					if arg == lastArg then
						segments[#segments] = replace
					end

					local argText = arg.Prefix .. table.concat(segments, ",")
					if argText:find(" ") or argText == "" then
						argText = ("%q"):format(argText)
					end

					newText = ("%s %s"):format(newText, argText)
					if arg == lastArg then
						break
					end
				end
			else
				newText = replace
			end
			self:SetEntryText(newText .. (insertSpace and " " or ""))
		end
	end
end

local lastPressTime = 0
local pressCount = 0
function Window:BeginInput(input: InputObject, gameProcessed: boolean): ()
	if GuiService.MenuIsOpen then
		self:Hide()
	end

	if gameProcessed and self:IsVisible() == false then
		return
	end

	if self.Cmdr.ActivationKeys[input.KeyCode] then
		if self.Cmdr.MashToEnable and not self.Cmdr.Enabled then
			if tick() - lastPressTime < 1 then
				if pressCount >= 5 then
					return self.Cmdr:SetEnabled(true)
				else
					pressCount = pressCount + 1
				end
			else
				pressCount = 1
			end
			lastPressTime = tick()
		elseif self.Cmdr.Enabled then
			self:SetVisible(not self:IsVisible())
			task.wait()
			self:SetEntryText("")

			if GuiService.MenuIsOpen then
				self:Hide()
			end
		end
		return
	end

	if self.Cmdr.Enabled == false or not self:IsVisible() then
		if self:IsVisible() then
			self:Hide()
		end
		return
	end

	if self.Cmdr.HideOnLostFocus and table.find(MOUSE_TOUCH_ENUM, input.UserInputType) then
		local root = self.Refs.Root
		local ac = self.Refs.Autocomplete
		local bar = self.Refs.MobileBar
		local toggle = self.Refs.MobileToggle
		local ps = input.Position
		local function inside(obj: GuiObject): boolean
			local ap = obj.AbsolutePosition
			local as = obj.AbsoluteSize
			return ps.X >= ap.X and ps.X <= ap.X + as.X and ps.Y >= ap.Y and ps.Y <= ap.Y + as.Y
		end
		if
			not inside(root)
			and (not ac.Visible or not inside(ac))
			and (not bar.Visible or not inside(bar))
			and (not toggle.Visible or not inside(toggle))
		then
			self:Hide()
		end
	elseif input.KeyCode == Enum.KeyCode.Down then
		self:HandleAction("Down")
	elseif input.KeyCode == Enum.KeyCode.Up then
		self:HandleAction("Up")
	elseif input.KeyCode == Enum.KeyCode.Return then
		task.wait()
		self:SetEntryText(self:GetEntryText():gsub("\n", ""):gsub("\r", ""))
	elseif input.KeyCode == Enum.KeyCode.Tab then
		task.wait()
		self:HandleAction("Tab")
		self:SetEntryText(self:GetEntryText())
	else
		self:ClearHistoryState()
	end
end

-- Initialise the controller against a built refs tree.
function Window.Init(refs: any, cmdr: any): WindowController
	Window.Refs = refs
	Window.Cmdr = cmdr
	Window._lineCount = 0
	Window._visible = false

	-- Theme application is live
	Theme.Subscribe(function(theme)
		UIBuilder.ApplyTheme(refs, theme)
	end)

	refs.TextBox.FocusLost:Connect(function(submit)
		return Window:LoseFocus(submit)
	end)

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		return Window:BeginInput(input, gameProcessed)
	end)

	refs.TextBox:GetPropertyChangedSignal("Text"):Connect(function()
		if refs.TextBox.Text:match("\t") then
			refs.TextBox.Text = refs.TextBox.Text:gsub("\t", "")
			return
		end
		if Window.OnTextChanged then
			return Window.OnTextChanged(refs.TextBox.Text)
		end
	end)

	-- Close button
	refs.CloseButton.MouseButton1Click:Connect(function()
		Window:Hide()
	end)
	refs.CloseButton.MouseEnter:Connect(function()
		TweenService:Create(refs.CloseButton, TweenInfo.new(0.1), { TextColor3 = Theme.Current.Error }):Play()
	end)
	refs.CloseButton.MouseLeave:Connect(function()
		TweenService:Create(refs.CloseButton, TweenInfo.new(0.15), { TextColor3 = Theme.Current.TextMuted }):Play()
	end)

	-- Mobile bar action wiring
	for name, btn in pairs(refs.MobileButtons) do
		btn.MouseButton1Click:Connect(function()
			Window:HandleAction(name)
			refs.TextBox:CaptureFocus()
		end)
	end

	-- Draggable header (desktop)
	do
		local dragging = false
		local dragStart: Vector2 = Vector2.zero
		local startPos: UDim2 = refs.Root.Position
		refs.Header.InputBegan:Connect(function(input)
			if
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				dragging = true
				dragStart = input.Position
				startPos = refs.Root.Position
			end
		end)
		refs.Header.InputEnded:Connect(function(input)
			if
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				dragging = false
			end
		end)
		UserInputService.InputChanged:Connect(function(input)
			if not dragging then
				return
			end
			if
				input.UserInputType == Enum.UserInputType.MouseMovement
				or input.UserInputType == Enum.UserInputType.Touch
			then
				local delta = input.Position - dragStart
				refs.Root.Position = UDim2.new(
					startPos.X.Scale,
					startPos.X.Offset + delta.X,
					startPos.Y.Scale,
					startPos.Y.Offset + delta.Y
				)
			end
		end)
	end

	return Window
end

return Window
