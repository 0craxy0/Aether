local A = ...

-- Owner panel ----------------------------------------------------------------
-- Local check on a local value. Nothing here identifies anyone: no hardware id
-- is read, stored or sent, no other client is contacted, and the page is only
-- ever built on this account. Everything it exposes is a control over this
-- instance of the script - re-check the CDN, restart into the latest build,
-- compose and preview a note - which is the same set of actions a user already
-- has on the Settings page.
local ADMIN_ID = 1562524075
if not A.LP or A.LP.UserId ~= ADMIN_ID then return end

local T, FONT = A.T, A.FONT
local new, button, makePage = A.new, A.button, A.makePage

local pAdmin = makePage("Admin", 9)

-- maintenance ---------------------------------------------------
local sMaint = pAdmin.section("Maintenance", 1)
button(sMaint, "Force update check", "CHECK", function()
	if A.updater then A.updater.checkNow() end
end)
button(sMaint, "Restart into latest", "RESTART", function()
	if not A.updater then return end
	local ok, saved, msg = pcall(A.flushConfig)
	if not (ok and saved == true) then
		A.notify("Restart", "config could not be saved: " .. tostring(msg or saved), "bad")
		return
	end
	A.updater.restart()
end)

-- publisher -----------------------------------------------------
-- The note composer. A client cannot write to GitHub, so this does the part that
-- is actually painful by hand: it builds the exact file, previews it in the real
-- toast, and puts it on the clipboard. Committing announcements.json publishes it.
local sAnn = pAdmin.section("Announcements", 2)

local KIND_ORDER = { "Info", "Good", "Bad" }
local KIND_COLOR = { Info = T.accent, Good = T.good, Bad = T.bad }
local draft = type(A.extra.announceDraft) == "table" and A.extra.announceDraft or {}
local noteKind = tostring(draft.kind or "Info")
local cap = (A.announce and A.announce.maxChars) or 220

local box = new("TextBox", {
	Text = tostring(draft.text or ""), PlaceholderText = "Write the note people will see…",
	MultiLine = true, ClearTextOnFocus = false, TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
	Font = FONT.reg, TextSize = 11, TextColor3 = T.text, PlaceholderColor3 = T.muted,
	BackgroundColor3 = T.raised, BackgroundTransparency = 0.35, BorderSizePixel = 0,
	Size = UDim2.new(1, 0, 0, 64), Parent = sAnn,
}, { new("UICorner", { CornerRadius = UDim.new(0, 7) }), new("UIStroke", { Color = T.stroke, Transparency = 0.4, Thickness = 1 }) })

