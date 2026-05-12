--!nonstrict
-- CmdrPlus client entry. Drop-in compatible with evaera/Cmdr's client API and
-- adds:
--   * `Cmdr:SetTheme(name | theme)` / `Cmdr:RegisterTheme(name, theme)`
--   * `Cmdr:GetTheme()` / `Cmdr:GetThemeNames()`
--   * `Cmdr:SetMobileToggleEnabled(bool)`
--   * `Cmdr:SetMobileToggleIcon(string)` (text icon — uses unicode glyphs)
--   * Floating draggable mobile toggle button (defaults to on for TouchEnabled)

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Shared = script:WaitForChild("Shared")
local Util = require(Shared:WaitForChild("Util"))
local Theme = require(script:WaitForChild("Theme"))

if RunService:IsClient() == false then
	error("[CmdrPlus] Server scripts cannot require the client library.")
end

--[=[
	@class CmdrPlusClient
	@client
	The CmdrPlus client singleton and entry point. Mirrors the public surface
	of evaera/Cmdr and adds theming + mobile chrome.
]=]
local Cmdr
do
	Cmdr = setmetatable({
		ReplicatedRoot = script,
		RemoteFunction = script:WaitForChild("CmdrFunction"),
		RemoteEvent = script:WaitForChild("CmdrEvent"),
		ActivationKeys = { [Enum.KeyCode.F2] = true },
		Enabled = true,
		MashToEnable = false,
		ActivationUnlocksMouse = false,
		HideOnLostFocus = true,
		PlaceName = "",
		Util = Util,
		Events = {},

		-- New: mobile + theming
		MobileToggleEnabled = UserInputService.TouchEnabled,
		MobileToggleIcon = "⌘",
	}, {
		__index = function(self, k)
			local r = self.Dispatcher[k]
			if r and type(r) == "function" then
				return function(_, ...)
					return r(self.Dispatcher, ...)
				end
			end
		end,
	})

	Cmdr.Registry = require(Shared.Registry)(Cmdr)
	Cmdr.Dispatcher = require(Shared.Dispatcher)(Cmdr)
end

local Interface = require(script:WaitForChild("CmdrInterface"))(Cmdr)

--[=[
	Sets the key codes that will show or hide CmdrPlus.
]=]
function Cmdr:SetActivationKeys(keys: { Enum.KeyCode })
	self.ActivationKeys = Util.MakeDictionary(keys)
end

--[=[
	Sets the place name label on the interface.
]=]
function Cmdr:SetPlaceName(name: string)
	self.PlaceName = name
	Interface.Window:UpdateLabel()
	-- Also update the visible PlaceName label in the header.
	self._refs.PlaceName.Text = name ~= "" and name or "CmdrPlus"
end

function Cmdr:SetEnabled(enabled: boolean)
	self.Enabled = enabled
end

function Cmdr:SetActivationUnlocksMouse(enabled: boolean)
	self.ActivationUnlocksMouse = enabled
end

function Cmdr:Show()
	if not self.Enabled then
		return
	end
	Interface.Window:Show()
end

function Cmdr:Hide()
	Interface.Window:Hide()
end

function Cmdr:Toggle()
	if not self.Enabled then
		self:Hide()
		return
	end
	Interface.Window:SetVisible(not Interface.Window:IsVisible())
end

function Cmdr:SetMashToEnable(enabled: boolean)
	self.MashToEnable = enabled
	if enabled then
		self:SetEnabled(false)
	end
end

function Cmdr:SetHideOnLostFocus(enabled: boolean)
	self.HideOnLostFocus = enabled
end

function Cmdr:HandleEvent(name: string, callback: (...any) -> ())
	self.Events[name] = callback
end

-- ============================================================================
-- New CmdrPlus APIs
-- ============================================================================

--[=[
	Switches the active visual theme. Accepts either the name of a registered
	preset (`"Dark"`, `"OLED"`, `"Light"`, `"Solarized"`, `"Synthwave"`) or a
	full / partial theme table. Partial tables are merged on top of the Dark
	preset so callers only have to specify what they want to change.
]=]
function Cmdr:SetTheme(themeOrName: any)
	Theme.Set(themeOrName)
end

--[=[
	Registers a custom theme preset that future `SetTheme(name)` calls can
	reference.
]=]
function Cmdr:RegisterTheme(name: string, theme: any)
	Theme.RegisterPreset(name, theme)
end

function Cmdr:GetTheme()
	return Theme.Current
end

function Cmdr:GetThemeNames()
	return Theme.GetPresetNames()
end

--[=[
	Enables / disables the floating toggle button shown on touch devices.
	Enabled by default when `UserInputService.TouchEnabled` is true.
]=]
function Cmdr:SetMobileToggleEnabled(enabled: boolean)
	self.MobileToggleEnabled = enabled
	if self._refs then
		self._refs.MobileToggle.Visible = enabled and UserInputService.TouchEnabled
	end
end

--[=[
	Sets the text/glyph used inside the floating toggle button.
]=]
function Cmdr:SetMobileToggleIcon(icon: string)
	self.MobileToggleIcon = icon
	if self._refs then
		self._refs.MobileToggle.Text = icon
	end
end

-- Wire the mobile toggle to Show/Hide and make it draggable.
do
	local refs = Cmdr._refs
	if refs then
		refs.MobileToggle.Text = Cmdr.MobileToggleIcon

		local dragging = false
		local moved = false
		local dragStart: Vector2 = Vector2.zero
		local startPos: UDim2 = refs.MobileToggle.Position
		refs.MobileToggle.InputBegan:Connect(function(input)
			if
				input.UserInputType == Enum.UserInputType.Touch
				or input.UserInputType == Enum.UserInputType.MouseButton1
			then
				dragging = true
				moved = false
				dragStart = input.Position
				startPos = refs.MobileToggle.Position
			end
		end)
		refs.MobileToggle.InputEnded:Connect(function(input)
			if
				input.UserInputType == Enum.UserInputType.Touch
				or input.UserInputType == Enum.UserInputType.MouseButton1
			then
				dragging = false
				if not moved then
					Cmdr:Toggle()
				end
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
				if delta.Magnitude > 6 then
					moved = true
				end
				refs.MobileToggle.Position = UDim2.new(
					startPos.X.Scale,
					startPos.X.Offset + delta.X,
					startPos.Y.Scale,
					startPos.Y.Offset + delta.Y
				)
			end
		end)
	end
end

-- Register client-replicated commands/types and hook up the event channel.
-- Mirrors evaera/Cmdr behaviour so existing command definitions Just Work.
if RunService:IsServer() == false then
	Cmdr.Registry:RegisterTypesIn(script:WaitForChild("Types"))
	Cmdr.Registry:RegisterCommandsIn(script:WaitForChild("Commands"))
end

Cmdr.RemoteEvent.OnClientEvent:Connect(function(name, ...)
	if Cmdr.Events[name] then
		Cmdr.Events[name](...)
	end
end)

require(script:WaitForChild("DefaultEventHandlers"))(Cmdr)

return Cmdr
