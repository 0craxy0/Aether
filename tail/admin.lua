local A = ...

-- Owner panel ----------------------------------------------------------------
-- Local check on a local value. Nothing here identifies anyone: no hardware id
-- is read, stored or sent, no other client is contacted, and the page is only
-- ever built on this account. Everything it exposes is a control over this
-- instance of the script - re-check the CDN, restart into the latest build,
-- compose and publish a note - which is the same set of actions a user already
-- has on the Settings page.
local ADMIN_ID = 1562524075
if not A.LP or A.LP.UserId ~= ADMIN_ID then return end

local T, FONT = A.T, A.FONT
local new, label, tween, button = A.new, A.label, A.tween, A.button
local makePage = A.makePage

local pAdmin = makePage("Admin", 9)

--------------------------------------------------------------------- furniture --
-- The page is meant to read like an instrument panel rather than a settings
-- list: a status strip at the top, then one group per job, with the small type
-- quiet and the numbers where the eye already is.

local function kicker(parent, text)
	return label({
		Text = text, Font = FONT.bold, TextSize = 9, TextColor3 = T.muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 12), Parent = parent,
	})
end

-- one key/value line: the key quiet on the left, the value on the right where
-- a column of numbers can be scanned
local function statRow(parent, key, value)
	local row = A.rowBaseRaw(parent, 28)
	label({
		Text = key, TextColor3 = T.muted, TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(11, 0), Size = UDim2.new(0.5, -11, 1, 0), Parent = row,
	})
	local v = label({
		Text = value, Font = FONT.med, TextSize = 11, TextColor3 = T.text,
		TextXAlignment = Enum.TextXAlignment.Right, TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.new(0.5, -11, 1, 0), Parent = row,
	})
	return v
end

-- a real text field, with the focus ring the shared input widget uses, so the
-- admin page does not feel like a different program
local function field(parent, placeholder, height, multiline)
	local box = new("TextBox", {
		Text = "", PlaceholderText = placeholder, MultiLine = multiline or false,
		ClearTextOnFocus = false, TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = multiline and Enum.TextYAlignment.Top or Enum.TextYAlignment.Center,
		Font = FONT.reg, TextSize = 11, TextColor3 = T.text, PlaceholderColor3 = T.muted,
		BackgroundColor3 = T.raised, BackgroundTransparency = 0.35, BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, height or 30), Parent = parent,
	}, { new("UICorner", { CornerRadius = UDim.new(0, 7) }) })
	local stroke = new("UIStroke", {
		Color = T.stroke, Transparency = 0.4, Thickness = 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = box,
	})
	if multiline then
		new("UIPadding", {
			PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8),
			PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6), Parent = box,
		})
	else
		new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), Parent = box })
	end
	box.Focused:Connect(function()
		tween(box, 0.12, { BackgroundTransparency = 0 })
		stroke.Color, stroke.Transparency = T.accent, 0
	end)
	box.FocusLost:Connect(function()
		tween(box, 0.15, { BackgroundTransparency = 0.35 })
		stroke.Color, stroke.Transparency = T.stroke, 0.4
	end)
	return box
end

