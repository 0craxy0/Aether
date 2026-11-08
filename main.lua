
local BASE = "https://raw.githubusercontent.com/0craxy0/Aether/main/"

-- A stage file is a few kilobytes. Anything far past that is not ours - a captive
-- portal, a proxy error page or a hostile host - and loadstring-ing it would only
-- turn a bad download into a confusing syntax error at best and an OOM at worst.
local MAX_BYTES = 2 * 1024 * 1024

-- Every entry is { path, group }. No group means core: it loads on every shelf.
-- "arsenal" is the combat set, "tesla" the vehicle set; the universal shelf loads
-- every group, which is the whole point of it.
local FILES = {
	{ "core/env.lua" },
	{ "core/games.lua" }, -- right after env: it only reads A
	{ "core/theme.lua" },
	{ "core/util.lua" },
	{ "core/notify.lua" },
	{ "core/sfx.lua" },
	{ "core/physics.lua" },
	{ "core/window.lua" },
	{ "core/depth.lua" },
	{ "core/motion.lua" },
	{ "core/widgets.lua" },
	{ "core/colorpicker.lua" }, -- after widgets: it is a widget built from rowBase
	{ "modules/filter.lua" },
	{ "modules/character.lua" }, -- walk speed, noclip, anti-afk: every shelf
	{ "modules/esp.lua" },
	{ "modules/actions.lua" },
	{ "modules/waypoints.lua" }, -- saved positions, persisted in A.extra
	{ "modules/world.lua" }, -- find/highlight/low graphics/server info
	{ "modules/guard.lua" }, -- anti-fling, anti-teleport, panic
	{ "modules/aim.lua", "arsenal" },
	{ "modules/silentaim.lua", "arsenal" },
	{ "modules/killaura.lua", "arsenal" },
	{ "modules/projectile.lua", "arsenal" },
	{ "modules/tesla.lua", "tesla" },
	{ "modules/sendglobal.lua", "sendglobal" }, -- cash farm: win pads, unlock order
	{ "core/pagekit.lua" },
	{ "pages/character.lua" },
	{ "pages/movement.lua" },
	{ "pages/visuals.lua" },
	{ "pages/combat.lua", "arsenal" },
	{ "pages/tesla.lua", "tesla" },
	{ "pages/players.lua" },
	{ "pages/world.lua" }, -- find, highlight, server info
	{ "pages/sendglobal.lua", "sendglobal" }, -- after Players: equal LayoutOrder, insertion order wins
	{ "tail/keylist.lua" }, -- before pages/ui (it creates A.kbList)
	{ "pages/ui.lua" }, -- creates A.sUI4 for the files below
	{ "tail/extras.lua" },
	{ "tail/hud.lua" },
	{ "tail/glass.lua" },
	{ "tail/commands.lua" }, -- before settings: the Commands section calls A.cmd
	{ "tail/settings.lua" },
	{ "tail/tts.lua" }, -- after settings: it reads and writes the config extras
	{ "tail/announcements.lua" }, -- after settings (extras) and pages/ui (A.sUI4)
	{ "tail/keybinds.lua" },
	{ "pages/games.lua" }, -- after Keybinds: the sidebar order is creation order
	{ "tail/startup.lua" },
	{ "tail/updater.lua" },
	{ "tail/admin.lua" }, -- last: it reads A.updater and A.announce
}

-- bumped whenever a push changes behaviour. Printed on load and shown in the
-- window header, so "am I on the new build?" is a fact instead of a guess.
local BUILD = "2026-11-08.51"
-- monotonic: the updater compares rev, never the date string
local REV = 51

-- opt-in, for chasing a stale copy: set getgenv().AetherFresh = true before
-- executing and every file is fetched with a unique URL, bypassing every cache
local FRESH = getgenv and getgenv().AetherFresh == true

local function url(path)
	if FRESH then return BASE .. path .. "?t=" .. tostring(os.time()) end
	return BASE .. path
