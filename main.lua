
local BASE = "https://raw.githubusercontent.com/0craxy0/Aether/main/"

-- A stage file is a few kilobytes. Anything far past that is not ours - a captive
-- portal, a proxy error page or a hostile host - and loadstring-ing it would only
-- turn a bad download into a confusing syntax error at best and an OOM at worst.
local MAX_BYTES = 2 * 1024 * 1024

local FILES = {
	"core/env.lua",
	"core/theme.lua",
	"core/util.lua",
	"core/notify.lua",
	"core/sfx.lua",
	"core/physics.lua",
	"core/window.lua",
	"core/depth.lua",
	"core/motion.lua",
	"core/widgets.lua",
	"modules/filter.lua",
	"modules/character.lua",
	"modules/esp.lua",
	"modules/aim.lua",
	"modules/silentaim.lua",
	"modules/killaura.lua",
	"modules/projectile.lua",
	"modules/actions.lua",
	"core/pagekit.lua",
	"pages/character.lua",
	"pages/movement.lua",
	"pages/visuals.lua",
	"pages/combat.lua",
	"pages/players.lua",
	"tail/keylist.lua",   -- before pages/ui (it creates A.kbList)
	"pages/ui.lua",       -- creates A.sUI4 for the files below
	"tail/extras.lua",
	"tail/hud.lua",
	"tail/glass.lua",
	"tail/settings.lua",
	"tail/tts.lua",       -- after settings: it reads and writes the config extras
	"tail/keybinds.lua",
	"tail/startup.lua",
	"tail/updater.lua",
}

-- bumped whenever a push changes behaviour. Printed on load and shown in the
-- window header, so "am I on the new build?" is a fact instead of a guess.
local BUILD = "2026-11-06.14"
-- monotonic: the updater compares rev, never the date string
local REV = 14

-- opt-in, for chasing a stale copy: set getgenv().AetherFresh = true before
-- executing and every file is fetched with a unique URL, bypassing every cache
local FRESH = getgenv and getgenv().AetherFresh == true

local function url(path)
	if FRESH then return BASE .. path .. "?t=" .. tostring(os.time()) end
	return BASE .. path
end

local A = { base = BASE, build = BUILD, rev = REV }

-- lets auto-execute on teleport re-run this loader. The private copy is the one
-- the queue string is built from; the getgenv one stays for compatibility and is
-- re-validated against this host before it is ever executed (see
-- modules/actions.lua - another script in the executor can write to getgenv).
A.source = BASE .. "main.lua"
getgenv().AetherSource = A.source
print("[Aether] build " .. BUILD .. (FRESH and " (fresh fetch)" or ""))

-- a half-loaded hub is worse than none: warn once, then tear down whatever was built
-- so the ScreenGui from core/notify.lua cannot outlive the load that made it
local function fail(msg)
	warn("[Aether] " .. msg)
	if type(A.unload) == "function" then pcall(A.unload) end
end

local function fetch(path)
	local ok, src = pcall(game.HttpGet, game, url(path))
	if not ok then return nil, tostring(src) end
	if type(src) ~= "string" then return nil, "not a text response" end
	if #src > MAX_BYTES then return nil, string.format("response too large (%d bytes)", #src) end
	if #src == 0 then return nil, "empty response" end
	return src
end

for _, path in ipairs(FILES) do
	local src, why = fetch(path)
	if not src then
		return fail("could not download " .. path .. ": " .. tostring(why))
	end
	local fn, compileErr = loadstring(src, "@" .. path)
	if not fn then
		return fail("syntax error in " .. path .. ": " .. tostring(compileErr))
	end
	local okRun, runErr = pcall(fn, A)
	if not okRun then
		return fail("error in " .. path .. ": " .. tostring(runErr))
	end
end
