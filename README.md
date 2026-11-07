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
- **material** - a press leaves a ripple in the row it landed on, and the row
  under the cursor grows a 2px accent rail on its leading edge
- **voice** - one short blip for the whole interface, pitched per intent

All four are switchable on the UI page, and none of them touch a module's state.

Toasts are readable on your own schedule: hovering one holds it open, moving
away lets it expire, and a click dismisses it immediately.

Dropdowns behave like dropdowns now: opening one closes any other, a click
outside the row closes it, it closes when you leave the page, and its caret
turns over while the list is out.

## games

Aether is a hub, not an Arsenal script with a theme. `main.lua` decides a **shelf**
from `game.PlaceId` *before it downloads the first file*, because the file list is
what changes:

| shelf | place | carries |
|---|---|---|
| `arsenal` | `286090429` | combat (aim, silent aim, kill aura, projectile counter), visuals, movement |
| `tesla` | `1794074302239` | vehicle tools only - cold gas, auto-pilot |
| `universal` | anything else | generic tools (character, ESP, movement, actions) + the detected game's own set, if it has one |

A group of game-specific files loads only when that game is **detected** here or
**selected** for this place - so a Tesla tab cannot appear in Arsenal, and a game
with no shelf gets the generic tools and nothing else. A manual shelf choice is
pinned to the place it was made for; the next teleport returns to auto-detect.
Both pages also refuse to build without their modules, so a tab can never exist
without the code behind it. The shelf shows as a pill in the header; the Games
page lists all three and restarts into the one you pick (config is flushed first,
same path the updater uses). `getgenv().AetherGame` overrides detection for a
place that is not in the table.

## flying tesla roadster

The Tesla page is two tools and a marker:

- **Cold gas** - two layers, because one is not enough. The poller holds every
  number in the car, on it, or in the backpack whose name looks like
  `gas`/`boost`/`nitro`/`turbo`/`charge` at the highest value it has ever had;
  boolean flags with those names are held true. `Scan gas values` prints every
  candidate. If a write does not stick (a value the server replicates down -
  `NitroMul` is exactly that), the page says *server-owned* and you can switch on
  **boost assist**: it raises the car's own top speed while it is rolling forward.
  It is off by default and never restored by config, because writing velocity on a
  server-simulated car costs a replication round trip per tick - it runs at 15 Hz,
  only for the driver, and disables itself within 3s if the speed does not rise.
- **Stunt coins** - the HUD number. It is not an attribute of the car, so it is
  found the same way those are: leaderstats, a folder on the player, or a player
  attribute whose name looks like a coin counter. The line above the row says
  which one it found, the box holds the real value, and `Set` (or Enter) writes it
  and reads it back. It is a client-side write: the HUD follows it, and the server
  may put its own number back afterwards.
- **Auto-pilot** - middle-click the spot you want on the map. The destination is
  marked in the world - a tag on the point and a beam from the ground up to it -
  and the scroll wheel raises it (`Destination height` in the page follows the
  wheel). The camera is deliberately left alone: the game's own chase camera keeps
  working, so `Drive` (or Enter) can start the run without the view ever being
  somewhere you did not put it. `Cancel` (or Escape) clears the marker.
  Default is `Seat inputs`: throttle and steer on the `VehicleSeat`, scaled by
  distance and aimed by heading error, with a short reverse manoeuvre instead of
  looping the block. `Velocity assist` pushes the assembly for custom chassis.
  `Invert steering` is the one-click fix if your car steers the wrong way.
- **Saved spots** - `Save destination` stores the point in your config under
  `teslaSpots`; each saved row has a `DRIVE` button, so the places you keep
  visiting are one click, not a re-pick.

Tuning notes that cannot be settled without the game open: steering sign (see the
toggle), and the throttle floor at close range (0.45 - raise it if the car stalls
on a slope). Both live in `modules/tesla.lua`'s drive step.

## loading

`main.lua` draws a small centred card before it fetches the first file, then
repaints it from `A.stage`. It reads `7 / 15 loaded · keybind overlay` with the
build number underneath, so a slow executor is visibly slow rather than frozen.

- the 15 stages are declared in one `PLAN` table in `main.lua`, in the order they
  are emitted (which is not the order of `FILES` - `hud` fires before `settings`,
  `tts` after it). Everything else in the loader calls `A.stage(label)`, so a
  stage can only be added by adding a row to that table.
- completion is the file loop ending, not the last stage: `tail/admin.lua`
  returns before announcing itself on a non-owner client, and the bar must not
  sit one short forever.
- every UI call is inside a `pcall`. If the executor will not parent a ScreenGui
  it logs `loading screen unavailable` and loads normally - the screen is a
  courtesy, not a dependency.
- a failed download or syntax error turns the card red with the reason and keeps
  it up for eight seconds instead of leaving a silent half-loaded hub.
- the panel is built from stage 3 onwards but its ScreenGui stays disabled until
  the card has finished fading, so nothing of the UI shows behind it. The window
  then animates in exactly as it always did. Announcements and the update check
  wait for the same moment, so a toast or a prompt can never be raised while
  nobody can see it.

The stage log lines (`[Aether] stage ...`) are unchanged, so console output still
shows exactly the same sequence.

## search

The field at the top filters every registered row by name and jumps to the first
page that has a match. A small counter on the right says how many rows matched,
so an empty page never looks like a broken search.

- `/` or `Ctrl+F` focuses the field (and shows the panel if it was hidden)
- `Escape` clears it and hands focus back
- both shortcuts stay out of the way while any other text box is focused

