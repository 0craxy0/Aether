local A = ...

-- shared target filter (whitelist / blacklist by UserId) --------
local TF = { white = {}, black = {} }
A.TF = TF

function TF.mode(plr)
	if TF.white[plr.UserId] then return "white" end
	if TF.black[plr.UserId] then return "black" end
	return nil
end

function TF.set(plr, mode)
	TF.white[plr.UserId] = nil
	TF.black[plr.UserId] = nil
	if mode then TF[mode][plr.UserId] = true end
end

-- UI mask: Drawing visuals never overlay the UI -----------------
local maskGuis = A.maskGuis
-- Drawing and the pointer work in window space; AbsolutePosition starts at the
-- topbar origin. The rectangles below are compared against both, so they are
-- kept in window space.
local INSET = A.guiInset or 0

local function uiRects()
	local out = {}
	for _, g in ipairs(maskGuis) do
		if g.Parent and g.Visible and g.AbsoluteSize.X > 0 and g.AbsoluteSize.Y > 0
			and not (g:IsA("CanvasGroup") and g.GroupTransparency >= 0.99) then
			local p, s = g.AbsolutePosition, g.AbsoluteSize
			out[#out + 1] = { p.X, p.Y + INSET, p.X + s.X, p.Y + INSET + s.Y }
		end
	end
	return out
end

local function uiHitBox(x, y, w, h)
	for _, r in ipairs(uiRects()) do
		if x < r[3] and x + w > r[1] and y < r[4] and y + h > r[2] then return true end
	end
	return false
end

local function uiHitCircle(c, rad)
	for _, r in ipairs(uiRects()) do
		local nx = math.clamp(c.X, r[1], r[3])
		local ny = math.clamp(c.Y, r[2], r[4])
		if (nx - c.X) ^ 2 + (ny - c.Y) ^ 2 <= rad * rad then return true end
	end
	return false
end

-- clips a segment against every UI rect, keeping the longest outside piece
local function uiClipSeg(a, b)
	for _, r in ipairs(uiRects()) do
		local t0, t1 = 0, 1
		local dx, dy = b.X - a.X, b.Y - a.Y
		local p = { -dx, dx, -dy, dy }
		local q = { a.X - r[1], r[3] - a.X, a.Y - r[2], r[4] - a.Y }
		local hit = true
		for i = 1, 4 do
			if p[i] == 0 then
				if q[i] < 0 then hit = false; break end
			else
				local t = q[i] / p[i]
				if p[i] < 0 then
					if t > t1 then hit = false; break end
					if t > t0 then t0 = t end
				else
					if t < t0 then hit = false; break end
					if t < t1 then t1 = t end
				end
			end
		end
		if hit then
			local keepA, keepB = t1, 1
			if t0 >= 1 - t1 then keepA, keepB = 0, t0 end
			if keepB - keepA < 0.001 then return false end
			local na, nb = a + (b - a) * keepA, a + (b - a) * keepB
			a, b = na, nb
		end
	end
	return true, a, b
end

local function uiHitSeg(a, b)
	local ok, a2, b2 = uiClipSeg(a, b)
	return (not ok) or a2 ~= a or b2 ~= b
end

local function uiHitTri(a, b, c)
	return uiHitSeg(a, b) or uiHitSeg(b, c) or uiHitSeg(c, a)
end

-- hides / clips every visible drawing of an ESP set that touches the UI
local function maskSet(set)
	if #uiRects() == 0 then return end
	for k, d in pairs(set) do
		if d.Visible then
			if k == "tracer" or k:match("^c%d$") or k:match("^sk%d+$") then
				local ok, a2, b2 = uiClipSeg(d.From, d.To)
				if ok then
					d.From = a2
					d.To = b2
				else
					d.Visible = false
				end
			else
				local hit = false
				if k == "name" or k == "info" or k == "hpText" then
					local w = #d.Text * d.Size * 0.55
					hit = uiHitBox(d.Position.X - w / 2, d.Position.Y, w, d.Size + 2)
				elseif k == "head" then
					hit = uiHitCircle(d.Position, d.Radius)
				elseif k == "arrow" then
					hit = uiHitTri(d.PointA, d.PointB, d.PointC)
				else
					hit = uiHitBox(d.Position.X, d.Position.Y, d.Size.X, d.Size.Y)
				end
				if hit then d.Visible = false end
			end
		end
	end
end

A.uiRects, A.uiHitBox, A.uiHitCircle = uiRects, uiHitBox, uiHitCircle
A.uiClipSeg, A.uiHitSeg, A.uiHitTri, A.maskSet = uiClipSeg, uiHitSeg, uiHitTri, maskSet

