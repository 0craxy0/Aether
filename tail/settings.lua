local A = ...
local T, tween, notify = A.T, A.tween, A.notify
local sfx = A.sfx
local HttpService, has = A.HttpService, A.has
local accentLinks = A.accentLinks
local toggle, button, dropdown = A.toggle, A.button, A.dropdown
local colorPicker = A.colorPicker

-- accent colour ---------------------------------------------------
local ACCENTS = {
	Blue = Color3.fromHex("0A84FF"), Teal = Color3.fromHex("64D2FF"), Green = Color3.fromHex("30D158"),
	Purple = Color3.fromHex("BF5AF2"), Pink = Color3.fromHex("FF375F"), Orange = Color3.fromHex("FF9F0A"),
	Red = Color3.fromHex("FF453A"),
}
local ACCENT_NAMES = { "Blue", "Teal", "Green", "Purple", "Pink", "Orange", "Red" }

function A.setAccent(c, name)
	-- name is only supplied by the presets; a picker drag leaves it alone so the
	-- cycle button resumes from the last named preset rather than resetting
	if name then A.accentName = name end
	T.accent = c
	for i = #accentLinks, 1, -1 do
		local l = accentLinks[i]
		if not l.obj.Parent then
			table.remove(accentLinks, i)
		else
			tween(l.obj, 0.25, { [l.kind == "text" and "TextColor3" or "BackgroundColor3"] = c })
		end
	end
	if A.activeTab then A.selectPage(A.activeTab) end
end

-- config save / load (replaces the placeholders from modules/actions.lua) --
local FOLDER, FILE = "Aether", "Aether/config.json"

function A.saveConfig()
	if not has.writefile then return false, "writefile unsupported" end
	local data = {}
	for _, e in ipairs(A.registry) do
		if e.save then
			local ok, v = pcall(e.save)
			if ok and v ~= nil then data[e.name] = v end
		end
	end
	if has.makefolder then
		pcall(function()
			if not (isfolder and isfolder(FOLDER)) then makefolder(FOLDER) end
		end)
	end
	return pcall(writefile, FILE, HttpService:JSONEncode(data))
end

function A.loadConfig()
	if not (has.readfile and has.isfile and isfile(FILE)) then return false, "no saved config" end
	local ok, data = pcall(function() return HttpService:JSONDecode(readfile(FILE)) end)
	if not ok or type(data) ~= "table" then return false, "config unreadable" end
	-- replaying a config fires every widget at once: do it silently
	sfx.mute = sfx.mute + 1
	pcall(function()
		for _, e in ipairs(A.registry) do
			local v = data[e.name]
			if e.load and v ~= nil then pcall(e.load, v) end
		end
	end)
	sfx.mute = sfx.mute - 1
	return true
end

-- page ------------------------------------------------------------
local pSet = A.makePage("Settings", 8)
A.pageSettings = pSet -- tail/updater.lua adds the Update section to it

local sLook = pSet.section("Appearance", 1)
-- the presets are shortcuts into the picker, not a second system: choosing one
-- moves the picker's own marker, so the picker and the palette cannot disagree
local picker = colorPicker(sLook, "Accent color", ACCENTS.Blue, function(c) A.setAccent(c) end)

local sPresets = pSet.section("Presets", 2)
button(sPresets, "Cycle preset", "NEXT", function()
	local cur = A.accentName or "Blue"
	local i = table.find(ACCENT_NAMES, cur) or 1
	local nxt = ACCENT_NAMES[i % #ACCENT_NAMES + 1]
	if picker then picker.set(ACCENTS[nxt]) end
	A.setAccent(ACCENTS[nxt], nxt)
end)

local sCfg = pSet.section("Config", 3)
button(sCfg, "Save config", "SAVE", function()
	local ok, err = A.saveConfig()
	if ok then notify("Config", "saved to " .. FILE, "good") else notify("Config", tostring(err), "bad") end
end)
button(sCfg, "Load config", "LOAD", function()
	local ok, err = A.loadConfig()
	if ok then notify("Config", "loaded", "good") else notify("Config", tostring(err), "bad") end
end)

local sSess = pSet.section("Session", 4)
toggle(sSess, "Auto-execute on teleport", false, A.setAutoExec)
button(sSess, "Rejoin server", "REJOIN", A.rejoin)
button(sSess, "Server hop", "HOP", A.hop)
button(sSess, "Copy server ID", "COPY", function() A.copy(game.JobId) end)
button(sSess, "Unload Aether", "UNLOAD", function()
	if _G.AetherUnload then _G.AetherUnload() end
end)

A.stage("7 settings page done")
