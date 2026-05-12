--!nonstrict
-- AutoComplete controller for CmdrPlus.
--
-- Renders the suggestion list + info panel against a built refs tree and
-- exposes the surface area the Window / CmdrInterface modules rely on.
--
-- Layout contract with UIBuilder:
--   * Each item is a single-line TextButton, fixed AC_ITEM_HEIGHT tall.
--   * The items ScrollingFrame's height is set explicitly here based on the
--     number of items (capped at AC_MAX_VISIBLE_ITEMS rows) so there is no
--     AutomaticSize feedback loop with the canvas size.
--   * The Info panel above the items shows description text — first the
--     command/argument context if Show() was called with one, otherwise the
--     selected item's own description (updates live on Tab/arrow/hover).

local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Parent:WaitForChild("Theme"))
local UIBuilder = require(script.Parent.Parent:WaitForChild("UIBuilder"))

local POPUP_TWEEN = TweenInfo.new(0.14, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

return function(Cmdr: any)
	local refs = Cmdr._refs
	assert(refs, "CmdrPlus AutoComplete requires refs to be set on Cmdr before initialisation")

	local AutoComplete = {
		Items = {} :: { any },
		ItemOptions = {} :: { any },
		SelectedItem = 0,
		Prefix = "",
		LastItem = false,
		Command = nil :: any,
		Arg = nil :: any,
		NumArgs = 0,
		IsPartial = false,
	}

	local guiItemsByIndex: { TextButton } = {}
	local argOptions: { [string]: any } = {}

	local function clearItems()
		for _, btn in ipairs(guiItemsByIndex) do
			btn:Destroy()
		end
		table.clear(guiItemsByIndex)
	end

	local function highlightedName(theme: any, leftText: string, rightText: string): string
		local matchStart, matchStop = string.find(rightText:lower(), leftText:lower(), 1, true)
		if not (matchStart and matchStop) or #leftText == 0 then
			return rightText
		end

		local pre = rightText:sub(1, matchStart - 1)
		local hi = rightText:sub(matchStart, matchStop)
		local post = rightText:sub(matchStop + 1)
		return ('%s<font color="rgb(%d,%d,%d)"><b>%s</b></font>%s'):format(
			pre,
			math.floor(theme.Accent.R * 255),
			math.floor(theme.Accent.G * 255),
			math.floor(theme.Accent.B * 255),
			hi,
			post
		)
	end

	-- Populate the info panel from either the argument-level Show() options
	-- or, when those are empty, the currently-selected item's own options.
	local function applyInfo(info: { [string]: any })
		local theme = Theme.Current
		local hasName = info.name ~= nil and info.name ~= ""
		local hasDesc = info.description ~= nil and info.description ~= ""
		local hasType = info.type ~= nil and info.type ~= ""

		refs.AcInfo.Visible = hasName or hasDesc or hasType

		refs.AcName.Text = tostring(info.name or "")
		refs.AcName.Visible = hasName

		local typeText = info.type and (": " .. tostring(info.type):sub(1, 1):upper() .. tostring(info.type):sub(2))
			or ""
		refs.AcType.Text = typeText
		refs.AcType.Visible = typeText ~= ""

		refs.AcDescription.Text = tostring(info.description or "")
		refs.AcDescription.TextColor3 = info.invalid and theme.Error or theme.TextMuted
		refs.AcDescription.Visible = hasDesc
	end

	local function updateInfoPanel()
		-- Argument-level context (from Show() options) takes precedence over
		-- the selected item's own description, because it is what the user is
		-- actively typing against.
		if argOptions.name or argOptions.description or argOptions.type then
			applyInfo(argOptions)
			return
		end

		local selected = AutoComplete.Items[AutoComplete.SelectedItem]
		local itemOptions = selected and selected.options or nil
		if itemOptions and (itemOptions.name or itemOptions.description) then
			applyInfo({
				name = itemOptions.name,
				description = itemOptions.description,
				type = nil,
				invalid = itemOptions.invalid,
			})
			return
		end

		refs.AcInfo.Visible = false
	end

	local function highlightItem(index: number)
		local theme = Theme.Current
		for i, btn in ipairs(guiItemsByIndex) do
			local selected = i == index
			TweenService:Create(btn, POPUP_TWEEN, {
				BackgroundTransparency = selected and 0.15 or 1,
				BackgroundColor3 = theme.AccentMuted,
				TextColor3 = selected and theme.TextStrong or theme.Text,
			}):Play()
		end
		updateInfoPanel()
	end

	local function positionPopup()
		local root = refs.Root
		local rp = root.AbsolutePosition
		local rs = root.AbsoluteSize
		local screen = refs.Gui.AbsoluteSize

		local width = UIBuilder.AC_POPUP_WIDTH
		refs.Autocomplete.Size = UDim2.fromOffset(width, 0)
		refs.Autocomplete.AutomaticSize = Enum.AutomaticSize.Y

		-- Use the popup's currently-resolved height for the below-vs-above
		-- decision. If the layout hasn't settled yet (Show on first frame),
		-- fall back to a conservative estimate.
		local popupHeight = refs.Autocomplete.AbsoluteSize.Y
		if popupHeight <= 0 then
			popupHeight = 160
		end

		local x = rp.X
		if x + width > screen.X - 8 then
			x = screen.X - width - 8
		end
		x = math.max(8, x)

		local y = rp.Y + rs.Y + 8
		local overflowBelow = (y + popupHeight) - (screen.Y - 8)
		if overflowBelow > 0 then
			-- Flip above the window
			y = math.max(8, rp.Y - popupHeight - 8)
		end

		if UserInputService.TouchEnabled and refs.MobileBar.Visible then
			local barTop = refs.MobileBar.AbsolutePosition.Y
			if y + popupHeight > barTop - 8 then
				y = math.max(8, barTop - popupHeight - 8)
			end
		end

		refs.Autocomplete.Position = UDim2.fromOffset(x, y)
	end

	local function renderItems()
		local theme = Theme.Current
		clearItems()

		local itemCount = #AutoComplete.Items
		if itemCount == 0 then
			refs.AcItems.Visible = false
			refs.AcItems.Size = UDim2.new(1, 0, 0, 0)
			return
		end

		refs.AcItems.Visible = true

		-- Explicit height: AC_ITEM_HEIGHT * visibleRows + spacing.
		local visibleRows = math.min(itemCount, UIBuilder.AC_MAX_VISIBLE_ITEMS)
		local h = visibleRows * UIBuilder.AC_ITEM_HEIGHT + math.max(0, visibleRows - 1) * UIBuilder.AC_ITEM_SPACING
		refs.AcItems.Size = UDim2.new(1, 0, 0, h)

		for i, item in ipairs(AutoComplete.Items) do
			local leftText = item[1]
			local rightText = item[2]

			local btn = refs.AcItemTemplate:Clone()
			btn.Name = ("Item_%d"):format(i)
			btn.LayoutOrder = i
			btn.Parent = refs.AcItems

			btn.Text = highlightedName(theme, leftText, rightText)
			btn.Font = theme.MonoFont
			btn.TextColor3 = theme.Text

			btn.MouseButton1Click:Connect(function()
				AutoComplete.SelectedItem = i
				highlightItem(i)
				-- Trigger Tab-fill via the Window's HandleAction
				local Window = require(script.Parent:WaitForChild("Window"))
				Window:HandleAction("Tab")
			end)

			btn.MouseEnter:Connect(function()
				AutoComplete.SelectedItem = i
				highlightItem(i)
			end)

			table.insert(guiItemsByIndex, btn)
		end

		highlightItem(AutoComplete.SelectedItem)
	end

	function AutoComplete:Show(items: { any }, options: { [string]: any }?): ()
		options = options or {}

		AutoComplete.SelectedItem = 1
		AutoComplete.Items = items
		AutoComplete.Prefix = options.prefix or ""
		AutoComplete.LastItem = options.isLast or false
		AutoComplete.Command = options.command
		AutoComplete.Arg = options.arg
		AutoComplete.NumArgs = options.numArgs
		AutoComplete.IsPartial = options.isPartial

		if #items == 0 then
			AutoComplete:Hide()
			return
		end

		argOptions = {
			name = options.name,
			description = options.description,
			type = options.type,
			invalid = options.invalid,
		}

		renderItems()
		updateInfoPanel()
		refs.Autocomplete.Visible = true
		positionPopup()
	end

	function AutoComplete:Hide(): ()
		refs.Autocomplete.Visible = false
		argOptions = {}
		clearItems()
	end

	function AutoComplete:IsVisible(): boolean
		return refs.Autocomplete.Visible
	end

	function AutoComplete:Select(delta: number): ()
		if #AutoComplete.Items == 0 then
			return
		end
		local newIndex = AutoComplete.SelectedItem + delta
		if newIndex < 1 then
			newIndex = #AutoComplete.Items
		elseif newIndex > #AutoComplete.Items then
			newIndex = 1
		end
		AutoComplete.SelectedItem = newIndex
		highlightItem(newIndex)

		-- Ensure visible in scrolling list
		local btn = guiItemsByIndex[newIndex]
		if btn then
			local relY = btn.AbsolutePosition.Y - refs.AcItems.AbsolutePosition.Y
			if relY < 0 then
				refs.AcItems.CanvasPosition = Vector2.new(0, math.max(0, refs.AcItems.CanvasPosition.Y + relY))
			elseif relY + btn.AbsoluteSize.Y > refs.AcItems.AbsoluteSize.Y then
				local overflow = relY + btn.AbsoluteSize.Y - refs.AcItems.AbsoluteSize.Y
				refs.AcItems.CanvasPosition = Vector2.new(0, refs.AcItems.CanvasPosition.Y + overflow)
			end
		end
	end

	function AutoComplete:GetSelectedItem()
		return AutoComplete.Items[AutoComplete.SelectedItem]
	end

	-- Re-position when the window moves/resizes, or when the popup's own
	-- AutomaticSize.Y settles to a new value after items render.
	refs.Root:GetPropertyChangedSignal("AbsolutePosition"):Connect(positionPopup)
	refs.Root:GetPropertyChangedSignal("AbsoluteSize"):Connect(positionPopup)
	refs.MobileBar:GetPropertyChangedSignal("Visible"):Connect(positionPopup)
	refs.Autocomplete:GetPropertyChangedSignal("AbsoluteSize"):Connect(positionPopup)

	return AutoComplete
end
