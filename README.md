# CmdrPlus

A fresh, themable, mobile-friendly command console for Roblox developers.
**Drop-in compatible** with [evaera/Cmdr](https://github.com/evaera/Cmdr) — same
`RegisterCommand`, `RegisterType`, `RegisterHook`, `RegisterDefaultCommands`,
remote function/event surface, and built-in types. Everything you already know.

## Why a "better Cmdr"?

Original Cmdr is excellent, but two pain points kept coming up:

1. **The UI hasn't aged well.** Flat 50%-transparent panels, basic monospace
   font, no focus states, no animations.
2. **Mobile is unusable.** No on-screen toggle, no virtual-keyboard handling,
   no tap-friendly autocomplete, no on-screen ↑/↓/Tab buttons.

CmdrPlus keeps the proven core (Registry / Dispatcher / Argument / Command /
Util, all the built-in types and commands) and rewrites only the parts that
need it: the visuals and the touch experience.

## What's new

### Fresh "Glass v2" UI

- Rounded corners, soft drop-shadow, accent-coloured prompt, monospaced input
- Subtle gradient overlay on the surface for depth
- Smooth slide-in / slide-out tweens
- Highlighted substring in autocomplete suggestions (RichText, not just a
  textcolor)
- Header with place-name badge, theme badge, and a close button
- Footer hint strip with the active shortcuts
- Animated invalid-input flash on the text field
- Draggable header on desktop (move the console anywhere)

### Built-in themes

- `Dark` (default)
- `OLED` (true black, cyan accent)
- `Light`
- `Solarized` (light surface, classic Solarized palette)
- `Synthwave` (pink/violet on plum)

Switch at runtime:

```lua
local Cmdr = require(ReplicatedStorage:WaitForChild("CmdrClient"))
Cmdr:SetTheme("OLED")
```

Define your own:

```lua
Cmdr:RegisterTheme("Mint", {
    Surface = Color3.fromRGB(8, 28, 24),
    Accent = Color3.fromRGB(0, 220, 170),
    AccentMuted = Color3.fromRGB(120, 235, 200),
})
Cmdr:SetTheme("Mint")
```

(Partial tables are merged on top of the `Dark` preset, so you only specify
what you want to change.)

### Mobile support

- **Floating toggle button** — draggable, round, snaps to wherever you leave
  it. Shown automatically on `UserInputService.TouchEnabled`. Tap to toggle.
- **On-screen action bar** — ↑ history, ↓ history, `Tab` to autofill,
  `Run ⏎` to submit, `Hide` to dismiss. Sits at the bottom, above the virtual
  keyboard so it's always reachable while the keyboard is open.
- **Autocomplete reflows** above the action bar instead of getting clipped by
  the keyboard.
- **Big hit targets** — every interactive control on the mobile bar is at
  least 40px tall.

Configure:

```lua
Cmdr:SetMobileToggleEnabled(true)      -- show the floating button
Cmdr:SetMobileToggleIcon("⌘")         -- change the glyph (default: ⌘)
```

## Installation

### Wally

```toml
[dependencies]
CmdrPlus = "cmdrplus/cmdrplus@^1.0.0"
```

### Manual / Rojo

Sync `src/` into `ServerScriptService.CmdrPlus`:

```json
{
    "name": "MyGame",
    "tree": {
        "$className": "DataModel",
        "ServerScriptService": {
            "CmdrPlus": { "$path": "src" }
        }
    }
}
```

## Usage

Identical to evaera/Cmdr.

### Server

```lua
local Cmdr = require(game:GetService("ServerScriptService"):WaitForChild("CmdrPlus"))

Cmdr:RegisterDefaultCommands()
-- or Cmdr:RegisterDefaultCommands({ "Help", "Utility" })

Cmdr:RegisterHook("BeforeRun", function(context)
    if context.Group == "DefaultAdmin" and context.Executor.UserId ~= game.CreatorId then
        return "You don't have permission to run this command."
    end
end)
```

### Client

```lua
local Cmdr = require(game:GetService("ReplicatedStorage"):WaitForChild("CmdrClient"))

Cmdr:SetActivationKeys({ Enum.KeyCode.F2, Enum.KeyCode.Backquote })
Cmdr:SetPlaceName("MyGame")
Cmdr:SetTheme("Synthwave")
Cmdr:SetMobileToggleEnabled(true)
```

## API additions over evaera/Cmdr

| Method                                  | Description                                                         |
|-----------------------------------------|---------------------------------------------------------------------|
| `Cmdr:SetTheme(name \| theme)`           | Switch to a preset, or a partial/full theme table                   |
| `Cmdr:RegisterTheme(name, theme)`       | Register a custom preset that `SetTheme(name)` can reference later  |
| `Cmdr:GetTheme()`                       | Returns the currently active theme table                            |
| `Cmdr:GetThemeNames()`                  | Returns a sorted list of registered preset names                    |
| `Cmdr:SetMobileToggleEnabled(enabled)`  | Show/hide the floating mobile toggle button                         |
| `Cmdr:SetMobileToggleIcon(text)`        | Customise the glyph in the mobile toggle button                     |

Everything else (`SetActivationKeys`, `SetPlaceName`, `Show/Hide/Toggle`,
`SetEnabled`, `SetMashToEnable`, `SetHideOnLostFocus`,
`SetActivationUnlocksMouse`, `HandleEvent`) is unchanged.

## Theme reference

```lua
type Theme = {
    Name: string,

    Surface: Color3,
    SurfaceAlt: Color3,
    SurfaceTransparency: number,
    Border: Color3,
    BorderTransparency: number,
    Shadow: Color3,

    Accent: Color3,
    AccentMuted: Color3,
    Success: Color3,
    Warning: Color3,
    Error: Color3,

    Text: Color3,
    TextMuted: Color3,
    TextStrong: Color3,
    Placeholder: Color3,

    Font: Enum.Font,
    MonoFont: Enum.Font,
    TextSize: number,
    HeaderTextSize: number,

    CornerRadius: number,
    Padding: number,
}
```

## Credits

CmdrPlus is a fork of evaera/Cmdr. The proven core — Registry, Dispatcher,
Argument, Command, Util, all the built-in types and commands — is © Eryn L. K.
and licensed under MIT. Fresh UI, mobile chrome, and theming layer are added
on top. See [LICENSE](LICENSE) for full attribution.

## License

MIT. See [LICENSE](LICENSE).
