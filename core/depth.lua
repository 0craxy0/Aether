local A = ...
local RunService, UserInputService, onCleanup = A.RunService, A.UserInputService, A.onCleanup
local window = A.window

-- Depth: the panel is not a flat picture. Its layers sit at slightly different
-- depths, drift against the cursor, and lag behind the shell when it is thrown,
-- so moving the mouse reads as looking *into* the window instead of at it.
local D = {
	enabled = true, amount = 5.5, items = {},
	cx = 0, cy = 0, ix = 0, iy = 0, px = nil, py = nil, rest = false,
}
A.depth = D

-- a layer whose position nothing else owns: its base is captured once
function D.register(obj, depth)
	if not obj then return end
	D.items[#D.items + 1] = { obj = obj, base = obj.Position, depth = depth or 1 }
end

-- a layer something else positions - the shadow is moved by the drag, the throw and
-- the resize. Its offset is added on top of that live position instead of a captured
-- base, or parallax pins it to where the window used to be.
function D.follow(obj, target, depth)
	if not obj or not target then return end
	D.items[#D.items + 1] = { obj = obj, follow = target, depth = depth or 1 }
end

D.follow(A.shadow, window, 1.7)
D.register(A.header, 0.45)
D.register(A.search, 0.6)
D.register(A.body, 0.85)
D.register(A.sidebar, 0.5)
D.register(A.content, 0.4)
D.register(A.toastLayer, 0.35)

local function park()
	if D.rest then return end
	D.rest = true
	for _, it in ipairs(D.items) do
		it.obj.Position = it.follow and it.follow.Position or it.base
	end
end

local function drift(dt)
	local shown = window.Visible and window.GroupTransparency < 0.98

	-- inertia: the contents trail the shell while the window is dragged or thrown
	local wp = window.AbsolutePosition
	if D.px and shown then
		local dx, dy = wp.X - D.px, wp.Y - D.py
		local decay = math.exp(-dt * 10)
		D.ix = math.clamp(D.ix * decay - dx * 0.35, -16, 16)
		D.iy = math.clamp(D.iy * decay - dy * 0.35, -16, 16)
	else
		D.ix, D.iy = 0, 0
	end
	D.px, D.py = wp.X, wp.Y

	local tx, ty = 0, 0
	if D.enabled and shown then
		local ws = window.AbsoluteSize
		local m = UserInputService:GetMouseLocation()
		local my = m.Y - (A.guiInset or 0) -- pointer and AbsolutePosition share a space only after this
		local nx = ((m.X - (wp.X + ws.X / 2)) / math.max(ws.X, 1)) * 2
		local ny = ((my - (wp.Y + ws.Y / 2)) / math.max(ws.Y, 1)) * 2
		tx = -math.clamp(nx, -1.4, 1.4) * D.amount
		ty = -math.clamp(ny, -1.4, 1.4) * D.amount
	end

	local k = 1 - math.exp(-dt * 9)
	D.cx += (tx - D.cx) * k
	D.cy += (ty - D.cy) * k

	local ox, oy = D.cx + D.ix, D.cy + D.iy
	if math.abs(ox) < 0.02 and math.abs(oy) < 0.02 then
		D.cx, D.cy, D.ix, D.iy = 0, 0, 0, 0
		return park()
	end
	D.rest = false
	for _, it in ipairs(D.items) do
		local b = it.follow and it.follow.Position or it.base
		it.obj.Position = UDim2.new(
			b.X.Scale, b.X.Offset + ox * it.depth,
			b.Y.Scale, b.Y.Offset + oy * it.depth
		)
	end
end

local conn = RunService.Heartbeat:Connect(function(dt)
	-- nothing to drift while the panel is behind the hide key
	local win = A.window
	if win and not (win.Visible and win.GroupTransparency < 0.98) then return end
	drift(math.min(dt, 1 / 30))
end)
onCleanup(function() conn:Disconnect() end)
