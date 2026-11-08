-- Kill All (prototype) ---------------------------------------------------------
-- Standalone, like the other tools: nothing here is wired into the hub yet.
--
--   loadstring(game:HttpGet("https://raw.githubusercontent.com/0craxy0/Aether/main/tools/killall.lua"))()
--
-- Why it fires instead of setting Health: the hook showed cash arriving only after
-- the server answers HitConfirm(), and a client-side `Humanoid.Health = 0` never
-- leaves the client, so it would empty your screen and pay nothing. This walks the
-- dummies and shoots them through the game's own path instead, which is the one
-- the server already trusts.
--
--   getgenv().KillAll.scan()        list what it can see, fires nothing
--   getgenv().KillAll.run()         work down the list
--   getgenv().KillAll.stop()        abort
--   F7 runs it, F6 scans
--
-- This is a measuring tool first: it prints per-target time and the cash delta, so
-- we know the real rate before anything is built on top of it.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local LP = Players.LocalPlayer

local CFG = {
	maxRange = 400,      -- studs; dummies further than this are skipped
	perTarget = 2.5,     -- seconds before giving up on one target
	fireEvery = 0.12,    -- seconds between Activate() calls
	aimSettle = 0.05,    -- let the gun notice the new aim before firing
	-- a Humanoid with no Dummy{number} ancestor is treated as scenery unless this
	-- is on: a menu stand or a shop NPC is not worth a bullet
	includeLoose = false,
}

local state = { running = false, stopAt = 0 }

local function char()
	local c = LP.Character
	return c, c and c:FindFirstChildOfClass("Humanoid")
end

local function cash()
	local v = LP:GetAttribute("Cash")
	return type(v) == "number" and v or nil
end

-- Where dummies actually live: a Dummies folder under Workspace, holding one model
-- per dummy. The Humanoid is not directly under that model - it sits in a nested rig
-- ("StandAvatar"), which is why matching on the immediate parent found the rig and
-- not the dummy. Folder membership is the reliable signal; the Dummy{number} name
-- pattern is kept as a second net for rounds that spawn outside it.
local function dummyFolder()
	for _, c in ipairs(Workspace:GetChildren()) do
		if c.Name:lower() == "dummies" then return c end
	end
	return nil
end

local function dummyRoot(inst)
	local node = inst
	for _ = 1, 8 do
		if not node or node == Workspace then break end
		if node.Name:match("^Dummy%d*$") then return node, true end
		node = node.Parent
	end
	return inst, false
end

local function humOf(model)
	local direct = model:FindFirstChildOfClass("Humanoid")
	if direct then return direct end
	local ok, found = pcall(function() return model:FindFirstChildWhichIsA("Humanoid", true) end)
	return ok and found or nil
end

local function partOf(model)
	local ok, found = pcall(function()
		return model:FindFirstChild("HumanoidRootPart")
			or model:FindFirstChild("Head")
			or model:FindFirstChild("HumanoidRootPart", true)
			or model:FindFirstChild("Head", true)
	end)
	return ok and found or nil
end

local function candidates()
	local me = LP.Character
	local out, seenModel = {}, {}
	local origin
	local root = me and me:FindFirstChild("HumanoidRootPart")
	if root then origin = root.Position end

	local function add(model, byFolder)
		if not model or model == me or seenModel[model] then return end
		if Players:GetPlayerFromCharacter(model) then return end
		local part = partOf(model)
		if not part then return end
		local hum = humOf(model)
		-- The folder's dummies have no Humanoid at all. This game keeps their state
		-- in attributes - Consciousness, BloodMl, Condition, Status - so a rig is
		-- optional and "dead" means something else entirely (see isDown).
		if hum and hum.Health <= 0 then return end
		if not hum and not byFolder and not CFG.includeLoose then return end
		local dist = origin and (part.Position - origin).Magnitude or 0
		if dist > CFG.maxRange then return end
		seenModel[model] = true
		out[#out + 1] = {
			model = model, hum = hum, part = part, dist = dist,
			folder = byFolder, rig = (hum and hum.Parent and hum.Parent.Name) or "no rig",
		}
	end

	-- 1. everything in Workspace.Dummies
	local folder = dummyFolder()
	local folderCount = 0
	if folder then
		for _, child in ipairs(folder:GetChildren()) do
			folderCount = folderCount + 1
			add(child, true)
		end
	end

	-- 2. Dummy{number} anywhere else, and loose Humanoids if asked for
	for _, d in ipairs(Workspace:GetDescendants()) do
		if d:IsA("Humanoid") and d.Health > 0 and d.Parent then
			local model, isDummy = dummyRoot(d.Parent)
			if isDummy or CFG.includeLoose then add(model, false) end
		end
	end

	table.sort(out, function(a, b) return a.dist < b.dist end)
	out.folderCount = folderCount
	out.folderFound = folder ~= nil
	return out
