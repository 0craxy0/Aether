local A = ...
local RunService, screen = A.RunService, A.screen

-- elastic edge: dragging past the screen edge stretches like rubber, release springs back
-- EL.apply is assigned in core/pagekit.lua once the window and config menus exist
local EL = {
	max = 80, k = 220, c = 15, vx = 0, vy = 0, lt = 0, lx = nil :: any, ly = nil :: any,
	cx = 0, cy = 0, sx = 0.5, sy = 0.5, size = Vector2.zero, active = false, token = 0,
	margin = 56, fr = 1.4, rest = 0.72, simulating = false, rubber = true, physics = true,
	endConn = nil :: any, apply = function(_pos) end,
}
A.EL = EL

function EL.bounds(size)
	local vp = screen.AbsoluteSize
	local hx, hy = math.min(size.X, vp.X) / 2, math.min(size.Y, vp.Y) / 2
	return vp, hx, math.max(vp.X - hx, hx), hy, math.max(vp.Y - hy, hy)
end

function EL.res(raw, lo, hi)
	local m = EL.rubber and math.min(EL.margin, (hi - lo) / 2) or 0
	if m <= 0 then return math.clamp(raw, lo, hi) end
	if raw < lo + m then return math.max(lo + m - m * (1 - math.exp(-(lo + m - raw) / m)), lo) end
	if raw > hi - m then return math.min(hi - m + m * (1 - math.exp(-(raw - hi + m) / m)), hi) end
	return raw
end

function EL.pos(pos, size)
	EL.token += 1
	EL.active = true
	EL.simulating = false
	EL.size = size
	EL.sx, EL.sy = pos.X.Scale, pos.Y.Scale
	local vp, lx, hx, ly, hy = EL.bounds(size)
	local cx = EL.res(vp.X * pos.X.Scale + pos.X.Offset, lx, hx)
	local cy = EL.res(vp.Y * pos.Y.Scale + pos.Y.Offset, ly, hy)
	local now = os.clock()
	if EL.lx == nil then
		EL.lx, EL.ly, EL.lt = cx, cy, now
	elseif now - EL.lt >= 0.004 then
		local dt = now - EL.lt
		EL.vx = EL.vx * 0.65 + (cx - EL.lx) / dt * 0.35
		EL.vy = EL.vy * 0.65 + (cy - EL.ly) / dt * 0.35
		EL.lx, EL.ly, EL.lt = cx, cy, now
	end
	EL.cx, EL.cy = cx, cy
	return UDim2.new(pos.X.Scale, cx - vp.X * pos.X.Scale, pos.Y.Scale, cy - vp.Y * pos.Y.Scale)
end

function EL.grab(pos, size)
	EL.token += 1
	EL.simulating = false
	EL.vx, EL.vy, EL.lx, EL.ly = 0, 0, nil, nil
	EL.size = size
	EL.sx, EL.sy = pos.X.Scale, pos.Y.Scale
	local vp = screen.AbsoluteSize
	EL.cx = vp.X * pos.X.Scale + pos.X.Offset
	EL.cy = vp.Y * pos.Y.Scale + pos.Y.Offset
end

-- release: fling with friction, cushion zone near the edges, hard bounce off the screen edge
function EL.release()
	local vx, vy = EL.vx, EL.vy
	if os.clock() - EL.lt > 0.08 then vx, vy = 0, 0 end
	vx, vy = math.clamp(vx, -4000, 4000), math.clamp(vy, -4000, 4000)
	if not EL.physics then vx, vy = 0, 0 end
	EL.vx, EL.vy, EL.lx, EL.ly = 0, 0, nil, nil
	EL.token += 1
	local id = EL.token
	local x, y = EL.cx, EL.cy
	local sx, sy, size = EL.sx, EL.sy, EL.size
	EL.simulating = true
	local conn
	conn = RunService.Heartbeat:Connect(function(dt)
		if EL.token ~= id then
			conn:Disconnect()
			return
		end
		dt = math.min(dt, 1 / 30)
		local _, lx, hx, ly, hy = EL.bounds(size)
		local mx = EL.rubber and math.min(EL.margin, (hx - lx) / 2) or 0
		local my = EL.rubber and math.min(EL.margin, (hy - ly) / 2) or 0
		local f = math.exp(-EL.fr * dt)
		vx *= f
		vy *= f
		local dxz, dyz = 0, 0
		if x < lx + mx then dxz = lx + mx - x elseif x > hx - mx then dxz = hx - mx - x end
		if y < ly + my then dyz = ly + my - y elseif y > hy - my then dyz = hy - my - y end
		vx += (EL.k * dxz - (dxz ~= 0 and EL.c * vx or 0)) * dt
		vy += (EL.k * dyz - (dyz ~= 0 and EL.c * vy or 0)) * dt
		x += vx * dt
		y += vy * dt
		if x < lx then x = lx; vx = math.abs(vx) * EL.rest end
		if x > hx then x = hx; vx = -math.abs(vx) * EL.rest end
		if y < ly then y = ly; vy = math.abs(vy) * EL.rest end
		if y > hy then y = hy; vy = -math.abs(vy) * EL.rest end
		local v = screen.AbsoluteSize
		EL.apply(UDim2.new(sx, x - v.X * sx, sy, y - v.Y * sy))
		if math.abs(vx) < 10 and math.abs(vy) < 10 and math.abs(dxz) < 0.5 and math.abs(dyz) < 0.5 then
			conn:Disconnect()
			EL.simulating = false
		end
	end)
end

-- keeps a centre-anchored frame fully on screen
function A.clampPos(pos, size)
	local vp = screen.AbsoluteSize
	local hx, hy = math.min(size.X, vp.X) / 2, math.min(size.Y, vp.Y) / 2
	local cx = math.clamp(vp.X * pos.X.Scale + pos.X.Offset, hx, math.max(vp.X - hx, hx))
	local cy = math.clamp(vp.Y * pos.Y.Scale + pos.Y.Offset, hy, math.max(vp.Y - hy, hy))
	return UDim2.new(pos.X.Scale, cx - vp.X * pos.X.Scale, pos.Y.Scale, cy - vp.Y * pos.Y.Scale)
end

