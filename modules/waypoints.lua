local A = ...
local notify = A.notify
local charParts = A.charParts

-- Waypoints -------------------------------------------------------------------
-- Saved positions, named by the user, living in the same config file as every
-- other setting (A.extra, under "waypoints"). They are the one movement tool that
-- is worth keeping between sessions: "the pads", "the shop", "that roof" are
-- places you return to, and re-walking to them is the whole cost being removed.
--
-- Stored as flat numbers rather than a Vector3 so the config stays plain JSON -
-- JSONEncode has no Vector3 and would write an empty table.

local WP = { max = 24, onChanged = nil }
A.waypoints = WP

local function store()
	if type(A.extra) ~= "table" then A.extra = {} end
	if type(A.extra.waypoints) ~= "table" then A.extra.waypoints = {} end
	return A.extra.waypoints
end

local function touch()
	if A.touch then A.touch() end
	if WP.onChanged then pcall(WP.onChanged) end
end

function WP.list()
	return store()
end

function WP.count()
	return #store()
end

function WP.find(name)
	for _, w in ipairs(store()) do
		if w.name == name then return w end
	end
	return nil
end

function WP.save(name)
	name = tostring(name or ""):gsub("^%s+", ""):gsub("%s+$", "")
	if name == "" then return false, "name is empty" end
	if #name > 24 then return false, "name is longer than 24 characters" end
	local _, _, root = charParts()
	if not root then return false, "no character" end
	local p = root.Position

	local existing = WP.find(name)
	if existing then
		existing.x, existing.y, existing.z = p.X, p.Y, p.Z
		touch()
		return true, "updated " .. name
	end
	local list = store()
	if #list >= WP.max then return false, "limit is " .. WP.max .. " waypoints" end
	list[#list + 1] = { name = name, x = p.X, y = p.Y, z = p.Z }
	touch()
	return true, "saved " .. name
end

function WP.remove(name)
	local list = store()
	for i, w in ipairs(list) do
		if w.name == name then
			table.remove(list, i)
			touch()
			return true
		end
	end
	return false, "no waypoint " .. tostring(name)
end

function WP.go(name)
	local w = WP.find(name)
	if not w then return false, "no waypoint " .. tostring(name) end
	local _, _, root = charParts()
	if not root then return false, "no character" end
	-- tell anti-teleport (when it is on) that this jump was ours
	if A.guard and A.guard.expect then A.guard.expect(2) end
	root.CFrame = CFrame.new(Vector3.new(w.x, w.y, w.z) + Vector3.new(0, 2, 0))
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	return true
end

function WP.position(name)
	local w = WP.find(name)
	if not w then return nil end
	return Vector3.new(w.x, w.y, w.z)
end
