local A = ...

A.T = {
	bg      = Color3.fromHex("1C1C1E"),
	panel   = Color3.fromHex("242426"),
	raised  = Color3.fromHex("2C2C2E"),
	stroke  = Color3.fromHex("38383A"),
	text    = Color3.fromHex("FFFFFF"),
	muted   = Color3.fromHex("98989D"),
	accent  = Color3.fromHex("0A84FF"),
	accent2 = Color3.fromHex("64D2FF"),
	good    = Color3.fromHex("30D158"),
	warn    = Color3.fromHex("FFD60A"),
	bad     = Color3.fromHex("FF453A"),
}

local function pickFont(name, fallback)
	local ok, f = pcall(function() return Enum.Font[name] end)
	if ok and f then return f end
	return fallback
end

A.FONT = {
	bold = pickFont("BuilderSansBold", Enum.Font.GothamSemibold),
	med = pickFont("BuilderSansMedium", Enum.Font.GothamMedium),
	reg = pickFont("BuilderSans", Enum.Font.Gotham),
}