## config

`Aether/config.json` is written 1.5s after the last change (Settings > Auto-save
on change). The Config section also gives you:

- **Save config** - flush the pending write right now
- **Load config** - replay the file through every widget, without starting a
  save in the middle of the read
- **Copy config** - the exact JSON the file would contain, on the clipboard
- **Reset all settings** - every row back to the value it was created with, then
  one write; the accent returns to its default through `A.setAccent`, so the
  whole panel repaints rather than only the swatch


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

## announcements

`tail/announcements.lua` reads notes from **two places, in order**:

1. `GET /announcements` on the version Worker (`A.announce.api`) - polls every
   15s. Publishing there is one authenticated request, so a note is live without
   touching GitHub.
2. `announcements.json` next to `version.json`, polled every 5 minutes - the floor.
   If the Worker is down, moved, or has no storage bound, this is what answers.

Either way the shape is the same:

```json
{
  "items": [
    { "id": "2026-11-06-a", "text": "Double XP this weekend.", "kind": "good" }
  ]
}
```

`id` is what makes a note appear once, so keep it stable (the endpoint mints one
when you leave it out). `kind` is `good`, `bad` or omitted. Each notice is capped at
220 characters and three are shown per check.

Publishing from anywhere, no browser and no GitHub edit:

```bash
curl -X POST https://aether-version.<subdomain>.workers.dev/announce \
  -H "Authorization: Bearer $AETHER_PUBLISH_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"text":"Double XP this weekend.","kind":"good"}'
```

`{"clear":true}` empties the list. The token is a Worker secret and never appears
in this repo or in the script - see `Aether-Version/README.md` for setup.

The owner panel also has a composer: type the note, cycle its kind, *Preview* it in
the real toast, then *Copy announcements.json* if you would rather commit it. The
draft survives a reload.

This is one-way by design: the client fetches **text** and displays it. It accepts
no command, no URL to run, no id to target - a note can never make a client do
anything. Users own the switch on the UI page (*Show announcements*), and turning
it off stops the fetch entirely.

## owner panel

`tail/admin.lua` builds an extra page for one account (`1562524075`) and returns
immediately for everyone else. It is a local comparison on a local value: no
hardware id is read, stored or sent, and no other client is contacted.

What it gives that account: force an update check, restart into the latest build,
re-read the announcements file, reset the seen list, copy the JSON template, and
see the executor / build / rev it is running. Every one of those is a control over
*this* instance of the script - the same actions the Settings page already offers -
just collected in one place.

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
│   ├── games.lua             game shelves: arsenal, tesla, universal
│   ├── theme.lua             colours and fonts
│   ├── util.lua              new, tween, corner, stroke, pad, drawX, label
│   ├── notify.lua            ScreenGui and toasts
│   ├── sfx.lua               one pitched voice for every interaction
│   ├── physics.lua           elastic window drag and throw
│   ├── window.lua            window, shadow, header, sidebar, drag
│   ├── depth.lua             cursor parallax and throw inertia
│   ├── motion.lua            staggered entrances, magnetism, ripples
│   ├── widgets.lua           toggle, slider, button, dropdown, keybind
│   ├── colorpicker.lua       saturation/value picker for the accent
│   └── pagekit.lua           makePage, makeConfig, gear, page hooks
├── modules/
│   ├── filter.lua            whitelist/blacklist and UI-mask helpers
│   ├── character.lua         fly, noclip, inf jump, anti-AFK, fullbright
│   ├── esp.lua
│   ├── aim.lua               arsenal shelf
│   ├── silentaim.lua         arsenal shelf
│   ├── killaura.lua          arsenal shelf
│   ├── projectile.lua        arsenal shelf: gravity counter
│   ├── tesla.lua             tesla shelf: cold gas, auto-pilot, saved spots
│   └── actions.lua           teleport, rejoin, hop, auto-execute, copy
├── pages/
│   ├── character.lua
│   ├── movement.lua
│   ├── visuals.lua
│   ├── combat.lua            aimbot, silent aim, kill aura (arsenal)
│   ├── tesla.lua             vehicle, cold gas, auto-pilot, spots (tesla)
│   ├── players.lua
│   ├── games.lua             active shelf, switch and restart
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
    ├── announcements.lua     read-only notes from announcements.json
    ├── admin.lua             owner panel (one account, local check only)
    └── startup.lua           show/hide, search, startup animation
```

## internet tycoon

Place `10767564282`. Its own shelf, so the tab only appears in that game - the
loader decides the shelf from the place id before it fetches anything, and this
one is `tycoon`.

- **Money** - the balance is a leaderstats value, a value in a folder on the
  player, or a player attribute; the page scans for the most money-shaped one
  (`Cash`, `Money`, `Dollars`, `Funds`, ...) and says which it took. The box holds
  the real number, `Set`/Enter writes it, and `Keep it there` re-applies it every
  0.35s - which is the only part of a server-reconciled balance a client can hold.
- **Thunderstorms** - the storm that eats cables and towers is game state, so the
  page finds the switches (weather/storm/thunder/rain values and attributes it can
  see on `Lighting`, the player, `workspace` and `ReplicatedStorage`), pins them to
  calm once a second while it is on, and switches off lightning and thunder effects
  that are already running - `Enabled = false`, saved and restored, never deleted.
  A storm the server has already run is not undone by this: the damage is the
  server's, the sky in front of you is the client's.

Both features are honest about the line they cannot cross: a client write reports
what it read back, and "server-owned" means exactly that.
