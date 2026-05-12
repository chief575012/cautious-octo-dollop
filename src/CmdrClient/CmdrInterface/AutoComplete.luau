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
			}):Play()

			local nameLabel = btn:FindFirstChild("ItemName")
			if nameLabel and nameLabel:IsA("TextLabel") then
				TweenService:Create(nameLabel, POPUP_TWEEN, {
					TextColor3 = selected and theme.TextStrong or theme.Text,
				}):Play()
			end
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

		-- Width matches root, clamped to keep names + description readable.
		local width = math.clamp(rs.X, 320, 560)
		refs.Autocomplete.Size = UDim2.fromOffset(width, 0)
		refs.Autocomplete.AutomaticSize = Enum.AutomaticSize.Y

		-- Default below the window
		local y = rp.Y + rs.Y + 8
		local x = rp.X

		-- Force AutomaticSize to resolve before reading AbsoluteSize so the
		-- below-vs-above-the-window decision uses the popup's real height.
		local popupHeight = refs.Autocomplete.AbsoluteSize.Y
		if popupHeight <= 0 then
			popupHeight = 120
		end

		if UserInputService.TouchEnabled and refs.MobileBar.Visible then
			-- Render above the mobile bar when there isn't room below it
			local barTop = refs.MobileBar.AbsolutePosition.Y
			if y + popupHeight > barTop - 8 then
				y = math.max(8, barTop - popupHeight - 8)
			end
		elseif y + popupHeight > screen.Y - 16 then
			-- Desktop: flip above the window if it would clip off the bottom
			y = math.max(8, rp.Y - popupHeight - 8)
		end

		-- Horizontal: push left if it would clip off the right edge
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

			local nameLabel = btn:FindFirstChild("ItemName") :: TextLabel?
			local descLabel = btn:FindFirstChild("ItemDesc") :: TextLabel?

			if nameLabel then
				nameLabel.Text = highlightedName(theme, leftText, rightText)
				nameLabel.Font = theme.MonoFont
				nameLabel.TextColor3 = theme.Text
			end

			if descLabel then
				local descText = options.description or options.name
				if descText then
					descLabel.Text = tostring(descText)
					descLabel.TextColor3 = options.invalid and theme.Error or theme.TextMuted
					descLabel.Visible = true
				else
					descLabel.Visible = false
				end
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

	-- Re-position when the window moves/resizes, or when the popup's own
	-- AutomaticSize.Y settles to a new value after items render (so we can
	-- flip above the window once the real height is known).
	refs.Root:GetPropertyChangedSignal("AbsolutePosition"):Connect(positionPopup)
	refs.Root:GetPropertyChangedSignal("AbsoluteSize"):Connect(positionPopup)
	refs.MobileBar:GetPropertyChangedSignal("Visible"):Connect(positionPopup)
	refs.Autocomplete:GetPropertyChangedSignal("AbsoluteSize"):Connect(positionPopup)

	return AutoComplete
end
