local A = ...
local notify, onCleanup, has = A.notify, A.onCleanup, A.has
local HttpService = A.HttpService
local T, FONT, new, tween, corner, stroke, label = A.T, A.FONT, A.new, A.tween, A.corner, A.stroke, A.label
local screen = A.screen
local toggle, button, dropdown = A.toggle, A.button, A.dropdown

-- Update check. Polls one small file, compares its rev with the rev this loader
-- was built with, and offers to restart into the new build. The config is written
-- to disk before the restart and replayed by tail/startup.lua on the way back up,
-- so nothing the user set is lost.
local U = {
	enabled = true,
	interval = 15, -- seconds between checks
	cooldown = 300, -- quiet for five minutes after a hit, as specified
	nextCheck = 0,
	quietUntil = 0,
	dialog = nil,
	dismissed = {}, -- revs the user said "not now" to: stay quiet, keep checking
	json = "version.json",
	api = "https://aether-version.mariavictorlennySingh.workers.dev",
}
A.updater = U

local function fetch()
	local req = (syn and syn.request) or (fluxus and fluxus.request) or http_request or request

	-- The POST endpoint is the optional path, and it is only reachable through an
	-- executor `request` function. Without one this used to fall through to a GET
	-- of the same URL, which the endpoint does not answer, so every check failed
	-- to decode and reported "up to date" forever. Try it, verify it, and fall
	-- back to the static file the loader already trusts.
	if U.api and req then
		local ok, res = pcall(req, {
			Url = U.api, Method = "POST",
			Headers = { ["Content-Type"] = "application/json" },
			Body = HttpService:JSONEncode({ rev = A.rev or 0, build = tostring(A.build or "?") }),
		})
		if ok and type(res) == "table" and type(res.Body) == "string" and res.Body ~= "" then
			local okDecode, data = pcall(function() return HttpService:JSONDecode(res.Body) end)
			if okDecode and type(data) == "table" and tonumber(data.rev) then return res.Body end
		end
	end

	-- bucket per minute: keeps the CDN useful without ever hiding a push for long
	local url = A.base .. U.json .. "?t=" .. tostring(math.floor(os.time() / 60))
	local ok, res = pcall(game.HttpGet, game, url)
	if ok and type(res) == "string" then return res end
	return nil
end

local warnedStale = false

local function check()
	local body = fetch()
	if not body then return nil end
	local ok, data = pcall(function() return HttpService:JSONDecode(body) end)
	if not ok or type(data) ~= "table" then return nil end
	local rev = tonumber(data.rev)
	if not rev then return nil end
	if rev < (A.rev or 0) then
		-- main.lua was bumped without version.json: nobody can ever be offered the
		-- next build, so say it once in the console instead of failing silently
		if not warnedStale then
			warnedStale = true
			warn(string.format("[Aether] version.json is behind the loader (rev %d < %d)", rev, A.rev))
		end
		return nil
	end
	if rev <= (A.rev or 0) then return nil end
	return { rev = rev, build = data.build, notes = data.notes }
end

-- dialog ---------------------------------------------------------
local function closeDialog()
	local d = U.dialog
	if not d then return end
	U.dialog = nil
	tween(d.card, 0.16, { GroupTransparency = 1 })
	tween(d.scrim, 0.16, { BackgroundTransparency = 1 })
	task.delay(0.18, function() if d.root.Parent then d.root:Destroy() end end)
end

