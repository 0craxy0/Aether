local A = ...
local T, tween, notify = A.T, A.tween, A.notify
local HttpService, has = A.HttpService, A.has
local accentLinks = A.accentLinks
local toggle, button, dropdown = A.toggle, A.button, A.dropdown

-- accent colour ---------------------------------------------------
local ACCENTS = {
	Blue = Color3.fromHex("0A84FF"), Teal = Color3.fromHex("64D2FF"), Green = Color3.fromHex("30D158"),
	Purple = Color3.fromHex("BF5AF2"), Pink = Color3.fromHex("FF375F"), Orange = Color3.fromHex("FF9F0A"),
	Red = Color3.fromHex("FF453A"),
}
local ACCENT_NAMES = { "Blue", "Teal", "Green", "Purple", "Pink", "Orange", "Red" }

function A.setAccent(c)
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
	for _, e in ipairs(A.registry) do
		local v = data[e.name]
		if e.load and v ~= nil then pcall(e.load, v) end
	end
	return true
end

-- page ------------------------------------------------------------
local pSet = A.makePage("Settings", 8)

local sLook = pSet.section("Appearance", 1)
dropdown(sLook, "Accent color", ACCENT_NAMES, "Blue", function(v)
	if ACCENTS[v] then A.setAccent(ACCENTS[v]) end
end)

local sCfg = pSet.section("Config", 2)
button(sCfg, "Save config", "SAVE", function()
	local ok, err = A.saveConfig()
	if ok then notify("Config", "saved to " .. FILE, "good") else notify("Config", tostring(err), "bad") end
end)
button(sCfg, "Load config", "LOAD", function()
	local ok, err = A.loadConfig()
	if ok then notify("Config", "loaded", "good") else notify("Config", tostring(err), "bad") end
end)

local sSess = pSet.section("Session", 3)
toggle(sSess, "Auto-execute on teleport", false, A.setAutoExec)
button(sSess, "Rejoin server", "REJOIN", A.rejoin)
button(sSess, "Server hop", "HOP", A.hop)
button(sSess, "Copy server ID", "COPY", function() A.copy(game.JobId) end)
button(sSess, "Unload Aether", "UNLOAD", function()
	if _G.AetherUnload then _G.AetherUnload() end
end)

A.stage("7 settings page done")
