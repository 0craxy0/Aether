local A = ...
local KB, keybinds, registry = A.KB, A.keybinds, A.registry
local UserInputService, RunService, onCleanup = A.UserInputService, A.RunService, A.onCleanup

-- extra overlay mappings (tail/keylist.lua reads KB.binds[module] -> bind name)
KB.binds["Noclip"] = "Toggle noclip"
KB.binds["Player ESP"] = "Toggle ESP"
KB.binds["Fullbright"] = "Toggle fullbright"

local pKeys = A.makePage("Keybinds", 7)
local sKeys = pKeys.section("Modules", 1)
A.keybind(sKeys, "Toggle fly", "F")
A.keybind(sKeys, "Toggle aimbot")
A.keybind(sKeys, "Toggle silent aim")
A.keybind(sKeys, "Toggle kill aura")
A.keybind(sKeys, "Toggle noclip", "N")
A.keybind(sKeys, "Toggle ESP")
A.keybind(sKeys, "Toggle fullbright")

local sKeys2 = pKeys.section("Interface", 2)
A.keybind(sKeys2, "Toggle UI", "RightShift")
A.keybind(sKeys2, "Teleport to cursor")

-- flips a toggle through the registry (fires its callback like a click) --
local function flip(widgetName)
	return function()
		for _, e in ipairs(registry) do
			if e.name == widgetName and e.save and e.load then
				e.load(not e.save())
				return
			end
		end
	end
end

local actions = {
	["Toggle fly"] = flip("Fly"),
	["Toggle aimbot"] = flip("Aimbot"),
	["Toggle silent aim"] = flip("Silent aim"),
	["Toggle kill aura"] = flip("Kill aura"),
	["Toggle noclip"] = flip("Noclip"),
	["Toggle ESP"] = flip("Player ESP"),
	["Toggle fullbright"] = flip("Fullbright"),
	["Toggle UI"] = function() if A.toggleUI then A.toggleUI() end end,
	["Teleport to cursor"] = function() A.tpToCursor() end,
}

-- Binds are read from the live map. The old version compared against a snapshot
-- rebuilt every Heartbeat, which meant a bind that existed but had not made it into
-- the snapshot yet simply did not fire - one of the ways this went quiet.
local CAPTURE_TTL = 8 -- a capture older than this is abandoned, never latched
local DEBUG = getgenv and getgenv().AetherDebug == true

local inputConn = UserInputService.InputBegan:Connect(function(i, gp)
	if gp or i.UserInputType ~= Enum.UserInputType.Keyboard then return end
	-- that keypress is being assigned to a row, not fired
	if KB.captureAt and os.clock() - KB.captureAt < CAPTURE_TTL then return end
	if UserInputService:GetFocusedTextBox() then return end

	local name = keybinds[i.KeyCode.Name]
	local fn = name and actions[name]
	if DEBUG then
		print(string.format("[Aether] key %s -> %s", i.KeyCode.Name, tostring(name or "unbound")))
	end
	if fn then
		local ok, err = pcall(fn)
		if not ok then A.notify(name, tostring(err), "bad") end
	end
end)
onCleanup(function() inputConn:Disconnect() end)

A.stage("8 keybinds done")
