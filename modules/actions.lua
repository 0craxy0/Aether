local A = ...
local notify, onCleanup, has = A.notify, A.onCleanup, A.has
local LP, UserInputService, TeleportService, HttpService = A.LP, A.UserInputService, A.TeleportService, A.HttpService
local charParts = A.charParts

function A.tpTo(plr)
	local _, _, mine = charParts()
	local theirs = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
	if mine and theirs then mine.CFrame = theirs.CFrame * CFrame.new(0, 0, 3) end
end

function A.tpToCursor()
	local _, _, root = charParts()
	local cam = workspace.CurrentCamera
	local loc = UserInputService:GetMouseLocation()
	local ray = cam:ScreenPointToRay(loc.X, loc.Y)
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 2000)
	if root then root.CFrame = CFrame.new((hit and hit.Position or (ray.Origin + ray.Direction * 40)) + Vector3.new(0, 4, 0)) end
end

function A.rejoin()
	TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LP)
end

function A.hop()
	local ok, res = pcall(function()
		return game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100")
	end)
	if not ok then return notify("Server hop", "request failed", "bad") end
	local decoded, data = pcall(function() return HttpService:JSONDecode(res) end)
	if not decoded or type(data) ~= "table" then
		return notify("Server hop", "unexpected response", "bad")
	end
	local pool = {}
	for _, s in ipairs(data.data or {}) do
		if s.id ~= game.JobId and s.playing < s.maxPlayers then pool[#pool + 1] = s.id end
	end
	if #pool == 0 then return notify("Server hop", "no open servers", "bad") end
	TeleportService:TeleportToPlaceInstance(game.PlaceId, pool[math.random(#pool)], LP)
end

-- auto-execute on teleport -------------------------------------
-- saveConfig / loadConfig are placeholders here. The tail files replace them
-- by assigning A.saveConfig / A.loadConfig, and everything below reads them through A.
function A.saveConfig() end
function A.loadConfig() end

local queueFn = queue_on_teleport or queueonteleport or (syn and syn.queue_on_teleport) or (fluxus and fluxus.queue_on_teleport)
local tpConn

-- The queue string is executed on a *later* server, after this one is gone and
-- nothing here can check it again, so the only URL it may carry is one this
-- loader chose. getgenv().AetherSource is writable by any other script in the
-- executor: honouring it unvalidated meant anything that set it could make
-- Aether re-run its own code on every teleport. Plain http is refused as well -
-- that string is a download, and a downgraded one is MITM-able.
local function ownSource(raw)
	if type(raw) ~= "string" then return nil end
	local scheme, host = raw:match("^(https)://([^/]+)/")
	if not scheme then return nil end
	local baseHost = (A.base or ""):match("^https://([^/]+)/")
	if not baseHost or host ~= baseHost then return nil end
	return raw
end

local function buildQueue()
	local src = ownSource(A.source) or ownSource(getgenv and getgenv().AetherSource)
	if src then
		return string.format("loadstring(game:HttpGet(%q))()", src)
	end
	if has.isfile and isfile("Aether/aether.lua") then
		return 'loadstring(readfile("Aether/aether.lua"))()'
	end
end

function A.setAutoExec(on)
	if tpConn then tpConn:Disconnect(); tpConn = nil end
	if not on then return end
	if not queueFn then return notify("Auto-execute", "queue_on_teleport unsupported", "bad") end
	local code = buildQueue()
	if not code then
		return notify("Auto-execute", "no valid source (must be an https URL on Aether's own host)", "bad")
	end
	tpConn = LP.OnTeleport:Connect(function(st)
		if st == Enum.TeleportState.Started then
			pcall(A.saveConfig)
			pcall(queueFn, "getgenv().AetherResume=true;" .. code)
		end
	end)
end
onCleanup(function() if tpConn then tpConn:Disconnect() end end)

function A.copy(text)
	if setclipboard then
		setclipboard(text)
		notify("Copied", tostring(text), "good")
	else
		notify("Clipboard", "unavailable", "bad")
	end
end

