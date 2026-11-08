local A = ...

-- Game profiles --------------------------------------------------------------
-- One loader, three shelves. main.lua picks the shelf before it fetches the
-- first file - it has to, the file list itself depends on the answer - and
-- leaves the key in A.profile. This file is the readable view of that decision:
-- the Games page, the window subtitle and any module that wants to know where it
-- is running all read from here.
--
--   arsenal    - Arsenal: combat, visuals and movement, tuned against its hit reg
--   tesla      - Flying Tesla Roadster: vehicle tools, no combat page
--   universal  - anything else: every module we have, none of it tuned
--
-- "universal" is the honest default. A game nobody has tested gets the whole
-- toolbox; the cost of that is that nothing is calibrated, which the Games page
-- says out loud rather than pretending otherwise.
local LIST = {
	{
		key = "arsenal", name = "Arsenal", place = (A.placeIds or {}).arsenal,
		blurb = "Combat, visuals and movement, tuned against Arsenal's hit registration.",
	},
	{
		key = "tesla", name = "Flying Tesla Roadster", place = (A.placeIds or {}).tesla,
		blurb = "Open world update: infinite cold gas and auto-pilot with a height-picking camera.",
	},
	{
		key = "sendglobal", name = "Send a Global Message", place = (A.placeIds or {}).sendglobal,
		blurb = "Cash farm: stands on a tier's WinPad to collect its payout, working up from the highest tier that pays.",
	},
	{
		key = "universal", name = "Universal", place = nil,
		blurb = "The generic shelf - character, ESP, movement, actions - plus the detected game's own modules, if it has any.",
	},
}

A.games = {}
for _, p in ipairs(LIST) do A.games[p.key] = p end
A.gameProfiles = LIST

-- A.profile is a key; A.game is the record. Anything that needs the name, the
-- place id or a sentence about it should read A.game.
A.game = A.games[A.profile] or A.games.universal
A.profile = A.game.key

function A.profileIs(key)
	return A.profile == key
end

-- True when the combat shelf is actually present here (selected or detected).
function A.hasCombat()
	return A.allows("arsenal")
end

-- The Tesla car tools: universal carries them only when this place actually is
-- the Tesla game (see A.allows), so the page cannot appear where there is no car
-- to drive.
function A.hasVehicleTools()
	return A.allows("tesla")
end

-- Is this group allowed here? Loaded when the shelf says so, or when the place
-- itself says so. A shelf chosen in a different game can never be why a tab is
-- on screen - that is the rule the loader applies to the file list, kept here in
-- one place so the UI and the modules cannot disagree.
function A.allows(group)
	if not group then return true end
	if A.profile == group then return true end
	if A.detectProfile and A.detectProfile(A.place or game.PlaceId) == group then return true end
	return false
end

-- Persisted override, pinned to the place it was chosen for.
function A.forceProfile(key)
	if not A.games[key] then return false end
	if getgenv then
		getgenv().AetherGame = key
		getgenv().AetherGameFor = A.place or game.PlaceId
	end
	return true
end

function A.clearProfile()
	if getgenv then
		getgenv().AetherGame = nil
		getgenv().AetherGameFor = nil
	end
end

-- Follow the place ------------------------------------------------------------
-- A teleport changes game.PlaceId under a loader that is already running, and the
-- shelf - and therefore the file list - was fixed when this one was fetched. The
-- only correct answer is to come back up on the shelf the new place wants, so the
-- loader restarts itself. A manual override is dropped first: it was a statement
-- about the old place, not about this one.
local watching = true
task.spawn(function()
	local last = A.place or game.PlaceId
	while watching do
		task.wait(2)
		local now = game.PlaceId
		if now ~= last then
			last = now
			A.place = now
			local want = (A.detectProfile and A.detectProfile(now)) or "universal"
			if getgenv then
				getgenv().AetherGame = nil
				getgenv().AetherGameFor = nil
			end
			if want ~= A.profile then
				if A.notify then
					A.notify("Games", "place changed · loading " .. ((A.games[want] or {}).name or want), "good")
				end
				task.wait(1.2)
				if watching and A.updater and A.updater.restart then
					pcall(A.updater.restart)
				elseif A.notify then
					A.notify("Games", "re-execute the loader to switch shelf", "bad")
				end
			end
		end
	end
end)
A.onCleanup(function() watching = false end)
