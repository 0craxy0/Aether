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
\tperTarget = 2.5,     -- seconds before giving up on one target
	fireEvery = 0.12,    -- seconds between Activate() calls
	aimSettle = 0.05,    -- let the gun notice the new aim before firing
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

-- Every Humanoid that is not us and not another player. Dummies in this game are
-- models with a Humanoid (KillsNpcs is an attribute, so something counts them).
local function candidates()
	local me = LP.Character
	local out = {}
	local origin
	local _, hum = char()
	local root = me and me:FindFirstChild("HumanoidRootPart")
	if root then origin = root.Position end

	for _, d in ipairs(Workspace:GetDescendants()) do
		if d:IsA("Humanoid") and d.Health > 0 then
			local model = d.Parent
			local isPlayer = model and Players:GetPlayerFromCharacter(model) ~= nil
			if model and not isPlayer and model ~= me then
				local hrp = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Head")
				if hrp then
					local dist = origin and (hrp.Position - origin).Magnitude or 0
					if dist <= CFG.maxRange then
						out[#out + 1] = { model = model, hum = d, part = hrp, dist = dist }
					end
				end
			end
		end
	end
	table.sort(out, function(a, b) return a.dist < b.dist end)
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

local function scan()
	local list = candidates()
	print(string.format("[KillAll] %d target(s) in %d studs:", #list, CFG.maxRange))
	for i = 1, math.min(#list, 20) do
		local t = list[i]
		print(string.format("  %2d. %-24s hp %5.0f/%-5.0f  %3.0f studs",
			i, t.model.Name:sub(1, 24), t.hum.Health, t.hum.MaxHealth, t.dist))
	end
	if #list == 0 then
		print("  (none - dummies may only spawn in a round, or they are not Humanoids)")
	end
	return list
end

local function killOne(target, tool)
	local started = os.clock()
	local before = cash()
	state.stopAt = os.clock() + CFG.perTarget

	while os.clock() < state.stopAt and state.running do
		if not target.hum.Parent or target.hum.Health <= 0 then break end
		local c = LP.Character
		if not c then break end
		local t = c:FindFirstChildOfClass("Tool") or tool
		if not t then break end

		aimAt(target.hum.Parent:FindFirstChild("Head") or target.part)
		task.wait(CFG.aimSettle)
		pcall(function() t:Activate() end)
		task.wait(CFG.fireEvery)
	end

	local after = cash()
	local took = os.clock() - started
	return target.hum.Health <= 0, (after and before) and (after - before) or 0, took
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
		if not target.hum.Parent or target.hum.Health <= 0 then
			-- already down (someone else, or a previous pass): not a failure
			killed = killed + 1
		else
			local ok, delta, took = killOne(target, tool)
			if ok then
				killed = killed + 1
				print(string.format("  %2d/%d  %s  %.1fs  %+d", i, #list, target.model.Name:sub(1, 20), took, delta))
			else
				missed = missed + 1
				print(string.format("  %2d/%d  %s  %.1fs  still %.0f hp", i, #list,
					target.model.Name:sub(1, 20), took, target.hum.Health))
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

local module = {
	scan = scan,
	run = run,
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
