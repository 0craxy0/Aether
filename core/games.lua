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
		key = "arsenal", name = "Arsenal", place = 286090429,
		blurb = "Combat, visuals and movement, tuned against Arsenal's hit registration.",
	},
	{
		key = "tesla", name = "Flying Tesla Roadster", place = 1794074302239,
		blurb = "Open world update: infinite cold gas and auto-pilot with a height-picking camera.",
	},
	{
		key = "universal", name = "Universal", place = nil,
		blurb = "Every module in one shelf, for games nobody has tuned yet.",
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

-- True for the two shelves that carry the combat modules.
function A.hasCombat()
	return A.profile == "arsenal" or A.profile == "universal"
end

-- The Tesla car tools: universal carries them too, because "every feature" is
-- what universal promises - they simply find no vehicle in a game without cars.
function A.hasVehicleTools()
	return A.profile == "tesla" or A.profile == "universal"
end

-- Persisted override. A restart is required because the file list was decided at
-- fetch time; the Games page offers the restart in the same click.
function A.forceProfile(key)
	if not A.games[key] then return false end
	if getgenv then getgenv().AetherGame = key end
	return true
end

function A.clearProfile()
	if getgenv then getgenv().AetherGame = nil end
end
