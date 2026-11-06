local A = ...
local T, tween, notify, onCleanup = A.T, A.tween, A.notify, A.onCleanup
local sfx = A.sfx
local HttpService, has = A.HttpService, A.has
local accentLinks = A.accentLinks
local toggle, button, dropdown = A.toggle, A.button, A.dropdown

-- accent colour ---------------------------------------------------
-- The picker stores a hex string. These names are kept only so a config written
-- by the old named-swatch dropdown still loads as the colour it meant.
local ACCENTS = {
	Blue = Color3.fromHex("0A84FF"), Teal = Color3.fromHex("64D2FF"), Green = Color3.fromHex("30D158"),
	Purple = Color3.fromHex("BF5AF2"), Pink = Color3.fromHex("FF375F"), Orange = Color3.fromHex("FF9F0A"),
	Red = Color3.fromHex("FF453A"),
}

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

-- persisted values that are not widget rows (the read-aloud prompt decision, for
-- one). One reserved key holds them all, so they can never collide with a row.
A.extra = {}

function A.saveExtra(key, value)
	A.extra[key] = value
	-- rare and decisive: write now rather than wait for the auto-save debounce
	if A.flushConfig then return A.flushConfig() end
	return A.saveConfig()
end

function A.saveConfig()
	if not has.writefile then return false, "writefile unsupported" end
	local data = {}
	for _, e in ipairs(A.registry) do
		if e.save then
			local ok, v = pcall(e.save)
			if ok and v ~= nil then data[e.name] = v end
		end
	end
	data.__extra = {}
	for k, v in pairs(A.extra) do data.__extra[k] = v end
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
	-- replaying a config fires every widget at once: do it silently, and keep
	-- auto-save out of it so the file is not rewritten while it is being read
	sfx.mute = sfx.mute + 1
	A.configLoading = true
	pcall(function()
		for _, e in ipairs(A.registry) do
			local v = data[e.name]
			if e.load and v ~= nil then pcall(e.load, v) end
		end
	end)
	A.configLoading = false
	sfx.mute = sfx.mute - 1
	if type(data.__extra) == "table" then
		for k, v in pairs(data.__extra) do A.extra[k] = v end
	end
	return true
end

-- auto-save ---------------------------------------------------------
-- One write, 1.5s after the last change, so dragging a slider does not hit the
-- disk sixty times a second. A config being replayed never schedules a write.
local AUTOSAVE_DELAY = 1.5
A.autoSave = true
local saveTimer

function A.touch()
	if not A.autoSave or A.configLoading or not has.writefile then return end
	if saveTimer then task.cancel(saveTimer) end
	saveTimer = task.delay(AUTOSAVE_DELAY, function()
		saveTimer = nil
		if A.configLoading or not A.autoSave then return end
		A.saveConfig()
	end)
end

function A.flushConfig()
	if saveTimer then task.cancel(saveTimer); saveTimer = nil end
	return A.saveConfig()
end

-- a change made in the last 1.5s is not on disk yet; write it before the panel
-- goes away, or the auto-save the user trusted loses the last thing they set
onCleanup(function() if saveTimer then A.flushConfig() end end)

-- page ------------------------------------------------------------
local pSet = A.makePage("Settings", 8)
A.pageSettings = pSet -- tail/updater.lua adds the Update section to it

local sLook = pSet.section("Appearance", 1)
A.colorPicker(sLook, "Accent color", ACCENTS.Blue or Color3.fromHex("0A84FF"), function(c)
	A.setAccent(c)
end, ACCENTS)

local sCfg = pSet.section("Config", 2)
toggle(sCfg, "Auto-save on change", true, function(v) A.autoSave = v end)
button(sCfg, "Save config", "SAVE", function()
	local ok, err = A.flushConfig()
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
	-- A.unload is this instance's own teardown. Going through _G.AetherUnload
	-- meant any other script in the executor could swap that name for its own
	-- function and have it called here instead.
	if type(A.unload) == "function" then A.unload() end
end)

A.stage("7 settings page done")
