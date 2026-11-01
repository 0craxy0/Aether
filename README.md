# aether, the actual best script  on roblox, called "aether"
## contents
- uhh basically just a really good script
- ton of features
- more coming soon

main.lua is the only file users run. It downloads the rest from `main` in the order
listed below; every file receives the shared table `A` as `...` and puts what it
builds on it for the files after it, so **load order matters** (pages/ui.lua has to
run after tail/keylist.lua, tail/extras.lua after pages/ui.lua).
If any file fails, the loader rolls the whole load back and warns in the console
instead of leaving half a UI behind.

## feel

The panel is built to behave like an object, not a picture:

- **depth** - its layers sit at different depths, drift against the cursor, and
  trail behind the shell when you throw the window
- **motion** - pages travel in from the side you came from and their rows settle
  one after another; controls lean toward the cursor
- **material** - a press leaves a ripple in the row it landed on
- **voice** - one short blip for the whole interface, pitched per intent

All four are switchable on the UI page, and none of them touch a module's state.
```
Aether/
├── main.lua                  loader (the only file users run)
├── core/
│   ├── env.lua               services, executor checks, cleanup list
│   ├── theme.lua             colours and fonts
│   ├── util.lua              new, tween, corner, stroke, pad, drawX, label
│   ├── notify.lua            ScreenGui and toasts
│   ├── sfx.lua               one pitched voice for every interaction
│   ├── physics.lua           elastic window drag and throw
│   ├── window.lua            window, shadow, header, sidebar, drag
│   ├── depth.lua             cursor parallax and throw inertia
│   ├── motion.lua            staggered entrances, magnetism, ripples
│   ├── widgets.lua           toggle, slider, button, dropdown, keybind
│   └── pagekit.lua           makePage, makeConfig, gear, config menu open/close
├── modules/
│   ├── filter.lua            whitelist/blacklist and UI-mask helpers
│   ├── character.lua         fly, noclip, inf jump, anti-AFK, fullbright
│   ├── esp.lua
│   ├── aim.lua
│   ├── silentaim.lua
│   ├── killaura.lua
│   └── actions.lua           teleport, rejoin, hop, auto-execute, copy
├── pages/
│   ├── character.lua
│   ├── movement.lua
│   ├── visuals.lua
│   ├── combat.lua            aimbot, silent aim, kill aura
│   ├── players.lua
│   └── ui.lua                keybind list toggle, rescaling, window physics
└── tail/
    ├── keylist.lua           keybind list overlay
    ├── extras.lua            easter egg
    ├── glass.lua             glass blur and Liquid Glass
    ├── settings.lua          accent colour, config save/load, session actions
    ├── keybinds.lua          key handlers and the Keybinds page
    └── startup.lua           show/hide, search, startup animation
```
