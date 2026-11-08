local A = ...
local new, tween, corner, stroke, label, drawX = A.new, A.tween, A.corner, A.stroke, A.label, A.drawX
local T, FONT, notify, onCleanup, TF = A.T, A.FONT, A.notify, A.onCleanup, A.TF
local LP, Players, RunService = A.LP, A.Players, A.RunService
local screen, window, maskGuis, uiScales = A.screen, A.window, A.maskGuis, A.uiScales
local charParts = A.charParts

local pPlr = A.makePage("Players", 5)
local sPlr = pPlr.section("In this server", 1)
local plrList = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = sPlr }, {
	new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
})

local refreshPlayers
do
	local PV = { plr = nil, open = false, query = "", marks = {}, spectating = nil, flinging = false, flingConn = nil, btns = {} }
	-- The card used to be a fixed 214x318, which was only ever right at the
	-- default window size: with "Scale UI contents" off the window grows in real
	-- pixels while the contents do not, so the card sat there at its old size
	-- against a much bigger panel. Deriving it from the logical window size makes
	-- both modes agree - scaled, A.W/H stay put and the UIScale does the growing;
	-- unscaled, they grow and the card grows with them.
	local function panelSize()
		local w = math.clamp(math.floor((A.W or 580) * 0.37), 190, 400)
		local h = math.clamp(math.floor((A.H or 430) * 0.74), 240, 470)
		return w, h
	end
	local PW, PH = panelSize()

	local psFrame = new("Frame", {
		Size = UDim2.new(1, 0, 0, 30), LayoutOrder = -1, BackgroundColor3 = T.panel, BorderSizePixel = 0, Parent = sPlr,
	}, { new("UICorner", { CornerRadius = UDim.new(0, 7) }), new("UIStroke", { Color = T.stroke, Transparency = 0.4, Thickness = 1 }) })
	local psBox = new("TextBox", {
		Text = "", PlaceholderText = "Search", PlaceholderColor3 = T.muted, BackgroundTransparency = 1,
		Font = FONT.reg, TextSize = 12, TextColor3 = T.text, TextXAlignment = Enum.TextXAlignment.Left,
		ClearTextOnFocus = false, Position = UDim2.fromOffset(11, 0), Size = UDim2.new(1, -22, 1, 0), Parent = psFrame,
	})

	local panel = new("CanvasGroup", {
		AnchorPoint = Vector2.new(0, 0.5), Size = UDim2.fromOffset(PW, PH), BackgroundColor3 = T.bg,
		BackgroundTransparency = 0.03, BorderSizePixel = 0, GroupTransparency = 1, Visible = false, Parent = screen,
	})
	corner(panel, 11)
	stroke(panel, T.stroke, 0.25)
	local pScale = new("UIScale", { Parent = panel })
	maskGuis[#maskGuis + 1] = panel

	local avatar = new("ImageLabel", {
		Position = UDim2.fromOffset(14, 14), Size = UDim2.fromOffset(56, 56), BackgroundColor3 = T.raised, BorderSizePixel = 0, Image = "", Parent = panel,
	}, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	local pDisplay = label({ Text = "", RichText = false, Font = FONT.bold, TextSize = 14, TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.fromOffset(78, 18), Size = UDim2.new(1, -112, 0, 20), Parent = panel })
	local pUser = label({ Text = "", RichText = false, TextColor3 = T.muted, TextSize = 11, TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.fromOffset(78, 40), Size = UDim2.new(1, -112, 0, 14), Parent = panel })
	local holder = new("Frame", {
		Position = UDim2.fromOffset(14, 84), Size = UDim2.new(1, -28, 1, -98), BackgroundTransparency = 1, Parent = panel,
	}, { new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })

	local function pbtn(text, onText, order, col, cb)
		local b = new("TextButton", {
			Text = text, Font = FONT.bold, TextSize = 11, TextColor3 = T.text, BackgroundColor3 = T.stroke,
			AutoButtonColor = false, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 32), LayoutOrder = order, Parent = holder,
		}, { new("UICorner", { CornerRadius = UDim.new(0, 7) }) })
		local e = { b = b, on = false, col = col }
		e.paint = function()
			b.Text = e.on and onText or text
			tween(b, 0.15, { BackgroundColor3 = e.on and e.col or T.stroke })
		end
		b.MouseEnter:Connect(function() if not e.on then tween(b, 0.12, { BackgroundColor3 = T.accent }) end end)
		b.MouseLeave:Connect(function() e.paint() end)
		b.MouseButton1Click:Connect(function()
			b.Size = UDim2.new(1, -28, 0, 24)
			tween(b, 0.6, { Size = UDim2.new(1, 0, 0, 32) }, Enum.EasingStyle.Elastic)
			if PV.plr then
				local ok, err = pcall(cb, PV.plr)
				if not ok then notify(text, tostring(err), "bad") end
			end
		end)
		PV.btns[text] = e
	end

	local function refreshButtons()
		local p = PV.plr
		if not p then return end
		local m = TF.mode(p)
		PV.btns["TP"].on = false
		PV.btns["Spectate"].on = PV.spectating == p
		PV.btns["Mark"].on = PV.marks[p] ~= nil
		PV.btns["Whitelist"].on = m == "white"
		PV.btns["Blacklist"].on = m == "black"
		PV.btns["Fling"].on = false
		for _, e in pairs(PV.btns) do e.paint() end
	end

	local function unmark(plr)
		local m = PV.marks[plr]
		if m then
			pcall(function() m.gui:Destroy() end)
			PV.marks[plr] = nil
		end
	end

	local function mark(plr)
		if PV.marks[plr] then
			unmark(plr)
			return
		end
		local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
		if not root then return notify("Mark", "no character", "bad") end
		local bb = new("BillboardGui", { Size = UDim2.fromOffset(150, 40), StudsOffset = Vector3.new(0, 3.8, 0), AlwaysOnTop = true, Adornee = root, Parent = screen })
		local txt = label({ Text = plr.DisplayName, RichText = false, Font = FONT.bold, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.4, Size = UDim2.new(1, 0, 0, 18), Parent = bb })
		new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 24), Size = UDim2.fromOffset(9, 9), BackgroundColor3 = T.accent, BorderSizePixel = 0, Rotation = 45, Parent = bb })
		PV.marks[plr] = { gui = bb, txt = txt }
	end

	local function stopSpectate()
		PV.spectating = nil
		local _, hum = charParts()
		local cam = workspace.CurrentCamera
		if cam and hum then cam.CameraSubject = hum end
	end

	local function spectate(plr)
		if PV.spectating == plr then
			stopSpectate()
			return
		end
		local hum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
		local cam = workspace.CurrentCamera
		if not hum or not cam then return notify("Spectate", "no character", "bad") end
		PV.spectating = plr
		cam.CameraSubject = hum
	end

	local flingSaved = {}
	local function restoreFling()
		for p in pairs(flingSaved) do
			if p.Parent then pcall(function() p.CanCollide = true end) end
			flingSaved[p] = nil
		end
	end

	local function fling(plr)
		if PV.flinging then return end
		local _, _, root = charParts()
		local troot = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
		if not root or not troot then return notify("Fling", "no character", "bad") end
		PV.flinging = true
		local origin = root.CFrame
		local t0 = tick()
		local conn
		conn = RunService.Heartbeat:Connect(function()
			local c, _, r = charParts()
			local tr = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
			if tick() - t0 > 2.5 or not r or not tr then
				conn:Disconnect()
				PV.flinging = false
				PV.flingConn = nil
				restoreFling()
				if r then
					r.AssemblyLinearVelocity = Vector3.zero
					r.AssemblyAngularVelocity = Vector3.zero
					r.CFrame = origin
				end
				return
			end
			for _, p in ipairs(c:GetDescendants()) do
				if p:IsA("BasePart") and p.CanCollide then
					flingSaved[p] = true
					p.CanCollide = false
				end
			end
			r.CFrame = tr.CFrame
			r.AssemblyAngularVelocity = Vector3.new(0, 4e4, 0)
			r.AssemblyLinearVelocity = Vector3.new(4e4, 0, 4e4)
		end)
		PV.flingConn = conn
	end

	local function setMode(plr, mode)
		if TF.mode(plr) == mode then
			TF.set(plr, nil)
			notify("Targets", plr.DisplayName .. " cleared")
		else
			TF.set(plr, mode)
			notify("Targets", plr.DisplayName .. (mode == "white" and " whitelisted" or " blacklisted"), mode == "white" and "good" or "bad")
		end
		refreshButtons()
		refreshPlayers()
	end

	local function closePanel()
		PV.open = false
		tween(panel, 0.2, { GroupTransparency = 1 })
		task.delay(0.2, function() if not PV.open then panel.Visible = false end end)
	end

	local function openPanel(plr)
		if PV.open and PV.plr == plr then
			closePanel()
			return
		end
		PV.plr = plr
		PV.open = true
		pDisplay.Text = plr.DisplayName
		pUser.Text = "@" .. plr.Name
		avatar.Image = ""
		task.spawn(function()
			local ok, img = pcall(Players.GetUserThumbnailAsync, Players, plr.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
			if ok and PV.plr == plr then avatar.Image = img end
		end)
		refreshButtons()
		panel.Visible = true
		-- target size is read at open time, and the heartbeat leaves it alone while
		-- the elastic tween is still running
		local w, h = panelSize()
		panel.Size = UDim2.fromOffset(w * 0.7, h * 0.7)
		PV.animating = true
		tween(panel, 0.8, { Size = UDim2.fromOffset(w, h) }, Enum.EasingStyle.Elastic)
		tween(panel, 0.22, { GroupTransparency = 0 })
		task.delay(0.85, function() PV.animating = false end)
	end

	pbtn("TP", "TP", 1, T.accent, A.tpTo)
	pbtn("Spectate", "Stop spectating", 2, T.accent, function(p) spectate(p); refreshButtons() end)
	pbtn("Mark", "Unmark", 3, T.accent, function(p) mark(p); refreshButtons() end)
	pbtn("Whitelist", "Whitelisted", 4, T.good, function(p) setMode(p, "white") end)
	pbtn("Blacklist", "Blacklisted", 5, T.bad, function(p) setMode(p, "black") end)
	pbtn("Fling", "Fling", 6, T.accent, fling)

	local xBtn = new("TextButton", {
		Text = "", Font = FONT.med, TextSize = 13, TextColor3 = T.muted, BackgroundTransparency = 1, AutoButtonColor = false,
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 10), Size = UDim2.fromOffset(22, 22), Parent = panel,
	})
	drawX(xBtn, 10, T.muted)
	xBtn.MouseEnter:Connect(function() for _, a in ipairs(xBtn:GetChildren()) do if a.Name == "xarm" then tween(a, 0.12, { BackgroundColor3 = T.text }) end end end)
	xBtn.MouseLeave:Connect(function() for _, a in ipairs(xBtn:GetChildren()) do if a.Name == "xarm" then tween(a, 0.12, { BackgroundColor3 = T.muted }) end end end)
	xBtn.MouseButton1Click:Connect(closePanel)

	local pvConn = RunService.Heartbeat:Connect(function()
		local ap, as = window.AbsolutePosition, window.AbsoluteSize
		pScale.Scale = uiScales[1].Scale
		if PV.open then
			panel.Visible = window.Visible and A.activeTab == "Players"
			local vp = screen.AbsoluteSize
			local w, h = panelSize()
			local pw = w * pScale.Scale
			local x = ap.X + as.X + 10
			if x + pw > vp.X then x = math.max(ap.X - pw - 10, 4) end
			panel.Position = UDim2.fromOffset(x, ap.Y + as.Y / 2)
			-- follow a resize: compare in on-screen pixels, because AbsoluteSize
			-- already includes the panel's own UIScale
			if not PV.animating and math.abs(panel.AbsoluteSize.X - pw) > 1 then
				panel.Size = UDim2.fromOffset(w, h)
			end
		end
		local _, _, mine = charParts()
		for plr, m in pairs(PV.marks) do
			local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
			m.gui.Adornee = root
			if root and mine then
				m.txt.Text = string.format("%s · %dm", plr.DisplayName, math.floor((root.Position - mine.Position).Magnitude))
			end
		end
		local sp = PV.spectating
		if sp then
			local cam = workspace.CurrentCamera
			local hum = sp.Character and sp.Character:FindFirstChildOfClass("Humanoid")
			if cam and hum and cam.CameraSubject ~= hum then cam.CameraSubject = hum end
		end
	end)

	local leaveConn = Players.PlayerRemoving:Connect(function(plr)
		unmark(plr)
		if PV.spectating == plr then stopSpectate() end
		if PV.plr == plr and PV.open then closePanel() end
	end)

	onCleanup(function()
		pvConn:Disconnect()
		leaveConn:Disconnect()
		if PV.flingConn then PV.flingConn:Disconnect(); PV.flingConn = nil end
		PV.flinging = false
		restoreFling()
		for plr in pairs(PV.marks) do unmark(plr) end
		stopSpectate()
		panel:Destroy()
	end)

	refreshPlayers = function()
		for _, c in ipairs(plrList:GetChildren()) do
			if c:IsA("TextButton") then c:Destroy() end
		end
		local q = PV.query:lower()
		local n = 0
		for _, plr in ipairs(Players:GetPlayers()) do
			if plr == LP then continue end
			if q ~= "" and not (plr.Name:lower():find(q, 1, true) or plr.DisplayName:lower():find(q, 1, true)) then continue end
			n += 1
			local mode = TF.mode(plr)
			local row = new("TextButton", {
				Text = "", BackgroundColor3 = T.raised, BackgroundTransparency = 0.35,
				AutoButtonColor = false, BorderSizePixel = 0, LayoutOrder = n,
				Size = UDim2.new(1, 0, 0, 38), Parent = plrList,
			}, { new("UICorner", { CornerRadius = UDim.new(0, 6) }) })
			label({ Text = plr.DisplayName, RichText = false, Font = FONT.med, TextSize = 12, TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -110, 0, 16), Parent = row })
			label({ Text = "@" .. plr.Name, RichText = false, TextSize = 10, TextColor3 = T.muted, TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.fromOffset(10, 20), Size = UDim2.new(1, -110, 0, 13), Parent = row })
			if mode then
				label({ Text = mode == "white" and "WL" or "BL", Font = FONT.bold, TextSize = 10, TextColor3 = mode == "white" and T.good or T.bad, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.new(1, -92, 0, 0), Size = UDim2.fromOffset(24, 38), Parent = row })
			end
			local go = new("TextButton", {
				Text = "View", Font = FONT.med, TextSize = 11, TextColor3 = T.text,
				BackgroundColor3 = T.stroke, AutoButtonColor = false, BorderSizePixel = 0,
				AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0),
				Size = UDim2.fromOffset(52, 22), Parent = row,
			}, { new("UICorner", { CornerRadius = UDim.new(0, 5) }) })
			go.MouseEnter:Connect(function() tween(go, 0.12, { BackgroundColor3 = T.accent }) end)
			go.MouseLeave:Connect(function() tween(go, 0.12, { BackgroundColor3 = T.stroke }) end)
			row.MouseEnter:Connect(function() tween(row, 0.15, { BackgroundTransparency = 0.2 }) end)
			row.MouseLeave:Connect(function() tween(row, 0.15, { BackgroundTransparency = 0.35 }) end)
			go.MouseButton1Click:Connect(function() openPanel(plr) end)
			row.MouseButton1Click:Connect(function() A.copy(plr.Name) end)
		end
	end

	psBox:GetPropertyChangedSignal("Text"):Connect(function()
		PV.query = psBox.Text
		refreshPlayers()
	end)
end

local addedConn = Players.PlayerAdded:Connect(function() refreshPlayers() end)
local removedConn = Players.PlayerRemoving:Connect(function() task.defer(refreshPlayers) end)
onCleanup(function() addedConn:Disconnect(); removedConn:Disconnect() end)
refreshPlayers()