-- segmented control: one row, N choices, the chosen one lit. A cycler was the
-- only option before because a dropdown registers a config row under a name
-- that could collide with a real setting; a segmented control has neither.
local function segmented(parent, key, options, initial, onPick)
	local row = A.rowBaseRaw(parent, 38)
	label({
		Text = key, TextColor3 = T.muted, TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(11, 0), Size = UDim2.new(0.45, -11, 1, 0), Parent = row,
	})
	local rail = new("Frame", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -9, 0.5, 0),
		Size = UDim2.fromOffset(148, 24), BackgroundColor3 = T.panel, BackgroundTransparency = 0.2,
		BorderSizePixel = 0, Parent = row,
	}, { new("UICorner", { CornerRadius = UDim.new(0, 6) }), new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder,
	}) })

	local state = initial
	local buttons = {}
	local paint

	for i, opt in ipairs(options) do
		local b = new("TextButton", {
			Text = opt.label, Font = FONT.bold, TextSize = 9, AutoButtonColor = false,
			TextColor3 = T.muted, BackgroundColor3 = T.accent, BackgroundTransparency = 1,
			BorderSizePixel = 0, LayoutOrder = i,
			Size = UDim2.fromOffset(math.floor(142 / #options), 20), Parent = rail,
		}, { new("UICorner", { CornerRadius = UDim.new(0, 5) }) })
		buttons[i] = { btn = b, value = opt.value }
		b.MouseEnter:Connect(function()
			if state ~= opt.value then tween(b, 0.12, { TextColor3 = T.text }) end
		end)
		b.MouseLeave:Connect(function()
			if state ~= opt.value then tween(b, 0.12, { TextColor3 = T.muted }) end
		end)
		b.MouseButton1Click:Connect(function()
			if state == opt.value then return end
			state = opt.value
			paint()
			if onPick then pcall(onPick, state) end
		end)
	end

	paint = function()
		for _, entry in ipairs(buttons) do
			local on = entry.value == state
			tween(entry.btn, 0.15, {
				BackgroundTransparency = on and 0.82 or 1,
				TextColor3 = on and T.text or T.muted,
			})
			entry.btn.BackgroundColor3 = T.accent
		end
	end
	paint()

	return { get = function() return state end, set = function(v) state = v; paint() end }
end

------------------------------------------------------------------------ status --
-- The strip answers "what am I running" before anything else on the page, and
-- carries the two actions that answer "and is that current".

local sTop = pAdmin.section("Status", 1)

local strip = A.rowBaseRaw(sTop, 52)
local dot = new("Frame", {
	AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromOffset(16, 26),
	Size = UDim2.fromOffset(8, 8), BackgroundColor3 = T.good, BorderSizePixel = 0, Parent = strip,
}, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
new("UIStroke", { Color = T.good, Transparency = 0.6, Thickness = 1, Parent = dot })

label({
	Text = "BUILD", Font = FONT.bold, TextSize = 9, TextColor3 = T.muted,
	TextXAlignment = Enum.TextXAlignment.Left,
	Position = UDim2.fromOffset(32, 10), Size = UDim2.new(1, -40, 0, 12), Parent = strip,
})
local buildLbl = label({
	Text = tostring(A.build or "?"), Font = FONT.bold, TextSize = 15, TextColor3 = T.text,
	TextXAlignment = Enum.TextXAlignment.Left,
	Position = UDim2.fromOffset(32, 22), Size = UDim2.new(0.6, -40, 0, 20), Parent = strip,
})
local revLbl = label({
	Text = "rev " .. tostring(A.rev or "?"), TextSize = 11, TextColor3 = T.muted,
	TextXAlignment = Enum.TextXAlignment.Right,
	AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 26),
	Size = UDim2.new(0.4, -16, 0, 16), Parent = strip,
})

-- the dot breathes while the panel is open: it is the one element that says
-- "this is live" rather than a screenshot of a build number
task.spawn(function()
	while strip.Parent do
		tween(dot, 1.4, { BackgroundTransparency = 0.55 }, Enum.EasingStyle.Sine)
		task.wait(1.4)
		tween(dot, 1.4, { BackgroundTransparency = 0 }, Enum.EasingStyle.Sine)
		task.wait(1.4)
	end
end)

button(sTop, "Force update check", "CHECK", function()
	if A.updater then A.updater.checkNow() end
end)
button(sTop, "Restart into latest", "RESTART", function()
	if not A.updater then return end
	local ok, saved, msg = pcall(A.flushConfig)
	if not (ok and saved == true) then
		A.notify("Restart", "config could not be saved: " .. tostring(msg or saved), "bad")
		return
	end
	A.updater.restart()
end)

--------------------------------------------------------------------- composer --
-- One note, four ways out: preview it as the toast a reader sees, publish it to
-- the endpoint, or copy it as the file/JSON the old commit-only path needed.

local sAnn = pAdmin.section("Composer", 2)

local draft = type(A.extra.announceDraft) == "table" and A.extra.announceDraft or {}
local cap = (A.announce and A.announce.maxChars) or 220
local kind = tostring(draft.kind or "Info"):lower()

local kindPick = segmented(sAnn, "Note kind", {
	{ label = "INFO", value = "info" },
	{ label = "GOOD", value = "good" },
	{ label = "BAD", value = "bad" },
}, kind, function(v)
	kind = v
	draft.kind = v
	if A.touch then A.touch() end
end)

kicker(sAnn, "MESSAGE")

local box = field(sAnn, "Write the note people will see…", 68, true)
box.Text = tostring(draft.text or "")

-- budget: a bar first, the number second - at a glance the bar is the answer
local track = new("Frame", {
	Size = UDim2.new(1, 0, 0, 3), BackgroundColor3 = T.stroke, BackgroundTransparency = 0.4,
	BorderSizePixel = 0, Parent = sAnn,
}, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
local fill = new("Frame", {
	Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = T.accent, BorderSizePixel = 0, Parent = track,
}, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })

local count = label({
	Text = "", TextColor3 = T.muted, TextSize = 10,
	TextXAlignment = Enum.TextXAlignment.Right,
	Size = UDim2.new(1, 0, 0, 12), Parent = sAnn,
})

local function trimmed()
	local s = tostring(box.Text or ""):gsub("%s+", " ")
	s = s:match("^%s*(.-)%s*$") or ""
	if #s > cap then s = s:sub(1, cap) end
	return s
end

local function refreshCount()
	local n = #(tostring(box.Text or ""):gsub("%s+", " "))
	count.Text = n .. " / " .. cap
	local over = n > cap
	count.TextColor3 = over and T.bad or T.muted
	fill.BackgroundColor3 = over and T.bad or T.accent
	tween(fill, 0.15, { Size = UDim2.fromScale(math.clamp(n / cap, 0, 1), 1) })
end
refreshCount()

local function saveDraft()
	A.extra.announceDraft = { text = box.Text or "", kind = kind }
	if A.touch then A.touch() end
end

box:GetPropertyChangedSignal("Text"):Connect(refreshCount)
box.FocusLost:Connect(saveDraft)

local function buildItem()
	local item = { id = os.date("!%Y%m%d-%H%M%S"), text = trimmed() }
	if kind == "good" then item.kind = "good" elseif kind == "bad" then item.kind = "bad" end
	return item
end

button(sAnn, "Preview note", "SHOW", function()
	local text = trimmed()
	if text == "" then return A.notify("Announcements", "nothing written yet", "bad") end
	local k = (kind == "good" or kind == "bad") and kind or nil
	A.notify("Aether", text, k) -- exactly what a reader will see
end)

----------------------------------------------------------------------- publish --
-- The token is typed here and lives nowhere else: never written to config.json,
-- never baked into the script, and an empty box means the button reports "paste
-- the token first". The ability to publish IS the token, and it only exists
-- while the owner is looking at this page.

kicker(sAnn, "PUBLISH")

local tokenBox = field(sAnn, "Paste publish token (kept in memory only)", 30, false)

local sending = false

local function endpoint()
	return (A.announce and A.announce.api) or (A.updater and A.updater.api)
end

local function post(path, payload)
	local req = (syn and syn.request) or (fluxus and fluxus.request) or http_request or request
	if not req then return nil, "this executor has no request function" end
	local token = (tostring(tokenBox.Text or ""):gsub("%s+", ""))
	if token == "" then return nil, "paste the publish token first" end
	local base = endpoint()
	if not base then return nil, "no endpoint configured" end

	local ok, res = pcall(req, {
		Url = base .. path,
		Method = "POST",
		Headers = {
			["Content-Type"] = "application/json",
			["Authorization"] = "Bearer " .. token,
		},
		Body = A.HttpService:JSONEncode(payload),
	})
	if not ok then return nil, tostring(res) end
	if type(res) ~= "table" then return nil, "no response" end

	local body = type(res.Body) == "string" and res.Body or ""
	local decoded
	if body ~= "" then
		local okDecode, data = pcall(function() return A.HttpService:JSONDecode(body) end)
		if okDecode and type(data) == "table" then decoded = data end
	end

	if tonumber(res.StatusCode) == 200 and decoded and decoded.ok then return true, decoded end
	return nil, (decoded and tostring(decoded.error)) or ("HTTP " .. tostring(res.StatusCode or "?"))
end

button(sAnn, "Send to everyone", "SEND", function()
	if sending then return end
	local text = trimmed()
	if text == "" then return A.notify("Announcements", "nothing written yet", "bad") end
	if #text > cap then return A.notify("Announcements", "over " .. cap .. " characters", "bad") end

	sending = true
	local item = buildItem()
	task.spawn(function()
		local ok, err = post("/announce", { text = item.text, kind = item.kind })
		sending = false
		if ok then
			A.notify("Announcements", "sent · readers see it within 15s", "good")
			if A.announce and A.announce.check then A.announce.check(true) end
		else
			A.notify("Announcements", "not sent: " .. tostring(err), "bad")
		end
	end)
end)

button(sAnn, "Copy announcements.json", "COPY", function()
	local text = trimmed()
	if text == "" then return A.notify("Announcements", "nothing written yet", "bad") end
	local ok, encoded = pcall(function() return A.HttpService:JSONEncode({ items = { buildItem() } }) end)
	if not ok or type(encoded) ~= "string" then
		return A.notify("Announcements", "could not encode: " .. tostring(encoded), "bad")
	end
	A.copy(encoded)
	A.notify("Announcements", "copied · commit it as announcements.json", "good")
end)

button(sAnn, "Copy the item only", "COPY", function()
	local text = trimmed()
	if text == "" then return A.notify("Announcements", "nothing written yet", "bad") end
	local ok, encoded = pcall(function() return A.HttpService:JSONEncode(buildItem()) end)
	if not ok or type(encoded) ~= "string" then
		return A.notify("Announcements", "could not encode: " .. tostring(encoded), "bad")
	end
	A.copy(encoded)
end)

button(sAnn, "Force announcement check", "CHECK", function()
	if A.announce then A.announce.check(true) end
end)
button(sAnn, "Reset seen announcements", "RESET", function()
	if A.announce then A.announce.reset() end
	A.notify("Announcements", "seen list cleared", "good")
end)

label({
	Text = "Send posts straight to the announcements endpoint - no commit, no repo edit, visible to every reader within 15s. The token box is memory only: closing the script forgets it. Copy is the fallback if the endpoint is down.",
	TextColor3 = T.muted, TextSize = 10, TextWrapped = true,
	Size = UDim2.new(1, 0, 0, 42), Parent = sAnn,
})

----------------------------------------------------------------------- release --
-- The wording of the update prompt, written here instead of in version.json.
-- The rev is still version.json's: a rev is a promise that fetching main.lua
-- returns that build, and only a commit can make that true. So the panel can
-- author every word the dialog shows, and nothing else.

local sRel = pAdmin.section("Release", 3)

kicker(sRel, "TITLE")
local relTitle = field(sRel, 'Update title (blank = "Aether release")', 30, false)

local relScope = "standalone"
segmented(sRel, "Shows to", {
	{ label = "EVERYONE", value = "standalone" },
	{ label = "THIS BUILD", value = "build" },
}, relScope, function(v) relScope = v end)

label({
	Text = "This build decorates the update prompt for the rev you are running; everyone shows it once, to all clients.",
	TextColor3 = T.muted, TextSize = 10, TextWrapped = true,
	Size = UDim2.new(1, 0, 0, 26), Parent = sRel,
})

local publishingRelease = false

button(sRel, "Publish release notes", "REL", function()
	if publishingRelease then return end
	-- the toast composer caps at 220; a release note has room for more
	local text = (tostring(box.Text or ""):gsub("%s+", " "))
	text = text:match("^%s*(.-)%s*$") or ""
	if text == "" then return A.notify("Release", "the note box is empty", "bad") end
	if #text > 400 then text = text:sub(1, 400) end

	local payload = { title = tostring(relTitle.Text or ""), notes = text }
	if relScope == "build" then
		payload.rev = A.rev
		payload.build = A.build
	end

	publishingRelease = true
	task.spawn(function()
		local ok, err = post("/release", payload)
		publishingRelease = false
		if ok then
			A.notify("Release", relScope == "build"
				and ("saved - decorates the rev " .. tostring(A.rev) .. " prompt")
				or "saved - every client sees it once", "good")
		else
			A.notify("Release", "not saved: " .. tostring(err), "bad")
		end
	end)
end)

button(sRel, "Clear release notes", "CLEAR", function()
	task.spawn(function()
		local ok, err = post("/release", { clear = true })
		A.notify("Release", ok and "cleared" or ("not cleared: " .. tostring(err)), ok and "good" or "bad")
	end)
end)

----------------------------------------------------------------------- session --
-- What this instance is, in one column, plus a copy of the same thing for a bug
-- report. Every value here is read from A, which this build already publishes.

local sInfo = pAdmin.section("Session", 4)

statRow(sInfo, "Account", tostring(A.LP.UserId))
statRow(sInfo, "Executor", tostring(A.executorName or "?"))
statRow(sInfo, "Build", tostring(A.build or "?"))
statRow(sInfo, "Rev", tostring(A.rev or "?"))
statRow(sInfo, "Place", tostring(game.PlaceId))
statRow(sInfo, "Shelf", tostring(A.profile or "?"))

button(sInfo, "Copy diagnostics", "COPY", function()
	local text = table.concat({
		"Aether " .. tostring(A.build) .. " (rev " .. tostring(A.rev) .. ")",
		"executor " .. tostring(A.executorName or "?"),
		"shelf " .. tostring(A.profile or "?"),
		"place " .. tostring(game.PlaceId),
		"job " .. tostring(game.JobId),
	}, "\n")
	A.copy(text)
	A.notify("Session", "copied", "good")
end)

label({
	Text = "Owner panel. It reads nothing about other clients and sends nothing about this one.",
	TextColor3 = T.muted, TextSize = 10, TextWrapped = true,
	Size = UDim2.new(1, 0, 0, 28), Parent = sInfo,
})

A.stage("admin panel ready")