end

local function equippedTool()
	local c = LP.Character
	if not c then return nil end
	local t = c:FindFirstChildOfClass("Tool")
	if t then return t end
	local pack = LP:FindFirstChildOfClass("Backpack")
	local hum = c:FindFirstChildOfClass("Humanoid")
	if pack and hum then
		local pick = pack:FindFirstChildOfClass("Tool")
		if pick then
			pcall(function() hum:EquipTool(pick) end)
			task.wait(0.15)
			return c:FindFirstChildOfClass("Tool")
		end
	end
	return nil
end

local function aimAt(part)
	local cam = Workspace.CurrentCamera
	if not cam or not part then return end
	local from = cam.CFrame.Position
	local to = part.Position
	if (to - from).Magnitude < 0.5 then return end
	cam.CFrame = CFrame.lookAt(from, to)
end

-- Guns usually shoot where the *cursor* is, not where the camera looks, and a
-- camera write cannot move the cursor. Executors expose mousemoverel for exactly
-- this: push the virtual cursor by the screen offset between the crosshair and the
-- target. Where it is unavailable the camera write above is the only option.
local function aimMouse(part)
	local cam = Workspace.CurrentCamera
	if not cam or not part then return false end
	local move
	if type(mousemoverel) == "function" then
		move = mousemoverel
	elseif syn and type(syn.mousemoverel) == "function" then
		move = syn.mousemoverel
	elseif type(mousemoveabs) == "function" then
		move = function(dx, dy)
			local loc = UserInputService:GetMouseLocation()
			mousemoveabs(loc.X + dx, loc.Y + dy)
		end
	end
	if not move then return false end

	local sp, on = cam:WorldToViewportPoint(part.Position)
	if not on or sp.Z <= 0 then return false end
	local vp = cam.ViewportSize
	local dx, dy = sp.X - vp.X / 2, sp.Y - vp.Y / 2
	if math.abs(dx) < 1 and math.abs(dy) < 1 then return true end
	pcall(move, dx, dy)
	return true
end