local function openDialog(info)
	if U.dialog then return end

	local root = new("Frame", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 200, Parent = screen,
	})
	local scrim = new("TextButton", {
		Text = "", AutoButtonColor = false, Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1,
		BorderSizePixel = 0, ZIndex = 200, Parent = root,
	})
	local card = new("CanvasGroup", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(392, 232), BackgroundColor3 = T.bg,
		BackgroundTransparency = 0.02, BorderSizePixel = 0, GroupTransparency = 1,
		ZIndex = 201, Parent = root,
	})
	corner(card, 8)
	stroke(card, T.stroke, 0.3)

	label({ Text = "Update available", Font = FONT.bold, TextSize = 17, RichText = false,
		Position = UDim2.fromOffset(20, 16), Size = UDim2.new(1, -40, 0, 20), ZIndex = 202, Parent = card })
	label({ Text = "build " .. tostring(info.build or info.rev), TextColor3 = T.muted, RichText = false,
		TextSize = 11, Position = UDim2.fromOffset(20, 38), Size = UDim2.new(1, -40, 0, 14), ZIndex = 202, Parent = card })
	label({ Text = tostring(info.notes or "A newer build is available."), TextColor3 = T.muted, RichText = false,
		TextSize = 12, TextWrapped = true, Position = UDim2.fromOffset(20, 58),
		Size = UDim2.new(1, -40, 0, 44), ZIndex = 202, Parent = card })

	-- the promise, in the dialog, before anything is touched
	label({
		Text = "Your configuration is saved now and put back automatically after the update.",
		TextColor3 = T.good, RichText = false, TextSize = 12, TextWrapped = true,
		Position = UDim2.fromOffset(20, 112), Size = UDim2.new(1, -40, 0, 32),
		ZIndex = 202, Parent = card,
	})

	local function dismiss()
		U.dismissed[info.rev] = true
		closeDialog()
	end

	local function mkBtn(text, color, xOff, cb)
		local b = new("TextButton", {
			Text = text, Font = FONT.bold, TextSize = 12, TextColor3 = T.text,
			BackgroundColor3 = color, AutoButtonColor = false, BorderSizePixel = 0,
			AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, xOff, 1, -16),
			Size = UDim2.fromOffset(108, 30), ZIndex = 203, Parent = card,
		}, { new("UICorner", { CornerRadius = UDim.new(0, 8) }) })
		b.MouseEnter:Connect(function() tween(b, 0.12, { BackgroundColor3 = T.accent }) end)
		b.MouseLeave:Connect(function() tween(b, 0.12, { BackgroundColor3 = color }) end)
		b.MouseButton1Click:Connect(function()
			A.sfx("tap")
			pcall(cb)
		end)
		return b
	end

	mkBtn("Update now", T.accent, -140, function() A.updater.apply(info) end)
	mkBtn("Not now", T.stroke, -20, dismiss)
	scrim.MouseButton1Click:Connect(function() pcall(dismiss) end)

	U.dialog = { root = root, card = card, scrim = scrim }
	tween(scrim, 0.2, { BackgroundTransparency = 0.5 })
	tween(card, 0.24, { GroupTransparency = 0 })
end

-- restart --------------------------------------------------------
-- Tear the running UI down through the same path the Unload button uses, then
-- fetch and run the loader again; it replays the config on the way back up.
-- A.unload is this instance's own teardown - _G.AetherUnload is writable by any
-- other script in the executor and would be called right here.
function U.restart()
	task.spawn(function()
		A.sfx("close")
		if type(A.unload) == "function" then pcall(A.unload) end
		task.wait(0.15)
		local url = A.base .. "main.lua?t=" .. tostring(os.time())
		local okGet, src = pcall(game.HttpGet, game, url)
		if not okGet or type(src) ~= "string" or #src > (2 * 1024 * 1024) then
			return warn("[Aether] restart failed: could not download main.lua: " .. tostring(src))
		end
		local fn, err = loadstring(src, "@main.lua")
		if not fn then return warn("[Aether] restart failed: " .. tostring(err)) end
		local okRun, runErr = pcall(fn)
		if not okRun then warn("[Aether] restart failed: " .. tostring(runErr)) end
	end)
end

-- a check the user or the owner panel asked for, bypassing the cooldown
function U.checkNow()
	U.dismissed = {}
	U.quietUntil = 0
	U.nextCheck = 0
	local info = check()
	if info then
		U.quietUntil = os.clock() + U.cooldown
		openDialog(info)
		return true
	end
	notify("Updates", "up to date", "good")
	return false
end

-- apply ----------------------------------------------------------
function U.apply(info)
	closeDialog()

	-- the dialog promised the config survives, so if it cannot be written we do not
	-- take the UI away at all rather than silently dropping everything the user set
	local okSave, saved, msg = pcall(A.flushConfig)
	if not (okSave and saved == true) then
		notify("Update cancelled", "config could not be saved: " .. tostring(msg or saved or "unknown"), "bad")
		return
	end

	U.restart()
end

-- settings rows --------------------------------------------------
local pSet = A.pageSettings
if pSet then
	local sUpd = pSet.section("Updates", 4)
	toggle(sUpd, "Check for updates", true, function(v) U.enabled = v end)
	dropdown(sUpd, "Check every", { "15s", "30s", "1 min", "5 min" }, "15s", function(v)
		U.interval = ({ ["15s"] = 15, ["30s"] = 30, ["1 min"] = 60, ["5 min"] = 300 })[v] or 15
		U.nextCheck = 0
	end)
	button(sUpd, "Check now", "CHECK", function() U.checkNow() end)
end

-- loop -----------------------------------------------------------
local running = true
U.nextCheck = os.clock() + 5

onCleanup(function()
	running = false
	closeDialog()
end)

task.spawn(function()
	while running do
		task.wait(1)
		-- self-throttled to its own interval; rides this loop instead of a second one
		if running and A.announce then A.announce.check() end
		if running and U.enabled then
			local now = os.clock()
			if now >= U.nextCheck and now >= U.quietUntil then
				U.nextCheck = now + U.interval
				local info = check()
				if info then
					-- one hit, then silence for five minutes
					U.quietUntil = os.clock() + U.cooldown
					U.nextCheck = U.quietUntil
					if not U.dismissed[info.rev] then openDialog(info) end
				end
			end
		end
	end
end)

A.stage("10 updater armed")
