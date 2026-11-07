local A = ...
local new, tween, corner, stroke, label = A.new, A.tween, A.corner, A.stroke, A.label
local T, FONT, toggle, notify = A.T, A.FONT, A.toggle, A.notify
local screen, maskGuis = A.screen, A.maskGuis
local RunService, UserInputService, TweenService = A.RunService, A.UserInputService, A.TweenService
local onCleanup = A.onCleanup
local TextService = game:GetService("TextService")

-- Read interface text aloud ---------------------------------------------------
-- Hover any label for three seconds and it is read out. A bar grows from the
-- middle of the text to both of its edges while the three seconds run, so the
-- wait is visible rather than mysterious.
--
-- Speaking is a backend, not a constant. A Roblox client script has no speech
-- synthesiser: Sound only plays rbxassetid:// assets, so nothing here can turn
-- arbitrary text into audio on its own. TTS.backend can be replaced with a real
-- one (A.tts.backend = function(text) ... end); until then the fallback voice is
-- a short, quiet blip per word, which at least confirms what was picked up.
local HOLD = 3     -- seconds of continuous hover before it speaks
local SCAN = 0.08  -- how often the pointer is re-tested against the labels
local THICK = 1.5  -- underline height in pixels

local TTS = { enabled = false, backend = nil, modal = nil }
A.tts = TTS

function TTS.speak(text)
	text = tostring(text or ""):gsub("<[^>]->", ""):gsub("%s+", " "):gsub("^%s*(.-)%s*$", "%1")
	if text == "" then return end

	if TTS.backend then
		local ok, err = pcall(TTS.backend, text)
		if not ok then notify("TTS", tostring(err), "bad") end
		return
	end

	-- fallback: one blip per word, capped, so a paragraph does not turn into a
	-- minute of pinging
	local n = 0
	for _ in text:gmatch("%S+") do n += 1 end
	for i = 1, math.min(n, 8) do
		task.delay((i - 1) * 0.11, function()
			if TTS.enabled then A.sfx("voice", 1.15) end
		end)
	end
end

