--!nonstrict
-- AutoComplete controller for CmdrPlus.
-- Renders the suggestion list + info panel against a built refs tree and
-- exposes the surface area the Window/CmdrInterface modules rely on.

local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Parent:WaitForChild("Theme"))

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

	local function clearItems()
		for _, btn in ipairs(guiItemsByIndex) do
			btn:Destroy()
		end
		table.clear(guiItemsByIndex)
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
	end

	local function positionPopup()
		-- Anchor the popup just below the Root window's bottom edge, aligned
		-- left. On mobile we want it just above the mobile action bar so the
		-- keyboard doesn't obscure it.
		local root = refs.Root
		local rp = root.AbsolutePosition
		local rs = root.AbsoluteSize
		local screen = refs.Gui.AbsoluteSize

		-- Width matches root, clamped between 240 and 480 for readability
		local width = math.clamp(rs.X, 260, 520)
		refs.Autocomplete.Size = UDim2.fromOffset(width, 0)
		refs.Autocomplete.AutomaticSize = Enum.AutomaticSize.Y

		-- Default below the window
		local y = rp.Y + rs.Y + 8
		local x = rp.X
		if UserInputService.TouchEnabled and refs.MobileBar.Visible then
			-- Render above the mobile bar
			local barTop = refs.MobileBar.AbsolutePosition.Y
			y = math.max(rp.Y + rs.Y + 8, math.min(y, barTop - refs.Autocomplete.AbsoluteSize.Y - 8))
		end

		-- If it would clip off the right edge, push left
		if x + width > screen.X - 8 then
			x = screen.X - width - 8
		end
		x = math.max(8, x)

		refs.Autocomplete.Position = UDim2.fromOffset(x, y)
	end

	local function renderInfo(options: { [string]: any })
		local info = refs.AcInfo
		local hasInfo = options.name ~= nil or options.description ~= nil or options.type ~= nil
		info.Visible = hasInfo
		if not hasInfo then
			return
		end
		refs.AcName.Text = tostring(options.name or "")
		refs.AcName.Visible = options.name ~= nil

		local typeText = options.type and (": " .. options.type:sub(1, 1):upper() .. options.type:sub(2)) or ""
		refs.AcType.Text = typeText
		refs.AcType.Visible = typeText ~= ""

		refs.AcDescription.Text = tostring(options.description or "")
		refs.AcDescription.TextColor3 = options.invalid and Theme.Current.Error or Theme.Current.TextMuted
		refs.AcDescription.Visible = options.description ~= nil
	end

	local function renderItems()
		local theme = Theme.Current
		clearItems()

		for i, item in ipairs(AutoComplete.Items) do
			local leftText = item[1]
			local rightText = item[2]
			local options = item.options or {}

			local btn = refs.AcItemTemplate:Clone()
			btn.Name = ("Item_%d"):format(i)
			btn.LayoutOrder = i
			btn.Parent = refs.AcItems

			-- Highlight matched substring using RichText
			local matchStart, matchStop = string.find(rightText:lower(), leftText:lower(), 1, true)
			local rendered: string
			if matchStart and matchStop and #leftText > 0 then
				local pre = rightText:sub(1, matchStart - 1)
				local hi = rightText:sub(matchStart, matchStop)
				local post = rightText:sub(matchStop + 1)
				rendered = ('<font color="rgb(%d,%d,%d)">%s</font><b>%s</b><font color="rgb(%d,%d,%d)">%s</font>'):format(
					math.floor(theme.TextMuted.R * 255),
					math.floor(theme.TextMuted.G * 255),
					math.floor(theme.TextMuted.B * 255),
					pre,
					hi,
					math.floor(theme.TextMuted.R * 255),
					math.floor(theme.TextMuted.G * 255),
					math.floor(theme.TextMuted.B * 255),
					post
				)
			else
				rendered = rightText
			end

			btn.Text = rendered
			btn.TextColor3 = theme.Text
			btn.Font = theme.MonoFont

			-- Right-aligned secondary line (the item type/name) — small label
			if options.description or options.name then
				local sub = Instance.new("TextLabel")
				sub.Name = "Sub"
				sub.AnchorPoint = Vector2.new(1, 0.5)
				sub.Position = UDim2.new(1, -8, 0.5, 0)
				sub.Size = UDim2.fromOffset(0, 18)
				sub.AutomaticSize = Enum.AutomaticSize.X
				sub.BackgroundTransparency = 1
				sub.Font = theme.Font
				sub.Text = options.description or options.name or ""
				sub.TextColor3 = theme.TextMuted
				sub.TextSize = theme.TextSize - 3
				sub.TextXAlignment = Enum.TextXAlignment.Right
				sub.Parent = btn
			end

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

		renderInfo(options)
		renderItems()
		refs.Autocomplete.Visible = true
		positionPopup()
	end

	function AutoComplete:Hide(): ()
		refs.Autocomplete.Visible = false
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

	-- Re-position when the window moves/resizes
	refs.Root:GetPropertyChangedSignal("AbsolutePosition"):Connect(positionPopup)
	refs.Root:GetPropertyChangedSignal("AbsoluteSize"):Connect(positionPopup)
	refs.MobileBar:GetPropertyChangedSignal("Visible"):Connect(positionPopup)

	return AutoComplete
end
