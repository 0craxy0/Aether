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
  under the cursor grows a 2px accent rail on its leading edge; section headings
  sit on a hairline so a group reads as finished, and the window edge is a
  gradient rim rather than a flat outline
- **voice** - one short blip for the whole interface, pitched per intent

All four are switchable on the UI page, and none of them touch a module's state.
Turning magnetism off mid-hover puts the leaning control back on its row instead
of leaving it a few pixels off.

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
| `sendglobal` | `10164995980` | cash farm: stands on a WinPad (see below) |
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

## send a global message

`shelf: sendglobal` · place `10164995980` (also `118282960139128`, the id the probe
actually ran under)

The game is a cash sink: finish an obby, get cash, spend it on a server or global
message. Tiers unlock in order - Easy, Medium, Hard, Nightmare, Insane - and a
WinPad you have not unlocked bounces you back to the previous tier's start.
**Touching a WinPad is enough to be paid**, which is what makes the farm possible:
the module stands on the pad rather than running the obby.

| tier | pays | cooldown | pad |
|---|---|---|---|
| Easy | 100 | 2s | `Map.Obbies.Easy.WinPad` |
| Medium | 200 | 3s | `Map.Obbies.Medium.WinPad` |
| Hard | 350 | 5s | `Map.Obbies.Hard.WinPad` |
| Nightmare | 550 | 8s | `Map.Obbies.Nightmare.WinPad` |
| Insane | 750 | 10s | `Map.Obbies.Insane.WinPad` |

**Cooldowns are per tier and are waited out, not attempted around.** A pad that
refuses is cooling, not broken, so a refusal never counts toward the three misses
that stop the farm: it sets that tier's `readyAt` and the loop sleeps until then,
in half-second slices so the switch still turns off promptly. Nothing is sent at
a pad that is known to be cooling, and the status block shows the countdown.

The ladder also decides what *Auto* picks. Cash per second including the cooldown
and the ~0.9s attempt overhead - 34 / 51 / 59 / 62 / 69 from Easy to Insane - is
what makes Insane the right target even with the longest cooldown, rather than
assuming the biggest number wins. `Cooldown padding (s)` adds to all five, for a
server that turns out to be stricter than measured; guessing high costs
throughput, guessing low costs a refusal.

Those six numbers a side (payout and counter) come from `tools/padlog.lua` on a
live run; the pads themselves are looked up **by instance** on every attempt, not
by the coordinates in this table. A part found by name cannot drift when the map
is edited, and a mismatch shows up as `WinPad not found` on the page instead of a
silent teleport into the floor.

Cash is `leaderstats.Cash`. `SG.cash()` reads any numeric leaderstat or player
attribute whose name looks like a currency, so a rename does not break the payout
check - and a payout that does not move the counter is how a locked tier is
detected, so the two must agree.

**The payout is confirmed by the server's own signal.** On completion the server
fires three notifications at the client - `ObbyUnlocked(tier, next)`,
`CashBurst(amount, tier)` and `TutorialObbyCompleted(tier)` - which is narration,
not protocol: the amount riding outbound is what a *display* needs, and a request
has no reason to state its own reward. The server watched the character touch the
pad itself, using the replicated position, which is why standing on it is enough.
So the farm listens to `CashBurst` and takes that amount as the result instead of
diffing the counter, and the counter read stays as the fallback. Nothing in this
shelf sends anything to the server.

- **Auto-farm cash** stands on the selected tier every *Attempt interval*.
- **Auto** touches each pad once from Easy up, keeps the highest one that paid,
  and farms that. It is the first thing it does when the switch is turned on and
  the unlocked tier is still unknown.
- three attempts in a row with no payout stop the loop and say so, rather than
  hammering a pad that has moved or a tier that is not unlocked.
- **Teleport height** is the one knob for a pad that does not register: it is how
  far above the pad centre the character is placed. The pads sit in the floor, so
  0-1 studs is usually right and the default is 2.
- **Rescan pads** re-resolves the five instances, for a map that replicated late.

## dev tools

`tools/` holds scripts the hub never loads and `main.lua` never fetches - they are
things you run yourself, once, while building a shelf for a game that has none.

