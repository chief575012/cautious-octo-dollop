--!nonstrict
-- UIBuilder: constructs the CmdrPlus ScreenGui purely in code so themes can be
-- applied live without round-tripping through StarterGui. Returns the root
-- ScreenGui plus a `refs` table of named instances the rest of the client uses.
--
-- Visual style: "Glass v2" — rounded surfaces, subtle gradients, soft shadow,
-- accent colour for the active row, monospaced output. Themed via Theme module.

local UserInputService = game:GetService("UserInputService")

local Theme = require(script.Parent:WaitForChild("Theme"))

type Theme = Theme.Theme

export type Refs = {
	Gui: ScreenGui,
	Root: Frame,
	Shadow: Frame,
	Container: Frame,
	Header: Frame,
	PlaceName: TextLabel,
	ThemeBadge: TextLabel,
	CloseButton: TextButton,
	Output: ScrollingFrame,
	OutputLayout: UIListLayout,
	OutputPadding: UIPadding,
	LineTemplate: TextLabel,
	Entry: Frame,
	Prompt: TextLabel,
	Caret: TextLabel,
	TextBox: TextBox,
	FooterHint: TextLabel,

	Autocomplete: Frame,
	AcInfo: Frame,
	AcName: TextLabel,
	AcType: TextLabel,
	AcDescription: TextLabel,
	AcItems: ScrollingFrame,
	AcItemTemplate: TextButton,
	AcItemsLayout: UIListLayout,

	MobileToggle: TextButton,
	MobileBar: Frame,
	MobileButtons: { [string]: TextButton },
}

local function make<T>(class: string, props: { [string]: any }?, children: { Instance }?): T
	local inst = Instance.new(class)
	if props then
		for k, v in pairs(props) do
			(inst :: any)[k] = v
		end
	end
	if children then
		for _, c in ipairs(children) do
			c.Parent = inst
		end
	end
	return inst :: any
end

local function rounded(radius: number): UICorner
	return make("UICorner", { CornerRadius = UDim.new(0, radius) })
end

local function stroke(color: Color3, transparency: number, thickness: number?): UIStroke
	return make("UIStroke", {
		Color = color,
		Transparency = transparency,
		Thickness = thickness or 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

local function asymPadding(top: number, right: number, bottom: number, left: number): UIPadding
	return make("UIPadding", {
		PaddingTop = UDim.new(0, top),
		PaddingRight = UDim.new(0, right),
		PaddingBottom = UDim.new(0, bottom),
		PaddingLeft = UDim.new(0, left),
	})
end

-- Builds an Instance.new("Frame") drop-shadow approximation by stacking three
-- 1px offset frames behind the container. Cheaper than ImageLabel shadow assets
-- because it doesn't require a marketplace asset id.
local function buildShadow(theme: Theme): Frame
	local shadow = make("Frame", {
		Name = "Shadow",
		BackgroundColor3 = theme.Shadow,
		BackgroundTransparency = 0.55,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 18, 1, 18),
		Position = UDim2.fromOffset(-9, -3),
		ZIndex = 0,
	}, {
		rounded(theme.CornerRadius + 6),
	})
	-- Outer halo
	local halo = make("Frame", {
		Name = "Halo",
		BackgroundColor3 = theme.Shadow,
		BackgroundTransparency = 0.78,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 40, 1, 40),
		Position = UDim2.fromOffset(-20, -16),
		ZIndex = 0,
	}, {
		rounded(theme.CornerRadius + 18),
	})
	halo.Parent = shadow
	return shadow
end

