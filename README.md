# aether, the actual best script  on roblox, called "aether"
## contents
- uhh basically just a really good script
- ton of features
- a lot today, more soon

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

## read aloud

Off until you say otherwise. A first-run card asks once; a "yes" is remembered
whatever the checkbox says, and a "no" only if *Don't show this again* is ticked.
The same thing lives as a normal switch on the UI page, so it can be turned on or
off at any time without the card coming back.

Point at any label and hold for three seconds. A bar grows out of the middle of
that text toward both edges while the wait runs; when it lands the text is read
out. Move off, or onto another label, and it starts over.

The voice is a backend, because a client script has no speech synthesiser: `Sound`
plays `rbxassetid://` assets only, so nothing here can turn arbitrary text into
audio by itself. `tail/tts.lua` ships a quiet fallback (one soft tone per word) and
calls out through `A.tts.backend` when one is set:

```lua
A.tts.backend = function(text)
    -- hand text to a real synthesiser here, then play what it returns
end
```

## updating

`tail/updater.lua` reads `version.json` every 15s (Settings > Updates) and compares
its `rev` with the `rev` compiled into the running loader. A POST endpoint on
`A.updater.api` is used when the executor has a `request` function, and the static
file is the fallback for everything else - a check never reports "up to date" just
because the endpoint could not be reached. On a newer rev it asks once, saying
plainly that the configuration will be saved and restored, then:

1. writes the config to `Aether/config.json`
2. unloads through `_G.AetherUnload`, exactly like the Unload button
3. downloads and runs `main.lua` again, which replays the config on the way up

If the config cannot be written the update is cancelled rather than silently
dropping it. After one detection the device goes quiet for five minutes, and a
rev the user declined is not asked about again (Check now resets that).

Releasing means bumping `REV` in `main.lua` and `rev` in `version.json`
together - the updater warns in the console if the file falls behind the loader,
because in that state nobody can be offered the next build.

No server is needed: `version.json` is a 4-line file on the CDN the script already
trusts. `A.updater.api` can point at a POST endpoint instead - it receives
`{rev, build}` in the body and answers with the same JSON shape - but a per-device
POST every few seconds costs money at scale and buys nothing over a static file.
```
Aether/
├── main.lua                  loader (the only file users run)
├── version.json              rev + notes the update check polls
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
    ├── hud.lua               stats HUD: fps, ping, players
    ├── glass.lua             glass blur and Liquid Glass
    ├── settings.lua          accent colour, config save/load, session actions
    ├── tts.lua               read-aloud: hover, progress bar, first-run prompt
    ├── keybinds.lua          key handlers and the Keybinds page
    ├── updater.lua           update check, prompt, restart
    └── startup.lua           show/hide, search, startup animation
```