- `padlog.lua` - the probe for a game with no shelf yet. It samples the character
  every frame and reports the three signals that actually identify a finish pad:
  a teleport that was not walking (the position *before* it is the pad), a coin
  counter that moved (the position you were standing on is the pad), and the
  tier-shaped models in Workspace with their centres. F8 prints the summary, F9
  writes `Aether/sendglobal-pads.json`. It reads your own position and your own
  counters only; it never teleports, touches or fires anything.

## loading

`main.lua` draws a small centred card before it fetches the first file, then
repaints it from `A.stage`. It reads `7 / 15 loaded Â· keybind overlay` with the
build number underneath, so a slow executor is visibly slow rather than frozen.

- **downloads overlap, execution does not.** It is the *execution* order that has
  dependencies, not the downloads, so a pool of four requests starts every file
  this shelf needs as soon as the load begins and the sequential loop picks each
  answer up as it reaches it. In turn that was the sum of forty round trips;
  overlapped it is roughly a quarter of that, and the files still run in exactly
  the order `FILES` lists them. A slot that misses its deadline falls through to
  a direct retry and then to that build's cached copy, exactly as before.
- **the cache is written off the load thread.** Forty synchronous `writefile`
  calls sat in the middle of the critical path for no benefit; they are spawned
  now, so a load never waits on the disk.
- **the first page's entrance plays when it can be seen.** `selectPage` used to
  run the full row stagger while the loading card still covered the screen, so
  the animation was spent invisibly and the panel's first frame was already
  settled. It now rests the page and `A.enterActive` plays the entrance from
  `show()`, once the card is gone.
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
  save in the middle of the read; pages whose rows come from the config (saved
  Tesla spots) are rebuilt afterwards, so the panel matches the file
- **Copy config** - the exact JSON the file would contain, on the clipboard
- **Reset all settings** - every row back to the value it was created with, then
  one write; the accent returns to its default through `A.setAccent`, so the
  whole panel repaints rather than only the swatch

The window's own size rides the same file under `Window layout`: drag a corner
and the size is remembered, so a restart comes back to the panel you left rather
than to 580x430. It is registered without a row, so it never appears in search,
and `Reset UI size` writes the default back.

### profiles

A named profile is the same config file under a different name, in
`Aether/profiles/<name>.json`. **Settings > Profiles** takes a name and offers
Save as profile / Load profile / Delete profile; the name is lowercased and
stripped to letters, digits, `-` and `_` first, so `Arsenal pvp` becomes
`arsenal-pvp`. Loading goes through the same replay as **Load config**, so a
profile is a whole panel state - every shelf, every slider, the window size -
not just a preset for one page. Nothing is written to a profile until you say
save, and the live config is never overwritten by a load until auto-save fires.

## world and safety

Two pages that are about the place rather than about your character.

**Movement** keeps waypoints: type a name, **SAVE** stores your position in the
config under `waypoints` (flat x/y/z numbers, not a `Vector3`, because
`JSONEncode` cannot write one). Each saved row shows its coordinates and how far
away it is, with **GO** to jump there and an x to delete it. 24 of them, names up
to 24 characters, re-saving the same name updates it in place.

**World** is the finder:

- **Find & teleport** searches every `BasePart` and `Model` in `Workspace` by name
  substring, capped at 40 hits. Each result shows the instance's path and your
  distance to it; **GO** puts you three studs above it.
- **Highlight objects** draws a box and a distance label on matching parts through
  the `Drawing` API, rescanned every 1.5s inside a range you set (default 300
  studs, 24 objects). Nothing is drawn on top of the panel itself.
- **This server** prints place id, job id, player count, server uptime, and ping
  (`Stats.Network.ServerStatsItem["Data Ping"]`), plus your name/id, executor and
  build, refreshed every two seconds while the page is open.
- **Low graphics** is on the Visuals page: it stops every particle/trail/beam/
  smoke/fire/sparkle and hides decals and textures, and zeroes the two lighting
  environment scales. It does not touch `FogEnd` or `GlobalShadows` - those belong
  to Remove fog and Fullbright, and one property with two owners means whichever
  switch you turn off last wins. Turning it off restores what it changed.

### guard

Three switches on the Character page, all about other people's scripts:

- **Anti-fling** cancels an `AssemblyAngularVelocity` above 2500 rad/s and caps
  linear velocity at 400 studs/s. Nothing legitimate spins you that fast.