end

local A = { base = BASE, build = BUILD, rev = REV }

-- Game shelf. It has to be decided here, before the first fetch, because FILES
-- is filtered by it; core/games.lua only turns the key into a record for the UI
-- and watches for a teleport that changes the answer.
--
-- The place ids live here, once: the loader is the only thing that can use them
-- before the first file exists, so it owns them and publishes them for the rest.
local PLACE_IDS = { arsenal = 286090429, tesla = 1794074302239, sendglobal = 10164995980 }

-- Extra ids that resolve to a shelf. A game can be reached through a start place
-- and a sub-place with different ids, and both have to land on the same one:
-- 118282960139128 is the place tools/padlog.lua actually ran in, and the shelf
-- has to recognise it as well or the farm disappears on that server.
local PLACE_ALIASES = { [118282960139128] = "sendglobal" }

local function detectProfile(place)
	local alias = PLACE_ALIASES[place]
	if alias then return alias end
	for key, id in pairs(PLACE_IDS) do
		if place == id then return key end
	end
	return "universal"
end

A.placeIds = PLACE_IDS
A.detectProfile = detectProfile
A.place = game.PlaceId
-- The override exists for a game whose id is not in the table yet (or for
-- testing a shelf from a place it was not written for). It is remembered with
-- the place it was chosen for: an override that outlived its game is how a
-- Tesla tab ends up sitting in Arsenal. Anything from another place is dropped
-- on the way up, so the shelf is always either selected here or detected here.
local forced = getgenv and getgenv().AetherGame
local forcedFor = getgenv and getgenv().AetherGameFor
local key
if (forced == "arsenal" or forced == "tesla" or forced == "universal") and forcedFor == A.place then
	key = forced
else
	if forced and getgenv then
		getgenv().AetherGame = nil
		getgenv().AetherGameFor = nil
	end
	key = detectProfile(A.place)
end
A.profile = key

-- lets auto-execute on teleport re-run this loader. The private copy is the one
-- the queue string is built from; the getgenv one stays for compatibility and is
-- re-validated against this host before it is ever executed (see
-- modules/actions.lua - another script in the executor can write to getgenv).
A.source = BASE .. "main.lua"
getgenv().AetherSource = A.source
print("[Aether] build " .. BUILD .. (FRESH and " (fresh fetch)" or ""))

-- ---------------------------------------------------------------- loading ---
-- The loader is one straight thread. Every game:HttpGet yields, and that yield is
-- the only chance the engine has to draw a frame between stages - which is why
-- the screen has to exist before the first fetch and be repainted by each
-- A.stage call. It is a courtesy, never a dependency: everything below is inside
-- a pcall, so a client that refuses the ScreenGui still loads the hub normally.
--
-- The order here is the order the stages are emitted, not the order of FILES:
-- a few stages fire from inside a file (hud before settings, tts after settings).
-- A stage that never fires - "admin panel ready" is owner-only - does not stall
-- the bar, because completion is declared by the loop ending, not by a stage.
local PLAN = {
	{ "0 start", "starting up" },
	{ "1 helpers + toasts done", "helpers and toasts" },
	{ "2 window built", "window" },
	{ "3 modules + config menus defined", "modules and config menus" },
	{ "4 character/movement/visuals pages done", "character, movement, visuals" },
	{ "5 combat page done", "combat" },
	{ "6 keybind overlay done", "keybind overlay" },
	{ "hud done", "stats HUD" },
	{ "7 settings page done", "settings" },
	{ "tts ready", "read-aloud" },
	{ "announcements ready", "announcements" },
	{ "8 keybinds done", "keybinds" },
	{ "9 startup done", "startup" },
	{ "10 updater armed", "updater" },
	{ "admin panel ready", "owner panel" },
}
local TOTAL = #PLAN
local STAGE_AT = {}
for i, s in ipairs(PLAN) do STAGE_AT[s[1]] = i end

