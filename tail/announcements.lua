local A = ...
local T, notify, toggle = A.T, A.notify, A.toggle
local HttpService = A.HttpService

-- Announcements ---------------------------------------------------------------
-- A read-only note the owner publishes as a file on the loader's own origin:
-- {"items":[{"id":"...","text":"...","kind":"good|bad|info"}]}
--
-- This is deliberately one-way. The client fetches text and shows it in the
-- toast layer; it never accepts a command, a URL to run, an id to target or
-- anything that reaches back into another machine. Writing the file is the
-- owner acting on their own repo, which is the whole point - there is no code
-- path here that lets a server act on a client that did not ask for it.
local N = {
	on = true,
	seen = {},        -- id -> true
	seenList = {},    -- oldest first, capped
	maxSeen = 60,
	last = 0,
	interval = 300,   -- seconds between checks
	busy = false,
	hydrated = false,
	url = "announcements.json",
	maxChars = 220,   -- a notice, not an essay
	maxItems = 3,     -- and not a wall of them
	maxBytes = 64 * 1024,
}
A.announce = N

local function hydrate()
	if N.hydrated then return end
	N.hydrated = true
	local saved = A.extra and A.extra.announceSeen
	if type(saved) == "table" then
		N.seenList = saved
		for _, id in ipairs(saved) do N.seen[id] = true end
	end
end

local function markSeen(id)
	if N.seen[id] then return end
	N.seen[id] = true
	N.seenList[#N.seenList + 1] = id
	while #N.seenList > N.maxSeen do
		local old = table.remove(N.seenList, 1)
		if old then N.seen[old] = nil end
	end
	A.extra.announceSeen = N.seenList
	if A.touch then A.touch() end -- debounced: the file is written once per burst
end

local function clean(s)
	s = tostring(s or ""):gsub("<[^>]->", ""):gsub("%s+", " ")
	s = s:match("^%s*(.-)%s*$")
	if #s > N.maxChars then s = s:sub(1, N.maxChars) .. "…" end
	return s
end

local function fetch()
	local url = A.base .. N.url .. "?t=" .. tostring(math.floor(os.time() / N.interval))
	local ok, res = pcall(game.HttpGet, game, url)
	if not ok or type(res) ~= "string" then return nil end
	if #res == 0 or #res > N.maxBytes then return nil end
	local okDecode, data = pcall(function() return HttpService:JSONDecode(res) end)
	if not okDecode or type(data) ~= "table" then return nil end
	return data
end

function N.check(force)
	hydrate()
	if not N.on or N.busy then return end
	local now = os.clock()
	if not force and now - N.last < N.interval then return end
	N.last = now
	N.busy = true
	local ok, err = pcall(function()
		local data = fetch()
		if not data or type(data.items) ~= "table" then return end
		local shown = 0
		for _, item in ipairs(data.items) do
			if shown >= N.maxItems then break end
			if type(item) == "table" then
				local id = tostring(item.id or "")
				local body = clean(item.text)
				if id ~= "" and body ~= "" and not N.seen[id] then
					local kind = item.kind
					if kind ~= "bad" and kind ~= "good" then kind = nil end
					markSeen(id)
					notify("Aether", body, kind)
					shown += 1
				end
			end
		end
	end)
	N.busy = false
	if not ok then warn("[Aether] announcements: " .. tostring(err)) end
end

function N.reset()
	N.seen = {}
	N.seenList = {}
	A.extra.announceSeen = {}
	if A.touch then A.touch() end
end

toggle(A.sUI4, "Show announcements", true, function(v) N.on = v end)
task.delay(4, function() N.check() end)

A.stage("announcements ready")
