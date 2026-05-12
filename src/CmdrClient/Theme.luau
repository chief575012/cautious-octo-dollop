--!strict
-- Theme module for CmdrPlus.
-- Defines a `Theme` shape, ships several presets, and provides a singleton
-- around the currently-active theme with subscribe semantics so that the UI
-- can live-update when the consumer calls `Cmdr:SetTheme(...)`.

export type Theme = {
	Name: string,

	-- Surfaces
	Surface: Color3,
	SurfaceAlt: Color3,
	SurfaceTransparency: number,
	Border: Color3,
	BorderTransparency: number,
	Shadow: Color3,

	-- Accent + states
	Accent: Color3,
	AccentMuted: Color3,
	Success: Color3,
	Warning: Color3,
	Error: Color3,

	-- Text
	Text: Color3,
	TextMuted: Color3,
	TextStrong: Color3,
	Placeholder: Color3,

	-- Typography
	Font: Enum.Font,
	MonoFont: Enum.Font,
	TextSize: number,
	HeaderTextSize: number,

	-- Geometry
	CornerRadius: number,
	Padding: number,
}

local function color(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local BASE: Theme = {
	Name = "Dark",
	Surface = color(15, 17, 24),
	SurfaceAlt = color(24, 27, 38),
	SurfaceTransparency = 0.08,
	Border = color(255, 255, 255),
	BorderTransparency = 0.92,
	Shadow = color(0, 0, 0),

	Accent = color(124, 92, 255),
	AccentMuted = color(180, 160, 255),
	Success = color(108, 220, 144),
	Warning = color(255, 196, 64),
	Error = color(244, 100, 100),

	Text = color(232, 234, 240),
	TextMuted = color(150, 156, 168),
	TextStrong = color(255, 255, 255),
	Placeholder = color(108, 116, 132),

	Font = Enum.Font.GothamMedium,
	MonoFont = Enum.Font.Code,
	TextSize = 15,
	HeaderTextSize = 14,

	CornerRadius = 14,
	Padding = 12,
}

local function withOverrides(base: Theme, overrides: { [string]: any }): Theme
	local t = table.clone(base)
	for k, v in pairs(overrides) do
		(t :: any)[k] = v
	end
	return t
end

local PRESETS: { [string]: Theme } = {
	Dark = BASE,

	OLED = withOverrides(BASE, {
		Name = "OLED",
		Surface = color(0, 0, 0),
		SurfaceAlt = color(12, 12, 14),
		SurfaceTransparency = 0.0,
		Accent = color(0, 200, 255),
		AccentMuted = color(140, 220, 255),
	}),

	Light = withOverrides(BASE, {
		Name = "Light",
		Surface = color(244, 246, 250),
		SurfaceAlt = color(230, 234, 242),
		SurfaceTransparency = 0.05,
		Border = color(0, 0, 0),
		BorderTransparency = 0.85,
		Accent = color(88, 60, 220),
		AccentMuted = color(130, 110, 230),
		Text = color(28, 32, 40),
		TextMuted = color(96, 104, 120),
		TextStrong = color(0, 0, 0),
		Placeholder = color(140, 148, 162),
	}),

	Solarized = withOverrides(BASE, {
		Name = "Solarized",
		Surface = color(0, 43, 54),
		SurfaceAlt = color(7, 54, 66),
		SurfaceTransparency = 0.05,
		Accent = color(38, 139, 210),
		AccentMuted = color(108, 113, 196),
		Success = color(133, 153, 0),
		Warning = color(181, 137, 0),
		Error = color(220, 50, 47),
		Text = color(238, 232, 213),
		TextMuted = color(147, 161, 161),
		TextStrong = color(253, 246, 227),
		Placeholder = color(101, 123, 131),
	}),

	Synthwave = withOverrides(BASE, {
		Name = "Synthwave",
		Surface = color(26, 12, 44),
		SurfaceAlt = color(43, 21, 75),
		Accent = color(255, 105, 180),
		AccentMuted = color(180, 130, 255),
		Success = color(80, 250, 200),
		Warning = color(255, 200, 100),
		Error = color(255, 84, 124),
		Text = color(244, 232, 255),
		TextMuted = color(180, 158, 222),
		TextStrong = color(255, 255, 255),
		Placeholder = color(140, 120, 180),
	}),
}

local ThemeService = {}
ThemeService.Current = PRESETS.Dark :: Theme
ThemeService._subscribers = {} :: { (Theme) -> () }

function ThemeService.GetPresetNames(): { string }
	local names = {}
	for name in pairs(PRESETS) do
		table.insert(names, name)
	end
	table.sort(names)
	return names
end

function ThemeService.GetPreset(name: string): Theme?
	return PRESETS[name]
end

function ThemeService.RegisterPreset(name: string, theme: Theme): ()
	assert(type(name) == "string" and #name > 0, "Theme name must be a non-empty string")
	PRESETS[name] = theme
end

function ThemeService.Set(themeOrName: Theme | string): Theme
	local resolved: Theme
	if type(themeOrName) == "string" then
		local preset = PRESETS[themeOrName]
		assert(preset, ("Unknown theme preset %q"):format(themeOrName))
		resolved = preset
	else
		resolved = withOverrides(BASE, themeOrName :: any)
	end
	ThemeService.Current = resolved
	for _, cb in ipairs(ThemeService._subscribers) do
		task.spawn(cb, resolved)
	end
	return resolved
end

function ThemeService.Subscribe(callback: (Theme) -> ()): () -> ()
	table.insert(ThemeService._subscribers, callback)
	task.spawn(callback, ThemeService.Current)
	return function()
		for i, cb in ipairs(ThemeService._subscribers) do
			if cb == callback then
				table.remove(ThemeService._subscribers, i)
				return
			end
		end
	end
end

return ThemeService