local THEME = {
	bg = Color3.fromHex("1C1C1E"),
	panel = Color3.fromHex("242426"),
	stroke = Color3.fromHex("38383A"),
	text = Color3.fromHex("FFFFFF"),
	muted = Color3.fromHex("98989D"),
	accent = Color3.fromHex("0A84FF"),
	bad = Color3.fromHex("FF453A"),
}

local loading
do
	local ok, api = pcall(function()
		local Players = game:GetService("Players")
		local TweenService = game:GetService("TweenService")

		local function font(name, fallback)
			local okf, f = pcall(function() return Enum.Font[name] end)
			if okf and f then return f end
			return fallback
		end

		local function mk(class, props, parent)
			local o = Instance.new(class)
			for k, v in pairs(props) do o[k] = v end
			o.Parent = parent
			return o
		end

		-- gethui is the only parent that reliably survives other scripts clearing
		-- PlayerGui; without it, use the normal GUI parents in that order.
		local host
		if gethui then host = gethui() end
		if not host and Players.LocalPlayer then host = Players.LocalPlayer:FindFirstChild("PlayerGui") end
		if not host then host = game:GetService("CoreGui") end
		if not host then error("no ScreenGui parent available") end
		local stale = host:FindFirstChild("AetherLoading")
		if stale then stale:Destroy() end -- a previous run that died before its fade

		local sg = mk("ScreenGui", {
			Name = "AetherLoading", IgnoreGuiInset = true, ResetOnSpawn = false,
			DisplayOrder = 999, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		}, host)

		local card = mk("CanvasGroup", {
			Name = "card", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(360, 108), BackgroundColor3 = THEME.bg,
			BackgroundTransparency = 0.02, BorderSizePixel = 0, GroupTransparency = 0,
		}, sg)
		mk("UICorner", { CornerRadius = UDim.new(0, 12) }, card)
		mk("UIStroke", { Color = THEME.stroke, Thickness = 1, Transparency = 0.25 }, card)

		mk("TextLabel", {
			BackgroundTransparency = 1, Font = font("BuilderSansBold", Enum.Font.GothamSemibold),
			Text = "Aether", TextSize = 17, TextColor3 = THEME.text,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.fromOffset(20, 15), Size = UDim2.new(0, 140, 0, 20),
		}, card)

		local counter = mk("TextLabel", {
			BackgroundTransparency = 1, Font = font("BuilderSansMedium", Enum.Font.GothamMedium),
			Text = "0 / " .. TOTAL .. " loaded", TextSize = 12, TextColor3 = THEME.muted,
			TextXAlignment = Enum.TextXAlignment.Right,
			AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -20, 0, 17),
			Size = UDim2.new(0, 200, 0, 16),
		}, card)

		local status = mk("TextLabel", {
			BackgroundTransparency = 1, Font = font("BuilderSans", Enum.Font.Gotham),
			Text = "starting up", TextSize = 11, TextColor3 = THEME.muted,
			TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
			Position = UDim2.fromOffset(20, 40), Size = UDim2.new(1, -40, 0, 14),
		}, card)

		local track = mk("Frame", {
			BackgroundColor3 = THEME.panel, BorderSizePixel = 0,
			Position = UDim2.fromOffset(20, 66), Size = UDim2.new(1, -40, 0, 4),
		}, card)
		mk("UICorner", { CornerRadius = UDim.new(1, 0) }, track)
		local fill = mk("Frame", {
			BackgroundColor3 = THEME.accent, BorderSizePixel = 0,
			Size = UDim2.fromScale(0.02, 1),
		}, track)
		mk("UICorner", { CornerRadius = UDim.new(1, 0) }, fill)

		mk("TextLabel", {
			BackgroundTransparency = 1, Font = font("BuilderSans", Enum.Font.Gotham),
			Text = "Build " .. BUILD, TextSize = 10, TextColor3 = THEME.muted,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.fromOffset(20, 80), Size = UDim2.new(1, -40, 0, 12),
		}, card)

		local api = { dead = false }

		function api.set(i, text)
			if api.dead then return end
			i = math.clamp(i, 0, TOTAL)
			counter.Text = string.format("%d / %d loaded", i, TOTAL)
			if text then status.Text = text end
			TweenService:Create(fill,
				TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
				{ Size = UDim2.fromScale(math.max(i / TOTAL, 0.02), 1) }):Play()
		end

		-- "ready" is shown for a beat before the card goes, so the last frame the
		-- user sees is a finished bar rather than the window popping into place.
		-- `after` runs only once the fade is over, which is what gates the hub's
		-- own ScreenGui (tail/startup.lua sets A.afterLoad while it builds).
		function api.done(after)
			if api.dead then return end
			api.set(TOTAL, "ready")
			task.delay(0.5, function()
				if api.dead then return end
				api.dead = true
				pcall(function()
					local tw = TweenService:Create(card, TweenInfo.new(0.3), { GroupTransparency = 1 })
					tw:Play()
					tw.Completed:Wait()
				end)
				if sg.Parent then sg:Destroy() end
				if after then
					local okAfter, errAfter = pcall(after)
					if not okAfter then warn("[Aether] could not show the panel: " .. tostring(errAfter)) end
				end
			end)
		end

		function api.fail(msg)
			if api.dead then return end
			api.dead = true
			counter.Text = "stopped"
			status.Text = tostring(msg):sub(1, 90)
			status.TextColor3 = THEME.bad
			task.delay(8, function() if sg.Parent then sg:Destroy() end end)
		end

		return api
	end)
	loading = ok and api or nil
	if not ok then warn("[Aether] loading screen unavailable: " .. tostring(api)) end