- **Anti-teleport** is off by default and honest about why: it cannot tell an
  attacker from the game itself, so it fights any scripted move including a game
  that teleports you after a win. Anything in the hub that moves you - waypoints,
  the finder, player teleport - calls `A.guard.expect(2)` first so it is left
  alone.
- **Panic** resets the character and unloads the hub in one press. Bound to `End`
  on the Keybinds page.

Both guard switches share one `Heartbeat` and one idea of "the current root";
last position is cleared on `CharacterAdded`, because a respawn legitimately
starts somewhere else.

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
â”œâ”€â”€ main.lua                  loader (the only file users run)
â”œâ”€â”€ version.json              rev + notes the update check polls
â”œâ”€â”€ core/
â”‚   â”œâ”€â”€ env.lua               services, executor checks, cleanup list
â”‚   â”œâ”€â”€ games.lua             game shelves: arsenal, tesla, universal
â”‚   â”œâ”€â”€ theme.lua             colours and fonts
â”‚   â”œâ”€â”€ util.lua              new, tween, corner, stroke, pad, drawX, label
â”‚   â”œâ”€â”€ notify.lua            ScreenGui and toasts
â”‚   â”œâ”€â”€ sfx.lua               one pitched voice for every interaction
â”‚   â”œâ”€â”€ physics.lua           elastic window drag and throw
â”‚   â”œâ”€â”€ window.lua            window, shadow, header, sidebar, drag
â”‚   â”œâ”€â”€ depth.lua             cursor parallax and throw inertia
â”‚   â”œâ”€â”€ motion.lua            staggered entrances, magnetism, ripples
â”‚   â”œâ”€â”€ widgets.lua           toggle, slider, button, dropdown, keybind
â”‚   â”œâ”€â”€ colorpicker.lua       saturation/value picker for the accent
â”‚   â””â”€â”€ pagekit.lua           makePage, makeConfig, gear, page hooks
â”œâ”€â”€ modules/
â”‚   â”œâ”€â”€ filter.lua            whitelist/blacklist and UI-mask helpers
â”‚   â”œâ”€â”€ character.lua         fly, noclip, inf jump, anti-AFK, fullbright
â”‚   â”œâ”€â”€ esp.lua
â”‚   â”œâ”€â”€ aim.lua               arsenal shelf
â”‚   â”œâ”€â”€ silentaim.lua         arsenal shelf
â”‚   â”œâ”€â”€ killaura.lua          arsenal shelf
â”‚   â”œâ”€â”€ projectile.lua        arsenal shelf: gravity counter
â”‚   â”œâ”€â”€ tesla.lua             tesla shelf: cold gas, auto-pilot, saved spots
â”‚   â””â”€â”€ actions.lua           teleport, rejoin, hop, auto-execute, copy
â”œâ”€â”€ pages/
â”‚   â”œâ”€â”€ character.lua
â”‚   â”œâ”€â”€ movement.lua
â”‚   â”œâ”€â”€ visuals.lua
â”‚   â”œâ”€â”€ combat.lua            aimbot, silent aim, kill aura (arsenal)
â”‚   â”œâ”€â”€ tesla.lua             vehicle, cold gas, auto-pilot, spots (tesla)
â”‚   â”œâ”€â”€ players.lua
â”‚   â”œâ”€â”€ games.lua             active shelf, switch and restart
â”‚   â””â”€â”€ ui.lua                keybind list toggle, rescaling, window physics
â””â”€â”€ tail/
    â”œâ”€â”€ keylist.lua           keybind list overlay
    â”œâ”€â”€ extras.lua            easter egg
    â”œâ”€â”€ hud.lua               stats HUD: fps, ping, players
    â”œâ”€â”€ glass.lua             glass blur and Liquid Glass
    â”œâ”€â”€ settings.lua          accent colour, config save/load, session actions
    â”œâ”€â”€ tts.lua               read-aloud: hover, progress bar, first-run prompt
    â”œâ”€â”€ keybinds.lua          key handlers and the Keybinds page
    â”œâ”€â”€ updater.lua           update check, prompt, restart
    â”œâ”€â”€ announcements.lua     read-only notes from announcements.json
    â”œâ”€â”€ admin.lua             owner panel (one account, local check only)
    â””â”€â”€ startup.lua           show/hide, search, startup animation
```
