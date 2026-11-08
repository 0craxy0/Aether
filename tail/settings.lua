local A = ...
local T, tween, notify, onCleanup = A.T, A.tween, A.notify, A.onCleanup
local sfx = A.sfx
local HttpService, has = A.HttpService, A.has
local accentLinks = A.accentLinks
local toggle, button, dropdown = A.toggle, A.button, A.dropdown
local input, label = A.input, A.label

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

-- The config table, independent of the disk. Exported on its own so "Copy
-- config" can put the exact JSON on the clipboard without writing a file first.
function A.buildConfig()
	local data = {}
	for _, e in ipairs(A.registry) do
		if e.save then
			local ok, v = pcall(e.save)
			if ok and v ~= nil then data[e.name] = v end
		end
	end
	data.__extra = {}
	for k, v in pairs(A.extra) do data.__extra[k] = v end
	return data
end

function A.saveConfig()
	if not has.writefile then return false, "writefile unsupported" end
	local data = A.buildConfig()
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
	if not ok then return false, "config unreadable" end
	return A.applyConfig(data)
end

-- Replaying a config is the same job whether it came from the live file or from
-- a named profile, so it lives in one place. sfx is muted and auto-save is held
-- off for the duration: a replay fires every widget at once and must not write
-- the file it is reading.
function A.applyConfig(data)
	if type(data) ~= "table" then return false, "config unreadable" end
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
	-- Pages whose rows are built from the config (saved Tesla spots, waypoints)
	-- were drawn before this file was read, so they still show the previous
	-- session's rows. Replaying a config without telling them is why "Load config"
	-- looked like it half-worked.
	if A.refreshPages then pcall(A.refreshPages) end
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

-- Put every widget back on the value it was created with, then write once.
-- Sound is muted and auto-save is held off for the duration: a reset fires
-- dozens of callbacks and one disk write, not dozens of both.
function A.resetConfig()
	sfx.mute = sfx.mute + 1
	A.configLoading = true
	for _, e in ipairs(A.registry) do
		if e.reset then pcall(e.reset) end
	end
	A.configLoading = false
	sfx.mute = sfx.mute - 1
	local ok, err = A.flushConfig()
	-- the in-memory reset already happened; persisting it is the bonus, and an
	-- executor without writefile is not a failed reset
	return ok or err == "writefile unsupported", err
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
button(sCfg, "Copy config", "COPY", function()
	local ok, encoded = pcall(function() return HttpService:JSONEncode(A.buildConfig()) end)
	if ok and type(encoded) == "string" then
		A.copy(encoded)
	else
		notify("Config", tostring(encoded), "bad")
	end
end)
button(sCfg, "Reset all settings", "RESET", function()
	local ok, err = A.resetConfig()
	notify("Config", ok and "every setting is back to its default" or tostring(err), ok and "good" or "bad")
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

-- profiles --------------------------------------------------------------------
-- A named profile is this same config file under a different name. One file is
-- fine until you use the hub for two things - a combat shelf and a farm have
-- almost nothing in common - and then every switch costs a round of re-dialling.
-- Deliberately a text field rather than a dropdown: the list changes as you
-- create and delete, and rebuilding a dropdown row in place is not worth the
-- plumbing for what is four rows and a label.
local PROFILE_DIR = "Aether/profiles"

local function cleanName(name)
	return tostring(name or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function profilePath(name)
	return PROFILE_DIR .. "/" .. name .. ".json"
end

function A.profileNames()
	local out = {}
	if type(listfiles) ~= "function" then return out end
	local ok, files = pcall(listfiles, PROFILE_DIR)
	if not ok or type(files) ~= "table" then return out end
	for _, f in ipairs(files) do
		local name = tostring(f):match("([^/\\]+)%.json$")
		if name then out[#out + 1] = name end
	end
	table.sort(out)
	return out
end

function A.saveProfile(name)
	name = cleanName(name)
	if name == "" then return false, "name is empty" end
	if not has.writefile then return false, "writefile unsupported" end
	if type(makefolder) == "function" then
		pcall(makefolder, "Aether")
		pcall(makefolder, PROFILE_DIR)
	end
	local ok, encoded = pcall(function() return HttpService:JSONEncode(A.buildConfig()) end)
	if not ok or type(encoded) ~= "string" then return false, tostring(encoded) end
	local okWrite, err = pcall(writefile, profilePath(name), encoded)
	return okWrite, okWrite and ("saved " .. name) or tostring(err)
end

function A.loadProfile(name)
	name = cleanName(name)
	if not (has.readfile and has.isfile and isfile(profilePath(name))) then
		return false, "no profile named " .. name
	end
	local ok, data = pcall(function() return HttpService:JSONDecode(readfile(profilePath(name))) end)
	if not ok then return false, "profile unreadable" end
	local applied, why = A.applyConfig(data)
	if applied then return true, "loaded " .. name end
	return false, tostring(why)
end

function A.deleteProfile(name)
	name = cleanName(name)
	if type(delfile) ~= "function" then return false, "delfile unsupported" end
	local ok, err = pcall(delfile, profilePath(name))
	return ok, ok and ("deleted " .. name) or tostring(err)
end

local sProf = pSet.section("Profiles", 5)
local refreshProfiles -- declared first: the input below calls it

local profInput = input(sProf, "Profile name", "arsenal, chill, farm", function(v)
	local ok, msg = A.saveProfile(v)
	notify("Profiles", tostring(msg), ok and "good" or "bad")
	refreshProfiles()
end)

button(sProf, "Save as profile", "SAVE", function()
	local ok, msg = A.saveProfile(profInput.get())
	notify("Profiles", tostring(msg), ok and "good" or "bad")
	refreshProfiles()
end)
button(sProf, "Load profile", "LOAD", function()
	local ok, msg = A.loadProfile(profInput.get())
	notify("Profiles", tostring(msg), ok and "good" or "bad")
end)
button(sProf, "Delete profile", "DELETE", function()
	local ok, msg = A.deleteProfile(profInput.get())
	notify("Profiles", tostring(msg), ok and "good" or "bad")
	refreshProfiles()
end)

local profListLbl = label({
	Text = "", TextColor3 = T.muted, TextSize = 10, TextWrapped = true,
	Size = UDim2.new(1, 0, 0, 32), Parent = sProf,
})

refreshProfiles = function()
	if not profListLbl.Parent then return end
	local names = A.profileNames()
	if #names == 0 then
		profListLbl.Text = has.writefile and "no saved profiles yet" or "writefile unsupported - profiles unavailable"
	else
		profListLbl.Text = "saved: " .. table.concat(names, ", ")
	end
end
A.onPage(function(name)
	if name == "Settings" then refreshProfiles() end
end)
refreshProfiles()

A.stage("7 settings page done")
