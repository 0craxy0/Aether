local A = ...
local T, notify, toggle = A.T, A.notify, A.toggle
local HttpService = A.HttpService
local DEBUG = getgenv and getgenv().AetherDebug == true

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
	interval = 300,       -- seconds between checks when reading the file
	apiInterval = 15,     -- and when the endpoint answers
	api = "https://aether-version.mariavictorlennySingh.workers.dev",
	source = nil,         -- "api" or "file": which one answered last
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

local function getJson(url)
	local ok, res = pcall(game.HttpGet, game, url)
	if not ok or type(res) ~= "string" then return nil end
	if #res == 0 or #res > N.maxBytes then return nil end
	local okDecode, data = pcall(function() return HttpService:JSONDecode(res) end)
	if not okDecode or type(data) ~= "table" then return nil end
	return data
end

-- The endpoint is the fast path (a publish is visible in seconds); the committed
-- file is the floor. If the Worker is down, moved or has no storage bound, this
-- falls back to exactly what it did before the endpoint existed.
local function fetch()
	local stamp = tostring(math.floor(os.time() / 15))
	if N.api then
		local data = getJson(N.api .. "/announcements?t=" .. stamp)
		-- Shape, not just "it parsed". A Worker deployed before this route existed
		-- answers 405 {"error":"POST required"} in valid JSON, which parses fine and
		-- would have pinned the client to the endpoint and skipped the file fallback
		-- entirely - so announcements looked permanently dead.
		if data and type(data.items) == "table" then
			N.source = "api"
			return data
		end
	end
	local data = getJson(A.base .. N.url .. "?t=" .. stamp)
	if data then N.source = "file" end
	return data
end

local function cadence()
	if N.api and N.source ~= "file" then return N.apiInterval end
	return N.interval
end

function N.check(force)
	hydrate()
	if not N.on or N.busy then return end
	-- a notice raised before the panel is drawn would fade out unseen behind the
	-- loading card; the updater loop calls this again once A.loadingDone is set
	if not A.loadingDone then return end
	local now = os.clock()
	if not force and now - N.last < cadence() then return end
	N.last = now
	N.busy = true
	local ok, err = pcall(function()
		local data = fetch()
		if DEBUG then
			print(string.format("[Aether] announcements: source=%s items=%d",
				tostring(N.source), (data and type(data.items) == "table") and #data.items or 0))
		end
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
