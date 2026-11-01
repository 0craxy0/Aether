
local BASE = "https://raw.githubusercontent.com/0craxy0/Aether/main/"

local FILES = {
	"core/env.lua",
	"core/theme.lua",
	"core/util.lua",
	"core/notify.lua",
	"core/physics.lua",
	"core/window.lua",
	"core/widgets.lua",
	"modules/filter.lua",
	"modules/character.lua",
	"modules/esp.lua",
	"modules/aim.lua",
	"modules/silentaim.lua",
	"modules/killaura.lua",
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
	"tail/glass.lua",
	"tail/settings.lua",
	"tail/keybinds.lua",
	"tail/startup.lua",
}

local A = { base = BASE }

-- lets auto-execute on teleport re-run this loader
getgenv().AetherSource = BASE .. "main.lua"

-- a half-loaded hub is worse than none: warn once, then tear down whatever was built
-- so the ScreenGui from core/notify.lua cannot outlive the load that made it
local function fail(msg)
	warn("[Aether] " .. msg)
	if type(A.unload) == "function" then pcall(A.unload) end
end

for _, path in ipairs(FILES) do
	local okGet, src = pcall(game.HttpGet, game, BASE .. path)
	if not okGet then
		return fail("could not download " .. path .. ": " .. tostring(src))
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