end
A.loading = loading

-- The stage reporter. main.lua owns it because the loader is the only place that
-- knows how many stages there are; core/env.lua only installs a console-only
-- fallback for the case where it is run on its own.
local stageCount = 0
function A.stage(label)
	label = tostring(label)
	print("[Aether] stage " .. label)
	local at = STAGE_AT[label]
	if at then
		stageCount = math.max(stageCount, at)
	else
		stageCount = math.min(stageCount + 1, TOTAL)
	end
	if loading then pcall(loading.set, stageCount, at and PLAN[at][2] or label) end
end

-- a half-loaded hub is worse than none: warn once, then tear down whatever was built
-- so the ScreenGui from core/notify.lua cannot outlive the load that made it
local function fail(msg)
	warn("[Aether] " .. msg)
	if loading then pcall(loading.fail, msg) end
	if type(A.unload) == "function" then pcall(A.unload) end
end

-- No fetch is waited on forever -----------------------------------------------
-- A load is forty small files, each one a network request. A request that never
-- answers is the one failure mode that looks exactly like a dead game: the card
-- stops mid-load and nothing happens again, because the loader thread is still
-- inside HttpGet. That is not a freeze we can cancel - but we can refuse to be
-- the thread that waits for it.
--
-- So each file is fetched on a thread of its own and the loader polls it with a
-- deadline. A file that misses the deadline is abandoned (it finishes or it does
-- not; nobody is listening), retried once, and then served from the copy this
-- executor wrote the last time the *same rev* loaded. The cache path carries the
-- rev, so a fallback can never hand us code from a different build - it is either
-- this build's bytes or a clean, reported failure.
local FETCH_TIMEOUT = 8   -- seconds one file may take before it is abandoned
local RETRY_TIMEOUT = 15  -- a cold DNS lookup or a dropped first packet deserves more
local BUDGET = 90         -- the whole load; past this we stop and say so
local CACHE_ROOT = "Aether/cache/" .. tostring(REV) .. "/"
local cacheReady = false
local cacheUsable = type(writefile) == "function" and type(readfile) == "function"