-- the progress bar: one shared bar in a layer above the panel, so no label's
-- layout is touched (an extra child would resize anything with AutomaticSize)
local bar = new("Frame", {
	Name = "ttsUnderline", AnchorPoint = Vector2.new(0.5, 0), Visible = false,
	Size = UDim2.fromOffset(0, THICK), BackgroundColor3 = T.accent,
	BorderSizePixel = 0, ZIndex = 300, Parent = screen,
}, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
maskGuis[#maskGuis + 1] = bar -- ESP must not draw across the underline

-- A.tween stretches by the animation scale, and this bar has to finish exactly
-- when the three seconds do, so it is tweened with an exact duration instead.
local function linear(o, dur, props)
	local t = TweenService:Create(o, TweenInfo.new(dur, Enum.EasingStyle.Linear), props)
	t:Play()
	return t
end

local barTween, barToken = nil, 0

local function hideBar()
	barToken += 1
	local id = barToken
	if barTween then barTween:Cancel(); barTween = nil end
	tween(bar, 0.12, { Size = UDim2.fromOffset(0, THICK) })
	task.delay(0.2, function()
		if barToken == id and bar.Parent then bar.Visible = false end
	end)
end

-- width of the text itself, not of the label: a left-aligned label in a wide row
-- would otherwise underline empty space
local function textWidth(lbl)
	if lbl.TextScaled then return lbl.AbsoluteSize.X end
	local ok, size = pcall(function()
		return TextService:GetTextSize(lbl.Text, lbl.TextSize, lbl.Font, Vector2.new(10000, lbl.TextSize * 3))
	end)
	if ok and typeof(size) == "Vector2" then
		return math.min(size.X, lbl.AbsoluteSize.X)
	end
	return lbl.AbsoluteSize.X
end

local function showBar(lbl)
	barToken += 1
	if barTween then barTween:Cancel(); barTween = nil end

	local ap, as = lbl.AbsolutePosition, lbl.AbsoluteSize
	local w = textWidth(lbl)
	local x
	if lbl.TextXAlignment == Enum.TextXAlignment.Center then
		x = ap.X + (as.X - w) / 2
	elseif lbl.TextXAlignment == Enum.TextXAlignment.Right then
		x = ap.X + as.X - w
	else
		x = ap.X
	end

	local textTop
	if lbl.TextYAlignment == Enum.TextYAlignment.Top then
		textTop = ap.Y
	elseif lbl.TextYAlignment == Enum.TextYAlignment.Bottom then
		textTop = ap.Y + as.Y - lbl.TextSize
	else
		textTop = ap.Y + (as.Y - lbl.TextSize) / 2
	end

	bar.Visible = true
	bar.BackgroundTransparency = 0
	bar.Position = UDim2.fromOffset(x + w / 2, textTop + lbl.TextSize * 1.02)
	-- pixels, not scale: UDim2.new(w, 0, ...) would read w as a fraction of the
	-- screen, which drew the underline across the whole viewport
	bar.Size = UDim2.fromOffset(0, THICK)
	barTween = linear(bar, HOLD, { Size = UDim2.fromOffset(w, THICK) })
end

-- which label is under the pointer ------------------------------------------
local cache, cacheAt = {}, 0

local function reachable(d)
	local p = d.Parent
	while p and p ~= screen do
		if not p.Visible then return false end
		p = p.Parent
	end
	return p == screen
end

local function refreshCache()
	cacheAt = os.clock()
	cache = {}
	for _, d in ipairs(screen:GetDescendants()) do
		if (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Visible and d.TextTransparency < 0.98 then
			local text = d.Text
			if type(text) == "string" and text ~= "" and reachable(d) then
				cache[#cache + 1] = d
			end
		end
	end
end

local function under(m)
	-- the pointer is in window space; the labels are in AbsolutePosition space
	local y = m.Y - (A.guiInset or 0)
	-- backwards: the later a label was created, the more likely it is on top
	for i = #cache, 1, -1 do
		local d = cache[i]
		if d.Parent then
			local p, s = d.AbsolutePosition, d.AbsoluteSize
			if m.X >= p.X and m.X <= p.X + s.X and y >= p.Y and y <= p.Y + s.Y then
				return d
			end
		end
	end
	return nil
end

local current, startedAt, spoken = nil, 0, false
local acc = 0

local function clearHover()
	current, startedAt, spoken = nil, 0, false
	hideBar()
end

local function tick(dt)
	if not TTS.enabled or TTS.modal then
		if current then clearHover() end
		return
	end

	acc += dt
	if acc < SCAN then return end
	acc = 0

	if os.clock() - cacheAt > 1 then refreshCache() end

	local hit = under(UserInputService:GetMouseLocation())
	if hit ~= current then
		current = hit
		spoken = false
		startedAt = os.clock()
		if hit then showBar(hit) else hideBar() end
	end
	if not current then return end

	if not spoken and os.clock() - startedAt >= HOLD then
		spoken = true
		TTS.speak(current.Text)
		-- hold the finished bar for a beat, then release it
		barToken += 1
		local id = barToken
		task.delay(0.4, function() if barToken == id then hideBar() end end)
	end
end

local conn = RunService.Heartbeat:Connect(function(dt) tick(math.min(dt, 1 / 20)) end)

function TTS.set(on)
	TTS.enabled = on and true or false
	if not TTS.enabled then clearHover() end
end

-- first run prompt ------------------------------------------------------------
-- Asking once is helpful; asking every launch is a nag. A "yes" is remembered
-- whatever the checkbox says - choosing to have it read to you is the answer the
-- checkbox was there to second-guess. A "no" is only remembered if it is ticked.
local function drawTick(parent)
	for i = 1, 2 do
		new("Frame", {
			Name = "tick", AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(i == 1 and 0.36 or 0.62, i == 1 and 0.60 or 0.42),
			Size = UDim2.fromOffset(i == 1 and 5 or 9, 1.6), Rotation = i == 1 and 45 or -45,
			BackgroundColor3 = T.bg, BorderSizePixel = 0, Parent = parent,
		})
	end
end

function TTS.maybePrompt()
	if TTS.enabled or (A.extra and A.extra.ttsPromptDone) or TTS.modal then return end

	local backdrop = new("TextButton", {
		Text = "", AutoButtonColor = false, BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1, ZIndex = 500, Parent = screen,
	})
	maskGuis[#maskGuis + 1] = backdrop

	local card = new("CanvasGroup", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(360, 206), BackgroundColor3 = T.panel,
		BackgroundTransparency = 0.02, GroupTransparency = 1, ZIndex = 501, Parent = screen,
	})
	corner(card, 12)
	stroke(card, T.stroke, 0.25)
	local pop = new("UIScale", { Scale = 0.85, Parent = card })

	label({ Text = "Read interface text aloud?", Font = FONT.bold, TextSize = 15, Position = UDim2.fromOffset(22, 20), Size = UDim2.new(1, -44, 0, 18), Parent = card })
	label({
		Text = "Point at a label and hold for three seconds and Aether will read it out. It is off until you turn it on, and one click on the UI page turns it off again.",
		TextColor3 = T.muted, TextSize = 11, TextWrapped = true,
		Position = UDim2.fromOffset(22, 46), Size = UDim2.new(1, -44, 0, 46), Parent = card,
	})

	local function mkButton(x, w, text, accent, onClick)
		local b = new("TextButton", {
			Text = text, Font = FONT.med, TextSize = 12, AutoButtonColor = false, BorderSizePixel = 0,
			Position = UDim2.fromOffset(x, 102), Size = UDim2.fromOffset(w, 34),
			TextColor3 = accent and T.bg or T.text,
			BackgroundColor3 = accent and T.accent or T.stroke, Parent = card,
		}, { new("UICorner", { CornerRadius = UDim.new(0, 8) }) })
		if accent then A.accentLinks[#A.accentLinks + 1] = { obj = b, kind = "fill" } end
		b.MouseEnter:Connect(function()
			if accent then return end
			tween(b, 0.12, { BackgroundColor3 = T.raised })
		end)
		b.MouseLeave:Connect(function()
			if accent then return end
			tween(b, 0.12, { BackgroundColor3 = T.stroke })
		end)
		b.MouseButton1Click:Connect(onClick)
		return b
	end

	-- checkbox, below the buttons as asked
	local checked = false
	local box = new("Frame", {
		Position = UDim2.fromOffset(22, 158), Size = UDim2.fromOffset(14, 14),
		BackgroundColor3 = T.raised, BorderSizePixel = 0, Parent = card,
	}, { new("UICorner", { CornerRadius = UDim.new(0, 4) }), new("UIStroke", { Color = T.stroke, Thickness = 1, Transparency = 0.2 }) })
	local tickMark = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, Parent = box })
	drawTick(tickMark)

	local hitRow = new("TextButton", {
		Text = "", AutoButtonColor = false, BackgroundTransparency = 1, BorderSizePixel = 0,
		Position = UDim2.fromOffset(18, 150), Size = UDim2.new(1, -36, 0, 30), Parent = card,
	})
	label({ Text = "Don't show this again", TextColor3 = T.muted, TextSize = 11, Position = UDim2.fromOffset(42, 150), Size = UDim2.new(1, -64, 0, 30), Parent = card })

	local function toggleCheck()
		checked = not checked
		tickMark.Visible = checked
		box.BackgroundColor3 = checked and T.accent or T.raised
		box.UIStroke.Color = checked and T.accent or T.stroke
	end
	hitRow.MouseButton1Click:Connect(toggleCheck)

	local function close()
		TTS.modal = nil
		tween(card, 0.25, { GroupTransparency = 1 })
		tween(pop, 0.25, { Scale = 0.9 })
		tween(backdrop, 0.25, { BackgroundTransparency = 1 })
		task.delay(0.26, function()
			card:Destroy()
			backdrop:Destroy()
		end)
	end

	mkButton(22, 155, "Enable", true, function()
		if TTS.row then TTS.row.set(true) else TTS.set(true) end
		-- yes is final, ticked or not: the checkbox was only there to second-guess a no
		A.saveExtra("ttsPromptDone", true)
		close()
		notify("Read aloud", "on · hover a label for 3s", "good")
	end)

	mkButton(185, 153, "Not now", false, function()
		TTS.set(false)
		if checked then A.saveExtra("ttsPromptDone", true) end -- only a no that was ticked sticks
		close()
	end)

	TTS.modal = true
	tween(card, 0.4, { GroupTransparency = 0 })
	tween(pop, 0.5, { Scale = 1 }, Enum.EasingStyle.Elastic)
	tween(backdrop, 0.3, { BackgroundTransparency = 0.45 })
end

-- the switch on the UI page is the source of truth once the prompt is answered
TTS.row = toggle(A.sUI4, "Read text aloud", false, TTS.set)

onCleanup(function()
	conn:Disconnect()
	if bar.Parent then bar:Destroy() end
	if TTS.modal then TTS.modal = nil end
end)

A.stage("tts ready")
