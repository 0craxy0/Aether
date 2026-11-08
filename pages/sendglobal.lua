local A = ...
local new, label = A.new, A.label
local T, FONT = A.T, A.FONT
local toggle, slider, dropdown, button = A.toggle, A.slider, A.dropdown, A.button
local SG = A.SG
local PAGE = "Send a Global Message"

local pSG = A.makePage(PAGE, 5)

-- farm -----------------------------------------------------------------------

local sFarm = pSG.section("Cash farm", 1)

toggle(sFarm, "Auto-farm cash", false, function(v)
	if v then SG.start() else SG.stop() end
end)

dropdown(sFarm, "Tier", { "Auto", "Easy", "Medium", "Hard", "Nightmare", "Insane" }, "Auto", function(v)
	SG.tier = v
	SG.last = "tier set to " .. v
end)

slider(sFarm, "Attempt interval (ms)", 300, 5000, 900, function(v)
	SG.interval = v / 1000
end)

-- The character is placed this far above the pad centre. The pads sit in the
-- floor, so 0-1 studs is usually right; the slider exists because a pad that
-- does not register is the one thing that cannot be fixed from code.
slider(sFarm, "Teleport height", 0, 8, 2, function(v)
	SG.lift = v
end)

button(sFarm, "Detect unlocked tier", "DETECT", function()
	A.notify("Cash farm", "touching each pad once, Easy up", "good")
	SG.detect()
	A.notify("Cash farm", tostring(SG.last), SG.unlocked and "good" or "bad")
end)

button(sFarm, "Touch selected pad once", "TOUCH", function()
	local tier = SG.tier
	if tier == "Auto" then tier = SG.unlocked and SG.tiers[SG.unlocked] or SG.tiers[1] end
	local ok, delta = SG.tryTier(tier, 2)
	if ok then
		A.notify("Cash farm", string.format("%s +%d", tier, delta), "good")
	else
		A.notify("Cash farm", tier .. " paid nothing", "bad")
	end
end)

-- pads -----------------------------------------------------------------------

local sPads = pSG.section("Finish pads", 2)

local function wipeRows()
	for _, c in ipairs(sPads:GetChildren()) do
		if c.Name == "padRow" then c:Destroy() end
	end
end

local function rebuild()
	if not sPads.Parent then return end
	wipeRows()
	SG.resolve()
	local found = 0
	for i, p in ipairs(SG.pads) do
		if p.pos then found += 1 end
		local row = A.rowBaseRaw(sPads, 40)
		row.Name = "padRow"
		row.LayoutOrder = i
		label({
			Text = string.format("%s  ·  %d cash", p.tier, SG.pays[p.tier] or 0),
			Font = FONT.med, TextSize = 12,
			Position = UDim2.fromOffset(11, 4), Size = UDim2.new(1, -80, 0, 16), Parent = row,
		})
		label({
			Text = p.pos and string.format("%.1f, %.1f, %.1f", p.pos.X, p.pos.Y, p.pos.Z) or "WinPad not found",
			TextColor3 = p.pos and T.muted or T.bad, TextSize = 10,
			Position = UDim2.fromOffset(11, 22), Size = UDim2.new(1, -80, 0, 13), Parent = row,
		})
		local go = new("TextButton", {
			Text = "GO", Font = FONT.bold, TextSize = 10, TextColor3 = T.text,
			BackgroundColor3 = T.stroke, AutoButtonColor = false, BorderSizePixel = 0,
			AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -9, 0.5, 0),
			Size = UDim2.fromOffset(52, 22), Parent = row,
		}, { new("UICorner", { CornerRadius = UDim.new(0, 5) }) })
		go.MouseEnter:Connect(function() A.tween(go, 0.12, { BackgroundColor3 = T.accent }) end)
		go.MouseLeave:Connect(function() A.tween(go, 0.12, { BackgroundColor3 = T.stroke }) end)
		go.MouseButton1Click:Connect(function()
			A.sfx("tap")
			local ok, delta = SG.tryTier(p.tier, 2)
			A.notify("Cash farm", ok and string.format("%s +%d", p.tier, delta) or (p.tier .. " · no payout"), ok and "good" or "bad")
		end)
	end
	if found == 0 then
		local note = label({
			Text = "No WinPad found in Workspace yet - press Rescan once the map has loaded.",
			TextColor3 = T.muted, TextSize = 11, TextWrapped = true,
			Size = UDim2.new(1, 0, 0, 30), Parent = sPads,
		})
		note.Name = "padRow" -- wiped by the next rebuild like the rows are
	end
end

button(sPads, "Rescan pads", "RESCAN", function()
	SG.padsReady = false
	rebuild()
	A.notify("Cash farm", SG.padsReady and "pads found" or "still nothing - wrong place?", SG.padsReady and "good" or "bad")
end)

-- status ---------------------------------------------------------------------

local sStatus = pSG.section("Status", 3)
local statusLbl = label({
	Text = "idle", TextColor3 = T.muted, TextSize = 11, TextWrapped = true,
	Size = UDim2.new(1, 0, 0, 44), Parent = sStatus,
})

-- The page is rebuilt around config rows only, so the two live readouts are
-- driven from here instead of being registered values.
local running = true
task.spawn(function()
	while running do
		task.wait(0.4)
		if A.activeTab == PAGE and statusLbl.Parent then
			local cash = SG.cash()
			local bits = {
				string.format("cash: %s%s", cash and tostring(cash) or "?",
					SG.cashPath and (" (" .. SG.cashPath .. ")") or ""),
				string.format("farm: %s · %d attempts · +%d", SG.on and "ON" or "off", SG.attempts, SG.earned),
				"last: " .. tostring(SG.last or "-"),
				string.format("unlocked: %s", SG.unlocked and SG.tiers[SG.unlocked] or "unknown"),
			}
			statusLbl.Text = table.concat(bits, "\n")
		end
	end
end)
A.onCleanup(function() running = false end)

A.onPage(function(name)
	if name == PAGE then rebuild() end
end)