-- Deep, readable dump of remote arguments. Needed because "Fire(Vector3, {0})" in
-- the log does not say which Vector3 or what the table holds, and a fabricated call
-- has to match the real one exactly.
local function deep(v, depth)
	local t = typeof(v)
	if t == "Vector3" then
		return string.format("V3(%.2f, %.2f, %.2f)", v.X, v.Y, v.Z)
	elseif t == "CFrame" then
		local p = v.Position
		return string.format("CFrame(%.1f, %.1f, %.1f)", p.X, p.Y, p.Z)
	elseif t == "Instance" then
		return v.Name
	elseif t == "string" then
		return string.format("%q", v:sub(1, 32))
	elseif t == "table" then
		if depth <= 0 then return "{...}" end
		local bits = {}
		for k, val in pairs(v) do
			bits[#bits + 1] = tostring(k) .. "=" .. deep(val, depth - 1)
			if #bits >= 8 then break end
		end
		return "{" .. table.concat(bits, ", ") .. "}"
	elseif t == "number" then
		return string.format("%.3f", v)
	end
	return tostring(v)
end

-- What "dead" means here. There is no Health: the model carries Consciousness
-- (100 → 0), BloodMl (5000 and falling), Condition/Status strings, and a Summary
-- written by the game's own medical simulation. Any of those leaving the healthy
-- range counts as a hit we can see, which is what the cash is paid for.
local function snapshot(model)
	local c = model:GetAttribute("Consciousness")
	local b = model:GetAttribute("BloodMl")
	local s = model:GetAttribute("Status")
	return string.format("cons %s · blood %s · %s",
		tostring(c == nil and "?" or math.floor(c)),
		tostring(b == nil and "?" or math.floor(b)),
		tostring(s or "?"))
end

local function isDown(model)
	local c = model:GetAttribute("Consciousness")
	if type(c) == "number" and c < 100 then return true end
	local s = model:GetAttribute("Status")
	if type(s) == "string" and s ~= "Conscious" and s ~= "" then return true end
	local b = model:GetAttribute("BloodMl")
	if type(b) == "number" and b < 5000 then return true end
	return false
end

local function dumpFolder()
	local folder = dummyFolder()
	if not folder then
		print("[KillAll] no Workspace.Dummies folder")
		return
	end
	local kids = folder:GetChildren()
	print(string.format("[KillAll] %s · %d child(ren)", folder:GetFullName(), #kids))
	for i, m in ipairs(kids) do
		if i > 12 then
			print("  ...")
			break
		end
		local attrs = {}
		local okA, a = pcall(function() return m:GetAttributes() end)
		if okA and type(a) == "table" then
			for k, v in pairs(a) do attrs[#attrs + 1] = k .. "=" .. tostring(v) end
		end
		local keyKids = {}
		for _, c in ipairs(m:GetChildren()) do
			if #keyKids < 7 then keyKids[#keyKids + 1] = c.Name .. ":" .. c.ClassName end
		end
		print(string.format("  %2d. %-14s %-9s attrs[%s] kids[%s]", i, m.Name:sub(1, 14), m.ClassName,
			table.concat(attrs, ","), table.concat(keyKids, ",")))
	end
end

local function scan()
	local list = candidates()
	local where = list.folderFound
		and string.format("Workspace.Dummies (%d child model(s))", list.folderCount)
		or "no Workspace.Dummies folder"
	print(string.format("[KillAll] %d target(s) within %d studs · %s", #list, CFG.maxRange, where))
	for i = 1, math.min(#list, 20) do
		local t = list[i]
		print(string.format("  %2d. %-10s %3.0f studs  %s", i, t.model.Name:sub(1, 10), t.dist, snapshot(t.model)))
	end
	if #list == 0 then
		-- The folder is there but nothing in it answered to Humanoid. Print what is
		-- actually in it, and what the Humanoids in the place do look like, rather
		-- than guessing again.
		dumpFolder()
		print("  (every Humanoid in Workspace follows:)")
		local n = 0
		for _, d in ipairs(Workspace:GetDescendants()) do
			if d:IsA("Humanoid") then
				n = n + 1
				if n <= 15 then
					local p1 = d.Parent and d.Parent.Name or "?"
					local p2 = d.Parent and d.Parent.Parent and d.Parent.Parent.Name or "?"
					local p3 = d.Parent and d.Parent.Parent and d.Parent.Parent.Parent and d.Parent.Parent.Parent.Name or "?"
					print(string.format("     %-14s <- %-14s <- %-14s hp %.0f", p1, p2, p3, d.Health))
				end
			end
		end
		if n == 0 then print("     no Humanoids at all - dummies may spawn only during a round") end
	end
	return list
end

local function killOne(target, tool)
	local started = os.clock()
	local before = cash()
	state.stopAt = os.clock() + CFG.perTarget

	while os.clock() < state.stopAt and state.running do
		if not target.model.Parent then break end
		if isDown(target.model) then break end
		local c = LP.Character
		if not c then break end
		local t = c:FindFirstChildOfClass("Tool") or tool
		if not t then break end

		local aimed = aimMouse(target.part)
		if not aimed then aimAt(target.part) end
		task.wait(CFG.aimSettle)
		pcall(function() t:Activate() end)
		task.wait(CFG.fireEvery)
	end

	local after = cash()
	local took = os.clock() - started
	return isDown(target.model), (after and before) and (after - before) or 0, took
end

local function run()
	if state.running then return end
	local list = candidates()
	if #list == 0 then
		print("[KillAll] nothing to kill - run .scan()")
		return
	end
	local tool = equippedTool()
	if not tool then
		print("[KillAll] no tool equipped and none in the backpack")
		return
	end

	state.running = true
	local startedAt = os.clock()
	local cashBefore = cash()
	local killed, missed = 0, 0

	print(string.format("[KillAll] %d target(s), tool %s, cash %s", #list, tool.Name, tostring(cashBefore)))

	for i, target in ipairs(list) do
		if not state.running then break end
		if not target.model.Parent or isDown(target.model) then
			-- already down (someone else, or a previous pass): not a failure
			killed = killed + 1
		else
			local ok, delta, took = killOne(target, tool)
			if ok then
				killed = killed + 1
				print(string.format("  %2d/%d  %-10s %.1fs  %+d   %s", i, #list,
					target.model.Name:sub(1, 10), took, delta, snapshot(target.model)))
			else
				missed = missed + 1
				print(string.format("  %2d/%d  %-10s %.1fs  unchanged   %s", i, #list,
					target.model.Name:sub(1, 10), took, snapshot(target.model)))
			end
		end
	end

	state.running = false
	local cashAfter = cash()
	local spent = os.clock() - startedAt
	local earned = (cashAfter and cashBefore) and (cashAfter - cashBefore) or 0
	print(string.format("[KillAll] %d killed, %d survived, %.1fs total · cash %s → %s (%+d)",
		killed, missed, spent, tostring(cashBefore), tostring(cashAfter), earned))
	if killed > 0 and spent > 0 then
		print(string.format("[KillAll] rate: %.1f kills/min, %.0f cash/min",
			killed / spent * 60, earned / spent * 60))
	end
end

-- Records the exact arguments the game sends when you shoot by hand. A fabricated
-- Fire() has to match the real call, and the summary in the hook log ("Vector3,
-- {0}") does not say which vector or what is in the table.
local capturing = false

local function capture(limit)
	if capturing then return print("[KillAll] already capturing") end
	limit = tonumber(limit) or 4
	capturing = true
	local count = 0

	local okHook = pcall(function()
		local old
		old = hookmetamethod(game, "__namecall", function(self, ...)
			local method = getnamecallmethod()
			if capturing and count < limit and (method == "FireServer" or method == "InvokeServer") then
				local name = typeof(self) == "Instance" and self.Name or "?"
				if name == "Fire" or name:find("Fire", 1, true) or name == "PointedAt" then
					local n = select("#", ...)
					local args = { ... }
					local bits = {}
					for i = 1, n do bits[#bits + 1] = deep(args[i], 2) end
					local holder = self.Parent and self.Parent.Name or "?"
					print(string.format("[KillAll] %s.%s(%s)", tostring(holder), name, table.concat(bits, ", ")))
					count = count + 1
					if count >= limit then
						capturing = false
						print("[KillAll] capture complete")
					end
				end
			end
			return old(self, ...)
		end)
	end)

	if not okHook then
		capturing = false
		return print("[KillAll] this executor will not let a script hook __namecall")
	end
	print("[KillAll] capture armed - fire the gun once by hand")
end

local module = {
	scan = scan,
	dump = dumpFolder,
	run = run,
	capture = capture,
	stop = function() state.running = false end,
}
getgenv().KillAll = module

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.F7 then
		run()
	elseif input.KeyCode == Enum.KeyCode.F6 then
		scan()
	end
end)

print("[KillAll] ready. F6 scans, F7 runs. .scan() first - it fires nothing and tells us what counts as a dummy.")