local function buildHeader(theme: Theme): (Frame, TextLabel, TextLabel, TextButton)
	local placeName = make("TextLabel", {
		Name = "PlaceName",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -120, 1, 0),
		Font = theme.Font,
		Text = "CmdrPlus",
		TextColor3 = theme.TextStrong,
		TextSize = theme.HeaderTextSize,
		TextXAlignment = Enum.TextXAlignment.Left,
		AutomaticSize = Enum.AutomaticSize.X,
	})

	local themeBadge = make("TextLabel", {
		Name = "ThemeBadge",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -40, 0.5, 0),
		Size = UDim2.fromOffset(0, 22),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = theme.SurfaceAlt,
		BackgroundTransparency = 0.2,
		Font = theme.Font,
		Text = "  " .. theme.Name .. "  ",
		TextColor3 = theme.AccentMuted,
		TextSize = theme.HeaderTextSize - 2,
		BorderSizePixel = 0,
	}, { rounded(6) })

	local close = make("TextButton", {
		Name = "CloseButton",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(28, 28),
		BackgroundColor3 = theme.SurfaceAlt,
		BackgroundTransparency = 0.2,
		Text = "×",
		Font = theme.Font,
		TextColor3 = theme.TextMuted,
		TextSize = 20,
		BorderSizePixel = 0,
		AutoButtonColor = false,
	}, { rounded(8) })

	local header = make("Frame", {
		Name = "Header",
		BackgroundColor3 = theme.SurfaceAlt,
		BackgroundTransparency = 0.4,
		Size = UDim2.new(1, 0, 0, 38),
		BorderSizePixel = 0,
	}, {
		asymPadding(0, 12, 0, 14),
		placeName,
		themeBadge,
		close,
	})

	-- top corners only — visual trick: cover bottom with a flat strip
	local cornerMask = make("Frame", {
		Name = "BottomMask",
		BackgroundColor3 = theme.SurfaceAlt,
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, theme.CornerRadius),
		ZIndex = 0,
	})
	cornerMask.Parent = header
	make("UICorner", { CornerRadius = UDim.new(0, theme.CornerRadius) }).Parent = header

	-- thin accent rule under the header
	local rule = make("Frame", {
		Name = "Rule",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = theme.Border,
		BackgroundTransparency = theme.BorderTransparency,
		BorderSizePixel = 0,
		ZIndex = 2,
	})
	rule.Parent = header

	return header, placeName, themeBadge, close
end

local function buildEntry(theme: Theme): (Frame, TextLabel, TextLabel, TextBox)
	local prompt = make("TextLabel", {
		Name = "Prompt",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(0, 22),
		AutomaticSize = Enum.AutomaticSize.X,
		Font = theme.MonoFont,
		Text = "player ›",
		TextColor3 = theme.Accent,
		TextSize = theme.TextSize,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 1,
	})

	local caret = make("TextLabel", {
		Name = "Caret",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(8, 22),
		Font = theme.MonoFont,
		Text = "▌",
		TextColor3 = theme.AccentMuted,
		TextSize = theme.TextSize,
		LayoutOrder = 2,
		Visible = false,
	})

	local box = make("TextBox", {
		Name = "TextBox",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 22),
		AutomaticSize = Enum.AutomaticSize.Y,
		Font = theme.MonoFont,
		Text = "",
		PlaceholderText = "type a command…",
		PlaceholderColor3 = theme.Placeholder,
		TextColor3 = theme.TextStrong,
		TextSize = theme.TextSize,
		TextXAlignment = Enum.TextXAlignment.Left,
		ClearTextOnFocus = false,
		LayoutOrder = 3,
		TextWrapped = false,
	})

	local entry = make("Frame", {
		Name = "Entry",
		BackgroundTransparency = 1,
		LayoutOrder = 999999999,
		Size = UDim2.new(1, 0, 0, 22),
		AutomaticSize = Enum.AutomaticSize.Y,
	}, {
		make("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
			VerticalAlignment = Enum.VerticalAlignment.Top,
		}),
		prompt,
		caret,
		box,
	})

	return entry, prompt, caret, box
end

-- Autocomplete layout (rewrite v2):
--   * Fixed popup width — no width clamp drama
--   * Single-line items at a fixed height — no AutomaticSize chain reactions
--   * Items ScrollingFrame's height is set explicitly per Show() based on count
--   * Description for the selected item is shown in the Info panel above the
--     list (mirroring how evaera/Cmdr does it); the row itself stays a clean
--     one-liner with a RichText accent highlight on the matched substring.
local AC_ITEM_HEIGHT = 28
local AC_ITEM_SPACING = 1
local AC_MAX_VISIBLE_ITEMS = 7
local AC_POPUP_WIDTH = 380