local function cachePath(p) return CACHE_ROOT .. (p:gsub("[/\\]", "_")) end

local function cachePrepare()
	if cacheReady then return cacheUsable end
	cacheReady = true
	if not cacheUsable then return false end
	if type(makefolder) == "function" then
		pcall(makefolder, "Aether")
		pcall(makefolder, "Aether/cache")
		pcall(makefolder, CACHE_ROOT)
	end
	return true
end

local function cacheRead(p)
	if not cachePrepare() or type(isfile) ~= "function" then return nil end
	local path = cachePath(p)
	local ok, isThere = pcall(isfile, path)
	if not (ok and isThere) then return nil end
	local okR, body = pcall(readfile, path)
	if not okR or type(body) ~= "string" or #body == 0 or #body > MAX_BYTES then return nil end
	return body
end

local function cacheWrite(p, src)
	if not cachePrepare() then return end
	pcall(writefile, cachePath(p), src)
end

-- one attempt, with a deadline. Returns src, why.
local function fetchTimed(path, timeout)
	local done, src, why = false, nil, nil
	task.spawn(function()
		local ok, res = pcall(game.HttpGet, game, url(path))
		if ok and type(res) == "string" then
			src = res
		elseif ok then
			why = "not a text response"
		else
			why = tostring(res)
		end
		done = true
	end)
	-- os.clock, not os.time: the latter counts whole seconds, so an 8s deadline
	-- was really "somewhere between 8 and 9" and a fast load could not be timed
	-- at all - the stall readout below had the same one-second floor
	local until_ = os.clock() + timeout
	while not done and os.clock() < until_ do task.wait(0.03) end
	if done and type(src) == "string" then return src end
	return nil, why or ("no answer in " .. tostring(timeout) .. "s")
end

-- Downloads overlap, execution does not ---------------------------------------
-- Fetched strictly in turn, a load costs the sum of forty round trips; nothing
-- about that is required, because it is the *execution* order that has the
-- dependencies, not the downloads. A small pool starts every file this shelf
-- needs as soon as the load begins, and the sequential loop below picks each
-- answer up as it reaches it. In turn that was ~40 x 120ms; overlapped it is
-- ~10 x 120ms, and the files still run in exactly the order FILES lists them.
local POOL = 4 -- in flight at once; the raw endpoint starts refusing past ~8

local prefetch, queue, qnext = {}, {}, 0