local count = A.label({
	Text = "", TextColor3 = T.muted, TextSize = 10,
	TextXAlignment = Enum.TextXAlignment.Right,
	Size = UDim2.new(1, 0, 0, 14), Parent = sAnn,
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
	count.TextColor3 = n > cap and T.bad or T.muted
end
refreshCount()

local function saveDraft()
	A.extra.announceDraft = { text = box.Text or "", kind = noteKind }
	if A.touch then A.touch() end -- debounced with everything else
end

box:GetPropertyChangedSignal("Text"):Connect(refreshCount)
box.FocusLost:Connect(saveDraft)

-- kind: a cycler rather than a dropdown, so it cannot register a row in the
-- shared config under a name that could collide with a real setting
local kindRow = A.rowBase(sAnn)
A.label({
	Text = "Note kind", Font = FONT.med, TextSize = 12,
	Position = UDim2.fromOffset(11, 0), Size = UDim2.new(1, -110, 1, 0), Parent = kindRow,
})
local kindBtn = new("TextButton", {
	Text = "", Font = FONT.bold, TextSize = 11, AutoButtonColor = false, BorderSizePixel = 0,
	AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -9, 0.5, 0),
	Size = UDim2.fromOffset(80, 22), Parent = kindRow,
}, { new("UICorner", { CornerRadius = UDim.new(0, 5) }) })

local function paintKind()
	kindBtn.Text = noteKind:upper()
	kindBtn.TextColor3 = KIND_COLOR[noteKind] or T.text
	kindBtn.BackgroundColor3 = T.stroke
end
paintKind()

kindBtn.MouseButton1Click:Connect(function()
	for i, k in ipairs(KIND_ORDER) do
		if k == noteKind then
			noteKind = KIND_ORDER[i % #KIND_ORDER + 1]
			break
		end
	end
	paintKind()
	saveDraft()
end)

local function buildItem()
	local item = { id = os.date("!%Y%m%d-%H%M%S"), text = trimmed() }
	if noteKind == "Good" then item.kind = "good" elseif noteKind == "Bad" then item.kind = "bad" end
	return item
end

button(sAnn, "Preview note", "SHOW", function()
	local text = trimmed()
	if text == "" then return A.notify("Announcements", "nothing written yet", "bad") end
	local kind = noteKind == "Good" and "good" or noteKind == "Bad" and "bad" or nil
	A.notify("Aether", text, kind) -- exactly what a reader will see
end)

-- Sending. The publish token is typed into this box and lives nowhere else: it
-- is never written to config.json, never baked into the script, and a box
-- holding nothing means the button reports "paste the token first". That is the
-- whole reason this is safe to ship - the ability to publish is the token, and
-- the token only exists while the owner is looking at this page.
local tokenBox = new("TextBox", {
	Text = "", PlaceholderText = "Paste publish token (kept in memory only)",
	ClearTextOnFocus = false, TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center,
	Font = FONT.reg, TextSize = 11, TextColor3 = T.text, PlaceholderColor3 = T.muted,
	BackgroundColor3 = T.raised, BackgroundTransparency = 0.35, BorderSizePixel = 0,
	Size = UDim2.new(1, 0, 0, 30), Parent = sAnn,
}, { new("UICorner", { CornerRadius = UDim.new(0, 7) }), new("UIStroke", { Color = T.stroke, Transparency = 0.4, Thickness = 1 }) })

local sending = false

local function endpoint()
	return (A.announce and A.announce.api) or (A.updater and A.updater.api)
end

local function publish(item)
	local req = (syn and syn.request) or (fluxus and fluxus.request) or http_request or request
	if not req then return nil, "this executor has no request function" end
	local token = (tostring(tokenBox.Text or ""):gsub("%s+", ""))
	if token == "" then return nil, "paste the publish token first" end
	local base = endpoint()
	if not base then return nil, "no endpoint configured" end

	local payload = { text = item.text }
	if item.kind then payload.kind = item.kind end

	local ok, res = pcall(req, {
		Url = base .. "/announce",
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
		local ok, err = publish(item)
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

A.label({
	Text = "Send posts straight to the announcements endpoint - no commit, no repo edit, visible to every reader within 15s. The token box is memory only: nothing is saved to disk, and closing the script forgets it. Copy is the old fallback if the endpoint is down.",
	TextColor3 = T.muted, TextSize = 10, TextWrapped = true,
	Size = UDim2.new(1, 0, 0, 42), Parent = sAnn,
})

-- session -------------------------------------------------------
local sInfo = pAdmin.section("Session", 3)
for _, row in ipairs({
	{ "UserId", tostring(A.LP.UserId) },
	{ "Executor", tostring(A.executorName) },
	{ "Build", tostring(A.build) },
	{ "Rev", tostring(A.rev) },
}) do
	A.label({
		Text = string.format('<font color="#79818C">%s</font>   %s', row[1], row[2]),
		TextSize = 11, Size = UDim2.new(1, 0, 0, 18), Parent = sInfo,
	})
end
A.label({
	Text = "Owner panel. It reads nothing about other clients and sends nothing about this one.",
	TextColor3 = T.muted, TextSize = 10, TextWrapped = true,
	Size = UDim2.new(1, 0, 0, 28), Parent = sInfo,
})

A.stage("admin panel ready")