local function buildAutocomplete(theme: Theme): (
	Frame,
	Frame,
	TextLabel,
	TextLabel,
	TextLabel,
	ScrollingFrame,
	TextButton,
	UIListLayout
)
	local name = make("TextLabel", {
		Name = "Name",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 18),
		Font = theme.MonoFont,
		Text = "",
		TextColor3 = theme.TextStrong,
		TextSize = theme.TextSize,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		LayoutOrder = 1,
	})

	local typeLabel = make("TextLabel", {
		Name = "Type",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 14),
		Font = theme.Font,
		Text = "",
		TextColor3 = theme.AccentMuted,
		TextSize = theme.TextSize - 3,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 2,
	})

	local desc = make("TextLabel", {
		Name = "Description",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Font = theme.Font,
		Text = "",
		TextColor3 = theme.TextMuted,
		TextSize = theme.TextSize - 2,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		LayoutOrder = 3,
	})

	local info = make("Frame", {
		Name = "Info",
		BackgroundColor3 = theme.SurfaceAlt,
		BackgroundTransparency = 0.15,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BorderSizePixel = 0,
		LayoutOrder = 1,
		Visible = false,
	}, {
		rounded(8),
		asymPadding(10, 12, 10, 12),
		make("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 4),
		}),
		name,
		typeLabel,
		desc,
	})

	-- Single-line item button. Fixed height so the items frame is predictable.
	local itemTemplate = make("TextButton", {
		Name = "ItemTemplate",
		Size = UDim2.new(1, 0, 0, AC_ITEM_HEIGHT),
		BackgroundColor3 = theme.AccentMuted,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Font = theme.MonoFont,
		Text = "",
		RichText = true,
		TextColor3 = theme.Text,
		TextSize = theme.TextSize,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, {
		rounded(6),
		asymPadding(0, 12, 0, 12),
	})

	-- The items ScrollingFrame's height is set explicitly in renderItems() to
	-- AC_ITEM_HEIGHT * min(count, AC_MAX_VISIBLE_ITEMS) + spacing, so there is
	-- never an AutomaticSize feedback loop with AutomaticCanvasSize.
	local items = make("ScrollingFrame", {
		Name = "Items",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = theme.AccentMuted,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ElasticBehavior = Enum.ElasticBehavior.Never,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		LayoutOrder = 2,
	}, {
		make("UISizeConstraint", {
			MaxSize = Vector2.new(math.huge, 240),
		}),
	})

	local itemsLayout = make("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, AC_ITEM_SPACING),
	})
	itemsLayout.Parent = items

	-- Popup: fixed width, AutomaticSize.Y derived from the (fixed) child sizes.
	local ac = make("Frame", {
		Name = "Autocomplete",
		BackgroundColor3 = theme.Surface,
		BackgroundTransparency = theme.SurfaceTransparency,
		Size = UDim2.fromOffset(AC_POPUP_WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 5,
	}, {
		rounded(theme.CornerRadius),
		stroke(theme.Border, theme.BorderTransparency, 1),
		asymPadding(10, 10, 10, 10),
		make("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
		}),
		info,
		items,
	})

	return ac, info, name, typeLabel, desc, items, itemTemplate, itemsLayout
end

local function buildMobileToggle(theme: Theme): TextButton
	return make("TextButton", {
		Name = "MobileToggle",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -120),
		Size = UDim2.fromOffset(56, 56),
		BackgroundColor3 = theme.Surface,
		BackgroundTransparency = 0.05,
		Text = "Cmd",
		Font = theme.Font,
		TextColor3 = theme.Accent,
		TextSize = 26,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Visible = false,
		ZIndex = 8,
	}, {
		make("UICorner", { CornerRadius = UDim.new(1, 0) }),
		stroke(theme.Border, theme.BorderTransparency - 0.4, 1),
	})
end