-- Takes the list of paths the shelf actually needs, rather than reading FILES and
-- calling loadsWith itself: loadsWith is declared further down, and a local is
-- only in scope below its own declaration, so reaching for it here would have
-- resolved to a nil global the moment this ran.
local function prefetchStart(paths)
	for _, path in ipairs(paths) do
		prefetch[path] = { done = false }
		queue[#queue + 1] = path
	end
	for _ = 1, math.min(POOL, #queue) do
		task.spawn(function()
			while true do
				qnext += 1
				local path = queue[qnext]
				if not path then return end
				local slot = prefetch[path]
				local ok, res = pcall(game.HttpGet, game, url(path))
				if ok and type(res) == "string" then
					slot.src = res
				else
					slot.why = ok and "not a text response" or tostring(res)
				end
				slot.done = true
			end
		end)
	end
end

-- The deadline is wall time from the moment the loader asks, not from when a
-- worker picked the file up: a pool that has wedged must fail here and fall
-- through to the retry below, never hang the load waiting for a request that is
-- still sitting in the queue.
local function awaitSlot(path, timeout)
	local slot = prefetch[path]
	if not slot then return nil, "not queued" end
	local until_ = os.clock() + timeout
	while not slot.done do
		if os.clock() > until_ then return nil, "no answer in " .. tostring(timeout) .. "s" end
		task.wait(0.03)
	end
	return slot.src, slot.why
end

local function fetch(path)
	local src, why = awaitSlot(path, FETCH_TIMEOUT)
	if not src then
		-- a second chance, not the same request again: the first one may have been
		-- a cold connection that is now warm
		src, why = fetchTimed(path, RETRY_TIMEOUT)
	end
	if src then
		if #src > MAX_BYTES then return nil, string.format("response too large (%d bytes)", #src) end
		if #src == 0 then return nil, "empty response" end
		-- written off the load thread: forty synchronous disk writes in the middle
		-- of the critical path cost more than the bytes are worth
		task.spawn(cacheWrite, path, src)
		return src
	end
	local cached = cacheRead(path)
	if cached then
		warn("[Aether] " .. path .. " could not be fetched (" .. tostring(why) .. ") · using this build's cached copy")
		return cached
	end
	return nil, tostring(why)
end

-- A group loads when that game is *selected* (this shelf) or *detected* (this
-- place). Everything else is generic. That is what keeps a Tesla tab out of
-- Arsenal and an aimbot page out of a game that has no shelf at all: on an
-- unsupported place, universal gets the generic tools and nothing else.
local function loadsWith(group)
	if not group then return true end
	if key == group then return true end
	return detectProfile(A.place) == group
end

-- One filtered list drives both the prefetch and the execution, so the two can
-- never disagree about what this shelf loads - and the order is still FILES order.
local loadPaths = {}
for _, entry in ipairs(FILES) do
	if loadsWith(entry[2]) then loadPaths[#loadPaths + 1] = entry[1] end
end

local loadStart = os.clock()
-- folder prep happens here, on this thread, so the cache writes spawned below
-- cannot race each other into a directory that does not exist yet
cachePrepare()
prefetchStart(loadPaths) -- everything this shelf needs is already in flight
local lastYield = os.clock()
for _, path in ipairs(loadPaths) do
	if os.clock() - loadStart > BUDGET then
		return fail("network too slow · gave up before " .. path)
	end
	local began = os.clock()
	local src, why = fetch(path)
	local spent = os.clock() - began
	-- a stall is shown, not hidden: "it froze" and "that file is slow" should not
	-- look the same, and the card is the only place the user can see the second
	if spent >= 1.5 and loading then
		pcall(loading.set, stageCount, string.format("%s · %.1fs", path, spent))
	end
	if not src then
		return fail("could not download " .. path .. ": " .. tostring(why))
	end
	local fn, compileErr = loadstring(src, "@" .. path)
	if not fn then
		return fail("syntax error in " .. path .. ": " .. tostring(compileErr))
	end
	local okRun, runErr = pcall(fn, A)
	if not okRun then
		return fail("error in " .. path .. ": " .. tostring(runErr))
	end
	-- The load used to yield on every HttpGet, which is what gave the engine a
	-- frame to repaint the card. Nothing blocks now that the answers are already
	-- in hand, so the loop has to hand control back itself or forty files compile
	-- and run in one uninterrupted frame and the card sits frozen at "1 / 15".
	-- Time-based rather than every file: 30ms of work per frame is invisible, and
	-- a fast shelf pays for two or three yields instead of forty.
	if os.clock() - lastYield > 0.03 then
		lastYield = os.clock()
		task.wait()
	end
end

-- The loop ending is the completion signal. Waiting for the last stage would
-- leave the bar one short forever on a non-owner client, where tail/admin.lua
-- returns before it can announce itself. A.afterLoad is tail/startup.lua's
-- reveal, so the panel's first frame happens after this card is gone.
A.loadMs = math.floor((os.clock() - loadStart) * 1000 + 0.5)
A.filesLoaded = #queue
if getgenv and getgenv().AetherDebug then
	print(string.format("[Aether] %d files fetched, compiled and run in %d ms (prefetch pool %d)",
		#queue, A.loadMs, POOL))
end
if loading then pcall(loading.done, A.afterLoad) end