local function buildMobileBar(theme: Theme): (Frame, { [string]: TextButton })
	local buttons: { [string]: TextButton } = {}

	local function pill(name: string, label: string, order: number): TextButton
		local btn = make("TextButton", {
			Name = name,
			Size = UDim2.fromOffset(0, 40),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = theme.SurfaceAlt,
			BackgroundTransparency = 0.1,
			Font = theme.Font,
			Text = "   " .. label .. "   ",
			TextColor3 = theme.TextStrong,
			TextSize = theme.TextSize,
			BorderSizePixel = 0,
			AutoButtonColor = false,
			LayoutOrder = order,
		}, { rounded(10) })
		buttons[name] = btn
		return btn
	end

	local bar = make("Frame", {
		Name = "MobileBar",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -8),
		Size = UDim2.new(1, -24, 0, 48),
		BackgroundColor3 = theme.Surface,
		BackgroundTransparency = theme.SurfaceTransparency,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 7,
	}, {
		rounded(12),
		stroke(theme.Border, theme.BorderTransparency, 1),
		asymPadding(4, 6, 4, 6),
		make("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
		}),
		pill("Up", "Up", 1),
		pill("Down", "Down", 2),
		pill("Tab", "Tab", 3),
		pill("Submit", "Run", 4),
		pill("Hide", "Hide", 5),
	})

	return bar, buttons
end

local UIBuilder = {}

UIBuilder.AC_ITEM_HEIGHT = AC_ITEM_HEIGHT
UIBuilder.AC_ITEM_SPACING = AC_ITEM_SPACING
UIBuilder.AC_MAX_VISIBLE_ITEMS = AC_MAX_VISIBLE_ITEMS
UIBuilder.AC_POPUP_WIDTH = AC_POPUP_WIDTH

function UIBuilder.Build(playerName: string): Refs
	local theme = Theme.Current

	-- Header
	local header, placeName, themeBadge, close = buildHeader(theme)

	-- Entry row
	local entry, prompt, caret, box = buildEntry(theme)

	-- Line template (cloned per output row)
	local lineTemplate = make("TextLabel", {
		Name = "LineTemplate",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 18),
		AutomaticSize = Enum.AutomaticSize.Y,
		Font = theme.MonoFont,
		Text = "",
		TextColor3 = theme.Text,
		TextSize = theme.TextSize,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = false,
	})

	local outputLayout = make("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 2),
	})
	local outputPadding = asymPadding(theme.Padding, theme.Padding, theme.Padding, theme.Padding)

	local output = make("ScrollingFrame", {
		Name = "Output",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, -38),
		Position = UDim2.fromOffset(0, 38),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = theme.AccentMuted,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		BorderSizePixel = 0,
	}, {
		outputLayout,
		outputPadding,
		entry,
	})

	local footerHint = make("TextLabel", {
		Name = "FooterHint",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 12, 1, -6),
		Size = UDim2.new(1, -24, 0, 14),
		Font = theme.Font,
		Text = "tab autocomplete · up/down history · enter run · F2 close",
		TextColor3 = theme.TextMuted,
		TextSize = theme.HeaderTextSize - 3,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTransparency = 0.2,
		ZIndex = 3,
	})

	-- Container window
	local container = make("Frame", {
		Name = "Container",
		BackgroundColor3 = theme.Surface,
		BackgroundTransparency = theme.SurfaceTransparency,
		Size = UDim2.new(1, 0, 1, 0),
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 1,
	}, {
		rounded(theme.CornerRadius),
		stroke(theme.Border, theme.BorderTransparency, 1),
		header,
		output,
		footerHint,
	})

	-- Background gradient overlay for depth
	local gradient = make("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, theme.Surface),
			ColorSequenceKeypoint.new(1, theme.SurfaceAlt),
		}),
		Rotation = 120,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.4),
			NumberSequenceKeypoint.new(1, 0.05),
		}),
	})
	gradient.Parent = container

	-- Shadow halo
	local shadow = buildShadow(theme)

	local root = make("Frame", {
		Name = "Root",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 24),
		Size = UDim2.new(0.94, 0, 0, 320),
		Visible = false,
	}, {
		shadow,
		container,
		make("UISizeConstraint", { MinSize = Vector2.new(280, 200), MaxSize = Vector2.new(1100, 720) }),
	})

	-- Autocomplete (floats above the input)
	local ac, info, acName, acType, acDesc, acItems, acItemTemplate, acItemsLayout = buildAutocomplete(theme)

	-- Mobile chrome
	local mobileToggle = buildMobileToggle(theme)
	local mobileBar, mobileButtons = buildMobileBar(theme)

	local gui = make("ScreenGui", {
		Name = "CmdrPlus",
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		DisplayOrder = 1000,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		AutoLocalize = false,
	}, {
		root,
		ac,
		mobileToggle,
		mobileBar,
	})

	-- Make autocomplete a sibling of Root so it can render outside its bounds
	-- Show the floating toggle on touch by default; controller can override.
	mobileToggle.Visible = UserInputService.TouchEnabled

	local refs: Refs = {
		Gui = gui,
		Root = root,
		Shadow = shadow,
		Container = container,
		Header = header,
		PlaceName = placeName,
		ThemeBadge = themeBadge,
		CloseButton = close,
		Output = output,
		OutputLayout = outputLayout,
		OutputPadding = outputPadding,
		LineTemplate = lineTemplate,
		Entry = entry,
		Prompt = prompt,
		Caret = caret,
		TextBox = box,
		FooterHint = footerHint,

		Autocomplete = ac,
		AcInfo = info,
		AcName = acName,
		AcType = acType,
		AcDescription = acDesc,
		AcItems = acItems,
		AcItemTemplate = acItemTemplate,
		AcItemsLayout = acItemsLayout,

		MobileToggle = mobileToggle,
		MobileBar = mobileBar,
		MobileButtons = mobileButtons,
	}

	-- Make prompt reflect player name early
	prompt.Text = playerName .. " ›"

	return refs
end

-- Re-applies the active theme to an existing refs tree. Called when consumer
-- calls `Cmdr:SetTheme(...)`. Avoid recreating the entire UI, just retint.
function UIBuilder.ApplyTheme(refs: Refs, theme: Theme): ()
	local function setStrokeOn(parent: Instance)
		local s = parent:FindFirstChildOfClass("UIStroke")
		if s then
			s.Color = theme.Border
			s.Transparency = theme.BorderTransparency
		end
	end

	refs.Container.BackgroundColor3 = theme.Surface
	refs.Container.BackgroundTransparency = theme.SurfaceTransparency
	setStrokeOn(refs.Container)

	refs.Header.BackgroundColor3 = theme.SurfaceAlt
	refs.PlaceName.TextColor3 = theme.TextStrong
	refs.PlaceName.Font = theme.Font
	refs.ThemeBadge.Text = "  " .. theme.Name .. "  "
	refs.ThemeBadge.TextColor3 = theme.AccentMuted
	refs.ThemeBadge.BackgroundColor3 = theme.SurfaceAlt
	refs.CloseButton.BackgroundColor3 = theme.SurfaceAlt
	refs.CloseButton.TextColor3 = theme.TextMuted

	refs.Output.ScrollBarImageColor3 = theme.AccentMuted

	refs.Prompt.TextColor3 = theme.Accent
	refs.Prompt.Font = theme.MonoFont
	refs.Caret.TextColor3 = theme.AccentMuted
	refs.Caret.Font = theme.MonoFont
	refs.TextBox.TextColor3 = theme.TextStrong
	refs.TextBox.PlaceholderColor3 = theme.Placeholder
	refs.TextBox.Font = theme.MonoFont
	refs.LineTemplate.TextColor3 = theme.Text
	refs.LineTemplate.Font = theme.MonoFont
	refs.FooterHint.TextColor3 = theme.TextMuted

	refs.Autocomplete.BackgroundColor3 = theme.Surface
	refs.Autocomplete.BackgroundTransparency = theme.SurfaceTransparency
	setStrokeOn(refs.Autocomplete)
	refs.AcInfo.BackgroundColor3 = theme.SurfaceAlt
	refs.AcName.TextColor3 = theme.TextStrong
	refs.AcType.TextColor3 = theme.AccentMuted
	refs.AcDescription.TextColor3 = theme.TextMuted

	refs.MobileToggle.BackgroundColor3 = theme.Surface
	refs.MobileToggle.TextColor3 = theme.Accent
	setStrokeOn(refs.MobileToggle)
	refs.MobileBar.BackgroundColor3 = theme.Surface
	refs.MobileBar.BackgroundTransparency = theme.SurfaceTransparency
	setStrokeOn(refs.MobileBar)
	for _, btn in pairs(refs.MobileButtons) do
		btn.BackgroundColor3 = theme.SurfaceAlt
		btn.TextColor3 = theme.TextStrong
		btn.Font = theme.Font
	end
end

return UIBuilder
